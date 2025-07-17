defmodule ExStaticWeb.PageController do
  use ExStaticWeb, :controller

  alias ExStatic.Blog

  def home(conn, _params) do
    render(conn, :home, posts: Blog.all_posts())
  end

  def about(conn, _params) do
    render(conn, :about)
  end
end
