defmodule Hyperex.Hypercard do
  @moduledoc "A HyperCard application"

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(args) do
    GenServer.start_link(Hyperex.Hypercard.Server, args, name: __MODULE__)
  end

  def peek_context() do
    GenServer.call(__MODULE__, :peek_context)
  end

  def get_stack(name) do
    GenServer.call(__MODULE__, {:get_stack, name})
  end

  def get_card_or_background(stack_name, kind, query) do
    GenServer.call(__MODULE__, {:get_card_or_background, stack_name, kind, query})
  end

  def get_part(stack_name, card_id, parent_kind, kind, query) do
    GenServer.call(__MODULE__, {:get_part, stack_name, card_id, parent_kind, kind, query})
  end

  def eval(ast) do
    GenServer.call(__MODULE__, {:eval, ast})
  end
end
