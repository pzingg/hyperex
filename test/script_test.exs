defmodule Hyperex.ScriptTest do
  use ExUnit.Case
  doctest Hyperex

  import Xpeg

  setup_all do
    {:ok, peg: Hyperex.Grammar.peg_script()}
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

  describe "script" do
    test "parses empty single handler", %{peg: peg} do
      run(peg, "on test1\nend test1", :ok, script: [{:handler, "test1", [], []}])
    end

    test "parses empty handler with params", %{peg: peg} do
      run(peg, "on test2 a\nend test2", :ok, script: [{:handler, "test2", ["a"], []}])
    end

    test "parses two empty handlers", %{peg: peg} do
      run(peg, "on test3\nend test3\non test4 a, b\nend test4", :ok,
        script: [
          {:handler, "test3", [], []},
          {:handler, "test4", ["a", "b"], []}
        ]
      )
    end

    test "parses single handler with single statement", %{peg: peg} do
      run(peg, "on test5\n1\nend test5", :ok, script: [{:handler, "test5", [], [integer: 1]}])
    end

    test "parses single handler with multiple statements", %{peg: peg} do
      run(peg, "on test6\n1\n2\nend test6", :ok,
        script: [{:handler, "test6", [], [integer: 1, integer: 2]}]
      )
    end

    test "parses empty function def with no parameters", %{peg: peg} do
      run(peg, "function test7\nend test7", :ok, script: [{:function, "test7", [], []}])
    end

    test "parses a real script", %{peg: peg} do
      script = """
      on test8 a, b
        1
        2
        3
      end test8

      function test9 c
        4
        5
      end test9
      """

      run(peg, script, :ok,
        script: [
          {:handler, "test8", ["a", "b"], [integer: 1, integer: 2, integer: 3]},
          {:function, "test9", ["c"], [integer: 4, integer: 5]}
        ]
      )
    end
  end

  describe "errors" do
    test "fails reserved", %{peg: peg} do
      run(peg, "then", :error)
    end

    test "parses empty script", %{peg: peg} do
      run(peg, "", :error)
    end
  end

  describe "scriptlet" do
    test "parses single statement", %{peg: peg} do
      run(peg, "3", :ok, scriptlet: [integer: 3])
    end

    test "parses two statements", %{peg: peg} do
      run(peg, "3\n4", :ok, scriptlet: [integer: 3, integer: 4])
    end

    test "parses string literal", %{peg: peg} do
      run(peg, "'hello world'", :ok, scriptlet: [string_lit: "hello world"])
    end

    test "fails unescaped single quoted", %{peg: peg} do
      run(peg, "'hello' world'", :partial, scriptlet: [string_lit: "hello"])
    end

    test "parses float", %{peg: peg} do
      run(peg, "3.14159", :ok, scriptlet: [float: 3.14159])
    end

    test "parses integer", %{peg: peg} do
      run(peg, "-300", :ok, scriptlet: [integer: -300])
    end

    test "parses constant", %{peg: peg} do
      run(peg, "true", :ok, scriptlet: [constant: "true"])
    end

    test "parses not", %{peg: peg} do
      run(peg, "not true", :ok, scriptlet: [not: [constant: "true"]])
    end

    test "parses not not", %{peg: peg} do
      run(peg, "not not true", :ok, scriptlet: [not: [not: [constant: "true"]]])
    end

    test "parses there is", %{peg: peg} do
      run(peg, "there is a true", :ok, scriptlet: [exists: [constant: "true"]])
    end

    test "parses exp", %{peg: peg} do
      run(peg, "4 ^ 2", :ok, scriptlet: [pow: [integer: 4, integer: 2]])
    end

    test "parses arithmetic", %{peg: peg} do
      run(peg, "1 + 4/2", :ok, scriptlet: [add: [integer: 1, div: [integer: 4, integer: 2]]])
    end

    test "parses parens", %{peg: peg} do
      run(peg, "1 + ( 4 ^ 2 )", :ok,
        scriptlet: [add: [integer: 1, pow: [integer: 4, integer: 2]]]
      )
    end
  end
end
