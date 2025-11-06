defmodule Hyperex.BugTest do
  use ExUnit.Case

  import Xpeg

  setup_all do
    {:ok, peg: Hyperex.Grammar.peg_script()}
  end

  def run(p, s, exp_result \\ :ok, exp_captures \\ []) do
    r = match(p, "{{" <> s <> "}}")

    result =
      if r.result == :ok && r.rest != [] do
        :partial
      else
        r.result
      end

    if r.rest != [] do
      IO.puts("unparsed: #{inspect(r)}'")
    end

    assert(r.captures == exp_captures)
    assert(result == exp_result)
  end
end
