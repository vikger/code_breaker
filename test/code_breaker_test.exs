defmodule CodeBreakerTest do
  use ExUnit.Case
  doctest CodeBreaker

  test "greets the world" do
    assert CodeBreaker.hello() == :world
  end
end
