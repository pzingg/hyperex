defmodule Hyperex.Hypercard.Stack do
  @moduledoc "A HyperCard stack"

  alias Hyperex.Hypercard.{Background, Card, Script}

  @derive Jason.Encoder
  defstruct [:name, :script, :cards, :last_id]

  @type card() :: Background.t() | Card.t()

  @typedoc "A HyperCard stack"
  @type t() :: %__MODULE__{
          name: String.t(),
          script: Script.t() | nil,
          cards: [Card.t()],
          last_id: integer()
        }

  def new(path) do
    %__MODULE__{
      name: Path.basename(path),
      last_id: 2500
    }
  end

  def new_id(stack) do
    id = stack.last_id + 1
    {id, %__MODULE__{stack | last_id: id}}
  end

  def json_decode(s) do
    case Jason.decode(s, keys: :atoms) do
      {:error, _} = error ->
        error

      {:ok, m} ->
        from_map(m)
    end
  end

  def from_map(m) do
    {cards, m} = Map.pop(m, :cards, [])

    cards_or_error =
      Enum.reduce_while(cards, [], fn card, acc ->
        case Card.from_map(card) do
          {:ok, card} -> {:cont, [card | acc]}
          error -> {:halt, error}
        end
      end)

    case cards_or_error do
      {:error, _} = error ->
        error

      cards ->
        card = struct(__MODULE__, m)
        {:ok, %__MODULE__{card | cards: Enum.reverse(cards)}}
    end
  end

  def find_card_or_background(stack, kind, query) do
    IO.puts("find_card st #{stack.name} k #{kind} q #{inspect(query)}")

    card =
      case Keyword.get(query, :id) do
        id when is_integer(id) ->
          find_card_by_id(stack, kind, id)

        _ ->
          case Keyword.get(query, :name) do
            name when is_binary(name) ->
              find_card_by_name_or_number(stack, kind, name)

            _ ->
              case Keyword.get(query, :number) do
                n when is_integer(n) -> find_card_by_number(stack, kind, n)
                _ -> nil
              end
          end
      end

    if is_nil(card) do
      {:error, :card_not_found}
    else
      if kind == :card do
        bkgnd = find_card_by_id(stack, :background, card.background)

        if is_nil(bkgnd) do
          {:error, :background_not_found}
        else
          {:ok, card, bkgnd}
        end
      else
        {:ok, card}
      end
    end
  end

  # If you use numbers for an object’s name, HyperCard could
  # misinterpret the name: it takes card "1812" to mean a
  # card whose number, rather than name, is 1812.
  def find_card_by_id(stack, kind, id) do
    Enum.find(stack.cards, fn card -> card.kind == kind && card.id == id end)
  end

  def find_card_by_name_or_number(stack, kind, name) do
    case Integer.parse(name) do
      {number, ""} ->
        Enum.find(stack.cards, fn card ->
          (card.kind == kind && card.number == number) || card.name == name
        end)

      _ ->
        Enum.find(stack.cards, fn card -> card.kind == kind && card.name == name end)
    end
  end

  def find_card_by_number(stack, kind, number) do
    Enum.find(stack.cards, fn card -> card.kind == kind && card.number == number end)
  end

  def find_part(card, background, parent_kind, kind, query) do
    IO.puts(
      "find_part cd #{card.id} bg #{background.id} p #{parent_kind} k #{kind} q #{inspect(query)}"
    )

    part =
      case Keyword.get(query, :id) do
        id when is_integer(id) ->
          find_part_by_id(card, background, parent_kind, kind, id)

        _ ->
          case Keyword.get(query, :name) do
            name when is_binary(name) ->
              find_part_by_name_or_number(card, background, parent_kind, kind, name)

            _ ->
              case Keyword.get(query, :number) do
                n when is_integer(n) ->
                  find_part_by_number(card, background, parent_kind, kind, n)

                _ ->
                  nil
              end
          end
      end

    if is_nil(part) do
      {:error, :part_not_found}
    else
      {:ok, part}
    end
  end

  def get_parent_kind(:background, _), do: :background
  def get_parent_kind(:card, _), do: :card
  def get_parent_kind(_, :field), do: :background
  def get_parent_kind(_, _), do: :card

  def get_source(card, background, parent_kind, kind) do
    case get_parent_kind(parent_kind, kind) do
      :card -> card
      :background -> background
    end
  end

  def find_part_by_id(card, background, parent_kind, kind, id) do
    get_source(card, background, parent_kind, kind)
    |> Map.get(:parts)
    |> Enum.find(fn part -> part.kind == kind && part.id == id end)
  end

  def find_part_by_name_or_number(card, background, parent_kind, kind, name) do
    parts =
      get_source(card, background, parent_kind, kind)
      |> Map.get(:parts)

    case Integer.parse(name) do
      {number, ""} ->
        Enum.find(parts, fn part ->
          (part.kind == kind && part.number == number) || part.name == name
        end)

      _ ->
        Enum.find(parts, fn part -> part.kind == kind && part.name == name end)
    end
  end

  def find_part_by_number(card, background, parent_kind, kind, number) do
    get_source(card, background, parent_kind, kind)
    |> Map.get(:parts)
    |> Enum.find(fn part -> part.kind == kind && part.number == number end)
  end
end
