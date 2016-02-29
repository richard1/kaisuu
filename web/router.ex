defmodule Kaisuu.Router do
  use Kaisuu.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Kaisuu do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
  end

  scope "/tag", Kaisuu do
    pipe_through :browser

    get "/", HashtagController, :index
    get "/:hashtag", HashtagController, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", Kaisuu do
  #   pipe_through :api
  # end
end
