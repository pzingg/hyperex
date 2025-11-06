defmodule Hyperex.Hypercard.StackFile do
  @moduledoc "A HyperCard stack file locator"

  alias Hyperex.Hypercard
  alias Hyperex.Hypercard.Stack

  defstruct [:path, :stack]

  @typedoc "A HyperCard stack file locator"
  @type t() :: %__MODULE__{
          path: String.t(),
          stack: Stack.t()
        }
end
