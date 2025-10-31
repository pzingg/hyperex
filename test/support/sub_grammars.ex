defmodule Hyperex.Test.SubGrammars do
  @moduledoc false

  import Xpeg

  @peg_test (peg(:program) do
               Whitespace <- " " | "\t"
               Comment <- "--" * star(1 - "\n")
               # Token delimeter
               :+ <- star(Whitespace) * opt(Comment)

               # Basics
               Nl <- "\n"
               AlphaLower <- {~c"a"..~c"z"}
               Alpha <- {~c"A"..~c"Z"} | AlphaLower
               Digit <- {~c"0"..~c"9"}
               Word <- AlphaLower * star(Alpha | Digit)

               Reserved <-
                 "else"
                 | "end"
                 | "exit"
                 | "function"
                 | "global"
                 | "if"
                 | "next"
                 | "on"
                 | "pass"
                 | "repeat"
                 | "return"
                 | "send"
                 | "then"

               NonReserved <- Reserved * +(Alpha | Digit)

               :id <- NonReserved | Word - Reserved
               :param <- str(:id) * fn [v | cs] -> [{:param, String.downcase(v)} | cs] end
               :parameter_list <- :param * :+ * star("," * :+ * :param)

               :handler_name <- :id

               :handler <-
                 "on" * :+ * str(:handler_name) * :+ * opt(:parameter_list) * :+ * +Nl *
                   :+ * "end" * :+ * :handler_name *
                   fn cs ->
                     {params, [name | rest]} =
                       Enum.split_while(cs, fn c -> is_tuple(c) && elem(c, 0) == :param end)

                     [
                       {:handler, String.downcase(name),
                        {:params,
                         params |> Enum.map(fn param -> elem(param, 1) end) |> Enum.reverse()}}
                       | rest
                     ]
                   end

               :script <-
                 star(Nl) * :+ * :handler * :+ * star(+Nl * :+ * :handler) * :+ *
                   star(Nl) *
                   fn cs ->
                     {elems, rest} =
                       Enum.split_while(cs, fn c -> is_tuple(c) && elem(c, 0) == :handler end)

                     [
                       {:script, Enum.reverse(elems)} | rest
                     ]
                   end

               :program <-
                 :+ * :script * :+
             end)

  @peg_strings (peg(:program) do
                  # Basics
                  Whitespace <- " " | "\t"
                  Comment <- "--" * star(1 - "\n")
                  # Token delimeter
                  :+ <- star(Whitespace) * opt(Comment)

                  :single_quoted <-
                    str(star("'" * "'" | 1 - "'")) *
                      fn [s | cs] ->
                        [{:string_lit, String.replace(s, "''", "'")} | cs]
                      end

                  :double_quoted <-
                    str(star("\"" * "\"" | 1 - "\"")) *
                      fn [s | cs] ->
                        [{:string_lit, String.replace(s, "\"\"", "\"")} | cs]
                      end

                  :string_lit <- "'" * :single_quoted * "'" | "\"" * :double_quoted * "\""
                  :program <- :+ * :string_lit * :+
                end)

  @peg_id (peg(:program) do
             # Basics
             Whitespace <- " " | "\t"
             Comment <- "--" * star(1 - "\n")
             # Token delimeter
             :+ <- star(Whitespace) * opt(Comment)

             AlphaLower <- {~c"a"..~c"z"}
             Alpha <- {~c"A"..~c"Z"} | AlphaLower
             Digit <- {~c"0"..~c"9"}
             Word <- AlphaLower * star(Alpha | Digit)

             Reserved <-
               "else"
               | "end"
               | "exit"
               | "function"
               | "global"
               | "if"
               | "next"
               | "on"
               | "pass"
               | "repeat"
               | "return"
               | "send"
               | "then"

             NonReserved <- Reserved * +(Alpha | Digit)

             :id <- NonReserved | Word - Reserved
             :program <- :+ * :id * :+
           end)

  def peg_test, do: @peg_test

  def peg_strings, do: @peg_strings

  def peg_id, do: @peg_id
end
