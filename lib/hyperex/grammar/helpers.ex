defmodule Hyperex.Grammar.Helpers do
  def collect_atoms(cs, opts) do
    fun =
      case Keyword.get(opts, :in) do
        nil -> fn c -> is_atom(c) end
        tags -> fn c -> is_atom(c) && c in List.wrap(tags) end
      end

    {atoms, rest} = Enum.split_with(cs, fun)

    atoms =
      if Keyword.get(opts, :reverse, false) do
        Enum.reverse(atoms)
      else
        atoms
      end

    {atoms, rest}
  end

  def collect_tuples(cs, opts) do
    fun =
      case Keyword.get(opts, :in) do
        nil -> fn c -> is_tuple(c) end
        tags -> fn c -> is_tuple(c) && elem(c, 0) in List.wrap(tags) end
      end

    {tuples, rest} = Enum.split_with(cs, fun)

    tuples =
      if Keyword.get(opts, :extract, false) do
        Enum.map(tuples, fn c -> elem(c, 1) end)
      else
        tuples
      end

    tuples =
      if Keyword.get(opts, :reverse, false) do
        Enum.reverse(tuples)
      else
        tuples
      end

    {tuples, rest}
  end
end
