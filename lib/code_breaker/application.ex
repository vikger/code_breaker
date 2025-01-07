defmodule CodeBreaker.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CodeBreaker.Server,
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: CodeBreaker.Router,
        options: [port: 8080, dispatch: dispatch()]
      )
    ]

    opts = [strategy: :one_for_one, name: CodeBreaker.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_,
       [
         {"/ws", CodeBreaker.Websocket, []},
         {:_, Plug.Cowboy.Handler, {CodeBreaker.Router, []}}
       ]}
    ]
  end
end
