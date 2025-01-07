defmodule CodeBreaker.Router do
  use Plug.Router

  plug(Plug.Logger, log: :debug)
  plug(Plug.Static, from: {:code_breaker, "priv/static"}, at: "/")

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["text/*"],
    json_decoder: Jason
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    priv_dir = :code.priv_dir(:code_breaker)
    send_file(conn, 200, "#{priv_dir}/static/index.html")
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end
