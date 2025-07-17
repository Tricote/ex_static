%{
  title: "Phoenix LiveView File Uploads with auto-recovery on server restarts",
  author: "Tricote",
  tags: ~w(Phoenix)
}
---

While Phoenix LiveView handles many aspects of file uploads elegantly, managing server restarts and deploys on forms with uploads is not completely handled by default. The auto-recovery mechanism works well for regular form fields so that if a server restart occurs while a user is filling out a form, all the standard fields are recovered automatically. However, file uploads are not.

In this post, I'll walk through a robust approach to managing file uploads in LiveView that survive server restarts and provide a seamless user experience.

We'll build a blog post system with document uploads using a step-by-step approach. Each `Post` can have multiple associated `Document` files that users can upload through both "new" and "edit" forms. Starting with basic upload functionality, we'll progressively add auto-recovery and cleanup mechanisms.

Note that we'll use the `Waffle` and `Waffle.Ecto` libraries to handle file uploads.


## Step 1: Basic File Upload and Association {: #file-upload}

First, let's set up our schemas and implement the basic file upload functionality. We'll create a `Post` schema with associated `Document` records.

### Schema Setup

```elixir
defmodule MyApp.Blog.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "blog_posts" do
    field :title, :string
    field :content, :string

    has_many :documents, MyApp.Blog.Document,
      on_replace: :delete,
      foreign_key: :post_id,
      preload_order: [desc: :inserted_at]

    belongs_to :author, MyApp.Accounts.User

    timestamps()
  end

  def changeset(post, attrs, documents \\ nil) do
    post
    |> cast(attrs, [:title, :content])
    |> validate_required([:title, :content])
    |> maybe_put_documents(documents)
  end

  defp maybe_put_documents(changeset, nil), do: changeset
  defp maybe_put_documents(changeset, documents) when is_list(documents) do
    put_assoc(changeset, :documents, documents)
  end
end
```

```elixir
defmodule MyApp.Blog.Document do
  use Ecto.Schema
  use Waffle.Ecto.Schema
  import Ecto.Changeset

  schema "blog_documents" do
    field :file, MyApp.Blog.DocumentFile.Type
    belongs_to :post, MyApp.Blog.Post
    belongs_to :creator, MyApp.Accounts.User

    timestamps()
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [])
    |> validate_required([:creator_id])
  end

  def file_changeset(document, attrs) do
    document
    |> cast_attachments(attrs, [:file])
    |> validate_required([:file])
  end
end
```

```elixir
defmodule MyApp.Blog.DocumentFile do
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  def storage_dir(_version, {_file, document}) do
    "uploads/blog_documents/#{document.id}"
  end
end
```

### Context Functions

Let's add the core functions in our context module to handle document creation and post management:

```elixir
defmodule MyApp.Blog do
  import Ecto.Query
  alias MyApp.Repo
  alias MyApp.Blog.Post
  alias MyApp.Blog.Document
  alias MyApp.Blog.DocumentFile
  require Logger

  # Basic Post CRUD operations
  def get_post!(id) do
    Post
    |> Repo.get!(id)
    |> preload_associations([:documents])
  end

  def preload_associations(post_or_posts, preloads \\ [:documents]) do
    Repo.preload(post_or_posts, preloads)
  end

  def create_post(attrs, documents, %{id: author_id}) do
    %Post{author_id: author_id}
    |> Post.changeset(attrs, documents)
    |> Repo.insert()
  end

  def update_post(%Post{} = post, attrs, documents \\ nil) do
    post
    |> Post.changeset(attrs, documents)
    |> Repo.update()
  end

  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  def get_document!(id) do
    Document
    |> where([d], d.id == ^id)
    |> Repo.one!()
  end

  # Document creation function
  def create_unattached_document(attrs \\ %{}, %{id: creator_id}) do
    changeset =
      %Document{creator_id: creator_id}
      |> Document.changeset(attrs)

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:document, changeset)
      |> Ecto.Multi.update(
        :document_with_file,
        &Document.file_changeset(&1.document, attrs)
      )
      |> Repo.transaction()

    case result do
      {:ok, %{document_with_file: document}} -> {:ok, document}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end
end
```

Note that the `create_unattached_document/2` function has two steps:

* first it creates the document entry in the DB,
* then it uploads the file to the storage backend. 

