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

  @tag :skip
  test "parses integer", %{peg: peg} do
    run(peg, "1", :ok, scriptlet: [{:integer, 0, 1}])
  end

  @tag :skip
  test "parses prefix", %{peg: peg} do
    run(peg, "not 1", :ok, scriptlet: [{:not, 1}, {:integer, 0, 1}])
  end

  test "parses compound 1", %{peg: peg} do
    run(peg, "16 + 4 / 2", :ok,
      scriptlet: [
        {:add, 2},
        {:integer, 0, 16},
        {:div, 2},
        {:integer, 0, 4},
        {:integer, 0, 2}
      ]
    )
  end

  test "parses compound 2", %{peg: peg} do
    run(peg, "16 / 4 + 2", :ok,
      scriptlet: [
        {:add, 2},
        {:div, 2},
        {:integer, 0, 16},
        {:integer, 0, 4},
        {:integer, 0, 2}
      ]
    )
  end

  test "parses compound 3", %{peg: peg} do
    run(peg, "(16 + 4) / 2", :ok,
      scriptlet: [
        {:div, 2},
        {:add, 2},
        {:integer, 0, 16},
        {:integer, 0, 4},
        {:integer, 0, 2}
      ]
    )
  end

  test "parses compound 4", %{peg: peg} do
    run(peg, "16 + (4 / 2)", :ok,
      scriptlet: [
        {:add, 2},
        {:integer, 0, 16},
        {:div, 2},
        {:integer, 0, 4},
        {:integer, 0, 2}
      ]
    )
  end
end
