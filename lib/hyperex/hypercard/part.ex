defmodule Hyperex.Hypercard.Part do
  @moduledoc "A card or background button or field"

  alias Hyperex.Hypercard.{Card, Script}

  @derive Jason.Encoder
  defstruct [
    :id,
    :kind,
    :name,
    :script,
    :contents,
    :stack,
    :parent,
    :parent_kind,
    :number,
    :part_number
  ]

  @type part_kind() :: :button | :field

  @typedoc """
  A card or background button or field.

  For buttons these fields are nil:
    - `:auto_select`
    - `:auto_tab`
    - `:dont_search`
    - `:dont_wrap`
    - `:fixed_line_height`
    - `:multiple_lines`
    - `:scroll`
    - `:shared_text`
    - `:show_lines`
    - `:wide_margins`

  For fields these fields are nil:
    - `:auto_hilite`
    - `:enabled`
    - `:family`
    - `:icon`
    - `:shared_hilite`
    - `:show_name`

  For card parts:
    - `:parent_kind` is `:card`

  For background parts:
    - `:parent_kind` is `:background`
  """
  @type t() :: %__MODULE__{
          id: integer(),
          kind: part_kind(),
          name: String.t(),
          script: String.t() | nil,
          contents: String.t(),
          stack: String.t(),
          parent: integer(),
          parent_kind: Card.card_kind(),
          number: non_neg_integer(),
          part_number: non_neg_integer()
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

      kind not in ["button", "field"] ->
        {:error, :invalid_kind}

      true ->
        part = struct(__MODULE__, m)
        {:ok, %__MODULE__{part | kind: String.to_atom(kind)}}
    end
  end
end
