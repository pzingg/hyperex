defmodule Hyperex.Grammar.Helpers do
  def calculate_lengths(ast) do
    sum_lengths(Enum.reverse(ast), [], [])
  end

  # Process from right to left (reversed list), building stack of computed lengths
  defp sum_lengths([], _op_stack, result_stack), do: result_stack

  defp sum_lengths([item | rest], op_stack, result_stack) when is_tuple(item) do
    {length, op_stack} =
      case elem(item, 1) do
        0 ->
          # Leaf node: length is 1, push to stack
          {1, op_stack}

        count ->
          # Operator: pop count operands from stack, calculate total length
          {operands, rest} = Enum.split(op_stack, count)
          {1 + Enum.sum(operands), rest}
      end

    sum_lengths(rest, [length | op_stack], [{item, length} | result_stack])
  end

  # Handle encapsulated list
  defp sum_lengths([item | rest], op_stack, result_stack) when is_list(item) do
    sum_lengths(rest, [1 | op_stack], [{item, 1} | result_stack])
  end

  # Handle non-tuple (i.e. raw string) item
  defp sum_lengths([item | rest], op_stack, result_stack) do
    sum_lengths(rest, [1 | op_stack], [{item, 1} | result_stack])
  end

  def chunk_captures(cs, n) do
    lengths = calculate_lengths(cs)

    {captures, rest} =
      Enum.reduce_while(0..(n - 1), {[], lengths}, fn _pass, {acc, rest} ->
        case rest do
          [] ->
            {:halt, {acc, rest}}

          [{_tup, len} | _] ->
            {items, rest} = Enum.split(rest, len)
            items = Enum.map(items, fn {tup, _len} -> tup end)
            {:cont, {[items | acc], rest}}
        end
      end)

    {Enum.reverse(captures), Enum.map(rest, fn {tup, _len} -> tup end)}
  end

  def collect_tuples(cs, opts) do
    fun =
      case Keyword.get(opts, :in) do
        nil -> fn c -> is_tuple(c) end
        tags -> fn c -> is_tuple(c) && elem(c, 0) in List.wrap(tags) end
      end

    lengths = calculate_lengths(cs)

    {captures, rest} =
      Enum.reduce_while(0..999, {[], lengths}, fn _pass, {acc, rest} ->
        case rest do
          [] ->
            {:halt, {acc, rest}}

          [{tup, len} | _] ->
            if fun.(tup) do
              {items, rest} = Enum.split(rest, len)
              items = Enum.map(items, fn {tup, _len} -> tup end)
              {:cont, {[items | acc], rest}}
            else
              {:halt, {acc, rest}}
            end
        end
      end)

    captures =
      if Keyword.get(opts, :reverse, false) do
        captures
      else
        Enum.reverse(captures)
      end

    {Enum.count(captures), List.flatten(captures), Enum.map(rest, fn {tup, _len} -> tup end)}
  end

  def wrap([a | _rest] = cs) when is_list(a), do: cs
  def wrap(cs), do: [cs]
end
