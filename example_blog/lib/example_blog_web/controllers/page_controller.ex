defmodule ExampleBlogWeb.PageController do
  use ExampleBlogWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
