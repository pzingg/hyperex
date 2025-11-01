defmodule Hyperex.IdTest do
  use ExUnit.Case
  doctest Hyperex

  import Xpeg

  setup_all do
    {:ok, peg: Hyperex.Test.SubGrammars.peg_id()}
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

  test "parses id", %{peg: peg} do
    run(peg, "myVar2")
  end

  test "parses id like reserved", %{peg: peg} do
    run(peg, "else2")
  end

  test "parses id like field", %{peg: peg} do
    run(peg, "fieldVar")
  end

  test "fails reserved", %{peg: peg} do
    run(peg, "else", :error)
  end

  test "fails empty", %{peg: peg} do
    run(peg, " ", :error)
  end
end
