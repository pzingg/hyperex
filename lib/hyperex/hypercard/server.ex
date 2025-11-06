defmodule Hyperex.Hypercard.Server do
  use GenServer

  alias Hyperex.Hypercard.{Evaluator, Context, Script, Stack, StackFile, Value}

  defstruct [
    :address,
    :context,
    :script
  ]

  @typedoc "A HyperCard application"
  @type t() :: %__MODULE__{
          address: String.t(),
          script: Script.t() | nil,
          context: Context.t()
        }

  @impl true
  def init(_args) do
    # TODO - stack_dir should come from config
    stacks_dir = Path.join(:code.priv_dir(:hyperex), "stacks")

    {:ok,
     %__MODULE__{
       address: "HyperCard",
       script: nil,
       context: Context.new()
     }, {:continue, {:load_home_stack, stacks_dir}}}
  end

  @impl true
  def handle_continue({:load_home_stack, dir}, state) do
    case load_home_stack(state, dir) do
      {:ok, state} -> {:noreply, state}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call(:peek_context, _from, state) do
    {:reply, state.context, state}
  end

  def handle_call({:get_stack, stack_name}, _from, state) do
    res = Context.get_stack(state.context, stack_name)
    {:reply, res, state}
  end

  def handle_call({:get_card_or_background, stack_name, kind, query}, _from, state) do
    res = Context.get_card_or_background(state.context, stack_name, kind, query)
    {:reply, res, state}
  end

  def handle_call({:get_part, stack_name, card_id, parent_kind, kind, query}, _from, state) do
    res = Context.get_part(state.context, stack_name, card_id, parent_kind, kind, query)
    {:reply, res, state}
  end

  def handle_call({:eval, ast}, _from, state) do
    res = Evaluator.new(ast, state.context) |> Evaluator.eval()
    {:reply, res, state}
  end

  ## Private functions

  defp load_home_stack(state, dir) do
    path = Path.join(dir, "Home.json")

    with {:ok, contents} <- File.read(path),
         {:ok, stack} <- Stack.json_decode(contents),
         {:ok, ctx} <-
           Context.insert_stack(state.context, stack, path,
             home?: true,
             start_using?: false,
             go_first?: true
           ) do
      {:ok, %__MODULE__{state | context: ctx}}
    end
  end
end
