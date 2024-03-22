defmodule ExStatic.Toc do
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
