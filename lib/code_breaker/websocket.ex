defmodule CodeBreaker.Websocket do
  require Logger

  @behaviour :cowboy_websocket

  @impl :cowboy_websocket
  def init(req, opts) do
    Logger.info("[websocket] init req => #{inspect(req)}")
    {:cowboy_websocket, req, opts, %{idle_timeout: :infinity}}
  end

  @impl :cowboy_websocket
  def websocket_init(_) do
    Logger.info("[websocket] init #{inspect(self())}")
    {:ok, %{}}
  end

  @impl :cowboy_websocket
  def websocket_handle({:text, message}, state) do
    message
    |> Jason.decode!()
    |> process_message(state)
  end

  @impl :cowboy_websocket
  def websocket_info(message, state) do
    Logger.info("Websocket info #{inspect(message)}")
    {:reply, {:text, message}, state}
  end

  def process_message(%{"name" => name, "guess" => guess}, state) do
    CodeBreaker.Server.guess(name, guess)
    {:ok, state}
  end
end
