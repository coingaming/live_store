defmodule LiveStore do
  @moduledoc """
  Share reactive state across nested LiveView's

  ## Example
  Root LiveView

      defmodule MyAppWeb.CounterLive do
        use Phoenix.LiveView

        def render(assigns) do
          ~L\"""
          <h1><%= @val %></h1>
          <%# render child template and pass the store pid with session %>
          <%= live_render @socket, UsersFlaskWeb.CounterButtonLive, session: %{store: @store} %>
          \"""
        end

        def mount(_session, socket) do
          # create a store in root component and subscribe for `:val` changes
          store =
            LiveStore.create(val: 0)
            |> LiveStore.subscribe([:val])

          socket =
            socket
            # store the pid of the store to assigns
            |> assign(store: store)
            # copy store `:val` to LiveView assigns
            |> assign(LiveStore.take(store, [:val]))

          {:ok, socket}
        end

        # handle all store changes by copying them to assigns
        def handle_info({:store_change, key, val}, socket) do
          {:noreply, assign(socket, key, val)}
        end
      end

  Child LiveView

      defmodule MyAppWeb.CounterButtonLive do
        use Phoenix.LiveView

        def render(assigns) do
          ~L\"""
          <button phx-click="inc"><%= @val %></button>
          \"""
        end

        # retrieve the store pid from the session
        def mount(%{store: store}, socket) do
          if connected?(socket) do
            # subscribe for `:val` changes
            LiveStore.subscribe(store, [:val])
          end

          socket =
            socket
            # store the pid of the store to assigns
            |> assign(store: store)
            # copy store `:val` to LiveView assigns
            |> assign(LiveStore.take(store, [:val]))

          {:ok, socket}
        end

        # handle all store changes by copying them to assigns
        def handle_info({:store_change, key, val}, socket) do
          {:noreply, assign(socket, key, val)}
        end

        # update store instead of the assigns
        def handle_event("inc", _, socket = %{assigns: %{store: store}}) do
          LiveStore.update(store, :val, &(&1 + 1))
          {:noreply, socket}
        end
      end
  """

  use GenServer

  defstruct [:assigns, :subscribers]

  @doc """
  Creates a store with initial `assigns`. Returns store pid.
  ## Examples
      iex> create(name: "Elixir")
      iex> create(name: "Elixir", logo: "💧")
  """
  def create(assigns) do
    {:ok, pid} = GenServer.start_link(__MODULE__, assigns)
    pid
  end

  def init(assigns = %{}) do
    {:ok, %LiveStore{assigns: assigns, subscribers: %{}}}
  end

  def init(state) do
    state
    |> Enum.into(%{})
    |> init()
  end

  @doc """
  Gets the value for a specific `key` in `store` assigns.

  If `key` is present in assigns, then value is returned.
  Otherwise, `default` is returned.
  ## Examples
      iex> get(store, :name)
      iex> get(store, :name, "Elixir")
  """
  def get(pid, key, default \\ nil) do
    GenServer.call(pid, {:get, key, default})
  end

  @doc """
  Returns a map with all the key-value pairs in map where the key is in keys.

  If keys contains keys that are not in map, they're simply ignored.
  ## Examples
      iex> take(store, [:name, :logo])
  """
  def take(pid, keys) do
    GenServer.call(pid, {:take, keys})
  end

  @doc """
  Adds key value pairs to store assigns.
  A single key value pair may be passed, or a keyword list
  of assigns may be provided to be merged into existing
  store assigns.
  ## Examples
      iex> assign(store, :name, "Elixir")
      iex> assign(store, name: "Elixir", logo: "💧")
  """
  def assign(pid, key, value) do
    assign(pid, [{key, value}])
  end

  def assign(pid, attrs)
      when is_map(attrs) or is_list(attrs) do
    GenServer.cast(pid, {:assign, attrs})
    pid
  end

  @doc """
  Updates an existing key in the store assigns.
  The update function receives the current key's value and
  returns the updated value. Raises if the key does not exist.
  ## Examples
      iex> update(store, :count, fn count -> count + 1 end)
      iex> update(store, :count, &(&1 + 1))
  """
  def update(pid, key, func) do
    GenServer.cast(pid, {:update, key, func})
    pid
  end

  @doc """
  Subscribes for assign changes.

  {:store_change, key, value}

  ## Examples
      # in mount
      subscribe(store, [:count, :sum])

      # handle change events and put them directly to assigns
      def handle_info({:store_change, key, val}, socket) do
        {:noreply, assign(socket, key, val)}
      end
  """
  def subscribe(pid, keys) do
    GenServer.cast(pid, {:subscribe, self(), keys})
    pid
  end

  def handle_call({:get, key, default}, _from, store = %LiveStore{assigns: assigns}) do
    {:reply, Map.get(assigns, key, default), store}
  end

  def handle_call({:take, keys}, _from, store = %LiveStore{assigns: assigns}) do
    {:reply, Map.take(assigns, keys), store}
  end

  def handle_cast({:assign, attrs}, store) do
    new_store =
      Enum.reduce(attrs, store, fn {key, val}, %LiveStore{assigns: assigns} = acc ->
        case Map.fetch(assigns, key) do
          {:ok, ^val} -> acc
          {:ok, _old_val} -> do_assign(acc, key, val)
          :error -> do_assign(acc, key, val)
        end
      end)

    {:noreply, new_store}
  end

  def handle_cast({:update, key, func}, store = %LiveStore{assigns: assigns}) do
    value =
      assigns
      |> Map.get(key)
      |> func.()

    {:noreply, do_assign(store, key, value)}
  end

  def handle_cast({:subscribe, pid, keys}, store = %LiveStore{subscribers: subscribers}) do
    new_subscribers = Enum.reduce(keys, subscribers, &Map.put(&2, &1, [pid | Map.get(&2, &1, [])]))
    {:noreply, %LiveStore{store | subscribers: new_subscribers}}
  end

  defp do_assign(store = %LiveStore{assigns: assigns, subscribers: subscribers}, key, value) do
    new_assigns = Map.put(assigns, key, value)
    new_subscribers = notify(subscribers, key, value)
    %LiveStore{store | assigns: new_assigns, subscribers: new_subscribers}
  end

  defp notify(subscribers, key, value) do
    pids = Map.get(subscribers, key, [])
    alive_pids = Enum.filter(pids, &Process.alive?/1)
    Enum.each(alive_pids, &send(&1, {:store_change, key, value}))
    Map.put(subscribers, key, alive_pids)
  end

end
