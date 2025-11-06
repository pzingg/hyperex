defmodule Hyperex.XpegTest do
  use ExUnit.Case

  import Xpeg

  setup_all do
    {:ok, peg: Hyperex.Test.SubGrammars.peg_test()}
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

  test "parses no parameters", %{peg: peg} do
    run(peg, "on test\nend test", :ok, script: [{:handler, "test", {:params, []}}])
  end

  test "parses one parameter", %{peg: peg} do
    run(peg, "on test a\nend test", :ok, script: [{:handler, "test", {:params, ["a"]}}])
  end

  test "parses many parameters", %{peg: peg} do
    run(peg, "on test a, b, c\nend test", :ok,
      script: [{:handler, "test", {:params, ["a", "b", "c"]}}]
    )
  end

  test "parses two handlers", %{peg: peg} do
    run(peg, "on test1\nend test1\non test2 a, b, c\nend test2", :ok,
      script: [
        {:handler, "test1", {:params, []}},
        {:handler, "test2", {:params, ["a", "b", "c"]}}
      ]
    )
  end

  test "parses with leading comment", %{peg: peg} do
    run(peg, "-- comment a, b, c\non test\nend test", :ok,
      script: [{:handler, "test", {:params, []}}]
    )
  end

  test "parses with trailing comment", %{peg: peg} do
    run(peg, "on test a, b -- comment c\nend test", :ok,
      script: [{:handler, "test", {:params, ["a", "b"]}}]
    )
  end
end
