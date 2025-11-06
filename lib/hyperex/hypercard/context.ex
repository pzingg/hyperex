defmodule Hyperex.Hypercard.Context do
  alias Hyperex.Hypercard.{CardTarget, Stack, StackFile}

  defstruct home_stack: nil,
            current: nil,
            go: nil,
            stacks_in_use: [],
            stacks: %{},
            variables: %{}

  @type t() :: %__MODULE__{
          home_stack: String.t() | nil,
          current: CardTarget.t() | nil,
          go: CardTarget.t() | nil,
          stacks_in_use: [String.t()],
          stacks: %{String.t() => StackFile.t()},
          variables: %{String.t() => String.t()}
        }

  def error?({:error, _}), do: true
  def error?(_), do: false

  defp default_stack_name(%__MODULE__{current: %CardTarget{stack: name}}, ""), do: name
  defp default_stack_name(%__MODULE__{current: %CardTarget{stack: name}}, nil), do: name
  defp default_stack_name(_, stack_name), do: stack_name

  defp default_card_id(%__MODULE__{current: %CardTarget{card: card}}, 0), do: card
  defp default_card_id(%__MODULE__{current: %CardTarget{card: card}}, nil), do: card
  defp default_card_id(_, id), do: id

  def new(), do: %__MODULE__{}

  def add_variable(ctx, name, value) do
    %__MODULE__{ctx | variables: Map.put(ctx.variables, name, value)}
  end

  def get_variable(ctx, name) when is_binary(name) do
    Map.get(ctx.variables, name)
  end

  def insert_stack(ctx, stack, path, opts) do
    ctx =
      if Keyword.get(opts, :go_first?) do
        first_card = Stack.find_card_by_number(stack, :card, 1)

        if is_nil(first_card) do
          {:error, :no_cards_in_stack}
        else
          %__MODULE__{ctx | current: %CardTarget{stack: stack.name, card: first_card.id}}
        end
      else
        ctx
      end

    if error?(ctx) do
      ctx
    else
      stacks = Map.put(ctx.stacks, stack.name, %StackFile{path: path, stack: stack})

      ctx =
        if Keyword.get(opts, :home?) do
          %__MODULE__{ctx | home_stack: stack.name, stacks: stacks}
        else
          %__MODULE__{ctx | stacks: stacks}
        end

      ctx =
        if Keyword.get(opts, :start_using?) do
          %__MODULE__{ctx | stacks_in_use: [stack.name | ctx.stacks_in_use]}
        else
          ctx
        end

      {:ok, ctx}
    end
  end

  def get_stack(ctx, stack_name) do
    stack_name = default_stack_name(ctx, stack_name)
    find_stack(ctx, stack_name)
  end

  def find_stack(ctx, name) do
    case Map.get(ctx.stacks, name) do
      nil ->
        {:error, :stack_not_found}

      stack_file ->
        {:ok, stack_file.stack, stack_file.path}
    end
  end

  def get_number_of_cards_or_backgrounds(ctx, stack_name, kind) do
    res = get_stack(ctx, stack_name)

    case res do
      {:error, _} = error ->
        error

      {:ok, stack, _} ->
        Stack.number_of_cards_or_backgrounds(stack, kind)
    end
  end

  def get_card_or_background(ctx, stack_name, kind, query) do
    res = get_stack(ctx, stack_name)

    case res do
      {:error, _} = error ->
        error

      {:ok, stack, _} ->
        Stack.find_card_or_background(stack, kind, query)
    end
  end

  def get_number_of_parts(ctx, stack_name, card_id, parent_kind, kind) do
    res = get_stack(ctx, stack_name)

    case res do
      {:error, _} = error ->
        error

      {:ok, stack, _} ->
        card_id = default_card_id(ctx, card_id)
        res = Stack.find_card_or_background(stack, :card, id: card_id)

        case res do
          {:error, _} = error ->
            error

          {:ok, card, background} ->
            Stack.number_of_parts(card, background, parent_kind, kind)
        end
    end
  end

  def get_part(ctx, stack_name, card_id, parent_kind, kind, query) do
    res = get_stack(ctx, stack_name)

    case res do
      {:error, _} = error ->
        error

      {:ok, stack, _} ->
        card_id = default_card_id(ctx, card_id)
        res = Stack.find_card_or_background(stack, :card, id: card_id)

        case res do
          {:error, _} = error ->
            error

          {:ok, card, background} ->
            Stack.find_part(card, background, parent_kind, kind, query)
        end
    end
  end
end
