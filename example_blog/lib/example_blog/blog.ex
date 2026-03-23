defmodule ExampleBlog.Blog do
  @moduledoc """
  Blog context — manages articles and full-text search via SearchTantivy.
  """

  use GenServer

  @index_name :blog_articles
  defp index_via, do: SearchTantivy.IndexRegistry.via(@index_name)

  # --- Articles ---

  @articles [
    %{
      id: "1",
      slug: "japanese-hand-planes",
      title: "The Art of Japanese Hand Planes",
      category: "handtools",
      author: "Sven Eriksson",
      date: "2026-03-15",
      reading_time: 8,
      summary: "Japanese kanna planes achieve mirror finishes that no sandpaper can match. Here's how centuries of tradition shaped the perfect cutting tool.",
      body: """
      The Japanese hand plane, or kanna, works by pulling rather than pushing — the opposite of Western planes. This fundamental difference leads to superior control and thinner shavings, sometimes as fine as 3 microns.

      A properly tuned kanna consists of three parts: the dai (wooden body), the blade, and the chip breaker. The dai is traditionally made from Japanese white oak, chosen for its stability and hardness. Setting the blade requires patience — you tap it into the dai with a small hammer, adjusting the projection by fractions of a millimeter.

      The steel used in Japanese plane blades is laminated: a hard high-carbon steel cutting edge forge-welded to a softer iron backing. This combination provides the extreme sharpness of hard steel with the resilience of soft iron. Master blacksmiths can produce blades that hold an edge through hours of continuous planing.

      Sharpening is done on natural Japanese waterstones, progressing from 1000 grit through 8000 or higher. The final polish on a fine stone produces an edge that can shave end grain as smoothly as long grain. Many woodworkers describe the experience as meditative — the rhythmic motion of stone against steel, the gradual revelation of a mirror finish.

      Modern woodworkers are rediscovering these tools. While power planers are faster, they cannot match the surface quality of a hand-planed board. The burnished surface left by a sharp kanna actually resists moisture better than a sanded surface, because the wood fibers are compressed rather than torn.
      """
    },
    %{
      id: "2",
      slug: "restoring-vintage-chisels",
      title: "Restoring Vintage Chisels: A Practical Guide",
      category: "handtools",
      author: "Sven Eriksson",
      date: "2026-03-10",
      reading_time: 6,
      summary: "Old chisels from flea markets often have better steel than new ones. Learn to bring them back to life with simple techniques.",
      body: """
      Finding quality vintage chisels is one of woodworking's great pleasures. Brands like Stanley, Marples, and Buck Brothers produced tools with steel quality that many modern manufacturers struggle to match. The key is knowing what to look for and how to restore what you find.

      Start by examining the steel. Hold the chisel up and look along the back — it should be relatively flat with no deep pitting. Surface rust is fine; deep corrosion is not. Tap the blade with another piece of metal — a clear ring means sound steel, a dull thud suggests cracks.

      Flattening the back is the most important step. Use a series of diamond plates or waterstones, starting at 250 grit. The back must be dead flat for at least an inch behind the cutting edge. This is tedious work but absolutely essential — a chisel with a convex back will never hold a consistent edge.

      For the bevel, most restoration work benefits from a 25-degree primary bevel with a 30-degree micro-bevel. The primary bevel can be ground on a slow-speed grinder with a tool rest, while the micro-bevel is honed by hand. This two-angle approach provides both durability and sharpness.

      Handle replacement is often needed. Octagonal handles give better rotational control than round ones. Turn them on a lathe from dense hardwood — hornbeam, dogwood, or hard maple work well. The ferrule prevents splitting and should be brass or copper, pressed on with a gentle taper fit.
      """
    },
    %{
      id: "3",
      slug: "icelandic-horse-gaits",
      title: "The Five Gaits of the Icelandic Horse",
      category: "horses",
      author: "Helga Jónsdóttir",
      date: "2026-03-12",
      reading_time: 7,
      summary: "Unlike most breeds, Icelandic horses have five distinct gaits including the famous tölt. Understanding these gaits reveals centuries of selective breeding.",
      body: """
      The Icelandic horse is unique among horse breeds for possessing up to five natural gaits. While most horses have three gaits — walk, trot, and canter — Icelandic horses add the tölt and the flying pace, making them extraordinarily versatile riding horses.

      The tölt is the signature gait of the breed. It's a four-beat lateral amble where the horse moves its legs in the same pattern as a walk but at much higher speeds, from a gentle cruise up to 30 kilometers per hour. What makes the tölt special is that the rider experiences virtually no bounce — one foot is always on the ground, creating an incredibly smooth ride. Medieval travelers prized this gait for covering long distances in comfort.

      The flying pace is the most spectacular gait. Both legs on the same side move together in a two-beat lateral motion, and there's a moment of suspension when all four feet are off the ground. Skilled pace riders can reach speeds of 45 kilometers per hour over short distances. This gait is used in pace racing, a beloved Icelandic tradition.

      Not all Icelandic horses possess all five gaits. Four-gaited horses have walk, trot, canter, and tölt. Five-gaited horses add the flying pace. Selective breeding over a thousand years has refined these gaits — Iceland banned the importation of horses in 982 AD, creating one of the purest breeds in the world.

      Training an Icelandic horse to refine its gaits requires patience and understanding. The tölt is natural but can be improved through balanced riding and proper conditioning. Riders learn to feel the rhythm and encourage the horse to maintain a clear four-beat pattern without breaking into trot.
      """
    },
    %{
      id: "4",
      slug: "horse-hoof-care",
      title: "Natural Hoof Care: Beyond the Horseshoe",
      category: "horses",
      author: "Helga Jónsdóttir",
      date: "2026-03-08",
      reading_time: 5,
      summary: "The barefoot movement in horse care is backed by growing scientific evidence. Learn why many horse owners are removing shoes and what it takes.",
      body: """
      For centuries, horseshoes were considered essential. But a growing body of evidence suggests that many horses perform better without them. The barefoot movement isn't about neglect — it's about understanding hoof biomechanics and providing the conditions for natural hoof health.

      A healthy bare hoof is a remarkable structure. The hoof wall, sole, and frog work together as a shock-absorbing system. When the horse steps down, the hoof expands slightly, pumping blood through the digital cushion. A metal shoe prevents this expansion, reducing blood flow and potentially weakening the hoof over time.

      Transitioning a shod horse to barefoot requires a carefully managed period of adjustment. The horse may be tender-footed for weeks or months as the hoof adapts. During this time, hoof boots can provide protection for riding on rough terrain. The sole thickens, the frog toughens, and the hoof wall grows stronger.

      Diet plays a crucial role in hoof health. Horses need adequate biotin, zinc, copper, and methionine for strong hoof growth. Excess sugar and starch in the diet can trigger laminitis — inflammation of the sensitive laminae inside the hoof. Many barefoot practitioners recommend a low-sugar hay-based diet.

      Regular trimming every 4-6 weeks maintains proper hoof balance. The trim should follow the natural wear pattern: a mustang roll on the hoof wall edge, a concave sole, and a well-developed frog that contacts the ground. This mimics the self-trimming that wild horses achieve through constant movement over varied terrain.
      """
    },
    %{
      id: "5",
      slug: "phoenix-liveview-patterns",
      title: "Phoenix LiveView Patterns That Scale",
      category: "web-frameworks",
      author: "Maria Santos",
      date: "2026-03-18",
      reading_time: 10,
      summary: "Battle-tested LiveView patterns from production applications handling thousands of concurrent users. Streams, components, and PubSub done right.",
      body: """
      Phoenix LiveView has matured into a production-ready framework for building interactive web applications. After deploying LiveView at scale, certain patterns emerge as essential for performance and maintainability.

      Streams are the single most important feature for handling large collections. Before streams, every item in a list lived in the socket's assigns, consuming memory proportional to the list size. With streams, the server only tracks the stream metadata while the client manages the DOM. This means you can display thousands of items with minimal server memory.

      Component design follows a clear hierarchy. Stateless function components handle presentation. They receive assigns, render HTML, and have no lifecycle of their own. Use them for cards, badges, buttons, and any reusable visual element. Stateful LiveComponents are reserved for independent interactive units — a chat widget, a sortable table, or a real-time chart.

      PubSub integration is where LiveView truly shines. Subscribe to topics in mount, broadcast changes from your context modules, and handle updates in handle_info. This pattern creates real-time collaborative features with minimal code. A user edits a document, the context broadcasts the change, and every connected client sees the update instantly.

      Error handling in LiveView differs from traditional request-response. A crashed LiveView process is automatically restarted by the supervisor. Design your mount/3 to be idempotent — it will be called again after recovery. Keep expensive initialization behind handle_continue to avoid blocking the initial render.

      Testing LiveView is straightforward with the built-in test helpers. Use live/2 to mount, render_click/2 for interactions, and assert on the rendered HTML. Test the flow, not the implementation — verify that clicking a button produces the expected visual result, not that a specific assign changed.
      """
    },
    %{
      id: "6",
      slug: "htmx-vs-liveview",
      title: "HTMX vs LiveView: Choosing Your Server-Side UI",
      category: "web-frameworks",
      author: "Maria Santos",
      date: "2026-03-05",
      reading_time: 9,
      summary: "Both HTMX and LiveView promise interactive UIs without JavaScript frameworks. Here's an honest comparison from someone who has shipped both.",
      body: """
      The server-side rendering renaissance has given us two compelling approaches to interactive web UIs: HTMX and Phoenix LiveView. Both reject the SPA paradigm, but they take fundamentally different paths.

      HTMX is a library, not a framework. It extends HTML with attributes like hx-get, hx-post, and hx-swap that let any element make HTTP requests and update the DOM. It's language-agnostic — use it with Django, Rails, Go, or anything that returns HTML. The mental model is simple: HTML in, HTML out.

      LiveView is a framework feature. It maintains a persistent WebSocket connection between client and server, with a virtual DOM diff that sends minimal updates over the wire. The server holds state for each connected client, and user interactions are handled as Elixir function calls. The mental model is closer to desktop GUI programming.

      Performance characteristics differ significantly. HTMX makes individual HTTP requests for each interaction, meaning each action has the latency of a round trip plus server processing. LiveView's WebSocket connection eliminates connection overhead — interactions feel near-instant after the initial connection is established.

      State management is where the approaches diverge most. With HTMX, the server is stateless between requests (or uses sessions). With LiveView, each connection has a process on the server holding the current state. This makes LiveView more memory-intensive per connection but dramatically simplifies complex interactive features like real-time collaboration, live search, and form validation.

      Choose HTMX when you want to add interactivity to an existing server-rendered application without changing your stack. Choose LiveView when you're building a new application in Elixir and want rich interactivity with minimal client-side code. Both are excellent choices — the right one depends on your existing stack and requirements.
      """
    },
    %{
      id: "7",
      slug: "elixir-pattern-matching",
      title: "Pattern Matching in Elixir: Beyond the Basics",
      category: "elixir",
      author: "Lars Nilsson",
      date: "2026-03-20",
      reading_time: 8,
      summary: "Pattern matching is Elixir's secret weapon. Move beyond simple destructuring into multi-clause functions, pin operators, and guard-driven dispatch.",
      body: """
      Pattern matching is the foundation of idiomatic Elixir. While many developers learn the basics — destructuring tuples and maps — the real power emerges when you use pattern matching to replace conditional logic entirely.

      Multi-clause functions are the most important pattern. Instead of writing a function with if/else branches, write multiple function heads that each match a specific shape of input. The BEAM runtime selects the matching clause, giving you dispatch that's both fast and readable.

      Consider error handling. In most languages, you'd write a try/catch block. In Elixir, you match on the result tuple. A function returns {:ok, value} or {:error, reason}, and the caller matches the specific shape they expect. This makes error paths explicit and visible — they're not hidden in exception handlers.

      The pin operator (^) is underused but powerful. It lets you match against an existing variable's value instead of rebinding. This is essential in database queries, Ecto changesets, and any situation where you need to assert that a value matches something already computed.

      Guards extend pattern matching beyond structural matching into value constraints. You can match on ranges, types, and even custom guard expressions. A defguard macro lets you define reusable guard conditions that the compiler can verify at compile time.

      Binary pattern matching deserves special attention. Elixir can destructure binary data with precise bit-level control. Parse network protocols, file formats, or any binary structure by describing its layout in a match expression. This is one of Elixir's inherited superpowers from Erlang.

      The with statement chains pattern matches, short-circuiting on the first failure. Use it when you have a sequence of operations that each produce {:ok, value} results and you want to compose them without nesting case statements.
      """
    },
    %{
      id: "8",
      slug: "elixir-otp-supervision",
      title: "OTP Supervision Trees: Designing for Failure",
      category: "elixir",
      author: "Lars Nilsson",
      date: "2026-03-14",
      reading_time: 11,
      summary: "The supervision tree is your application's immune system. Learn to design trees that let individual components fail and recover without taking down the whole system.",
      body: """
      Most software is designed to prevent failure. Elixir, through OTP, takes a radically different approach: design for failure, then let the system heal itself. The supervision tree is the mechanism that makes this possible.

      A supervisor is a process whose only job is to watch other processes and restart them when they crash. This sounds simple, but the implications are profound. Instead of writing defensive code full of try/rescue blocks, you write code that does its job correctly and crashes when something unexpected happens. The supervisor handles the recovery.

      The three supervision strategies determine how failures cascade. One-for-one restarts only the failed child — use this when children are independent. Rest-for-one restarts the failed child and all children started after it — use this when later children depend on earlier ones. One-for-all restarts every child — use this when children are tightly coupled.

      A common pattern is Registry plus DynamicSupervisor under a one-for-all supervisor. The Registry provides process discovery, the DynamicSupervisor manages the actual worker processes. If the Registry crashes, the DynamicSupervisor must restart too (its workers need to re-register), hence one-for-all.

      Max restarts and max seconds configure the circuit breaker. If a child crashes more than max_restarts times within max_seconds, the supervisor itself crashes, escalating the failure to its parent. This prevents infinite restart loops and ensures that persistent failures are handled at a higher level.

      Design your supervision tree from the bottom up. Start with the processes that have no dependencies. Layer supervisors above them. Infrastructure processes (database connections, PubSub, telemetry) start first. Domain processes (business logic workers) start next. The endpoint (HTTP/WebSocket interface) starts last, ensuring everything is ready before accepting traffic.

      The error kernel pattern separates stable state from volatile computation. Keep critical state in long-lived, rarely-crashing processes. Spawn short-lived processes for risky operations. When the volatile process crashes, the stable state survives. This is how database connection pools work — the pool supervisor is stable, individual connections are volatile.
      """
    },
    %{
      id: "9",
      slug: "marking-gauge-essentials",
      title: "The Marking Gauge: Precision Layout Without Electricity",
      category: "handtools",
      author: "Sven Eriksson",
      date: "2026-03-01",
      reading_time: 4,
      summary: "A marking gauge is the most underrated layout tool in the shop. One pin, one fence, and you can lay out joinery with watchmaker precision.",
      body: """
      Every woodworking joint starts with a line. The marking gauge is the simplest tool for scribing that line parallel to an edge, and it does so with remarkable precision. Unlike a pencil line, a gauged line is a physical groove in the wood surface that guides your saw or chisel.

      The tool consists of a beam, a fence that slides along it, and a marking pin or cutting wheel. The fence references against the workpiece edge while the pin scribes a line at the set distance. A thumbscrew locks the fence in position. That's it — no batteries, no calibration, no software updates.

      Setting the gauge is best done against a ruler or the workpiece itself. For mortise and tenon layout, set the gauge to the chisel width that will cut the mortise. This guarantees the marked line matches the tool that will cut to it. No measurement error, no conversion — the chisel IS the reference.

      Wheel-style gauges cut cleaner lines across the grain than pin-style gauges. The rolling cutter severs the wood fibers cleanly instead of tearing them. For along-the-grain work, either style works well. Japanese marking gauges use a knife blade that can be resharpened — the best of both worlds.

      Keep three gauges set up in your shop: one for stock thickness, one for mortise width, and one free for general use. Resetting a gauge mid-project introduces opportunities for error. Dedicated settings eliminate this risk entirely.
      """
    },
    %{
      id: "10",
      slug: "elixir-genserver-patterns",
      title: "GenServer Patterns for Real-World Applications",
      category: "elixir",
      author: "Lars Nilsson",
      date: "2026-03-03",
      reading_time: 7,
      summary: "GenServer is the workhorse of OTP. Here are patterns that emerge after building dozens of production systems — from state design to testing strategies.",
      body: """
      GenServer is the most-used OTP behaviour, and for good reason. It provides a clean abstraction for any process that needs to manage state and handle requests. But the gap between a tutorial GenServer and a production one is substantial.

      State design is the first decision. Keep state in a struct, not a plain map. Structs enforce a known shape at compile time — if you add a field, every pattern match that destructures the struct will warn you about the change. Use enforce_keys for fields that must be set at initialization.

      The client API should be a clean public interface that hides GenServer internals. Callers shouldn't know or care that they're talking to a GenServer. Export functions like create/1, get/1, and update/2 — not raw GenServer.call wrappers. This makes refactoring possible without changing the public API.

      Prefer call over cast. Calls provide backpressure (the caller waits), error propagation (crashes surface to the caller), and acknowledgment (you know the operation succeeded). Use cast only for genuinely fire-and-forget operations like logging or metrics emission.

      Handle_continue is essential for post-initialization work. If your init/1 needs to do expensive setup (loading data, connecting to services), return {:ok, state, {:continue, :setup}}. The process starts immediately, serves its supervision tree registration, and then handles the expensive work. This prevents initialization timeouts.

      Testing GenServers requires start_supervised! from ExUnit. This ensures the process is stopped after each test, preventing cross-test contamination. For async tests, give each GenServer a unique name based on the test module and line number. Never hardcode registered names in tests.

      Format_status should be implemented on every GenServer that holds sensitive data. When a process crashes, its state is dumped to logs by default. Format_status lets you redact passwords, tokens, and large binaries from crash reports. It's a single callback that prevents data leaks.
      """
    },
    %{
      id: "11",
      slug: "draft-horse-comeback",
      title: "The Quiet Comeback of Draft Horses in Small Farming",
      category: "horses",
      author: "Helga Jónsdóttir",
      date: "2026-02-28",
      reading_time: 6,
      summary: "On small, diversified farms, draft horses are proving more economical and sustainable than tractors. The numbers might surprise you.",
      body: """
      On farms under fifty acres, a curious reversal is happening. Farmers are trading their tractors for draft horses — not out of nostalgia, but out of hard economic calculation. The numbers favor horses in ways that most people don't expect.

      A good team of Percherons costs roughly the same as a used tractor. But the horse depreciates in reverse — a well-trained draft horse gains value over its working life and can produce offspring. The tractor loses value from day one and produces nothing but exhaust.

      Fuel costs are zero. A draft horse runs on hay and pasture, most of which can be produced on the farm itself. A tractor requires diesel, which must be purchased. When fuel prices spike, the horse farmer's costs don't change. Feed costs are predictable and largely controllable.

      Soil compaction is dramatically less with horses. A tractor concentrates thousands of pounds on small tire contact patches, compressing soil structure that took decades to build. Horses distribute their weight across larger areas and their hooves actually aerate the soil as they work. Farmers who switch from tractors to horses report improved soil health within two to three seasons.

      The work is slower, but the quality is often higher. A farmer walking behind a horse-drawn cultivator can see every plant, every weed, every change in soil texture. This intimacy with the land leads to better decisions — earlier problem detection, more targeted intervention, less waste.

      Maintenance is biological rather than mechanical. Veterinary care replaces mechanic bills. The farrier replaces the tire shop. And at the end of a long day, the tractor sits cold in the barn while the horse nickers a greeting when you bring the evening hay. There's value in that relationship too.
      """
    },
    %{
      id: "12",
      slug: "tailwind-component-patterns",
      title: "Tailwind CSS Component Patterns for Production",
      category: "web-frameworks",
      author: "Maria Santos",
      date: "2026-02-25",
      reading_time: 8,
      summary: "Utility-first doesn't mean utility-only. Learn to build maintainable component systems with Tailwind that scale across large applications.",
      body: """
      Tailwind CSS is opinionated about utilities, but production applications need more structure. After building several large applications with Tailwind, clear patterns emerge for organizing styles into maintainable component systems.

      The component boundary should be your framework's component, not CSS. In Phoenix LiveView, a function component with well-defined attrs is your style boundary. The Tailwind classes live inside the component, and the component's API is the contract. Callers pass semantic props like variant and size, not raw classes.

      Conditional classes deserve a clean pattern. Phoenix 1.8 supports array syntax in class attributes — combine static classes with conditional ones in a single list. False values are filtered out automatically. This replaces messy string interpolation with clean, readable declarations.

      Design tokens map to Tailwind's configuration. Your brand colors, spacing scale, and typography choices should be defined once in the Tailwind config and used everywhere via utility classes. Don't hardcode hex values in components — use the semantic color names that Tailwind provides.

      Responsive design follows a mobile-first approach. Start with the mobile layout using unprefixed utilities, then add breakpoint prefixes for larger screens. Test on actual mobile devices, not just browser dev tools — the interaction model is fundamentally different.

      Dark mode should be handled at the design system level, not per-component. Define your color palette with light and dark variants, then use Tailwind's dark: prefix consistently. DaisyUI's theme system makes this particularly clean — switch themes at the root element and every component adapts.

      Animation should be purposeful and performant. Use Tailwind's transition utilities for hover and state changes. For more complex animations, use CSS keyframes defined in your app.css. Avoid animating properties that trigger layout recalculation — stick to transform and opacity for smooth 60fps animations.
      """
    }
  ]

  def articles, do: @articles

  def get_article_by_slug(slug) do
    Enum.find(@articles, fn a -> a.slug == slug end)
  end

  # --- Search ---

  @spec search(String.t()) :: [map()]
  def search(""), do: []

  def search(query_string) do
    with {:ok, reader_ref} <- SearchTantivy.Index.reader(index_via()),
         {:ok, index_ref} <- SearchTantivy.Index.index_ref(index_via()),
         {:ok, query_ref} <- build_fuzzy_query(index_ref, query_string),
         {:ok, raw_results} <-
           SearchTantivy.Native.search_with_snippets(reader_ref, query_ref, 20, 0, ["title", "body"]) do
      Enum.map(raw_results, fn {score, field_pairs, snippet_pairs} ->
        doc = Map.new(field_pairs)
        highlights = Map.new(snippet_pairs)
        slug = doc["slug"]

        %{
          slug: slug,
          title: doc["title"],
          category: doc["category"],
          score: score,
          highlight: highlights["body"],
          article: get_article_by_slug(slug)
        }
      end)
    else
      _ -> []
    end
  end

  defp build_fuzzy_query(index_ref, query_string) do
    terms =
      query_string
      |> String.downcase()
      |> String.split(~r/\s+/, trim: true)

    # For each term, create fuzzy queries against title (boosted) and body
    clauses =
      Enum.flat_map(terms, fn term ->
        distance = if String.length(term) <= 3, do: 0, else: 1

        fuzzy_clauses =
          for field <- [:title, :body] do
            {:ok, q} = SearchTantivy.Query.fuzzy_term(index_ref, field, term, distance: distance)
            q
          end

        # Boost title matches
        {:ok, title_boosted} = SearchTantivy.Query.boost(hd(fuzzy_clauses), 2.0)

        [
          {:should, title_boosted},
          {:should, Enum.at(fuzzy_clauses, 1)}
        ]
      end)

    SearchTantivy.Query.boolean_query(clauses)
  end

  # --- Search field mapping (single source of truth) ---

  @search_fields [
    {:title, :text, stored: true},
    {:body, :text, stored: true},
    {:slug, :string, stored: true, indexed: true},
    {:category, :string, stored: true, indexed: true},
    {:author, :string, stored: true, indexed: true}
  ]

  # --- GenServer (indexes articles on startup) ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}, {:continue, :build_index}}
  end

  @impl true
  def handle_continue(:build_index, state) do
    schema = SearchTantivy.Ecto.build_schema!(@search_fields)
    {:ok, _index} = SearchTantivy.create_index(@index_name, schema)
    :ok = SearchTantivy.Ecto.index_all(@index_name, @articles, @search_fields)

    {:noreply, state}
  end
end
