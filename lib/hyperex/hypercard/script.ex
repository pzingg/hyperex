defmodule Hyperex.Hypercard.Script do
  @moduledoc "A HyperTalk script with message handlers and functions"

  @type script() :: {:script, elements :: term()}
  @type ast_handler() :: {:handler, name :: String.t(), params :: term(), stmnts :: term()}
  @type ast_function() :: {:function, name :: String.t(), params :: term(), stmnts :: term()}
  @type parse_result() :: :ok | {:error, reason :: term()}

  defstruct [:text, :ast, :parse_result, :handlers, :functions]

  @typedoc "A HyperTalk script with message handlers and functions"
  @type t() :: %__MODULE__{
          text: String.t(),
          ast: script(),
          parse_result: parse_result(),
          handlers: [ast_handler()],
          functions: [ast_function()]
        }
end
