defmodule ExampleBlogWeb.BlogLive do
  use ExampleBlogWeb, :live_view

  alias ExampleBlog.Blog

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       articles: Blog.articles(),
       search_query: "",
       search_results: [],
       search_open: false,
       selected_category: nil
     )}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _uri, socket) do
    case Blog.get_article_by_slug(slug) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Article not found")
         |> push_navigate(to: ~p"/")}

      article ->
        {:noreply,
         assign(socket,
           page_title: article.title,
           view: :article,
           article: article
         )}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     assign(socket,
       page_title: "Craft & Code",
       view: :index,
       article: nil
     )}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    results = Blog.search(query)

    {:noreply,
     assign(socket,
       search_query: query,
       search_results: results,
       search_open: query != ""
     )}
  end

  def handle_event("close_search", _params, socket) do
    {:noreply, assign(socket, search_open: false, search_query: "", search_results: [])}
  end

  def handle_event("filter_category", %{"category" => category}, socket) do
    selected =
      if socket.assigns.selected_category == category,
        do: nil,
        else: category

    {:noreply, assign(socket, selected_category: selected)}
  end

  # --- Rendering ---

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
      <.navbar search_query={@search_query} search_open={@search_open} search_results={@search_results} />

      <%= if @view == :index do %>
        <.hero />
        <.article_grid
          articles={@articles}
          selected_category={@selected_category}
        />
      <% else %>
        <.article_detail article={@article} />
      <% end %>

      <.footer />
    </div>
    """
  end

  # --- Components ---

  defp navbar(assigns) do
    ~H"""
    <nav class="sticky top-0 z-50 bg-base-100/80 backdrop-blur-lg border-b border-base-300">
      <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16">
          <.link navigate={~p"/"} class="flex items-center gap-2 group">
            <span class="text-2xl">&#9998;</span>
            <span class="text-xl font-bold tracking-tight text-base-content group-hover:text-primary transition-colors">
              Craft & Code
            </span>
          </.link>

          <div class="relative">
            <form phx-change="search" phx-submit="search" class="relative">
              <div class="flex items-center">
                <.icon name="hero-magnifying-glass" class="size-4 text-base-content/50 absolute left-3 pointer-events-none" />
                <input
                  type="text"
                  name="query"
                  value={@search_query}
                  placeholder="Search articles..."
                  phx-debounce="200"
                  autocomplete="off"
                  class="input input-bordered input-sm w-48 sm:w-64 pl-9 bg-base-200/50 focus:bg-base-100 transition-all"
                />
                <%= if @search_query != "" do %>
                  <button
                    type="button"
                    phx-click="close_search"
                    class="absolute right-2 text-base-content/50 hover:text-base-content"
                  >
                    <.icon name="hero-x-mark" class="size-4" />
                  </button>
                <% end %>
              </div>
            </form>

            <%= if @search_open do %>
              <.search_dropdown results={@search_results} query={@search_query} />
            <% end %>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  defp search_dropdown(assigns) do
    ~H"""
    <div class="absolute right-0 top-full mt-2 w-96 max-h-[70vh] overflow-y-auto bg-base-100 border border-base-300 rounded-xl shadow-2xl z-50">
      <%= if @results == [] do %>
        <div class="p-6 text-center text-base-content/60">
          <.icon name="hero-magnifying-glass" class="size-8 mx-auto mb-2 opacity-40" />
          <p class="text-sm">No results for "<span class="font-medium">{@query}</span>"</p>
        </div>
      <% else %>
        <div class="p-2">
          <p class="px-3 py-1 text-xs font-medium text-base-content/50 uppercase tracking-wider">
            {length(@results)} result{if length(@results) != 1, do: "s"}
          </p>
          <div class="space-y-1 mt-1">
            <%= for result <- @results do %>
              <.link
                navigate={~p"/article/#{result.slug}"}
                class="block p-3 rounded-lg hover:bg-base-200 transition-colors group"
              >
                <div class="flex items-start gap-3">
                  <.category_dot category={result.category} />
                  <div class="flex-1 min-w-0">
                    <p class="font-medium text-sm text-base-content group-hover:text-primary transition-colors truncate">
                      {result.title}
                    </p>
                    <%= if result.highlight do %>
                      <p class="text-xs text-base-content/60 mt-1 line-clamp-2">
                        {Phoenix.HTML.raw(result.highlight)}
                      </p>
                    <% end %>
                    <span class="text-xs text-base-content/40 capitalize">{format_category(result.category)}</span>
                  </div>
                </div>
              </.link>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp hero(assigns) do
    ~H"""
    <section class="py-16 sm:py-24 px-4">
      <div class="max-w-4xl mx-auto text-center">
        <h1 class="text-4xl sm:text-5xl font-bold tracking-tight text-base-content">
          Where Traditional Craft
          <br />
          <span class="text-primary">Meets Modern Code</span>
        </h1>
        <p class="mt-6 text-lg text-base-content/70 max-w-2xl mx-auto leading-relaxed">
          Stories about handtools, horses, Elixir, and the web frameworks that bring it all together. Powered by
          <.link
            href="https://github.com/quickwit-oss/tantivy"
            class="font-medium text-primary hover:underline"
            target="_blank"
          >
            tantivy
          </.link>
          full-text search.
        </p>
      </div>
    </section>
    """
  end

  defp article_grid(assigns) do
    categories = ["handtools", "horses", "web-frameworks", "elixir"]

    filtered =
      if assigns.selected_category do
        Enum.filter(assigns.articles, &(&1.category == assigns.selected_category))
      else
        assigns.articles
      end

    assigns = assign(assigns, categories: categories, filtered_articles: filtered)

    ~H"""
    <section class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 pb-20">
      <div class="flex flex-wrap gap-2 mb-10 justify-center">
        <%= for cat <- @categories do %>
          <button
            phx-click="filter_category"
            phx-value-category={cat}
            class={[
              "px-4 py-2 rounded-full text-sm font-medium transition-all cursor-pointer",
              if(@selected_category == cat,
                do: "bg-primary text-primary-content shadow-md",
                else: "bg-base-200 text-base-content/70 hover:bg-base-300"
              )
            ]}
          >
            {format_category(cat)}
          </button>
        <% end %>
        <%= if @selected_category do %>
          <button
            phx-click="filter_category"
            phx-value-category={@selected_category}
            class="px-4 py-2 rounded-full text-sm font-medium bg-base-200 text-base-content/50 hover:bg-base-300 transition-all cursor-pointer"
          >
            Clear filter
          </button>
        <% end %>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= for article <- @filtered_articles do %>
          <.article_card article={article} />
        <% end %>
      </div>
    </section>
    """
  end

  defp article_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/article/#{@article.slug}"}
      class="group block bg-base-100 border border-base-300 rounded-xl overflow-hidden hover:shadow-lg hover:border-primary/30 transition-all duration-300"
    >
      <div class={"h-2 #{category_gradient(@article.category)}"} />
      <div class="p-6">
        <div class="flex items-center gap-2 mb-3">
          <span class={"inline-block px-2.5 py-0.5 rounded-full text-xs font-medium #{category_badge(@article.category)}"}>
            {format_category(@article.category)}
          </span>
          <span class="text-xs text-base-content/40">{@article.reading_time} min read</span>
        </div>
        <h2 class="text-lg font-semibold text-base-content group-hover:text-primary transition-colors leading-snug mb-2">
          {@article.title}
        </h2>
        <p class="text-sm text-base-content/60 leading-relaxed line-clamp-3">
          {@article.summary}
        </p>
        <div class="mt-4 flex items-center text-xs text-base-content/40">
          <span>{@article.author}</span>
          <span class="mx-2">&middot;</span>
          <span>{@article.date}</span>
        </div>
      </div>
    </.link>
    """
  end

  defp article_detail(assigns) do
    paragraphs =
      assigns.article.body
      |> String.split("\n\n", trim: true)
      |> Enum.map(&String.trim/1)

    assigns = assign(assigns, paragraphs: paragraphs)

    ~H"""
    <article class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <.link navigate={~p"/"} class="inline-flex items-center gap-1 text-sm text-base-content/50 hover:text-primary transition-colors mb-8">
        <.icon name="hero-arrow-left" class="size-4" />
        Back to articles
      </.link>

      <header class="mb-10">
        <div class="flex items-center gap-2 mb-4">
          <span class={"inline-block px-3 py-1 rounded-full text-xs font-medium #{category_badge(@article.category)}"}>
            {format_category(@article.category)}
          </span>
          <span class="text-sm text-base-content/40">{@article.reading_time} min read</span>
        </div>
        <h1 class="text-3xl sm:text-4xl font-bold tracking-tight text-base-content leading-tight">
          {@article.title}
        </h1>
        <p class="mt-4 text-lg text-base-content/60 leading-relaxed">
          {@article.summary}
        </p>
        <div class="mt-6 flex items-center gap-3 text-sm text-base-content/50">
          <div class="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
            <span class="text-primary font-medium text-xs">
              {String.first(@article.author)}
            </span>
          </div>
          <div>
            <p class="font-medium text-base-content">{@article.author}</p>
            <p>{@article.date}</p>
          </div>
        </div>
      </header>

      <div class={"w-full h-1 rounded #{category_gradient(@article.category)} mb-10"} />

      <div class="prose prose-lg max-w-none">
        <%= for paragraph <- @paragraphs do %>
          <p class="text-base-content/80 leading-relaxed mb-6">
            {paragraph}
          </p>
        <% end %>
      </div>
    </article>
    """
  end

  defp footer(assigns) do
    ~H"""
    <footer class="border-t border-base-300 py-10 mt-10">
      <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 text-center text-sm text-base-content/40">
        <p>
          Craft & Code &mdash; A <span class="font-medium text-primary/60">SearchTantivy</span> demo.
          Full-text search powered by
          <.link href="https://github.com/quickwit-oss/tantivy" target="_blank" class="underline hover:text-primary">tantivy</.link>.
        </p>
      </div>
    </footer>
    """
  end

  # --- Helpers ---

  defp category_dot(assigns) do
    ~H"""
    <span class={"mt-1 w-2 h-2 rounded-full shrink-0 #{category_dot_color(@category)}"} />
    """
  end

  defp format_category("web-frameworks"), do: "Web Frameworks"
  defp format_category(cat), do: String.capitalize(cat)

  defp category_gradient("handtools"), do: "bg-gradient-to-r from-amber-500 to-orange-500"
  defp category_gradient("horses"), do: "bg-gradient-to-r from-emerald-500 to-teal-500"
  defp category_gradient("web-frameworks"), do: "bg-gradient-to-r from-violet-500 to-purple-500"
  defp category_gradient("elixir"), do: "bg-gradient-to-r from-indigo-500 to-blue-500"
  defp category_gradient(_), do: "bg-gradient-to-r from-gray-400 to-gray-500"

  defp category_badge("handtools"), do: "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300"
  defp category_badge("horses"), do: "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-300"
  defp category_badge("web-frameworks"), do: "bg-violet-100 text-violet-800 dark:bg-violet-900/30 dark:text-violet-300"
  defp category_badge("elixir"), do: "bg-indigo-100 text-indigo-800 dark:bg-indigo-900/30 dark:text-indigo-300"
  defp category_badge(_), do: "bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-300"

  defp category_dot_color("handtools"), do: "bg-amber-500"
  defp category_dot_color("horses"), do: "bg-emerald-500"
  defp category_dot_color("web-frameworks"), do: "bg-violet-500"
  defp category_dot_color("elixir"), do: "bg-indigo-500"
  defp category_dot_color(_), do: "bg-gray-400"
end
