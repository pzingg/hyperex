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

  describe "scriptlet if" do
    test "single line", %{peg: peg} do
      run(peg, "if true then 1", :ok,
        scriptlet: [{:if, 2}, {:constant, "true"}, {:integer, 0, 1}]
      )
    end

    test "multiple line", %{peg: peg} do
      script = """
      if true then
        1
        2
      end if
      """

      run(peg, script, :ok,
        scriptlet: [{:if, 2}, {:constant, 0, "true"}, {:integer, 0, 1}, {:integer, 0, 2}]
      )
    end

    test "single line if-else", %{peg: peg} do
      run(peg, "if true then \"Monday\" else \"Tuesday\"", :ok,
        scriptlet: [
          {:if, 3},
          {:constant, 0, "true"},
          {:string_lit, 0, "Monday"},
          {:else, 1},
          {:string_lit, 0, "Tuesday"}
        ]
      )
    end

    test "multiple line if-else", %{peg: peg} do
      script = """
      if true then
        "hi"
      else
        "bye"
        2
      end if
      """

      run(peg, script, :ok,
        scriptlet: [
          {:if, 3},
          {:constant, 0, "true"},
          {:string_lit, 0, "hi"},
          {:else, 2},
          {:string_lit, 0, "bye"},
          {:integer, 0, 2}
        ]
      )
    end
  end
end
