defmodule ExStaticWeb.PageController do
  use ExStaticWeb, :controller

  alias ExStatic.Blog

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, posts: Blog.all_posts())
  end

  def other(conn, _params) do
    render(conn, :other)
  end

  def about(conn, _params) do
    render(conn, :about)
  end
end
