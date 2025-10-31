defmodule Hyperex.StringsTest do
  use ExUnit.Case
  doctest Hyperex

  import Xpeg

  setup_all do
    {:ok, peg: Hyperex.Test.SubGrammars.peg_strings()}
  end

  def run(p, s, exp_result \\ :ok, exp_captures \\ []) do
    r = match(p, s)

    result =
      if r.result == :ok && r.rest != [] do
        :partial
      else
        r.result
      end

    assert(result == exp_result)
    assert(r.captures == exp_captures)
  end

  test "parses single quoted with embedded quote", %{peg: peg} do
    run(peg, "'hello ''world'''", :ok, string_lit: "hello 'world'")
  end

  test "parses double quoted", %{peg: peg} do
    run(peg, "\"hello world\"", :ok, string_lit: "hello world")
  end

  test "fails unescaped single quoted", %{peg: peg} do
    run(peg, "'hello' world'", :partial, string_lit: "hello")
  end
end
