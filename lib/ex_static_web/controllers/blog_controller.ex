defmodule ExStaticWeb.BlogController do
  use ExStaticWeb, :controller

  alias ExStatic.Blog
  alias ExStatic.Toc

  def index(conn, _params) do
    render(conn, "index.html", posts: Blog.all_posts())
  end

  def show(conn, %{"id" => id}) do
    post = Blog.get_post_by_id!(id)
    toc_items = Toc.build_from_html(post.body) |> IO.inspect()

    render(conn, "show.html", page_title: post.title, post: post, toc_items: toc_items)
  end
end
