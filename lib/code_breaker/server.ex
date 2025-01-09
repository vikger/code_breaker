defmodule CodeBreaker.Server do
  use GenServer

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
  @frame 10
  @padding 10
  @cell_size 40
  @dot_size 20
  @check_size 12
  @full_color {0, 128, 0}
  @half_color {200, 200, 20}
  @canvas_width 2 * @frame + 8 * @padding + 5 * @cell_size
  @canvas_height 2 * @frame + 10 * @cell_size + 11 * @padding

  defmodule State do
    defstruct new_game: nil,
              window: nil,
              canvas: nil,
              solution: nil,
              guesses: [],
              attempts: 0,
              status: :running,
              result: nil
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
        width: 2 * @frame + @canvas_width + 250,
        height: 2 * @frame + @canvas_height
      )

    canvas = create_canvas(window)

    button =
      :gs.button(window, x: 2 * @frame + @canvas_width, y: @frame, label: {:text, ~c"New Game"})

    :gs.config(window, map: true)
    {:ok, %State{new_game: button, window: window, canvas: canvas, solution: new_solution()}}
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
      winner =
        :gs.label(state.window,
          x: 2 * @frame + @canvas_width,
          y: @frame + 100,
          label: {:text, to_charlist("Winner: " <> player)}
        )

      {:reply, :ok, %State{state | status: :ended, result: winner}}
    else
      if state.attempts == 10 do
        result =
          :gs.label(state.window,
            x: 2 * @frame + @canvas_width,
            y: @frame + 100,
            label: {:text, ~c"Game ended"}
          )

        {:reply, :ok, %State{state | status: :ended, result: result}}
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

    if state.result != nil do
      :gs.destroy(state.result)
    end

    state =
      %State{
        state
        | guesses: [],
          solution: new_solution(),
          attempts: 0,
          status: :running,
          result: nil
      }
      |> update()

    {:noreply, state}
  end

  defp create_canvas(window) do
    canvas =
      :gs.canvas(window,
        x: @frame,
        y: @frame,
        width: @canvas_width,
        height: @canvas_height,
        bg: :white
      )

    :gs.rectangle(canvas,
      coords: [
        {@frame, @frame},
        {@frame + @padding + 5 * (@cell_size + @padding) + 2 * @padding,
         @frame + @padding + 10 * (@cell_size + @padding)}
      ],
      fill: @board_color,
      fg: :black
    )

    for y <- 0..9 do
      for x <- 0..3 do
        :gs.rectangle(canvas,
          coords: [
            {@frame + @padding + (@cell_size + @padding) * x,
             @frame + @padding + (@cell_size + @padding) * y},
            {@frame + @padding + @cell_size + (@cell_size + @padding) * x,
             @frame + @padding + @cell_size + (@cell_size + @padding) * y}
          ],
          fill: @board_color,
          fg: :black
        )
      end

      :gs.rectangle(canvas,
        coords: [
          {@frame + 4 * (@padding + @cell_size) + 3 * @padding,
           @frame + @padding + (@cell_size + @padding) * y},
          {@frame + 4 * (@padding + @cell_size) + 3 * @padding + @cell_size,
           @frame + @padding + (@cell_size + @padding) * y + @cell_size}
        ],
        fill: @board_color,
        fg: :black
      )
    end

    canvas
  end

  defp update(%State{window: window, canvas: canvas, guesses: guesses} = state) do
    :gs.destroy(canvas)
    canvas = create_canvas(window)

    for {{dots, check}, y} <- Enum.with_index(guesses) do
      for {dot, x} <- Enum.with_index(dots) do
        draw_dot(canvas, dot, x, y)
      end

      for {check_y, check_x, color} <- check do
        draw_check(canvas, y, check_x, check_y, color)
      end
    end

    %State{state | canvas: canvas}
  end

  defp draw_dot(canvas, dot, x, y) do
    x1 = @frame + @padding + x * (@cell_size + @padding) + round(@cell_size / 2 - @dot_size / 2)
    x2 = @frame + @padding + x * (@cell_size + @padding) + round(@cell_size / 2 + @dot_size / 2)
    y1 = @frame + @padding + y * (@cell_size + @padding) + round(@cell_size / 2 - @dot_size / 2)
    y2 = @frame + @padding + y * (@cell_size + @padding) + round(@cell_size / 2 + @dot_size / 2)
    :gs.oval(canvas, coords: [{x1, y1}, {x2, y2}], fg: :black, fill: @color_map[dot])
  end

  defp draw_check(canvas, col, x, y, color) do
    x1 =
      @frame + @padding + 4 * (@cell_size + @padding) + 2 * @padding +
        round(@cell_size / 3 * x - @check_size / 2)

    x2 =
      @frame + @padding + 4 * (@cell_size + @padding) + 2 * @padding +
        round(@cell_size / 3 * x + @check_size / 2)

    y1 =
      @frame + @padding + col * (@cell_size + @padding) +
        round(@cell_size / 3 * y - @check_size / 2)

    y2 =
      @frame + @padding + col * (@cell_size + @padding) +
        round(@cell_size / 3 * y + @check_size / 2)

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
end
