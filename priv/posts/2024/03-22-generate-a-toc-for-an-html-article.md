%{
  title: "A Phoenix component to display a Table of Content (TOC) for an html document",
  author: "Tricote",
  tags: ~w(Phoenix)
}
---

A table of contents (TOC) is the list of links to sections (headings) of a document. It helps to better navigate large documents. But it would be obviously painful to write this by hand, so here is a Phoenix Component to automatically generate and display a TOC for any HTML document.

## High level overview {: #overview}

The idea is to parse the html document to produce a `Toc` Struct based on the document headings **that have an id attribute** (ids are required to build the anchor links to the headings).

The `Toc` Struct is a tree-like structure to reflect the levels of the headings in the table of content: for instance `<h3>` tags located after `<h2>` in the document will be represented as children `Toc` struct of the parent `<h2>`'s `Toc` struct.

```elixir
[
  %Toc{id: "foo", title: "Hello", toc_level: 1, children: [
    %Toc{id: "bar", title: "Crazy", toc_level: 2, children: []},
    %Toc{id: "baz", title: "World", toc_level: 2, children: []}
  ]},
  %Toc{id: "boo", title: "Byebye", toc_level: 1, children: []}
]
```

The `TocComponent` uses this `Toc` Struct to to build the HTML table of content.

The output of the component looks like this (notice the nested `<ul>` tags to reflect the different headings levels) :

```html
<ul class="toc">
  <li><a href="#heading-1">Heading 1</a></li>
  <li><a href="#heading-2">Heading 2</a>
    <ul class="toc">
      <li><a href="#heading-2.1">Heading 2.1</a></li>
      <li><a href="#heading-2.2">Heading 2.2</a></li>
    </ul>
  </li>
  <li><a href="#heading-3">Heading 3</a></li>
</ul>
```

## The code {: #code}

The module that builds the `Toc` Struct from the HTML document.

```elixir
defmodule CMS.Toc do
  @enforce_keys [:id, :title, :toc_level]
  defstruct [:id, :title, :toc_level, children: []]

  @doc """
  Build Table Of Content (TOC) from an html document.

  Parse all headings tags (h1, h2, ...) and produce a recursive
  TOC Struct that can be used to create a HTML TOC

  ## Examples:
      iex> build_from_html("<h1 id='foo'>Hello</h1><h1 id='bar'>World</h1>")
      [
        %Toc{id: "foo", title: "Hello", toc_level: 1, children: []},
        %Toc{id: "bar", title: "World", toc_level: 1, children: []}
      ]

      iex> build_from_html(~s(
      ...>   <h1 id='foo'>Hello</h1>
      ...>     <h2 id='bar'>Crazy</h2>
      ...>     <h2 id='baz'>World</h2>
      ...>   <h1 id='boo'>Byebye</h1>
      ...>  ))
      [
        %Toc{id: "foo", title: "Hello", toc_level: 1, children: [
          %Toc{id: "bar", title: "Crazy", toc_level: 2, children: []},
          %Toc{id: "baz", title: "World", toc_level: 2, children: []}
        ]},
        %Toc{id: "boo", title: "Byebye", toc_level: 1, children: []}
      ]
  """
  def build_from_html(html) do
    {:ok, document} = Floki.parse_document(html)

    find_headers(document)
    |> Enum.reduce([], &handle_heading/2)
  end

  defp find_headers(document) do
    document
    |> Floki.find("*")
    |> Enum.filter(&match?({name, _attrs, _nodes} when name in ~w(h1 h2 h3 h4 h5), &1))
  end

  defp handle_heading(heading_tuple, toc_items_list_acc)

  defp handle_heading({tag, attributes, [title]}, toc_items_list_acc) do
    case Enum.find(attributes, {:no_id, nil}, &match?({"id", _}, &1)) do
      {:no_id, nil} ->
        toc_items_list_acc

      {_, id} ->
        toc_item = %__MODULE__{
          id: id,
          title: title,
          toc_level: get_toc_level(tag),
          children: []
        }

        add_toc_item(toc_item, toc_items_list_acc)
    end
  end

  defp add_toc_item(toc_item, []), do: [toc_item]

  defp add_toc_item(toc_item, toc_items_list) do
    [last_toc_item | previous_toc_items] = toc_items_list |> Enum.reverse()

    last_toc_level = last_toc_item.toc_level

    case toc_item.toc_level do
      toc_level when toc_level > last_toc_level ->
        last_toc_item = %{
          last_toc_item
          | children: Map.get(last_toc_item, :children) ++ [toc_item]
        }

        previous_toc_items ++ [last_toc_item]

      toc_level when toc_level <= last_toc_level ->
        toc_items_list ++ [toc_item]
    end
  end

  defp get_toc_level(tag) do
    {heading_level, _} = Integer.parse(String.last(tag))
    heading_level
  end
end

```

And the related Phoenix component:

```elixir
defmodule CMS.TocComponent do
  use Phoenix.Component

  @doc """
  Renders a Table of Content

  ## Examples

      <.toc toc_items={toc_items} />
      <.toc toc_items={toc_items} max_level={1} wrapper_class="toc" item_class="mb-2" />
  """
  attr(:toc_items, :any, required: true)
  attr(:max_heading_level, :any, default: 2)
  attr(:wrapper_class, :string, default: "")
  attr(:item_class, :string, default: "")

  def toc(assigns) do
    ~H"""
    <ul :if={!Enum.empty?(@toc_items)} class={[@wrapper_class]}>
      <%= for toc_item <- @toc_items do %>
        <%= render_toc_item(assigns, toc_item) %>
      <% end %>
    </ul>
    """
  end

  defp render_toc_item(assigns, toc_item) do
    assigns = assign(assigns, :toc_item, toc_item)

    ~H"""
    <li :if={@toc_item.toc_level <= @max_heading_level} class={[@item_class]}>
      <.link href={"#" <> @toc_item.id}><%= @toc_item.title %></.link>
      <ul
        :if={!Enum.empty?(@toc_item.children) and @toc_item.toc_level < @max_heading_level}
        class={[@wrapper_class]}
      >
        <%= for child_toc_item <- @toc_item.children do %>
          <%= render_toc_item(assigns, child_toc_item) %>
        <% end %>
      </ul>
    </li>
    """
  end
end
```

Note that it is somehow a "recursive component".

## Usage exmemple {: #usage}

Build the `Toc` in your controller:

```elixir
defmodule MyAppWeb.ArticleController do
  use CancerConsultWeb, :controller
  # ...
  alias CancerConsult.Articles.Toc

  def show(conn, params) do
    acrticle_content = "<h1 ...>....<h1>"
    toc_items = Toc.build_from_html(acrticle_content)

    conn
    |> render(:show,
      content: content,
      toc_items: toc_items
    )
  end
end
```

And use the component in your heex template:

```html
<TocComponent.toc toc_items={@toc_items} max_heading_level={3} />
```