defmodule Hyperex.Hypercard.Card do
  @moduledoc "A background or card in a stack"

  alias Hyperex.Hypercard.{Part, Script}

  @derive Jason.Encoder
  defstruct [:id, :kind, :name, :script, :stack, :background, :number, :parts]

  @type card_kind() :: :card | :background

  @typedoc """
  A background or card in a stack.

  For cards:
    - `:background` is the id of the card's background

  For backgrounds:
    - `:background` is 0
  """
  @type t() :: %__MODULE__{
          id: integer(),
          kind: card_kind(),
          name: String.t(),
          script: Script.t() | nil,
          stack: String.t(),
          background: non_neg_integer(),
          number: non_neg_integer() | nil,
          parts: [Part.t()]
        }

  def json_decode(s) do
    case Jason.decode(s, keys: :atoms) do
      {:error, _} = error ->
        error

      {:ok, m} ->
        from_map(m)
    end
  end

  def from_map(m) do
    {kind, m} = Map.pop(m, :kind)

    cond do
      !is_binary(kind) ->
        {:error, :no_kind}

      kind not in ["background", "card"] ->
        {:error, :invalid_kind}

      true ->
        {parts, m} = Map.pop(m, :parts, [])

        parts_or_error =
          Enum.reduce_while(parts, [], fn part, acc ->
            case Part.from_map(part) do
              {:ok, part} -> {:cont, [part | acc]}
              error -> {:halt, error}
            end
          end)

        case parts_or_error do
          {:error, _} = error ->
            error

          parts ->
            card = struct(__MODULE__, m)
            {:ok, %__MODULE__{card | kind: String.to_atom(kind), parts: Enum.reverse(parts)}}
        end
    end
  end
end
