defmodule Hyperex.ScriptTest do
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

  describe "scriplet integer statements" do
    test "parses integer", %{peg: peg} do
      run(peg, "1", :ok, scriptlet: [{:integer, 0, 1}])
    end

    test "parses 2 integer statements", %{peg: peg} do
      run(peg, "1\n2", :ok, scriptlet: [{:integer, 0, 1}, {:integer, 0, 2}])
    end

    test "parses 3 integer statements", %{peg: peg} do
      run(peg, "1\n2\n3", :ok, scriptlet: [{:integer, 0, 1}, {:integer, 0, 2}, {:integer, 0, 3}])
    end
  end

  describe "scriptlet global" do
    test "with multiple names", %{peg: peg} do
      run(peg, "global a, b", :ok, scriptlet: [{:global, 2}, {:param, 0, "a"}, {:param, 0, "b"}])
    end
  end

  describe "scriptlet return" do
    test "with no params", %{peg: peg} do
      run(peg, "return", :ok, scriptlet: [{:return, 0}])
    end

    test "with params", %{peg: peg} do
      run(peg, "return 42", :ok, scriptlet: [{:return, 1}, {:integer, 0, 42}])
    end

    test "followed by another statement", %{peg: peg} do
      run(peg, "return 43\nglobal d", :ok,
        scriptlet: [{:return, 1}, {:integer, 0, 43}, {:global, 1}, {:param, 0, "d"}]
      )
    end
  end

  describe "scriplet function call" do
    test "the target", %{peg: peg} do
      run(peg, "the target", :ok, scriptlet: [{:function_call, 0, "the_target", []}])
    end

    test "the long target", %{peg: peg} do
      run(peg, "the long target", :ok,
        scriptlet: [{:function_call, 0, "the_target", [format: :long]}]
      )
    end

    test "the abs", %{peg: peg} do
      run(peg, "the abs of 1", :ok, scriptlet: [{:function_call, 1, "abs", []}, {:integer, 0, 1}])
    end

    test "abs", %{peg: peg} do
      run(peg, "abs(1)", :ok, scriptlet: [{:function_call, 1, "abs", []}, {:integer, 0, 1}])
    end

    test "average", %{peg: peg} do
      run(peg, "average(1, 2)", :ok,
        scriptlet: [{:function_call, 2, "average", []}, {:integer, 0, 1}, {:integer, 0, 2}]
      )
    end

    test "the number of cards in stack", %{peg: peg} do
      run(peg, "the number of cards in stack \"Home\"", :ok,
        scriptlet: [
          {:function_call, 1, "number", []},
          {:number_args, 0, "cards in stack \"Home\""}
        ]
      )
    end
  end

  describe "scriptlet message" do
    test "without params", %{peg: peg} do
      run(peg, "test20", :ok, scriptlet: [{:message_or_var, 0, "test20"}])
    end

    test "with string params", %{peg: peg} do
      run(peg, "searchScript \"WildCard\", \"Help\"", :ok,
        scriptlet: [
          {:message, 2, "searchScript"},
          {:string_lit, 0, "WildCard"},
          {:string_lit, 0, "Help"}
        ]
      )
    end

    test "with var params", %{peg: peg} do
      run(peg, "test21 2, b", :ok,
        scriptlet: [{:message, 2, "test21"}, {:integer, 0, 2}, {:var, 0, "b"}]
      )
    end

    test "with var params followed by another statement", %{peg: peg} do
      run(peg, "test21 2, b\nexit to HyperCard", :ok,
        scriptlet: [
          {:message, 2, "test21"},
          {:integer, 0, 2},
          {:var, 0, "b"},
          {:exit_to_hypercard, 0}
        ]
      )
    end
  end

  describe "scriptlet pass" do
    test "handler", %{peg: peg} do
      run(peg, "pass test10", :ok, scriptlet: [{:pass, 0, "test10"}])
    end
  end

  describe "scriptlet exit" do
    test "handler", %{peg: peg} do
      run(peg, "exit test11", :ok, scriptlet: [{:exit_handler, 0, "test11"}])
    end

    test "repeat", %{peg: peg} do
      run(peg, "exit repeat", :ok, scriptlet: [{:exit_repeat, 0}])
    end
  end

  describe "scriptlet repeat" do
    test "while", %{peg: peg} do
      run(peg, "repeat while true\n1\n2\nend repeat", :ok,
        scriptlet: [
          {:repeat_while, 3},
          {:constant, 0, "true"},
          {:integer, 0, 1},
          {:integer, 0, 2}
        ]
      )
    end

    test "until", %{peg: peg} do
      run(peg, "repeat until true\n1\n2\nend repeat", :ok,
        scriptlet: [
          {:repeat_until, 3},
          {:constant, 0, "true"},
          {:integer, 0, 1},
          {:integer, 0, 2}
        ]
      )
    end

    test "forever", %{peg: peg} do
      run(peg, "repeat forever\n1\n2\nend repeat", :ok,
        scriptlet: [{:repeat_forever, 2}, {:integer, 0, 1}, {:integer, 0, 2}]
      )
    end

    test "for", %{peg: peg} do
      run(peg, "repeat for 3 times\n1\n2\nend repeat", :ok,
        scriptlet: [{:repeat_count, 3}, {:integer, 0, 3}, {:integer, 0, 1}, {:integer, 0, 2}]
      )
    end

    test "with asc", %{peg: peg} do
      run(peg, "repeat with i = 4 to 5\n1\n2\nend repeat", :ok,
        scriptlet: [
          {:repeat_with_asc, 4, "i"},
          {:integer, 0, 4},
          {:integer, 0, 5},
          {:integer, 0, 1},
          {:integer, 0, 2}
        ]
      )
    end

    test "with asc and following statement", %{peg: peg} do
      run(peg, "repeat with i = 4 to 5\n1\n2\nend repeat\ntrue", :ok,
        scriptlet: [
          {:repeat_with_asc, 4, "i"},
          {:integer, 0, 4},
          {:integer, 0, 5},
          {:integer, 0, 1},
          {:integer, 0, 2},
          {:constant, 0, "true"}
        ]
      )
    end

    test "with asc and subexp in from and to", %{peg: peg} do
      run(peg, "repeat with i = startVar to endVar\n1\n2\nend repeat", :ok,
        scriptlet: [
          {:repeat_with_asc, 4, "i"},
          {:var, 0, "startVar"},
          {:var, 0, "endVar"},
          {:integer, 0, 1},
          {:integer, 0, 2}
        ]
      )
    end

    test "with desc", %{peg: peg} do
      run(peg, "repeat with i = 9 down to 8\n1\n2\nend repeat", :ok,
        scriptlet: [
          {:repeat_with_desc, 4, "i"},
          {:integer, 0, 9},
          {:integer, 0, 8},
          {:integer, 0, 1},
          {:integer, 0, 2}
        ]
      )
    end
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

  describe "scriplet command" do
    test "beep no args", %{peg: peg} do
      run(peg, "beep", :ok, scriptlet: [{:command, "beep", ""}])
    end

    test "beep with args", %{peg: peg} do
      run(peg, "beep 2", :ok, scriptlet: [{:command, "beep", "2"}])
    end

    test "show with args", %{peg: peg} do
      run(peg, "show tool window", :ok, scriptlet: [{:command, "show", "tool window"}])
    end
  end

  describe "scriplet property" do
    @tag :skip
    test "global blindTyping", %{peg: peg} do
      run(peg, "blindTyping", :ok, scriptlet: [{:global_property, "blindTyping", []}])
    end

    test "hypercard address", %{peg: peg} do
      run(peg, "address of HyperCard", :ok, scriptlet: [{:global_property, "address", []}])
    end

    test "hypercard version", %{peg: peg} do
      run(peg, "version", :ok, scriptlet: [{:global_property, "version", []}])
    end

    test "hypercard long version", %{peg: peg} do
      run(peg, "long version", :ok, scriptlet: [{:global_property, "version", [format: :long]}])
    end

    test "rect", %{peg: peg} do
      run(peg, "rect of myVar", :ok, scriptlet: [{:object_property, "rect", {:var, "myVar"}, []}])
    end

    test "name", %{peg: peg} do
      run(peg, "name of myVar", :ok, scriptlet: [{:object_property, "name", {:var, "myVar"}, []}])
    end

    test "english name", %{peg: peg} do
      run(peg, "english name of myVar", :ok,
        scriptlet: [{:object_property, "name", {:var, "myVar"}, [format: :english]}]
      )
    end

    test "global the blindTyping", %{peg: peg} do
      run(peg, "the blindTyping", :ok, scriptlet: [{:global_property, "blindTyping", []}])
    end

    test "the hypercard address", %{peg: peg} do
      run(peg, "the address of HyperCard", :ok, scriptlet: [{:global_property, "address", []}])
    end

    test "the hypercard version", %{peg: peg} do
      run(peg, "the version", :ok, scriptlet: [{:global_property, "version", []}])
    end

    test "the hypercard long version", %{peg: peg} do
      run(peg, "the long version", :ok,
        scriptlet: [{:global_property, "version", [format: :long]}]
      )
    end

    test "the rect", %{peg: peg} do
      run(peg, "the rect of myVar", :ok,
        scriptlet: [{:object_property, "rect", {:var, "myVar"}, []}]
      )
    end

    test "the name", %{peg: peg} do
      run(peg, "the name of myVar", :ok,
        scriptlet: [{:object_property, "name", {:var, "myVar"}, []}]
      )
    end

    test "the english name", %{peg: peg} do
      run(peg, "the english name of myVar", :ok,
        scriptlet: [{:object_property, "name", {:var, "myVar"}, [format: :english]}]
      )
    end
  end

  describe "scriplet function call" do
    test "the target", %{peg: peg} do
      run(peg, "the target", :ok, scriptlet: [{:function_call, 0, "the_target", []}])
    end

    test "the long target", %{peg: peg} do
      run(peg, "the long target", :ok,
        scriptlet: [{:function_call, 0, "the_target", [format: :long]}]
      )
    end

    test "the abs", %{peg: peg} do
      run(peg, "the abs of 1", :ok, scriptlet: [{:function_call, 1, "abs", []}, {:integer, 0, 1}])
    end

    test "abs", %{peg: peg} do
      run(peg, "abs(1)", :ok, scriptlet: [{:function_call, 1, "abs", []}, {:integer, 0, 1}])
    end

    test "average", %{peg: peg} do
      run(peg, "average(1, 2)", :ok,
        scriptlet: [{:function_call, 2, "average", []}, {:integer, 0, 1}, {:integer, 0, 2}]
      )
    end

    test "the number of cards in stack", %{peg: peg} do
      run(peg, "the number of cards in stack \"Home\"", :ok,
        scriptlet: [
          {:function_call, 1, "number", []},
          {:string_lit, 0, "cards in stack \"Home\""}
        ]
      )
    end
  end

  describe "scriptlet parts" do
    @tag :skip
    test "named stack", %{peg: peg} do
      run(peg, "stack \"Home\"", :ok, scriptlet: [{:stack, 0, {:string_lit, "Home"}}])
    end

    @tag :skip
    test "card button 1", %{peg: peg} do
      run(peg, "card button \"Rolo\"", :ok,
        scriptlet: [{:card_button, 0, {:by_name_or_number, {:string_lit, "Rolo"}}}]
      )
    end

    @tag :skip
    test "card button 2", %{peg: peg} do
      run(peg, "card button \"Rolo\" of card \"Home\"", :ok,
        scriptlet: [
          {:card_part, 1, {:by_name_or_number, {:string_lit, "Home"}}},
          {:card_button, 0, {:by_name_or_number, {:string_lit, "Rolo"}}}
        ]
      )
    end

    @tag :skip
    test "card button 3", %{peg: peg} do
      run(peg, "card button \"Rolo\" of card \"Home\" of stack \"Home\"", :ok,
        scriptlet: [
          {:stack_part, 1, {:string_lit, "Home"}},
          {:card_part, 1, {:by_name_or_number, {:string_lit, "Home"}}},
          {:card_button, 0, {:by_name_or_number, {:string_lit, "Rolo"}}}
        ]
      )
    end

    @tag :skip
    test "background button 1", %{peg: peg} do
      run(peg, "background button \"Rolo\"", :ok,
        scriptlet: [{:background_button, 0, {:by_name_or_number, {:string_lit, "Rolo"}}}]
      )
    end

    @tag :skip
    test "background button 2", %{peg: peg} do
      run(peg, "background button \"Rolo\" of background \"Home\"", :ok,
        scriptlet: [
          {:background_part, 1, {:by_name_or_number, {:string_lit, "Home"}}},
          {:background_button, 0, {:by_name_or_number, {:string_lit, "Rolo"}}}
        ]
      )
    end

    @tag :skip
    test "background button 3", %{peg: peg} do
      run(
        peg,
        "background button \"Rolo\" of background \"Home\" of stack \"MyHardDisk:Home\"",
        :ok,
        scriptlet: [
          {:stack_part, 1, {:string_lit, "MyHardDisk:Home"}},
          {:background_part, 1, {:by_name_or_number, {:string_lit, "Home"}}},
          {:background_button, 0, {:by_name_or_number, {:string_lit, "Rolo"}}}
        ]
      )
    end

    @tag :skip
    test "background button 4", %{peg: peg} do
      run(peg, "background button \"Rolo\" of card id 2500", :ok,
        scriptlet: [
          {:card_part, 1, {:by_id, {:integer, 2500}}},
          {:background_button, 0, {:by_name_or_number, {:string_lit, "Rolo"}}}
        ]
      )
    end
  end

  describe "scriptlet chunks" do
    @tag :skip
    test "lines of string", %{peg: peg} do
      run(peg, "lines of \"Hello\nGoodbye\"", :ok,
        scriptlet: [{:chunk, {:string_lit, "Hello\nGoodbye"}, :lines}]
      )
    end

    @tag :skip
    test "ordinal line of string", %{peg: peg} do
      run(peg, "second line of \"Hello\nGoodbye\"", :ok,
        scriptlet: [
          {:chunk, {:string_lit, "Hello\nGoodbye"}, {:line_chunk, {:by_position, "second"}, nil}}
        ]
      )
    end

    @tag :skip
    test "words of string", %{peg: peg} do
      run(peg, "words of \"Hello\nGoodbye\"", :ok,
        scriptlet: [
          {:chunk, {:string_lit, "Hello\nGoodbye"}, :words}
        ]
      )
    end

    @tag :skip
    test "words of ordinal line of string", %{peg: peg} do
      run(peg, "words of second line of \"Hello\nGoodbye\"", :ok,
        scriptlet: [
          {:chunk, {:string_lit, "Hello\nGoodbye"},
           {:line_chunk, {:by_position, "second"}, :words}}
        ]
      )
    end

    @tag :skip
    test "ordinal char of string", %{peg: peg} do
      run(peg, "third char of \"Hello\nGoodbye\"", :ok,
        scriptlet: [
          {:chunk, {:string_lit, "Hello\nGoodbye"}, {:char_chunk, {:by_position, "third"}, nil}}
        ]
      )
    end

    @tag :skip
    test "ordinal char of ordinal word of string", %{peg: peg} do
      run(peg, "third char of first word of \"Hello\nGoodbye\"", :ok,
        scriptlet: [
          {:chunk, {:string_lit, "Hello\nGoodbye"},
           {:word_chunk, {:by_position, "first"}, {:char_chunk, {:by_position, "third"}, nil}}}
        ]
      )
    end

    @tag :skip
    test "ordinal char of ordinal word of ordinal line of string", %{peg: peg} do
      run(peg, "third char of first word of second line of \"Hello\nGoodbye\"", :ok,
        scriptlet: [
          {:chunk, {:string_lit, "Hello\nGoodbye"},
           {:line_chunk, {:by_position, "second"},
            {:word_chunk, {:by_position, "first"}, {:char_chunk, {:by_position, "third"}, nil}}}}
        ]
      )
    end

    @tag :skip
    test "ordinal char of ordinal line of string", %{peg: peg} do
      run(peg, "third char of second line of \"Hello\nGoodbye\"", :ok,
        scriptlet: [
          {:chunk, {:string_lit, "Hello\nGoodbye"},
           {:line_chunk, {:by_position, "second"}, {:char_chunk, {:by_position, "third"}, nil}}}
        ]
      )
    end

    @tag :skip
    test "chunk of part", %{peg: peg} do
      run(peg, "first line of card field \"Rolo\"", :ok,
        scriptlet: [
          {:chunk, {:card_field, {:by_name_or_number, {:string_lit, "Rolo"}}},
           {:line_chunk, {:by_position, "first"}, nil}}
        ]
      )
    end
  end

  describe "scriptlet exprs" do
    test "parses string literal", %{peg: peg} do
      run(peg, "'hello world'", :ok, scriptlet: [{:string_lit, 0, "hello world"}])
    end

    test "fails unescaped single quoted", %{peg: peg} do
      run(peg, "'hello' world'", :error, [{:string_lit, 0, "hello"}])
    end

    test "parses float", %{peg: peg} do
      run(peg, "3.14159", :ok, scriptlet: [{:float, 0, 3.14159}])
    end

    test "parses integer", %{peg: peg} do
      run(peg, "-300", :ok, scriptlet: [{:integer, 0, -300}])
    end

    test "parses constant", %{peg: peg} do
      run(peg, "true", :ok, scriptlet: [{:constant, 0, "true"}])
    end

    test "parses not true", %{peg: peg} do
      run(peg, "not true", :ok, scriptlet: [{:not, 1}, {:constant, 0, "true"}])
    end

    test "parses not 1", %{peg: peg} do
      run(peg, "not 1", :ok, scriptlet: [{:not, 1}, {:integer, 0, 1}])
    end

    test "parses not not", %{peg: peg} do
      run(peg, "not not true", :ok, scriptlet: [{:not, 1}, {:not, 1}, {:constant, 0, "true"}])
    end

    test "parses there is", %{peg: peg} do
      run(peg, "there is a true", :ok, scriptlet: [exists: [{:constant, 0, "true"}]])
    end

    test "parses exp", %{peg: peg} do
      run(peg, "4 ^ 2", :ok, scriptlet: [{:pow, 2}, {:integer, 0, 4}, {:integer, 0, 2}])
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

    test "parses compound 5", %{peg: peg} do
      run(peg, "(1 + 2) + (3 - 4)", :ok,
        scriptlet: [
          {:add, 2},
          {:add, 2},
          {:integer, 0, 1},
          {:integer, 0, 2},
          {:sub, 2},
          {:integer, 0, 3},
          {:integer, 0, 4}
        ]
      )
    end
  end
end
