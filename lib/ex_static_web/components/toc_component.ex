defmodule ExStaticWeb.TocComponent do
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
