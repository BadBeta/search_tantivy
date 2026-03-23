defmodule ExampleBlogWeb.Router do
  use ExampleBlogWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExampleBlogWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", ExampleBlogWeb do
    pipe_through :browser

    live "/", BlogLive
    live "/article/:slug", BlogLive
  end
end
