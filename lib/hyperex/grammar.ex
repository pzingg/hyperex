defmodule Hyperex.Grammar do
  @moduledoc false

  import Xpeg

  @peg_script (peg(:program) do
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
                   # add all the others!
                   | "not"
                   | "true"
                   | "there"

                 NonReserved <- Reserved * +(Alpha | Digit)
                 :id <- NonReserved | Word - Reserved

                 # HyperTalk vocabulary
                 :true_false <- "true" | "false"

                 :cardinal_value <-
                   "zero"
                   | "one"
                   | "two"
                   | "three"
                   | "four"
                   | "five"
                   | "six"
                   | "seven"
                   | "eight"
                   | "nine"
                   | "ten"

                 :constant <-
                   str(
                     :true_false
                     | :cardinal_value
                     | "empty"
                     | "pi"
                     | "quote"
                     | "return"
                     | "space"
                     | "tab"
                     | "formfeed"
                     | "formFeed"
                     | "linefeed"
                     | "lineFeed"
                     | "comma"
                     | "colon"
                   ) * fn [v | cs] -> [{:constant, String.downcase(v)} | cs] end

                 :float <-
                   float(
                     opt("-") *
                       ("." * +Digit | +Digit * "." * star(Digit)) *
                       opt(("e" | "E") * opt("-" | "+") * +Digit)
                   ) * fn [v | cs] -> [{:float, v} | cs] end

                 :integer <- int(opt("-") * +Digit) * fn [v | cs] -> [{:integer, v} | cs] end

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

                 :variable <- str(:id) * fn [v | cs] -> [{:var, v} | cs] end

                 :factor <-
                   "(" * :+ * :expr * :+ * ")"
                   | :constant
                   | :float
                   | :integer
                   | :string_lit
                   | :variable

                 # Put factor first to avoid collision of negative :float
                 :term_b10 <- :factor | :prefix_b10
                 :term_b9 <- :term_b10 * star(:infix_b9)
                 :term_b8 <- :term_b9 * star(:infix_b8)
                 :term_b7 <- :term_b8 * star(:infix_b7)
                 :term_b6 <- :term_b7 * star(:infix_b6)
                 :term_b5 <- :term_b6 * star(:infix_b5)
                 :term_b4 <- :term_b5 * star(:infix_b4)
                 :term_b3 <- :term_b4 * star(:infix_b3)
                 :term_b2 <- :term_b3 * star(:infix_b2)

                 # Finally...
                 :expr <- :+ * :term_b2 * star(:infix_b1)
                 :expr_list <- :expr * :+ * star("," * :+ * :expr)

                 # Operators, lowest to highest binding power
                 :infix_b1 <-
                   :+ * "or" * :+ * :expr *
                     fn [b, a | cs] ->
                       [{:or, [a, b]} | cs]
                     end

                 :infix_b2 <-
                   :+ * "and" * :+ * :term_b2 *
                     fn [b, a | cs] ->
                       [{:and, [a, b]} | cs]
                     end

                 # equality
                 :op_not_equals <-
                   ("is" * :+ * "not" | "<>" | "≠") * fn cs -> [:not_equals | cs] end

                 :op_equals <- ("=" | "is") * fn cs -> [:equals | cs] end

                 :infix_b3 <-
                   :+ * (:op_not_equals | :op_equals) * :+ * :term_b3 *
                     fn [b, op, a | cs] ->
                       [{op, [a, b]} | cs]
                     end

                 # comparisons
                 :op_not_in <- "is" * :+ * "not" * :+ * "in" * fn cs -> [:not_in | cs] end

                 :op_not_type <-
                   "is" * :+ * "not" * :+ * ("a" * opt("n")) * fn cs -> [:not_type | cs] end

                 :op_in <- "is" * :+ * "in" * fn cs -> [:in | cs] end
                 :op_is_type <- "is" * :+ * ("a" * opt("n")) * fn cs -> [:is_type | cs] end

                 :infix_b4 <-
                   :+ *
                     str(
                       "<="
                       | "≤"
                       | ">="
                       | "≥"
                       | "<"
                       | ">"
                       | "contains"
                       | :op_not_in
                       | :op_not_type
                       | :op_in
                       | :op_is_type
                     ) * :+ * :term_b4 *
                     fn [b, op, a | cs] ->
                       case op do
                         ">" -> [{:gt, [a, b]} | cs]
                         "≥" -> [{:gte, [a, b]} | cs]
                         ">=" -> [{:gte, [a, b]} | cs]
                         "<" -> [{:lt, [a, b]} | cs]
                         "≤" -> [{:gte, [a, b]} | cs]
                         "<=" -> [{:gte, [a, b]} | cs]
                         "contains" -> [{:contains, [a, b]} | cs]
                         _ -> [{op, [a, b]} | cs]
                       end
                     end

                 # concat, concat_ws
                 :infix_b5 <-
                   :+ * str("&&" | "&") * :+ * :term_b5 *
                     fn [b, op, a | cs] ->
                       case op do
                         "&&" -> [{:concat_ws, [a, b]} | cs]
                         "&" -> [{:concat, [a, b]} | cs]
                       end
                     end

                 # add, sub
                 :infix_b6 <-
                   :+ * str({~c"+", ~c"-"}) * :+ * :term_b6 *
                     fn [b, op, a | cs] ->
                       case op do
                         "+" -> [{:add, [a, b]} | cs]
                         "-" -> [{:sub, [a, b]} | cs]
                       end
                     end

                 # mul, div, mod, div_trunc
                 :infix_b7 <-
                   :+ * str("*" | "/" | "div" | "mod") * :+ * :term_b7 *
                     fn [b, op, a | cs] ->
                       case op do
                         "*" -> [{:mul, [a, b]} | cs]
                         "/" -> [{:div, [a, b]} | cs]
                         "mod" -> [{:mod, [a, b]} | cs]
                         "div" -> [{:div_trunc, [a, b]} | cs]
                       end
                     end

                 # pow
                 :infix_b8 <-
                   :+ * str("^") * :+ * :term_b8 *
                     fn [b, _op, a | cs] -> [{:pow, [a, b]} | cs] end

                 # within
                 :op_not_within <-
                   "is" * :+ * "not" * :+ * "within" * fn cs -> [:not_within | cs] end

                 :op_within <- "is" * :+ * "within" * fn cs -> [:within | cs] end

                 :infix_b9 <-
                   :+ * (:op_not_within | :op_within) * :+ * :term_b9 *
                     fn [b, op, a | cs] ->
                       [{op, [a, b]} | cs]
                     end

                 # exists, not, negate
                 :op_not_exists <-
                   "there" * :+ * "is" * :+ * ("no" * opt("t")) * :+ * ("a" * opt("n")) *
                     fn cs -> [:not_exists | cs] end

                 :op_exists <-
                   "there" * :+ * "is" * :+ * ("a" * opt("n")) * fn cs -> [:exists | cs] end

                 :prefix_b10 <-
                   (str("-" | "not") | :op_not_exists | :op_exists) * :+ * :term_b10 *
                     fn [x, op | cs] ->
                       case op do
                         "-" -> [{:negate, [x]} | cs]
                         "not" -> [{:not, [x]} | cs]
                         _ -> [{op, [x]} | cs]
                       end
                     end

                 #       | exit_statement
                 #       | pass_statement
                 #       | if_statement
                 #       | repeat_statement
                 #       | command_statement
                 #       | function_call
                 #       | message_statement

                 :parameter_list <-
                   :param * :+ * star("," * :+ * :param) *
                     fn cs ->
                       {params, rest} =
                         Enum.split_while(cs, fn c -> is_tuple(c) && elem(c, 0) == :param end)

                       [
                         {:params, params |> Enum.map(fn c -> elem(c, 1) end) |> Enum.reverse()}
                         | rest
                       ]
                     end

                 :global <-
                   "global" * :+ * :parameter_list *
                     fn cs ->
                       {params, rest} =
                         Enum.split_with(cs, fn c -> is_tuple(c) && elem(c, 0) == :params end)

                       case params do
                         [{:params, params}] -> [{:global, params} | rest]
                         [] -> [{:global, []} | rest]
                       end
                     end

                 :return <-
                   "return" * :+ * opt(:expr) *
                     fn cs -> [{:return, cs}] end

                 :handler_name <- str(:id) * fn [name | cs] -> [{:handler_name, name} | cs] end

                 :pass <-
                   "pass" * :+ * :handler_name *
                     fn [{:handler_name, name} | cs] -> [{:pass, name} | cs] end

                 :exit_to_hypercard <-
                   "to" * :+ * ("HyperCard" | "hypercard") *
                     fn cs -> [:exit_to_hypercard | cs] end

                 :exit_repeat <- "repeat" * fn cs -> [:exit_repeat | cs] end

                 :exit_handler <-
                   :handler_name *
                     fn [{:handler_name, name} | cs] -> [{:exit_handler, name} | cs] end

                 :exit <- "exit" * :+ * (:exit_to_hypercard | :exit_repeat | :exit_handler)

                 :end_if <- "end" * :+ * "if"
                 :else_single <- :statement * :+ * opt(+:Nl * :+ * :end_if)
                 :else_multi <- +:Nl * :+ * opt(:statement_list) * :+ * :end_if
                 :else <- "else" * :+ * (:else_single | :else_multi)

                 :then_multiline <-
                   +:Nl * :+ * :statement_list * :+ * star(:Nl) * :+ * (:else | :end_if) *
                     fn cs ->
                       IO.puts("then #{inspect(cs)}")
                       cs
                     end

                 :then_single_line <- :statement * :+ * opt(:Nl) * :+ * opt(:else)
                 :then <- "then" * :+ * (:then_multiline | :then_single_line)

                 :if <-
                   "if" * :+ * :expr * :+ * opt(:Nl) * :+ * :then * fn cs ->
                    {stmnts, [test | rest]} = Enum.split_while(cs, fn c -> is_tuple(c) && elem(c, 0) in [:statement, :statements] end)
                    case stmnts do
                      [{:statement, if_path}] -> [{:if, test, [if_path], []} | rest]
                      [{:statements, if_path}] -> [{:if, test, if_path, []} | rest]
                      [{:statement, else_path}, {:statement, if_path}] -> [{:if, test, [if_path], [else_path]} | rest]
                      [{:statements, else_path}, {:statements, if_path}] -> [{:if, test, if_path, else_path} | rest]
                    end
                  end

                 :message_name <- str(:id)

                 :message <-
                   :message_name * :+ * opt(:expr_list) *
                     fn cs ->
                       {exprs, [name | rest]} =
                         Enum.split_while(cs, fn c -> is_tuple(c) end)

                       [{:message, name, Enum.reverse(exprs)} | rest]
                     end

                 :statement <-
                   (:global | :return | :pass | :exit | :if | :message | :expr) *
                     fn [e | cs] -> [{:statement, e} | cs] end

                 :statement_list <-
                   :statement * :+ * star(+Nl * :+ * :statement) * :+ * star(Nl) *
                     fn cs ->
                       {stmnts, rest} =
                         Enum.split_while(cs, fn c -> is_tuple(c) && elem(c, 0) == :statement end)

                       [
                         {:statements,
                          stmnts |> Enum.map(fn s -> elem(s, 1) end) |> Enum.reverse()}
                         | rest
                       ]
                     end

                 :scriptlet <-
                   star(Nl) * :+ * :statement_list *
                     fn [stmnts | _] -> [scriptlet: elem(stmnts, 1)] end

                 :param <- str(:id) * fn [v | cs] -> [{:param, String.downcase(v)} | cs] end

                 :handler_end <- :id

                 :handler <-
                   "on" * :+ * :handler_name * :+ * opt(:parameter_list) * :+ * +Nl *
                     :+ *
                     opt(:statement_list) * :+ * "end" * :+ * :handler_end *
                     fn cs ->
                       {handler, rest} =
                         Enum.split_with(cs, fn c ->
                           is_tuple(c) && elem(c, 0) in [:params, :statements, :handler_name]
                         end)

                       {name, params, stmnts} =
                         Enum.reduce(handler, {"", [], []}, fn elem, {n, p, s} ->
                           case elem do
                             {:handler_name, name} -> {name, p, s}
                             {:params, params} -> {n, params, s}
                             {:statements, statement_list} -> {n, p, statement_list}
                           end
                         end)

                       [{:handler, String.downcase(name), params, stmnts} | rest]
                     end

                 :function_name <- str(:id) * fn [name | cs] -> [{:function_name, name} | cs] end

                 :function_def <-
                   "function" * :+ * :function_name * :+ * opt(:parameter_list) * :+ * +Nl * :+ *
                     opt(:statement_list) * :+ * "end" * :+ * :id *
                     fn cs ->
                       {function, rest} =
                         Enum.split_with(cs, fn c ->
                           is_tuple(c) && elem(c, 0) in [:params, :statements, :function_name]
                         end)

                       {name, params, stmnts} =
                         Enum.reduce(function, {"", [], []}, fn elem, {n, p, s} ->
                           case elem do
                             {:function_name, name} -> {name, p, s}
                             {:params, params} -> {n, params, s}
                             {:statements, statement_list} -> {n, p, statement_list}
                           end
                         end)

                       [{:function, String.downcase(name), params, stmnts} | rest]
                     end

                 :script_elem <- :handler | :function_def

                 :script <-
                   star(Nl) * :+ * :script_elem * :+ * star(+Nl * :+ * :script_elem) * :+ *
                     star(Nl) *
                     fn cs ->
                       {elems, rest} =
                         Enum.split_while(cs, fn c ->
                           is_tuple(c) && elem(c, 0) in [:handler, :function]
                         end)

                       [
                         {:script, Enum.reverse(elems)} | rest
                       ]
                     end

                 :program <- :+ * (:script | :scriptlet) * :+
               end)

  def peg_script, do: @peg_script
end
