defmodule Hyperex.Grammar.Helpers do
  def split_opt_list(cs, opts) do
    fun =
      case Keyword.get(opts, :in) do
        nil -> fn c -> is_tuple(c) end
        tags -> fn c -> is_tuple(c) && elem(c, 0) in List.wrap(tags) end
      end

    {opt_list, rest} = Enum.split_with(cs, fun)

    opt_list =
      if Keyword.get(opts, :extract, false) do
        Enum.map(opt_list, fn c -> elem(c, 1) end)
      else
        opt_list
      end

    opt_list =
      if Keyword.get(opts, :reverse, false) do
        Enum.reverse(opt_list)
      else
        opt_list
      end

    {opt_list, rest}
  end
end
