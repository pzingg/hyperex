defmodule Hyperex.HypercardTest do
  use ExUnit.Case

  alias Hyperex.Hypercard

  test "checks context" do
    ctx = Hypercard.peek_context()
    stack_file = Map.get(ctx.stacks, "Home")
    assert stack_file != nil
  end

  test "gets Home stack" do
    res = Hypercard.get_stack("Home")
    assert {:ok, stack, path} = res
    assert stack.name == "Home"
    assert Path.basename(path) == "Home.json"
  end

  test "gets card by id" do
    res = Hypercard.get_card_or_background("Home", :card, id: 2301)
    assert {:ok, card, bkgnd} = res
    assert card.id == 2301
    assert card.background > 0
    assert bkgnd.id == card.background
  end

  describe "evaluates" do
    test "integer" do
      ast = {:integer, 101}
      res = Hypercard.eval(ast)
      assert res.value.as_integer == 101
    end

    test "contents of card button with default stack and card" do
      ast = {:card_button, {:by_name_or_number, {:string_lit, "Card Button"}}}
      ev = Hypercard.eval(ast)
      assert ev.error == nil
      assert ev.value.as_string == "button contents"
    end

    test "contents of card button in stack" do
      ast =
        {:stack_part, {:string_lit, "Home"},
         {:card_part, {:by_name_or_number, {:string_lit, "Card 2"}},
          {:card_button, {:by_name_or_number, {:string_lit, "Card Button"}}}}}

      ev = Hypercard.eval(ast)
      assert ev.error == nil
      assert ev.value.as_string == "2nd card button contents"
    end
  end
end
