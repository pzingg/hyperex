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
        IO.puts("partial '#{r.rest}'")
        :partial
      else
        r.result
      end

    assert(result == exp_result)
    assert(r.captures == exp_captures)
  end

  describe "syntax errors" do
    test "reserved word", %{peg: peg} do
      run(peg, "then", :error)
    end

    test "empty script", %{peg: peg} do
      run(peg, "", :error)
    end
  end

  describe "parses script" do
    test "message handler", %{peg: peg} do
      run(peg, "on test1\nend test1", :ok, script: [{:handler, "test1", [], []}])
    end

    test "message handler with params", %{peg: peg} do
      run(peg, "on test2 a\nend test2", :ok, script: [{:handler, "test2", ["a"], []}])
    end

    test "two message handlers", %{peg: peg} do
      run(peg, "on test3\nend test3\non test4 a, b\nend test4", :ok,
        script: [
          {:handler, "test3", [], []},
          {:handler, "test4", ["a", "b"], []}
        ]
      )
    end

    test "single message handler with single statement", %{peg: peg} do
      run(peg, "on test5\n1\nend test5", :ok, script: [{:handler, "test5", [], [integer: 1]}])
    end

    test "single message handler with multiple statements", %{peg: peg} do
      run(peg, "on test6\n1\n2\nend test6", :ok,
        script: [{:handler, "test6", [], [integer: 1, integer: 2]}]
      )
    end

    test "empty function def with no params", %{peg: peg} do
      run(peg, "function test7\nend test7", :ok, script: [{:function, "test7", [], []}])
    end

    test "message handler and function def", %{peg: peg} do
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

  describe "scriptlet global" do
    test "with multiple names", %{peg: peg} do
      run(peg, "global a, b", :ok, scriptlet: [global: ["a", "b"]])
    end
  end

  describe "scriptlet return" do
    test "with no params", %{peg: peg} do
      run(peg, "return", :ok, scriptlet: [return: []])
    end

    test "with params", %{peg: peg} do
      run(peg, "return 42", :ok, scriptlet: [return: [integer: 42]])
    end

    test "followed by another statement", %{peg: peg} do
      run(peg, "return 43\nglobal d", :ok, scriptlet: [return: [integer: 43], global: ["d"]])
    end
  end

  describe "scriptlet pass" do
    test "handler", %{peg: peg} do
      run(peg, "pass test10", :ok, scriptlet: [pass: "test10"])
    end
  end

  describe "scriptlet exit" do
    test "handler", %{peg: peg} do
      run(peg, "exit test11", :ok, scriptlet: [exit_handler: "test11"])
    end

    test "repeat", %{peg: peg} do
      run(peg, "exit repeat", :ok, scriptlet: [:exit_repeat])
    end
  end

  describe "scriptlet if" do
    test "single line", %{peg: peg} do
      run(peg, "if true then 1", :ok, scriptlet: [{:if, {:constant, "true"}, [integer: 1], []}])
    end

    test "multiple line", %{peg: peg} do
      script = """
      if true then
        1
        2
      end if
      """

      run(peg, script, :ok, scriptlet: [{:if, {:constant, "true"}, [integer: 1, integer: 2], []}])
    end

    test "single line if-then-else", %{peg: peg} do
      run(peg, "if true then \"Monday\" else \"Tuesday\"", :ok,
        scriptlet: [{:if, {:constant, "true"}, [string_lit: "Monday"], [string_lit: "Tuesday"]}]
      )
    end

    test "multiple line if-then-else", %{peg: peg} do
      script = """
      if true then
        "hi"
      else
        "bye"
      end if
      """

      run(peg, script, :ok,
        scriptlet: [{:if, {:constant, "true"}, [string_lit: "hi"], [string_lit: "bye"]}]
      )
    end
  end

  describe "scriptlet repeat" do
    test "while", %{peg: peg} do
      run(peg, "repeat while true\n1\n2\nend repeat", :ok,
        scriptlet: [{:repeat_while, [integer: 1, integer: 2], {:constant, "true"}}]
      )
    end

    test "until", %{peg: peg} do
      run(peg, "repeat until true\n1\n2\nend repeat", :ok,
        scriptlet: [{:repeat_until, [integer: 1, integer: 2], {:constant, "true"}}]
      )
    end

    test "forever", %{peg: peg} do
      run(peg, "repeat forever\n1\n2\nend repeat", :ok,
        scriptlet: [{:repeat_forever, [integer: 1, integer: 2]}]
      )
    end

    test "for", %{peg: peg} do
      run(peg, "repeat for 3 times\n1\n2\nend repeat", :ok,
        scriptlet: [{:repeat_count, [integer: 1, integer: 2], {:integer, 3}}]
      )
    end
  end

  describe "scriplet command" do
    test "show", %{peg: peg} do
      run(peg, "show marked cards", :ok, scriptlet: [{:command, "show", "marked cards"}])
    end
  end

  describe "scriplet property" do
    test "global", %{peg: peg} do
      run(peg, "the address", :ok, scriptlet: [{:global_property, "address", []}])
    end

    test "long version", %{peg: peg} do
      run(peg, "the long version", :ok,
        scriptlet: [{:global_property, "version", [format: :long]}]
      )
    end

    test "object", %{peg: peg} do
      run(peg, "the rect of fieldVar", :ok,
        scriptlet: [{:object_property, "rect", {:var, "fieldVar"}, []}]
      )
    end

    test "english name", %{peg: peg} do
      run(peg, "the english name of myVar", :ok,
        scriptlet: [{:object_property, "name", {:var, "myVar"}, [format: :english]}]
      )
    end

    test "BUG english name", %{peg: peg} do
      run(peg, "the english name of fieldVar", :ok,
        scriptlet: [{:object_property, "name", {:var, "fieldVar"}, [format: :english]}]
      )
    end

  end

  describe "scriplet function call" do
    test "the target", %{peg: peg} do
      run(peg, "the target", :ok, scriptlet: [{:function_call, "the_target", [], []}])
    end

    test "the long target", %{peg: peg} do
      run(peg, "the long target", :ok,
        scriptlet: [{:function_call, "the_target", [], [format: :long]}]
      )
    end

    test "the abs", %{peg: peg} do
      run(peg, "the abs of 1", :ok, scriptlet: [{:function_call, "abs", [integer: 1], []}])
    end

    test "abs", %{peg: peg} do
      run(peg, "abs(1)", :ok, scriptlet: [{:function_call, "abs", [integer: 1], []}])
    end

    test "average", %{peg: peg} do
      run(peg, "average(1, 2)", :ok,
        scriptlet: [{:function_call, "average", [integer: 1, integer: 2], []}]
      )
    end
  end

  describe "scriptlet message" do
    test "without params", %{peg: peg} do
      run(peg, "test20", :ok, scriptlet: [{:message, "test20", []}])
    end

    test "with params", %{peg: peg} do
      run(peg, "searchScript \"WildCard\", \"Help\"", :ok,
        scriptlet: [{:message, "searchScript", [string_lit: "WildCard", string_lit: "Help"]}]
      )
    end

    test "followed by another statement", %{peg: peg} do
      run(peg, "test21 2, b\nexit to HyperCard", :ok,
        scriptlet: [{:message, "test21", [integer: 2, var: "b"]}, :exit_to_hypercard]
      )
    end
  end

  describe "scriptlet parts" do
    test "named stack", %{peg: peg} do
      run(peg, "stack \"Home\"", :ok, scriptlet: [{:stack, {:string_lit, "Home"}}])
    end
  end

  describe "scriptlet exprs" do
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
