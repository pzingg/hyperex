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
                   | :date_time_func_name
                   | :zero_arg_func_name
                   | :single_arg_func_name
                   | :two_arg_func_name
                   | :list_arg_func_name
                   | "is"
                   | "not"
                   | "there"
                   | "true"
                   | "false"

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
                     | "formFeed"
                     | "formfeed"
                     | "lineFeed"
                     | "linefeed"
                     | "comma"
                     | "colon"
                   ) * fn [v | cs] -> [{:constant, String.downcase(v)} | cs] end

                 :float <-
                   float(
                     opt("-") *
                       (opt("0") * "." * +Digit | +Digit * "." * star(Digit)) *
                       opt(("e" | "E") * opt("-" | "+") * +Digit)
                   ) * fn [v | cs] -> [{:float, v} | cs] end

                 :integer <-
                   int("0" | opt("-") * {~c"1"..~c"9"} * star(Digit)) *
                     fn [v | cs] -> [{:integer, v} | cs] end

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

                 :parameter_list <-
                   :param * :+ * star("," * :+ * :param) *
                     fn cs ->
                       {params, rest} =
                         Kernel.apply(Hyperex.Grammar.Helpers, :split_opt_list, [
                           cs,
                           [in: :param, reverse: true, extract: true]
                         ])

                       [{:params, params} | rest]
                     end

                 :global <-
                   "global" * :+ * :parameter_list *
                     fn cs ->
                       {params, rest} =
                         Kernel.apply(Hyperex.Grammar.Helpers, :split_opt_list, [
                           cs,
                           [in: :params]
                         ])

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
                   +:Nl * :+ * :statement_list * :+ * star(:Nl) * :+ * (:else | :end_if)

                 :then_single_line <- :statement * :+ * opt(:Nl) * :+ * opt(:else)
                 :then <- "then" * :+ * (:then_multiline | :then_single_line)

                 :if <-
                   "if" * :+ * :expr * :+ * opt(:Nl) * :+ * :then *
                     fn cs ->
                       {stmnts, [test | rest]} =
                         Kernel.apply(Hyperex.Grammar.Helpers, :split_opt_list, [
                           cs,
                           [in: [:statement, :statements]]
                         ])

                       case stmnts do
                         [{:statement, if_path}] ->
                           [{:if, test, [if_path], []} | rest]

                         [{:statements, if_path}] ->
                           [{:if, test, if_path, []} | rest]

                         [{:statement, else_path}, {:statement, if_path}] ->
                           [{:if, test, [if_path], [else_path]} | rest]

                         [{:statements, else_path}, {:statements, if_path}] ->
                           [{:if, test, if_path, else_path} | rest]
                       end
                     end

                 :repeat_until <-
                   "until" * :+ * :expr * fn [ex | cs] -> [{:repeat_until, [], ex} | cs] end

                 :repeat_while <-
                   "while" * :+ * :expr * fn [ex | cs] -> [{:repeat_while, [], ex} | cs] end

                 :repeat_with_desc <-
                   str(:id) * :+ * "=" * :+ * :expr * :+ * "down" * :+ * "to" * :+ * :expr *
                     fn [to, from, var | cs] -> [{:repeat_with_desc, [], var, from, to} | cs] end

                 :repeat_with_asc <-
                   str(:id) * :+ * "=" * :+ * :expr * :+ * "to" * :+ * :expr *
                     fn [to, from, var | cs] -> [{:repeat_with_asc, [], var, from, to} | cs] end

                 :repeat_with <- "with" * :+ * (:repeat_with_desc | :repeat_with_asc)

                 :repeat_forever <- "forever" * fn cs -> [{:repeat_forever, []} | cs] end

                 :repeat_count <-
                   opt("for") * :+ * :expr * :+ * opt("times") *
                     fn [ex | cs] -> [{:repeat_count, [], ex} | cs] end

                 :repeat_range <-
                   :repeat_until
                   | :repeat_while
                   | :repeat_with
                   | :repeat_forever
                   | :repeat_count

                 :repeat <-
                   "repeat" * :+ * :repeat_range * :+ * +Nl * :+ * :statement_list * :+ *
                     "end" * :+ * "repeat" *
                     fn [{:statements, stmnts}, rep | cs] ->
                       rep =
                         case rep do
                           {:repeat_until, _, ex} ->
                             {:repeat_until, stmnts, ex}

                           {:repeat_while, _, ex} ->
                             {:repeat_while, stmnts, ex}

                           {:repeat_with_desc, _, var, from, to} ->
                             {:repeat_with_desc, stmnts, var, from, to}

                           {:repeat_with_asc, _, var, from, to} ->
                             {:repeat_with_asc, stmnts, var, from, to}

                           {:repeat_forever, _} ->
                             {:repeat_forever, stmnts}

                           {:repeat_count, _, ex} ->
                             {:repeat_count, stmnts, ex}
                         end

                       [rep | cs]
                     end

                 :adjective <-
                   str("abbreviated" | "abbrev" | "abbr" | "long" | "short") *
                     fn [v | cs] ->
                       format =
                         case v do
                           "long" -> {:format, :long}
                           "short" -> {:format, :short}
                           _ -> {:format, :abbrev}
                         end

                       [format | cs]
                     end

                 :date_time_func_name <- "date" | "time"

                 :zero_arg_func_name <-
                   "clickChunk"
                   | "clickchunk"
                   | "clickH"
                   | "clickh"
                   | "clickLine"
                   | "clickline"
                   | "clickLoc"
                   | "clickloc"
                   | "clickText"
                   | "clicktext"
                   | "clickV"
                   | "clickv"
                   | "commandKey"
                   | "commandkey"
                   | "cmdKey"
                   | "cmdkey"
                   | "date"
                   | "destination"
                   | "diskSpace"
                   | "diskspace"
                   | "foundChunk"
                   | "foundchunk"
                   | "foundField"
                   | "foundfield"
                   | "foundLine"
                   | "foundline"
                   | "foundText"
                   | "foundtext"
                   | "heapSpace"
                   | "heapspace"
                   | "menus"
                   | "mouseClick"
                   | "mouseclick"
                   | "mouseH"
                   | "mouseh"
                   | "mouseLoc"
                   | "mouseloc"
                   | "mouseV"
                   | "mousev"
                   | "mouse"
                   | "number"
                   | "optionKey"
                   | "optionkey"
                   | "paramCount"
                   | "paramcount"
                   | "params"
                   | "programs"
                   | "result"
                   | "screenRect"
                   | "screenrect"
                   | "seconds"
                   | "secs"
                   | "selectedChunk"
                   | "selectedchunk"
                   | "selectedField"
                   | "selectedfield"
                   | "selectedLoc"
                   | "selectedloc"
                   | "shiftKey"
                   | "shiftkey"
                   | "sound"
                   | "stackSpace"
                   | "stackspace"
                   | "stacks"
                   | "systemVersion"
                   | "systemversion"
                   | "ticks"
                   | "time"
                   | "tool"
                   | "voices"
                   | "windows"

                 :single_arg_func_name <-
                   "abs"
                   | "atan"
                   | "charToNum"
                   | "chartonum"
                   | "cos"
                   | "exp1"
                   | "exp2"
                   | "exp"
                   | "length"
                   | "ln1"
                   | "ln"
                   | "log2"
                   | "numToChar"
                   | "numtochar"
                   | "param"
                   | "random"
                   | "round"
                   | "selectedButton"
                   | "selectedbutton"
                   | "selectedLine"
                   | "selectedline"
                   | "selectedText"
                   | "selectedtext"
                   | "sin"
                   | "sqrt"
                   | "tan"
                   | "trunc"
                   | "value"

                 :two_arg_func_name <-
                   "annuity"
                   | "compound"
                   | "offset"

                 :list_arg_func_name <-
                   "average"
                   | "min"
                   | "max"
                   | "sum"

                 :the_formatted_func <-
                   "the" * :+ * opt(:adjective) * :+ * str(:date_time_func_name | "target") *
                     fn [name | cs] ->
                       name =
                         if name == "target" do
                           "the_target"
                         else
                           name
                         end

                       case cs do
                         [{:format, _} = format | rest] ->
                           [{:function_call, name, [], [format]} | rest]

                         _ ->
                           [{:function_call, name, [], []} | cs]
                       end
                     end

                 :target_func <- "target" * fn cs -> [{:function_call, "target", [], []} | cs] end

                 :number_func <-
                   opt("the") * :+ * "number" * :+ * "of" * :+ * str(1 - Nl) *
                     fn [obj | cs] -> [{:function_call, "number", [obj], []} | cs] end

                 :zero_arg_func <-
                   str(:zero_arg_func_name) *
                     fn [name | cs] -> [{:function_call, name, [], []} | cs] end

                 :single_arg_func <-
                   str(:single_arg_func_name) *
                     fn [name | cs] -> [{:function_call, name, [], []} | cs] end

                 :the_single_arg_func_of <-
                   "the" * :+ * :single_arg_func * :+ * "of" * :+ * :expr *
                     fn [ex, {:function_call, name, _, opts} | cs] ->
                       [{:function_call, name, [ex], opts} | cs]
                     end

                 :single_arg_func_parens <-
                   :single_arg_func * :+ * "(" * :+ * :expr * :+ * ")" *
                     fn [ex, {:function_call, name, _, opts} | cs] ->
                       [{:function_call, name, [ex], opts} | cs]
                     end

                 :list_arg_func <-
                   str(:two_arg_func_name | :list_arg_func_name) * :+ *
                     "(" * :+ * :expr_list * :+ * ")" *
                     fn cs ->
                       {exlist, [name | rest]} =
                         Kernel.apply(Hyperex.Grammar.Helpers, :split_opt_list, [
                           cs,
                           [reverse: true]
                         ])

                       [{:function_call, name, exlist, []} | rest]
                     end

                 :built_in_func <-
                   :the_formatted_func
                   | :the_single_arg_func_of
                   | "the" * :+ * :zero_arg_func
                   | :target_func
                   | :number_func
                   | :zero_arg_func * :+ * "(" * :+ * ")"
                   | :single_arg_func_parens
                   | :list_arg_func

                 :user_func <-
                   str(:id) * :+ * "(" * :+ * opt(:expr_list) * :+ * ")" *
                     fn cs ->
                       {exlist, [name | rest]} =
                         Kernel.apply(Hyperex.Grammar.Helpers, :split_opt_list, [
                           cs,
                           [reverse: true]
                         ])

                       [{:function_call, name, exlist, [user_defined: true]} | rest]
                     end

                 :function_call <- :built_in_func | :user_func

                 :message_name <- str(:id)

                 :message <-
                   :message_name * :+ * opt(:expr_list) *
                     fn cs ->
                       {exlist, [name | rest]} =
                         Kernel.apply(Hyperex.Grammar.Helpers, :split_opt_list, [
                           cs,
                           [reverse: true]
                         ])

                       [{:message, name, exlist} | rest]
                     end

                 :statement <-
                   (:global
                    | :return
                    | :pass
                    | :exit
                    | :if
                    | :repeat
                    | :function_call
                    | :message
                    | :expr) *
                     fn [e | cs] -> [{:statement, e} | cs] end

                 :statement_list <-
                   :statement * :+ * star(+Nl * :+ * :statement) * :+ * star(Nl) *
                     fn cs ->
                       {stmnts, rest} =
                         Kernel.apply(Hyperex.Grammar.Helpers, :split_opt_list, [
                           cs,
                           [in: :statement, reverse: true, extract: true]
                         ])

                       [{:statements, stmnts} | rest]
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
                         Kernel.apply(Hyperex.Grammar.Helpers, :split_opt_list, [
                           cs,
                           [in: [:params, :statements, :handler_name]]
                         ])

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
                         Kernel.apply(Hyperex.Grammar.Helpers, :split_opt_list, [
                           cs,
                           [in: [:params, :statements, :function_name]]
                         ])

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
                         Kernel.apply(Hyperex.Grammar.Helpers, :split_opt_list, [
                           cs,
                           [in: [:handler, :function], reverse: true]
                         ])

                       [{:script, elems} | rest]
                     end

                 :program <- :+ * (:script | :scriptlet) * :+
               end)

  def peg_script, do: @peg_script
end
