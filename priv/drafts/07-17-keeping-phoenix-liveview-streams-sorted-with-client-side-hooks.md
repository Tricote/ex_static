%{
  title: "Keeping Phoenix LiveView Streams Sorted with Client-Side Hooks",
  author: "Tricote",
  tags: ~w(Phoenix)
}
---

When building real-time applications with Phoenix LiveView, you often need to display lists that update dynamically as data changes. Phoenix Streams provide an efficient way to update individual items in large collections without the performance cost of re-rendering the entire list. However, they present a challenge when you need to maintain a specific sort order based on attributes that may change after the initial stream load.

## The Sorting Challenge  {: #challenge}

The fundamental issue comes from how Phoenix LiveView streams work under the hood. Unlike traditional server-rendered lists where the server maintains complete control over the order and content, **Phoenix LiveView streams are stateless on the server side**. They function more like a series of DOM manipulation instructions sent to the client:

- When you call `stream_insert/3`, LiveView tells the client "add or update this specific item"
- When you call `stream_delete/3`, it tells the client "remove this specific item"
- The server doesn't track the current order of items displayed on the client

This design is intentional and provides a way to manage large datasets in LiveViews, but it means the server has no knowledge of how items are currently arranged in the browser's DOM.

Consider this practical scenario: you have a player leaderboard initially sorted by score (highest to lowest). A background process updates a player's score, and you use `stream_insert/3` to update their entry. The updated item will appear in the DOM wherever LiveView decides to place it (typically at the end or replacing the existing item in place), **not** in the correct sorted position based on the new score.

You basically have 2 main options:

**Option 1: Server-Side Re-sorting (Full Reload)**
- Fetch the entire updated dataset from the database
- Clear the existing stream with `stream/4` and reload all items in the correct order
- **Downside**: You lose the performance benefits of streams and create unnecessary database load

**Option 2: Client-Side Sorting**
- Let LiveView handle the efficient item updates via streams
- Use JavaScript hooks to automatically re-sort the DOM elements when items are updated
- **Advantage**: Maintains stream efficiency while achieving the desired sorting behavior

To illustrate the second approach, let's build this dummy player leaderboard where player scores are updated by background processes (like game servers or scheduled jobs). We want to keep players sorted by score in real-time. Here's how we can implement it:

## The JavaScript Hook  {: #js}

First, create a generic hook that sorts items based on a `data-sort-key` attribute:

```js
// assets/js/hooks/sort_items.js
const SortItems = {
  mounted() {
    this.sortItems();
    this.handleEvent("sort_items", () => {
      // Small delay to ensure DOM updates are complete
      setTimeout(() => this.sortItems(), 50);
    });
  },

  sortItems() {
    const container = this.el;
    const items = Array.from(container.children);

    // Sort items by data-sort-key attribute in descending order (highest score first)
    items.sort((a, b) => {
      const sortKeyA = parseFloat(a.dataset.sortKey || '0');
      const sortKeyB = parseFloat(b.dataset.sortKey || '0');

      return sortKeyB - sortKeyA; // Descending order
    });

    // Only reorder if the current order is different from the sorted order
    let needsReordering = false;
    for (let i = 0; i < items.length; i++) {
      if (container.children[i] !== items[i]) {
        needsReordering = true;
        break;
      }
    }

    if (needsReordering) {
      // Reorder elements in the DOM
      items.forEach(item => {
        container.appendChild(item);
      });
    }
  }
};

export default SortItems;
```

Register the hook in the main hooks file:

```js
// assets/js/hooks/index.js
import SortItems from "./sort_items"

let Hooks = {}
Hooks.SortItems = SortItems

export default Hooks;
```

```js
// assets/js/app.js
import Hooks from "./hooks/index"
let liveSocket = new LiveSocket("/live", Socket, { params: { _csrf_token: csrfToken }, hooks: Hooks })
```

## The LiveView Implementation  {: #liveview}

Here's how you'd implement this in your LiveView:

```elixir
defmodule MyAppWeb.LeaderboardLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to player score updates
      Phoenix.PubSub.subscribe(MyApp.PubSub, "player_scores")
    end

    players = MyApp.Games.list_players()

    {:ok,
     socket
     |> stream(:players, players)}
  end

  def handle_info({:player_score_updated, player}, socket) do
    {:noreply,
     socket
     |> stream_insert(:players, player)
     |> push_event("sort_items", %{})}
  end
end
```

A background process that updates player scores and broadcast the information to the LiveView might look like this (could be for instance an Oban worker):

```elixir
defmodule MyApp.ScoreUpdater do
  def update_player_score(player_id, new_score) do
    player = MyApp.Games.update_player_score(player_id, new_score)

    # Broadcast the update to all connected clients
    Phoenix.PubSub.broadcast(
      MyApp.PubSub,
      "player_scores",
      {:player_score_updated, player}
    )
  end
end
```

## The Template  {: #template}

In the template, plug the Hook and add a `data-sort-key` with the score on each stream item:

```html
<div
  id="players"
  phx-update="stream"
  phx-hook="SortItems"
>
  <div
    :for={{dom_id, player} <- @streams.players}
    id={dom_id}
    data-sort-key={player.score}
  >
    <div>
      <h3>{player.name}</h3>
      <p>Score: {player.score}</p>
    </div>
  </div>
</div>
```

## How It Works {: #how}

1. **Initial Load**: When the page loads, the hook's `mounted()` function sorts the items once
2. **Background Updates**: When a player's score is updated by a background process, the server:
  * Updates the stream item with `stream_insert/3`
  * Triggers the sorting by pushing a `sort_items` event
3. **Client-Side Sorting**: The hook receives the event and re-sorts all items based on their `data-sort-key` values

This approach gives you the best of both worlds: the efficiency of Phoenix Streams for updates and the real-time sorting behavior your users expect, all while keeping the server-side logic optimized.