This allows to use the document ID in the storage directory with Waffle. This process is explained in the Waffle documentation here: [How to use :id in filepath](https://hexdocs.pm/waffle_ecto/filepath-with-id.html)


### LiveView Implementation

Now, let's create the LiveView module to handle blog post creation with file uploads:

```elixir
defmodule MyAppWeb.BlogLive.Form do
  use MyAppWeb, :live_view
  require Logger

  alias MyApp.Blog
  alias MyApp.Blog.Post

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:document,
       accept: ~w(.pdf .jpg .png),
       max_entries: 5,
       max_file_size: 10_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    current_user = socket.assigns.current_user
    post = %Post{
      author_id: current_user.id,
      documents: []
    }

    socket
    |> assign(:page_title, "New Blog Post")
    |> assign(:post, post)
    |> assign(:documents, [])
    |> assign(:form, to_form(Blog.change_post(post)))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    post = Blog.get_post!(id)

    socket
    |> assign(:page_title, "Edit Blog Post")
    |> assign(:post, post)
    |> assign(:documents, post.documents)
    |> assign(:form, to_form(Blog.change_post(post)))
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    changeset =
      Blog.change_post(socket.assigns.post, post_params)

    {:noreply,
     socket
     |> assign(form: to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("save", %{"post" => post_params}, socket) do
    save_post(socket, socket.assigns.live_action, post_params)
  end

  @impl true
  def handle_event("delete-document", %{"id" => document_id}, socket) do
    post = socket.assigns.post
    documents = socket.assigns.documents

    document_to_delete = Blog.get_document!(document_id)

    # Remove from documents list
    documents = Enum.reject(documents, &(&1.id == document_to_delete.id))

    {:noreply, assign(socket, :documents, documents)}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :document, ref)}
  end

  defp handle_progress(:document, entry, socket) do
    if entry.done? do
      Logger.debug("Upload finished")

      document =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          upload = %Plug.Upload{
            content_type: entry.client_type,
            filename: entry.client_name,
            path: path
          }

          {:ok, document} =
            Blog.create_unattached_document(%{"file" => upload}, socket.assigns.current_user)

          document
        end)

      {:noreply,
       socket
       |> update(:documents, &(&1 ++ [document]))}
    else
      {:noreply, socket}
    end
  end

  defp save_post(socket, :edit, post_params) do
    case Blog.update_post(
           socket.assigns.post,
           post_params,
           socket.assigns.documents
         ) do
      {:ok, post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post updated successfully")
         |> push_navigate(to: ~p"/blog/posts/#{post}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_post(socket, :new, post_params) do
    current_user = socket.assigns.current_user

    case Blog.create_post(
           post_params,
           socket.assigns.documents,
           current_user
         ) do
      {:ok, post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post created successfully")
         |> push_navigate(to: ~p"/blog/posts/#{post}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "Unacceptable file type (PDF, JPG, PNG only)"
  defp error_to_string(:too_many_files), do: "Too many files selected"
end
```

The `consume_uploaded_entry/3` function creates documents immediately upon upload, but these remain unattached to any blog post (which may not even exist yet during the `new` action). The actual association happens later when the user saves the form.

When the save button is clicked, the `create_post/3` or `update_post/3` functions link the uploaded documents to the Post using `put_assoc(changeset, :documents, socket.assigns.documents)`. The `on_replace: :delete` option in the Post schema ensures that documents removed from the `socket.assigns.documents` list are properly deleted from the database and from the storage.

However, documents that are uploaded but then removed _before saving the Post_ will remain in the database and storage as "orphan documents" until a cleanup process removes them.


### Basic Template with Upload UI

Here's our the raw LiveView template

```html
<.form for={@form} phx-change="validate" phx-submit="save">
  <.input field={@form[:title]} type="text" label="Title" required />
  <.input field={@form[:content]} type="textarea" label="Content" required />

  <h3>Documents</h3>
  <div phx-drop-target={@uploads.document.ref}>
    <.live_file_input upload={@uploads.document} />

    <div>
      <%= for err <- upload_errors(@uploads.document) do %>
        <div class="alert alert-danger">
          {error_to_string(err)}
        </div>
      <% end %>
    </div>

    <div>
      <%= for entry <- @uploads.document.entries do %>
        <div>
          <div>
            {entry.client_name}
          </div>
          <div>
            <div
              role="progressbar"
              style={"width: #{entry.progress}%"}
              aria-valuenow={entry.progress}
              aria-valuemin="0"
              aria-valuemax="100"
            >
              {entry.progress}%
            </div>
          </div>
        </div>
      <% end %>
    </div>

    <h3>Uploaded Files</h3>
    <%= for document <- @documents do %>
      <div>{document.file.file_name}</div>
      <button
          type="button"
          phx-click="delete-document"
          phx-value-id={document.id}
        >
        Delete document
      </button>
    <% end %>
  </div>

  <div class="">
    <button type="submit">Save</button>
  </div>
</.form>
```

## Step 2: Adding Auto-Recovery Mechanism {: #auto-recover}

Our current implementation has a problem: if a server restart occurs while a user has uploaded documents but hasn't saved the post yet, the `socket.assigns.documents` list is lost, causing the user to lose their uploaded (or "to be deleted") files.

While other `Post` fields are automatically recovered through LiveView's standard form recovery mechanism (the client resends all form data and triggers the `validate` event on reconnect), this doesn't work for documents since they aren't represented by form input fields.

The solution is to add hidden input fields containing the document IDs currently in `socket.assigns.documents`, allowing us to recover the uploaded documents during the form validation process.


```html
<.form for={@form} phx-change="validate" phx-submit="save">
  <%= for document <- @documents do %>
    <input type="hidden" name="autorecover_document_ids[]" value={document.id} />
  <% end %>
<!-- rest of the form -->
 </.form>
```


```elixir
defmodule MyAppWeb.BlogLive.Form do
  # ... existing code

  @impl true
  def handle_event("validate", %{"post" => post_params} = params, socket) do
    # Handle autorecovery of documents
    documents =
      recover_documents(
        socket.assigns.documents,
        Map.get(params, "autorecover_document_ids", []),
        socket.assigns.current_user
      )

    changeset =
      Blog.change_post(socket.assigns.post, post_params)

    {:noreply,
     socket
     |> assign(form: to_form(changeset, action: :validate))
     |> assign(:documents, documents)}
  end

  # Auto-recovery mechanism
  defp recover_documents(documents, autorecover_document_ids, current_user) do
    autorecover_document_ids
    |> Enum.reduce(documents, fn document_id, acc ->
      case Enum.find(acc, &(&1.id == document_id)) do
        nil ->
          # If document not in list, fetch it from database
          # Only if created by current user (security check)
          document = Blog.get_document!(document_id)

          if document.creator_id == current_user.id do
            Logger.debug("Recovering document #{document_id} for creator #{document.creator_id}")
            acc ++ [document]
          else
            acc
          end

        _ ->
          # Document already in list
          acc
      end
    end)
  end
end
```

As a security measure, we verify that recovered documents were uploaded by the current user, preventing unauthorized access to documents uploaded by other users.

## Step 3: Adding Cleanup for Orphaned Documents {: #cleanup}

Now we need to implement a cleanup mechanism to handle orphaned documents - files that were uploaded but never associated with a blog post.

These orphaned documents can occur in several scenarios:
- A user uploads files but abandons the form without saving
- A user uploads files, removes them from the UI, then saves the post

Since these documents exist in both the database and storage but aren't linked to any post, they consume resources unnecessarily and should be periodically cleaned up.

```elixir
defmodule MyApp.Blog do
  # ...

  def list_orphan_documents(opts \\ []) do
    count = Keyword.get(opts, :count, 3)
    interval = Keyword.get(opts, :interval, "day")

    Document
    |> where([d], is_nil(d.post_id))
    |> where([d], d.inserted_at < ago(^count, ^interval))
    |> Repo.all()
  end

  def delete_orphan_documents(opts \\ []) do
    orphan_documents = list_orphan_documents(opts)
    Logger.info("Deleting #{length(orphan_documents)} orphan documents")

    orphan_documents
    |> Enum.each(fn document ->
      Logger.info("Deleting orphan document #{document.id}")
      :ok = DocumentFile.delete({document.file, document})
      Repo.delete(document)
    end)

    Logger.info("Deleted #{length(orphan_documents)} orphan documents")
  end
end
```

Create an Oban worker to perform the cleanup:

```elixir
defmodule MyApp.Workers.CleanupOrphanDocuments do
  use Oban.Worker, queue: :maintenance
  require Logger

  alias MyApp.Blog

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Starting cleanup of orphaned documents")
    Blog.delete_orphan_documents()
    :ok
  end
end
```

Configure the job to run periodicaly:

```elixir
# In your config
config :my_app, Oban,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"0 3 * * *", MyApp.Workers.CleanupOrphanDocuments}
     ]}
  ]
```

## Key Takeaways

This approach provides a robust solution for handling file uploads in Phoenix LiveView applications. The key principles are:

1. **Upload immediately, associate later**: Create documents and store files as soon as they're uploaded, then link them to posts only when the form is saved
2. **Implement auto-recovery**: Use hidden form inputs to preserve document IDs across server restarts
3. **Add security checks**: Always verify file ownership during recovery to prevent unauthorized access
4. **Schedule cleanup jobs**: Regularly remove orphaned documents to prevent storage bloat

This pattern ensures users never lose their uploaded files due to server restarts or connectivity issues, providing a seamless and reliable file upload experience in LiveView applications.
