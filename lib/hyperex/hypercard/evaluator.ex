defmodule Hyperex.Hypercard.Evaluator do
  alias Hyperex.Hypercard.{Context, Stack, Value}

  defstruct [:ast, :error, :context, :stack, :card, :background, :value, value_stack: []]

  @type t() :: %__MODULE__{
          ast: tuple(),
          context: Context.t(),
          stack: String.t() | nil,
          card: non_neg_integer(),
          background: non_neg_integer(),
          error: term(),
          value: Value.t(),
          value_stack: list()
        }

  def error?({:error, _e}), do: true
  def error?(%__MODULE__{error: e}) when not is_nil(e), do: true
  def error?(_), do: false
  def set_special(t, ev), do: %__MODULE__{ev | value: %Value{special: t}}
  def set_value(val, ev), do: %__MODULE__{ev | value: val}
  def set_error(reason, ev), do: %__MODULE__{ev | error: reason}

  def push_stack(t, ev) do
    %__MODULE__{ev | value_stack: [t | ev.value_stack]}
  end

  def new(ast, ctx) do
    %__MODULE__{
      ast: ast,
      context: ctx,
      stack: nil,
      card: 0,
      background: 0,
      error: nil,
      value: %Value{special: :empty},
      value_stack: []
    }
  end

  def eval(ev) do
    do_eval(ev, ev.ast)
  end

  def do_eval(ev, t) do
    case t do
      {:integer, v} -> eval_integer(ev, v)
      {:float, v} -> eval_float(ev, v)
      {:string_lit, v} -> eval_string_lit(ev, v)
      {:stack_part, v, nxt} -> eval_stack_part(ev, v, nxt)
      {:card_part, v, nxt} -> eval_card_part(ev, v, nxt)
      {:background_part, v, nxt} -> eval_background_part(ev, v, nxt)
      {:card_button, v} -> eval_card_button(ev, v)
      {:card_field, v} -> eval_card_field(ev, v)
      {:background_button, v} -> eval_background_button(ev, v)
      {:background_field, v} -> eval_background_field(ev, v)
      _ -> %__MODULE__{ev | error: "#{elem(t, 0)} unimplemented"}
    end
  end

  def ordinal_to_value(ev, ord) when is_binary(ord) do
    case ord do
      "first" -> eval_integer(ev, 1)
      "second" -> eval_integer(ev, 2)
      "third" -> eval_integer(ev, 3)
      "fourth" -> eval_integer(ev, 4)
      "fifth" -> eval_integer(ev, 5)
      "sixth" -> eval_integer(ev, 6)
      "seventh" -> eval_integer(ev, 7)
      "eighth" -> eval_integer(ev, 8)
      "ninth" -> eval_integer(ev, 9)
      "tenth" -> eval_integer(ev, 10)
      "middle" -> set_special(:middle, ev)
      "mid" -> set_special(:middle, ev)
      "last" -> eval_integer(ev, -1)
      "any" -> set_special(:any, ev)
    end
  end

  def eval_integer(ev, v) when is_integer(v) do
    %Value{as_string: "#{v}", as_integer: v, as_float: v + 0.0} |> set_value(ev)
  end

  def eval_float(ev, v) when is_float(v) do
    ival = trunc(v)

    if v == ival do
      ival
    else
      nil
    end

    %Value{as_string: "#{v}", as_integer: ival, as_float: v} |> set_value(ev)
  end

  def eval_string_lit(ev, v) when is_binary(v) do
    ival =
      case Integer.parse(v) do
        {i, ""} -> i
        _ -> nil
      end

    fval =
      case Float.parse(v) do
        {f, ""} -> f
        _ -> nil
      end

    %Value{as_string: v, as_integer: ival, as_float: fval} |> set_value(ev)
  end

  def eval_stack_part(ev, v, nxt) do
    ev = do_eval(ev, v)

    if error?(ev) do
      ev
    else
      cond do
        is_binary(ev.value.as_string) ->
          do_eval(%__MODULE__{ev | stack: ev.value.as_string}, nxt)

        true ->
          set_error("not a string #{inspect(v)}", ev)
      end
    end
  end

  def eval_card_part(ev, v, nxt) do
    query = get_query(ev, v)

    if error?(query) do
      query
    else
      res = Context.get_card_or_background(ev.context, ev.stack, :card, query)

      case res do
        {:error, reason} -> set_error(reason, ev)
        {:ok, card, _} -> do_eval(%__MODULE__{ev | card: card.id}, nxt)
      end
    end
  end

  def eval_background_part(ev, v, nxt) do
    query = get_query(ev, v)

    if error?(query) do
      query
    else
      res = Context.get_card_or_background(ev.context, ev.stack, :background, query)

      case res do
        {:error, reason} -> set_error(reason, ev)
        {:ok, background} -> do_eval(%__MODULE__{ev | background: background.id}, nxt)
      end
    end
  end

  def eval_card_button(ev, v), do: eval_part(ev, v, :card, :button)
  def eval_card_field(ev, v), do: eval_part(ev, v, :card, :field)
  def eval_background_button(ev, v), do: eval_part(ev, v, :background, :button)
  def eval_background_field(ev, v), do: eval_part(ev, v, :background, :field)

  def eval_part(ev, v, parent_kind, kind) do
    query = get_query(ev, v)

    if error?(query) do
      query
    else
      parent =
        case parent_kind do
          :background -> ev.background
          _ -> ev.card
        end

      res = Context.get_part(ev.context, ev.stack, parent, parent_kind, kind, query)

      case res do
        {:error, reason} -> set_error(reason, ev)
        {:ok, part} -> %Value{as_string: part.contents} |> set_value(ev)
      end
    end
  end

  def get_query(ev, spec) do
    case spec do
      {:by_name_or_number, pos} ->
        ev
        |> do_eval(pos)
        |> by_name_or_number_query(pos)

      {:by_id, id} ->
        ev
        |> do_eval(id)
        |> by_id_query(id)

      other ->
        set_error("invalid part query #{inspect(other)}", ev)
    end
  end

  def by_name_or_number_query(%__MODULE__{error: e} = ev, _) when not is_nil(e), do: ev

  def by_name_or_number_query(ev, pos) do
    cond do
      !is_nil(ev.value.special) ->
        [number: ev.value.special]

      is_integer(ev.value.as_integer) ->
        [number: ev.value.as_integer]

      is_binary(ev.value.as_string) ->
        [name: ev.value.as_string]

      true ->
        set_error("invalid position #{inspect(pos)}", ev)
    end
  end

  def by_id_query(%__MODULE__{error: e} = ev, _) when not is_nil(e), do: ev

  def by_id_query(ev, id) do
    cond do
      is_integer(ev.value.as_integer) ->
        [id: ev.value.as_integer]

      true ->
        set_error("invalid id '#{id}'", ev)
    end
  end
end
