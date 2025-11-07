defmodule Hyperex.Grammar.Helpers do
  def split_rest([a | _] = rest) when is_tuple(a) do
    n_a = elem(a, 1) + 1
    {Enum.take(rest, n_a), Enum.drop(rest, n_a)}
  end

  def split_rest([a | rest]) when is_atom(a), do: {[a], rest}
  def split_rest(rest), do: {[], rest}

  def split_infix_op(cs) do
    IO.puts("split_infix_op cs #{inspect(cs)}")
    {b, [op | rest]} = Enum.split_while(cs, fn c -> is_tuple(c) end)

    {a, rest} = split_rest(rest)
    {op, a ++ b ++ rest}
  end

  def collect_tuples(cs, opts) do
    fun =
      case Keyword.get(opts, :in) do
        nil -> fn c -> is_tuple(c) end
        tags -> fn c -> is_tuple(c) && elem(c, 0) in List.wrap(tags) end
      end

    IO.puts("collect_tuples #{inspect(cs)}, #{inspect(opts)}")

    {_, tuples, rest} =
      Enum.reduce(cs, {0, [], []}, fn c, {n, acc, r} ->
        if n > 0 do
          IO.puts("#{n} > 0, collecting #{inspect(c)}")

          {n - 1, [c | acc], r}
        else
          if fun.(c) do
            n = elem(c, 1)
            IO.puts("#{inspect(c)} true, will collect #{n} following")

            if Keyword.get(opts, :extract, false) do
              {n, acc, r}
            else
              {n, [c | acc], r}
            end
          else
            IO.puts("#{inspect(c)} false, adding to rest")

            {0, acc, [c | r]}
          end
        end
      end)

    tuples =
      if Keyword.get(opts, :reverse, false) do
        Enum.reverse(tuples)
      else
        tuples
      end

    rest = Enum.reverse(rest)
    IO.puts("after collect_tuples #{inspect(tuples)}, #{inspect(rest)}")

    {tuples, rest}
  end
end
