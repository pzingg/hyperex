defmodule Hyperex.Hypercard.Value do
  defstruct [:special, :as_string, :as_integer, :as_float]

  @type t() :: %__MODULE__{
          special: term(),
          as_string: String.t() | nil,
          as_integer: integer() | nil,
          as_float: float() | nil
        }
end
