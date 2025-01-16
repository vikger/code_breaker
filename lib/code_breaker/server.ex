defmodule CodeBreaker.Server do
  use GenServer, restart: :transient

  require Logger

  @colors ["black", "green", "blue", "red", "white", "yellow"]
  @color_map %{
    "black" => {0, 0, 0},
    "green" => {0, 255, 0},
    "blue" => {0, 0, 255},
    "red" => {255, 0, 0},
    "white" => {255, 255, 255},
    "yellow" => {255, 255, 0}
  }
  @board_color {229, 152, 102}
  @full_color {0, 128, 0}
  @half_color {200, 200, 20}
  @window_width 600
  @window_height 550

  defmodule State do
    defstruct new_game: nil,
              window: nil,
              canvas: nil,
              solution: nil,
              guesses: [],
              attempts: 0,
              status: :running,
              result: nil,
              unit: nil
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def guess(player, guess) do
    GenServer.call(__MODULE__, {:guess, player, guess})
  end

  def init(_) do
    g = :gs.start()

    window =
      :gs.window(g,
        title: ~c"CodeBreaker",
        width: @window_width,
        height: @window_height
      )

    unit = get_unit(@window_width, @window_height)
    canvas = draw_canvas(window, unit)

    button =
      :gs.button(window, x: 32 * unit, y: unit, label: {:text, ~c"New Game"})

    result = :gs.label(window, x: 32 * unit, y: 20 * unit, label: {:text, ~c""})

    :gs.config(window, map: true)

    {:ok,
     %State{
       new_game: button,
       window: window,
       canvas: canvas,
       solution: new_solution(),
       result: result,
       unit: unit
     }}
  end

  def handle_call(_, _from, %State{status: :ended} = state) do
    {:reply, :ok, state}
  end

  def handle_call({:guess, player, guess}, _from, state) do
    check = check_guess(guess, state.solution)

    state =
      %State{
        state
        | guesses: state.guesses ++ [{guess, format_check(check)}],
          attempts: state.attempts + 1
      }
      |> update()

    if check == {4, 0} do
      :gs.config(state.result, label: {:text, to_charlist("Winner: " <> player)})
      {:reply, :ok, %State{state | status: :ended}}
    else
      if state.attempts == 10 do
        :gs.config(state.result, label: {:text, ~c"Game ended"})
        {:reply, :ok, %State{state | status: :ended}}
      else
        {:reply, :ok, state}
      end
    end
  end

  def handle_info({:gs, window, :destroy, _, _}, %State{window: window} = state) do
    Logger.info("CodeBreaker exit")
    {:stop, :normal, state}
  end

  def handle_info({:gs, button, :click, _, _}, %State{new_game: button} = state) do
    Logger.info("CodeBreaker new game")
    :gs.config(state.result, label: {:text, ~c""})

    state =
      %State{
        state
        | guesses: [],
          solution: new_solution(),
          attempts: 0,
          status: :running
      }
      |> update()

    {:noreply, state}
  end

  defp draw_canvas(window, unit) do
    canvas =
      :gs.canvas(window,
        x: unit,
        y: unit,
        width: 30 * unit,
        height: 53 * unit,
        bg: :white
      )

    :gs.rectangle(canvas,
      coords: [{unit, unit}, {29 * unit, 52 * unit}],
      fill: @board_color,
      fg: :black
    )

    for y <- 0..9 do
      for x <- 0..3 do
        :gs.rectangle(canvas,
          coords: [
            {2 * unit + 5 * unit * x, 2 * unit + 5 * unit * y},
            {6 * unit + 5 * unit * x, 6 * unit + 5 * unit * y}
          ],
          fill: @board_color,
          fg: :black
        )
      end

      :gs.rectangle(canvas,
        coords: [{24 * unit, 2 * unit + 5 * unit * y}, {28 * unit, 6 * unit + 5 * unit * y}],
        fill: @board_color,
        fg: :black
      )
    end

    canvas
  end

  defp update(%State{window: window, canvas: canvas, guesses: guesses, unit: unit} = state) do
    :gs.destroy(canvas)
    canvas = draw_canvas(window, unit)

    for {{dots, check}, y} <- Enum.with_index(guesses) do
      for {dot, x} <- Enum.with_index(dots) do
        draw_dot(canvas, dot, x, y, unit)
      end

      for {check_y, check_x, color} <- check do
        draw_check(canvas, y, check_x, check_y, color, unit)
      end
    end

    %State{state | canvas: canvas}
  end

  defp draw_dot(canvas, dot, x, y, unit) do
    x1 = 3 * unit + 5 * x * unit
    x2 = 5 * unit + 5 * x * unit
    y1 = 3 * unit + 5 * y * unit
    y2 = 5 * unit + 5 * y * unit
    :gs.oval(canvas, coords: [{x1, y1}, {x2, y2}], fg: :black, fill: @color_map[dot])
  end

  defp draw_check(canvas, col, x, y, color, unit) do
    x1 = 24 * unit + round((3 * x - 2) * 4 * unit / 7)
    x2 = 24 * unit + round(3 * x * 4 * unit / 7)
    y1 = 2 * unit + 5 * col * unit + round((3 * y - 2) * 4 * unit / 7)
    y2 = 2 * unit + 5 * col * unit + round(3 * y * 4 * unit / 7)
    :gs.oval(canvas, coords: [{x1, y1}, {x2, y2}], fg: :black, fill: color)
  end

  defp new_solution() do
    for _ <- 1..4 do
      Enum.random(@colors)
    end
  end

  def check_guess(guess, solution) do
    {full, {r1, r2}} = check1(guess, solution, [], [], 0)
    half = check2(Enum.sort(r1), Enum.sort(r2))
    {full, half}
  end

  defp check1([a | g], [a | s], r1, r2, n), do: check1(g, s, r1, r2, n + 1)
  defp check1([a | g], [b | s], r1, r2, n), do: check1(g, s, r1 ++ [a], r2 ++ [b], n)
  defp check1([], [], r1, r2, n), do: {n, {r1, r2}}

  defp check2([a | g], [a | s]), do: 1 + check2(g, s)
  defp check2([a | g], [b | s]) when a > b, do: check2([a | g], s)
  defp check2([_a | g], [b | s]), do: check2(g, [b | s])
  defp check2(_, _), do: 0

  defp format_check({full, half}) do
    fields = [{1, 1}, {1, 2}, {2, 1}, {2, 2}]
    {full_fields, rest} = Enum.split(fields, full)
    {half_fields, _} = Enum.split(rest, half)

    Enum.map(full_fields, fn {y, x} -> {y, x, @full_color} end) ++
      Enum.map(half_fields, fn {y, x} -> {y, x, @half_color} end)
  end

  defp get_unit(w, h) do
    min(round(w / 2 / 30), round(h / 55))
  end
end
