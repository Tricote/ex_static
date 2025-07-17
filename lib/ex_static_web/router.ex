defmodule ExStaticWeb.Router do
  use ExStaticWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExStaticWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ExStaticWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/about", PageController, :about
    get "/other", PageController, :other

    get "/blog", BlogController, :index
    get "/blog/:id", BlogController, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", ExStaticWeb do
  #   pipe_through :api
  # end
end
