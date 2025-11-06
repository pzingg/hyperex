defmodule Hyperex.Hypercard.CardTarget do
  defstruct [:stack, :card]

  @type t() :: %__MODULE__{
          stack: String.t(),
          card: non_neg_integer()
        }
end
