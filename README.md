# Hyperex

Parsing Apple's HyperTalk language using [xpeg](https://github.com/zevv/xpeg).

Much learning from [ex_pression grammar](https://github.com/balance-platform/ex_pression/blob/master/lib/ex_pression/parser/grammar.ex).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `hyperex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hyperex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/hyperex>.

## Notes

The PEG parser is greedy. There was a bug in trying to parse this scriplet:

```
the english name of fieldVal
```

When the parser got to "fieldVal", it found a rule for identifying fields
and just gladly ate up the "field" part of the string. I inserted a 
`:^` (mandatory white space) in a few of the rules, just before the end
of the rule that had an `opt`. This also may require appending a space 
character to the end of all scripts (or to the ends of each line in a
script).

## Message passing

When buttons and fields are layered on top of each other, mouse messages are
sent only to the closest one. Background buttons and fields can never overlay
those belonging to the card. Both background fields and card fields precede the
card in the message-passing hierarchy even though the background itself
comes after the card.