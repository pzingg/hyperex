defmodule Hyperex.Grammar do
  @moduledoc false

  import Xpeg

  @peg_script (peg(:program) do
                 ### Inlined delimeters
                 Ws <- " " | "\t"
                 Soi <- "{{"
                 Eoi <- "}}"
                 :+ <- opt(Ws)
                 Sp <- +Ws
                 Eol <- Eoi | Nl

                 ### Program, script, scriptlet
                 :program <- Soi * star(Nl) * :+ * (:script | :scriptlet) * :+ * Eoi

                 :script <-
                   :script_elem * star(+Nl * :script_elem) * ((&Eoi) | +Nl) *
                     fn cs ->
                       {elems, rest} =
                         Kernel.apply(Hyperex.Grammar.Helpers, :collect_tuples, [
                           cs,
                           [in: [:handler, :function], reverse: true]
                         ])

                       [{:script, elems} | rest]
                     end

                 :script_elem_kind <- :handler | :function_def
                 :script_elem <- :+ * :script_elem_kind

                 :scriptlet <-
                   :statement_list *
                     fn [stmnts | _] -> [scriptlet: elem(stmnts, 1)] end

                 ### All the rest
                 :statement_list <-
                   :statement * star(+Nl * :statement) * ((&Eoi) | +Nl) *
                     fn cs ->
                       {stmnts, rest} =
                         Kernel.apply(Hyperex.Grammar.Helpers, :collect_tuples, [
                           cs,
                           [in: :statement, reverse: true, extract: true]
                         ])

                       [{:statements, stmnts} | rest]
                     end

                 :statement_kind <-
                   :global
                   | :return
                   | :pass
                   | :exit
                   | :if
                   | :repeat
                   | :expr_top
                   | :command
                   | :message_with_params
                   | :message_or_var

                 :statement <-
                   :+ * :statement_kind *
                     fn [e | cs] -> [{:statement, e} | cs] end

                 :expr_list <- :expr * star(:+ * "," * :+ * :expr)

                 :expr <- :expr_top | :variable

                 # Put factor first to avoid collision of negative :float
                 :term_b10 <- :factor | :prefix_b10
                 :term_b9 <- :term_b10 * star(:+ * :infix_b9)
                 :term_b8 <- :term_b9 * star(:+ * :infix_b8)
                 :term_b7 <- :term_b8 * star(:+ * :infix_b7)
                 :term_b6 <- :term_b7 * star(:+ * :infix_b6)
                 :term_b5 <- :term_b6 * star(:+ * :infix_b5)
                 :term_b4 <- :term_b5 * star(:+ * :infix_b4)
                 :term_b3 <- :term_b4 * star(:+ * :infix_b3)
                 :term_b2 <- :term_b3 * star(:+ * :infix_b2)
                 :expr_top <- :+ * :term_b2 * :+ * star(:+ * :infix_b1)

                 :factor <-
                   "(" * :+ * :expr * :+ * ")"
                   | :constant
                   | :float
                   | :integer
                   | :chunk
                   | :function_call
                   | :container_special
                   | :string_lit
                   | :message_box
                   | :part
                   | :menu
                   | :menu_item
                   | :property

                 :function_call <- :built_in_func | :user_func

                 :message_with_params <-
                   str(:message_name | :id) * Sp * :expr_list *
                     fn cs ->
                       {exlist, [name | rest]} =
                         Kernel.apply(Hyperex.Grammar.Helpers, :collect_tuples, [
                           cs,
                           [reverse: true]
                         ])

                       [{:message, name, exlist} | rest]
                     end

                 :message_or_var <-
                   str(:message_name | :id) *
                     fn [name | cs] -> [{:message_or_var, name} | cs] end

                 :variable <-
                   str(:message_name | :id) *
                     fn [name | cs] -> [{:var, name} | cs] end

                 ### Properties

                 :property <-
                   opt("the" * Sp) *
                     (:object_property_phrase
                      | :global_system_property
                      | :global_hypercard_property)

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

                 :long_opt <- "long" * fn cs -> [{:format, :long} | cs] end

                 :english_opt <- "english" * fn cs -> [{:format, :english} | cs] end

                 :hypercard_property <-
                   str("address")
                   | opt(:long_opt * Sp) * str("version")
                   | opt(:adjective * Sp) * str("ID" | "id" | "name")

                 :global_hypercard_property <-
                   :hypercard_property * :+ * opt(opt("of") * :+ * ("HyperCard" | "hypercard")) *
                     fn cs ->
                       case cs do
                         [name, {:format, _} = fmt | rest] ->
                           [{:global_property, name, [fmt]} | rest]

                         [name | rest] ->
                           [{:global_property, name, []} | rest]
                       end
                     end

                 :global_system_property <-
                   str(:global_property_name) *
                     fn [name | cs] -> [{:global_property, name, []} | cs] end

                 :object_property_name <-
                   :stack_prop_name
                   | :background_prop_name
                   | :card_prop_name
                   | :field_prop_name
                   | :button_prop_name
                   | :rectangle_prop_name
                   | :painting_prop_name
                   | :window_prop_name
                   | :menu_prop_name
                   | :watcher_prop_name

                 :object_property <-
                   str(:object_property_name)
                   | opt(:english_opt * Sp) * str("name")
                   | opt(:adjective * Sp) * str("ID" | "id" | "name")

                 :object_property_phrase <-
                   :object_property * Sp * "of" * Sp * :expr *
                     fn cs ->
                       case cs do
                         [obj, name, {:format, _} = fmt | rest] ->
                           [{:object_property, name, obj, [fmt]} | rest]

                         [obj, name | rest] ->
                           [{:object_property, name, obj, []} | rest]
                       end
                     end

                 # Factor - literals
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

                 ### Factor - containers
                 :container_special <-
                   str("It" | "it" | "each" | "target")
                   | opt("the") * :+ * str("selection") *
                       fn [v | cs] ->
                         src =
                           case v do
                             "each" -> {:container_each}
                             "target" -> {:container_target}
                             "selection" -> {:container_selection}
                             _ -> {:container_it}
                           end

                         [src | cs]
                       end

                 :message_box <-
                   opt("the" * Ws) * ("message" | "msg") * Ws * opt("window" | "box") *
                     fn cs -> [{:container_message_box} | cs] end

                 :menu <-
                   "menu" * Ws * :expr
                   | :position * Ws * "menu" *
                       fn [mid | cs] -> [{:menu, mid} | cs] end

                 :menu_item <-
                   ("menuItem" | "menuitem") * Ws * :expr * :+ * "of" * Ws * :menu
                   | :position * Ws * ("menuItem" | "menuitem") * Ws * "of" * Ws * :menu *
                       fn [{:menu, m}, mid | cs] -> [{:menu_item, mid, m} | cs] end

                 ### Chunks

                 :chunk <-
                   :lines_chunk
                   | :items_chunk
                   | :line_chunk
                   | :item_chunk
                   | :word_chunk
                   | :character_chunk

                 :of_source <-
                   Ws * :of * :+ * :expr *
                     fn [src | cs] -> [{:source, src} | cs] end

                 :lines_chunk <-
                   "lines" * :of_source *
                     fn cs ->
                       case cs do
                         [{:source, src} | rest] -> [{:chunk, src, :lines} | rest]
                         _ -> [{:chunk, nil, :lines} | cs]
                       end
                     end

                 :items_chunk <-
                   "items" * :of_source *
                     fn cs ->
                       case cs do
                         [{:source, src} | rest] -> [{:chunk, src, :items} | rest]
                         _ -> [{:chunk, nil, :items} | cs]
                       end
                     end

                 :line_from_to <-
                   "line" * :+ * :expr * :+ * "to" * :+ * :expr *
                     fn [to, from | cs] -> [{:line_chunk, {:range, from, to}} | cs] end

                 :line_at <-
                   "line" * :+ * :expr *
                     fn [pos | cs] -> [{:line_chunk, {:by_position, pos}} | cs] end

                 :line_ordinal <-
                   str(:ordinal_value) * Ws * "line" *
                     fn [ord | cs] -> [{:line_chunk, {:by_position, ord}} | cs] end

                 :line_spec <-
                   :line_ordinal
                   | :line_from_to
                   | :line_at

                 :line_chunk <-
                   :line_spec * :of_source *
                     fn cs ->
                       IO.inspect(cs, label: :line_chunk)

                       case cs do
                         [
                           {:source, src},
                           {:line_chunk, line_pos},
                           {:word_chunk, word_pos},
                           {:char_chunk, char_pos} | rest
                         ] ->
                           [
                             {:chunk, src,
                              {:line_chunk, line_pos,
                               {:word_chunk, word_pos, {:char_chunk, char_pos, nil}}}}
                             | rest
                           ]

                         [{:source, src}, {:line_chunk, line_pos}, {:word_chunk, word_pos} | rest] ->
                           [
                             {:chunk, src, {:line_chunk, line_pos, {:word_chunk, word_pos, nil}}}
                             | rest
                           ]

                         [{:source, src}, {:line_chunk, line_pos}, {:char_chunk, char_pos} | rest] ->
                           [
                             {:chunk, src, {:line_chunk, line_pos, {:char_chunk, char_pos, nil}}}
                             | rest
                           ]

                         [{:source, src}, {:line_chunk, pos} | rest] ->
                           [{:chunk, src, {:line_chunk, pos, nil}} | rest]

                         _ ->
                           IO.puts("line_chunk NOT HANDLED")
                           cs
                       end
                     end

                 :item_from_to <-
                   "item" * :+ * :expr * :+ * "to" * :+ * :expr *
                     fn [to, from | cs] -> [{:item_chunk, {:range, from, to}} | cs] end

                 :item_at <-
                   "item" * :+ * :expr *
                     fn [pos | cs] -> [{:item_chunk, {:by_position, pos}} | cs] end

                 :item_ordinal <-
                   str(:ordinal_value) * Ws * "item" *
                     fn [ord | cs] -> [{:item_chunk, {:by_position, ord}} | cs] end

                 :item_spec <-
                   :item_ordinal
                   | :item_from_to
                   | :item_at

                 :item_chunk <-
                   :item_spec * :of_source *
                     fn cs ->
                       case cs do
                         [{:source, src}, {:item_chunk, pos} | rest] ->
                           [{:chunk, src, {:item_chunk, pos}} | rest]

                         _ ->
                           [:item_chunk | cs]
                       end
                     end

                 :of_line <-
                   :of_line_chunk
                   | :of_source

                 :of_line_chunk <-
                   Ws * :of * :line_chunk *
                     fn cs ->
                       IO.inspect(cs, label: :of_line_chunk)
                       cs
                     end

                 :words_of_line <-
                   "words" * :of_line *
                     fn
                       cs ->
                         IO.inspect(cs, label: :words_of_line)

                         case cs do
                           [{:source, {:chunk, src, {:line_chunk, pos, nil}}} | rest] ->
                             [{:chunk, src, {:line_chunk, pos, :words}} | rest]

                           [{:source, src} | rest] ->
                             [{:chunk, src, :words} | rest]

                           _ ->
                             cs
                         end
                     end

                 :word_from_to <-
                   "word" * :+ * :expr * :+ * "to" * :+ * :expr *
                     fn [to, from | cs] -> [{:word_chunk, {:range, from, to}} | cs] end

                 :word_at <-
                   "word" * :+ * :expr *
                     fn [pos | cs] -> [{:word_chunk, {:by_position, pos}} | cs] end

                 :word_ordinal <-
                   str(:ordinal_value) * Ws * "word" *
                     fn [ord | cs] -> [{:word_chunk, {:by_position, ord}} | cs] end

                 :word_spec <-
                   :word_ordinal
                   | :word_from_to
                   | :word_at

                 :word_of_line <-
                   :word_spec * opt(:of_line) *
                     fn cs ->
                       IO.inspect(cs, label: :word_of_line)

                       case cs do
                         [
                           {:source, {:chunk, src, {:line_chunk, line_pos}}},
                           {:word_chunk, word_pos} | rest
                         ] ->
                           [
                             {:chunk, src, {:word_chunk, word_pos, {:line_chunk, line_pos, nil}}}
                             | rest
                           ]

                         [{:source, src}, {:word_chunk, word_pos} | rest] ->
                           [{:chunk, src, {:word_chunk, word_pos, nil}} | rest]

                         [{:source, {:chunk, src, sub_chunks}} | rest] ->
                           [{:chunk, src, sub_chunks} | rest]

                         _ ->
                           IO.puts("word_of_line NOT HANDLED")
                           cs
                       end
                     end

                 :word_chunk <-
                   :words_of_line
                   | :word_of_line

                 :of_word_chunk <-
                   Ws * "of" * :word_chunk *
                     fn cs ->
                       IO.inspect(cs, label: :of_word_chunk)
                       cs
                     end

                 :of_word <-
                   :of_word_chunk
                   | :of_line_chunk
                   | :of_source

                 :chars_of_word <-
                   :characters * :of_word *
                     fn
                       cs ->
                         IO.inspect(cs, label: :chars_of_word)
                         cs
                     end

                 :char_from_to <-
                   :character * :+ * :expr * :+ * "to" * :+ * :expr *
                     fn [to, from | cs] -> [{:char_chunk, {:range, from, to}} | cs] end

                 :char_at <-
                   :character * :+ * :expr *
                     fn [pos | cs] -> [{:char_chunk, {:by_position, pos}} | cs] end

                 :char_ordinal <-
                   str(:ordinal_value) * Ws * :character *
                     fn [ord | cs] -> [{:char_chunk, {:by_position, ord}} | cs] end

                 :char_spec <-
                   :char_ordinal
                   | :char_from_to
                   | :char_at

                 :char_of_word <-
                   :char_spec * opt(:of_word) *
                     fn cs ->
                       IO.inspect(cs, label: :char_of_word)

                       case cs do
                         [
                           {:source, {:chunk, src, {:word_chunk, word_pos, _}}},
                           {:char_chunk, char_pos} | rest
                         ] ->
                           [
                             {:chunk, src, {:word_chunk, word_pos, {:char_chunk, char_pos, nil}}}
                             | rest
                           ]

                         [{:source, src}, {:char_chunk, pos} | rest] ->
                           [{:chunk, src, {:char_chunk, pos, nil}} | rest]

                         [{:source, {:chunk, src, sub_chunks}} | rest] ->
                           [{:chunk, src, sub_chunks} | rest]

                         _ ->
                           IO.puts("char_of_word NOT HANDLED")
                           cs
                       end
                     end

                 :character_chunk <-
                   :chars_of_word
                   | :char_of_word

                 ### Parts
                 # Order is important, e.g. "opt(:card) :button" before ":card :expr"
                 :part <-
                   :me
                   | :stack_part
                   | :card_part_part
                   | :background_part_part
                   | :button_part
                   | :field_part
                   | :window_part
                   | :card_part
                   | :background_part

                 :by_id <-
                   "id" * Ws * :expr *
                     fn [ex | cs] -> [{:by_id, ex} | cs] end

                 :by_name_or_number <-
                   :expr *
                     fn [ex | cs] -> [{:by_name_or_number, ex} | cs] end

                 :by_id_or_number <- :by_id | :by_name_or_number

                 # These can come after :expr, so ws may have been consumed already
                 :of_stack <-
                   :+ * :of * Ws * :stack_part *
                     fn [stack, card | cs] ->
                       [{:stack_card, stack, card} | cs]
                     end

                 :of_card_or_background <-
                   :+ * :of * Ws * (:card_part | :background_part) *
                     fn cs ->
                       case cs do
                         [{:stack_card, {:stack, stack}, {:card, card}}, part | rest] ->
                           [{:stack_part, stack, {:card_part, card, part}} | rest]

                         [{:stack_card, {:stack, stack}, {:background, bkgnd}}, part | rest] ->
                           [{:stack_part, stack, {:background_part, bkgnd, part}} | rest]

                         [{:card, card}, part | rest] ->
                           [{:card_part, card, part} | rest]

                         [{:background, bkgnd}, part | rest] ->
                           [{:background_part, bkgnd, part} | rest]

                         _ ->
                           cs
                       end
                     end

                 ### Me
                 :me <- "me" * fn cs -> [:me | cs] end

                 ### Stack part
                 :stack_part <- :named_stack | :this_stack

                 :named_stack <-
                   "stack" * Ws * :expr *
                     fn [ex | cs] -> [{:stack, ex} | cs] end

                 :this_stack <-
                   opt("this" * Ws) * "stack" *
                     fn cs -> [{:stack, :this} | cs] end

                 ### Window part
                 :window_part <- :id_window | opt("the" * Ws) * (:system_window | :card_window)

                 :id_window <-
                   "window" * opt(Ws * "id") * Ws * :expr *
                     fn [ex | cs] -> [{:id_window, ex} | cs] end

                 :system_window <-
                   (str("tool" | "pattern") * Ws * "window"
                    | str("message" | "variable") * Ws * "watcher") *
                     fn [name | cs] -> [{:system_window, name} | cs] end

                 :card_window <-
                   :card * Ws * "window" *
                     fn cs -> [:card_window | cs] end

                 ### Card "part" part
                 :card_part_part <-
                   :card * Ws * "part" * Ws * :expr *
                     fn [ex | cs] -> [{:card_part, ex} | cs] end

                 ### Background "part" part
                 :background_part_part <-
                   :background * Ws * "part" * Ws * :expr *
                     fn [ex | cs] -> [{:background_part, ex} | cs] end

                 ### Button part, can start with :card or :background
                 :button_part <-
                   (:button_by_position | :button_by_id_or_number) * opt(:of_card_or_background)

                 :button_by_position <-
                   str(:position) * Ws * :background_or_card_button *
                     fn [type, pos | cs] ->
                       [{type, {:by_position, pos}} | cs]
                     end

                 :button_by_id_or_number <-
                   :background_or_card_button * Ws * :by_id_or_number *
                     fn [id, type | cs] ->
                       [{type, id} | cs]
                     end

                 :background_or_card_button <- :background_button | :card_button

                 :background_button <-
                   :background * Ws * :button * fn cs -> [:background_button | cs] end

                 :card_button <-
                   opt(:card * Ws) * :button * fn cs -> [:card_button | cs] end

                 ### Field part, can start with :card or :background
                 :field_part <-
                   (:field_by_position | :field_by_id_or_number) * opt(:of_card_or_background)

                 :card_field <-
                   :card * Ws * :field * fn cs -> [:card_field | cs] end

                 :field_by_position <-
                   str(:position) * Ws * :background_or_card_field *
                     fn [type, pos | cs] ->
                       [{type, {:by_position, pos}} | cs]
                     end

                 :field_by_id_or_number <-
                   :background_or_card_field * Ws * :by_id_or_number *
                     fn [id, type | cs] ->
                       [{type, id} | cs]
                     end

                 :background_field <-
                   opt(:background * Ws) * :field * fn cs -> [:background_field | cs] end

                 :background_or_card_field <- :card_field | :background_field

                 ### Card part
                 :card_part <-
                   (:specific_card | :this_card) * opt(:of_stack)

                 :card_by_position <-
                   str(:position) * Ws * :card *
                     fn [pos | cs] ->
                       [{:card, {:by_position, pos}} | cs]
                     end

                 :card_by_id <-
                   :card * Ws * :by_id_or_number *
                     fn [pos | cs] ->
                       [{:card, pos} | cs]
                     end

                 :specific_card <-
                   :card_by_id
                   | :card_by_position

                 :this_card <-
                   opt("this" * Ws) * :card *
                     fn cs -> [{:card, :this} | cs] end

                 ### Background part
                 :background_part <-
                   (:specific_background | :this_background) * opt(:of_stack)

                 :background_by_position <-
                   str(:position) * Ws * :background *
                     fn [pos | cs] ->
                       [{:background, {:by_position, pos}} | cs]
                     end

                 :background_by_id <-
                   :background * Ws * :by_id_or_number *
                     fn [pos | cs] ->
                       [{:background, pos} | cs]
                     end

                 :specific_background <-
                   :background_by_id
                   | :background_by_position

                 :this_background <-
                   opt("this" * Ws) * :background *
                     fn cs -> [{:background, :this} | cs] end

                 ### Expression operators, lowest to highest binding power
                 :infix_b1 <-
                   "or" * :+ * :expr *
                     fn [b, a | cs] ->
                       [{:or, [a, b]} | cs]
                     end

                 :infix_b2 <-
                   "and" * :+ * :term_b2 *
                     fn [b, a | cs] ->
                       [{:and, [a, b]} | cs]
                     end

                 # equality
                 :op_not_equals <-
                   ("is" * Ws * "not" | "<>" | "≠") * fn cs -> [:not_equals | cs] end

                 :op_equals <- ("=" | "is") * fn cs -> [:equals | cs] end

                 :infix_b3 <-
                   (:op_not_equals | :op_equals) * :+ * :term_b3 *
                     fn [b, op, a | cs] ->
                       [{op, [a, b]} | cs]
                     end

                 # comparisons
                 :op_not_in <- "is" * Ws * "not" * Ws * "in" * fn cs -> [:not_in | cs] end

                 :op_not_type <-
                   "is" * Ws * "not" * Ws * ("an" | "a") * fn cs -> [:not_type | cs] end

                 :op_in <- "is" * Ws * "in" * fn cs -> [:in | cs] end
                 :op_is_type <- "is" * Ws * ("an" | "a") * fn cs -> [:is_type | cs] end

                 :infix_b4 <-
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
                   str("&&" | "&") * :+ * :term_b5 *
                     fn [b, op, a | cs] ->
                       case op do
                         "&&" -> [{:concat_ws, [a, b]} | cs]
                         "&" -> [{:concat, [a, b]} | cs]
                       end
                     end

                 # add, sub
                 :infix_b6 <-
                   str({~c"+", ~c"-"}) * :+ * :term_b6 *
                     fn [b, op, a | cs] ->
                       case op do
                         "+" -> [{:add, [a, b]} | cs]
                         "-" -> [{:sub, [a, b]} | cs]
                       end
                     end

                 # mul, div, mod, div_trunc
                 :infix_b7 <-
                   str("*" | "/" | "div" | "mod") * :+ * :term_b7 *
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
                   str("^") * :+ * :term_b8 *
                     fn [b, _op, a | cs] -> [{:pow, [a, b]} | cs] end

                 # within
                 :op_not_within <-
                   "is" * Ws * "not" * Ws * "within" * fn cs -> [:not_within | cs] end

                 :op_within <- "is" * Ws * "within" * fn cs -> [:within | cs] end

                 :infix_b9 <-
                   (:op_not_within | :op_within) * :+ * :term_b9 *
                     fn [b, op, a | cs] ->
                       [{op, [a, b]} | cs]
                     end

                 # exists, not, negate
                 :op_not_exists <-
                   "there" * Ws * "is" * Ws * ("not" * opt(Ws * ("an" | "a")) | "no") *
                     fn cs -> [:not_exists | cs] end

                 :op_exists <-
                   "there" * Ws * "is" * opt(Ws * ("an" | "a")) * fn cs -> [:exists | cs] end

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
                   :param * star(:+ * "," * :+ * :param) *
                     fn cs ->
                       {params, rest} =
                         Kernel.apply(Hyperex.Grammar.Helpers, :collect_tuples, [
                           cs,
                           [in: :param, reverse: true, extract: true]
                         ])

                       [{:params, params} | rest]
                     end

                 :global <-
                   "global" * Ws * :parameter_list *
                     fn cs ->
                       {params, rest} =
                         Kernel.apply(Hyperex.Grammar.Helpers, :collect_tuples, [
                           cs,
                           [in: :params]
                         ])

                       case params do
                         [{:params, params}] -> [{:global, params} | rest]
                         [] -> [{:global, []} | rest]
                       end
                     end

                 :return <-
                   "return" * opt(Ws * :expr) *
                     fn cs -> [{:return, cs}] end

                 :handler_id <- :command_name | :message_name | :id

                 :handler_name <-
                   str(:handler_id) *
                     fn [name | cs] -> [{:handler_name, name} | cs] end

                 :pass <-
                   "pass" * Ws * :handler_name *
                     fn [{:handler_name, name} | cs] -> [{:pass, name} | cs] end

                 :exit_to_hypercard <-
                   "to" * Ws * ("HyperCard" | "hypercard") *
                     fn cs -> [:exit_to_hypercard | cs] end

                 :exit_repeat <- "repeat" * fn cs -> [:exit_repeat | cs] end

                 :exit_handler <-
                   :handler_name *
                     fn [{:handler_name, name} | cs] -> [{:exit_handler, name} | cs] end

                 :exit <- "exit" * Ws * (:exit_to_hypercard | :exit_repeat | :exit_handler)

                 :end_if <- "end" * Ws * "if"
                 :else_single <- Ws * :statement * opt(+Nl * :+ * :end_if)
                 :else_multi <- +Nl * :+ * opt(:statement_list) * :+ * :end_if
                 :else <- "else" * (:else_single | :else_multi)

                 :then_multiline <-
                   +Nl * :+ * :statement_list * star(Nl) * :+ * (:else | :end_if)

                 :then_single_line <- Ws * :statement * opt(Nl) * :+ * opt(:else)
                 :then <- "then" * (:then_multiline | :then_single_line)

                 :if <-
                   "if" * Ws * :expr * opt(Nl) * :+ * :then *
                     fn cs ->
                       {stmnts, [test | rest]} =
                         Kernel.apply(Hyperex.Grammar.Helpers, :collect_tuples, [
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
                   "until" * Ws * :expr *
                     fn [ex | cs] -> [{:repeat_until, [], ex} | cs] end

                 :repeat_while <-
                   "while" * Ws * :expr *
                     fn [ex | cs] -> [{:repeat_while, [], ex} | cs] end

                 :repeat_with_desc <-
                   str(:id) * :+ * "=" * :+ * :expr * :+ * "down" * Ws * "to" * Ws *
                     :expr *
                     fn [to, from, var | cs] -> [{:repeat_with_desc, [], var, from, to} | cs] end

                 :repeat_with_asc <-
                   str(:id) * :+ * "=" * :+ * :expr * :+ * "to" * Ws * :expr *
                     fn [to, from, var | cs] -> [{:repeat_with_asc, [], var, from, to} | cs] end

                 :repeat_with <- "with" * Ws * (:repeat_with_desc | :repeat_with_asc)

                 :repeat_forever <- "forever" * fn cs -> [{:repeat_forever, []} | cs] end

                 :repeat_count <-
                   opt("for") * Ws * :expr * :+ * opt("times") *
                     fn [ex | cs] -> [{:repeat_count, [], ex} | cs] end

                 :repeat_range <-
                   :repeat_until
                   | :repeat_while
                   | :repeat_with
                   | :repeat_forever
                   | :repeat_count

                 :repeat <-
                   "repeat" * Ws * :repeat_range * +Nl * :+ * :statement_list * :+ *
                     "end" * Ws * "repeat" *
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

                 ### Commands
                 :command <- :arg_command | :zero_arg_command

                 :command_name <-
                   :zero_arg_command_name
                   | :zero_or_arg_command_name
                   | :arg_command_name

                 :arg_command <-
                   str(:zero_or_arg_command_name | :arg_command_name) * Sp * str(WordsToEol) *
                     fn [args, name | cs] -> [{:command, name, args} | cs] end

                 :zero_arg_command <-
                   str(:zero_or_arg_command_name | :zero_arg_command_name) *
                     fn [name | cs] -> [{:command, name, ""} | cs] end

                 :the_formatted_func <-
                   "the" * opt(Ws * :adjective) * Ws * str(:date_time_func_name | "target") *
                     fn [name | cs] ->
                       name =
                         if name == "target" do
                           "the_target"
                         else
                           name
                         end

                       case cs do
                         [{:format, _} = fmt | rest] ->
                           [{:function_call, name, [], [fmt]} | rest]

                         _ ->
                           [{:function_call, name, [], []} | cs]
                       end
                     end

                 :target_func <- "target" * fn cs -> [{:function_call, "target", [], []} | cs] end

                 :number_func <-
                   opt("the") * Ws * "number" * Ws * "of" * Ws * str(1 - Nl) *
                     fn [obj | cs] -> [{:function_call, "number", [obj], []} | cs] end

                 :zero_arg_func <-
                   str(:zero_arg_func_name) *
                     fn [name | cs] -> [{:function_call, name, [], []} | cs] end

                 :single_arg_func <-
                   str(:single_arg_func_name) *
                     fn [name | cs] -> [{:function_call, name, [], []} | cs] end

                 :the_single_arg_func_of <-
                   "the" * Ws * :single_arg_func * Ws * "of" * Ws * :expr *
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
                         Kernel.apply(Hyperex.Grammar.Helpers, :collect_tuples, [
                           cs,
                           [reverse: true]
                         ])

                       [{:function_call, name, exlist, []} | rest]
                     end

                 :built_in_func <-
                   :the_formatted_func
                   | :the_single_arg_func_of
                   | "the" * Ws * :zero_arg_func
                   | :target_func
                   | :number_func
                   | :zero_arg_func * :+ * "(" * :+ * ")"
                   | :single_arg_func_parens
                   | :list_arg_func

                 :user_func <-
                   str(:id) * :+ * "(" * :+ * opt(:expr_list) * :+ * ")" *
                     fn cs ->
                       {exlist, [name | rest]} =
                         Kernel.apply(Hyperex.Grammar.Helpers, :collect_tuples, [
                           cs,
                           [reverse: true]
                         ])

                       [{:function_call, name, exlist, [user_defined: true]} | rest]
                     end

                 :param <- str(:id) * fn [v | cs] -> [{:param, v} | cs] end

                 :end_handler <- "end" * Ws * :handler_id

                 :handler <-
                   "on" * Ws * :handler_name * opt(:+ * :parameter_list) * +Nl *
                     :+ * opt(:statement_list) * :+ * :end_handler *
                     fn cs ->
                       {handler, rest} =
                         Kernel.apply(Hyperex.Grammar.Helpers, :collect_tuples, [
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

                       [{:handler, name, params, stmnts} | rest]
                     end

                 :function_name <- str(:id) * fn [name | cs] -> [{:function_name, name} | cs] end

                 :function_def <-
                   "function" * Ws * :function_name * :+ * opt(:parameter_list) * +Nl * :+ *
                     opt(:statement_list) * :+ * "end" * Ws * :id *
                     fn cs ->
                       {function, rest} =
                         Kernel.apply(Hyperex.Grammar.Helpers, :collect_tuples, [
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

                       [{:function, name, params, stmnts} | rest]
                     end

                 ## HyperTalk vocabulary
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
                   | :true_false
                   | :of
                   | :cardinal_value
                   | :ordinal_value
                   | :button
                   | :field
                   | :card
                   | :background
                   | :message_name
                   | :command_name
                   | :property_name
                   | :date_time_func_name
                   | :zero_arg_func_name
                   | :single_arg_func_name
                   | :two_arg_func_name
                   | :list_arg_func_name
                   | "stack"
                   | "next"
                   | "previous"
                   | "prev"
                   | "this"
                   | "there"
                   | "the"
                   | "is"
                   | "not"

                 ## Message names
                 :message_name <-
                   "appleEvent"
                   | "appleevent"
                   | "arrowKey"
                   | "arrowkey"
                   | "closeBackground"
                   | "closebackground"
                   | "closeCard"
                   | "closecard"
                   | "closeField"
                   | "closefield"
                   | "closePalette"
                   | "closepalette"
                   | "closePicture"
                   | "closepicture"
                   | "closeStack"
                   | "closestack"
                   | "close"
                   | "commandKeyDown"
                   | "commandkeydown"
                   | "controlKey"
                   | "controlkey"
                   | "deleteBackground"
                   | "deletebackground"
                   | "deleteButton"
                   | "deletebutton"
                   | "deleteCard"
                   | "deletecard"
                   | "deleteField"
                   | "deletefield"
                   | "deleteStack"
                   | "deletestack"
                   | "doMenu"
                   | "domenu"
                   | "enterInField"
                   | "enterinfield"
                   | "enterKey"
                   | "enterkey"
                   | "errorDialog"
                   | "errordialog"
                   | "exitField"
                   | "exitfield"
                   | "functionKey"
                   | "functionkey"
                   | "help"
                   | "hide"
                   | "idle"
                   | "keyDown"
                   | "keydown"
                   | "mouseDoubleClick"
                   | "mousedoubleclick"
                   | "mouseDownInPicture"
                   | "mousedowninpicture"
                   | "mouseDown"
                   | "mousedown"
                   | "mouseEnter"
                   | "mouseenter"
                   | "mouseLeave"
                   | "mouseleave"
                   | "mouseStillDown"
                   | "mousestilldown"
                   | "mouseUpInPicture"
                   | "mouseupinpicture"
                   | "mouseUp"
                   | "mouseup"
                   | "mouseWithin"
                   | "mousewithin"
                   | "moveWindow"
                   | "movewindow"
                   | "newBackground"
                   | "newbackground"
                   | "newButton"
                   | "newbutton"
                   | "newCard"
                   | "newcard"
                   | "newField"
                   | "newfield"
                   | "newStack"
                   | "newstack"
                   | "openBackground"
                   | "openbackground"
                   | "openCard"
                   | "opencard"
                   | "openField"
                   | "openfield"
                   | "openPalette"
                   | "openpalette"
                   | "openPicture"
                   | "openpicture"
                   | "openStack"
                   | "openstack"
                   | "quit"
                   | "resume"
                   | "resumeStack"
                   | "resumestack"
                   | "returnInField"
                   | "returninfield"
                   | "returnKey"
                   | "returnkey"
                   | "show"
                   | "sizeWindow"
                   | "sizewindow"
                   | "startUp"
                   | "startup"
                   | "suspendStack"
                   | "suspendstack"
                   | "suspend"
                   | "tabKey"
                   | "tabkey"

                 ## Command names
                 :zero_arg_command_name <-
                   "enterInField"
                   | "enterinfield"
                   | "enterKey"
                   | "enterkey"
                   | "help"
                   | "returnInField"
                   | "returninfield"
                   | "returnKey"
                   | "returnkey"
                   | "tabKey"
                   | "tabkey"

                 :zero_or_arg_command_name <-
                   "beep"

                 :arg_command_name <-
                   "add"
                   | "answer"
                   | "arrowKey"
                   | "arrowkey"
                   | "ask"
                   | "choose"
                   | "click"
                   | "close"
                   | "commandKeyDown"
                   | "commandkeyDown"
                   | "controlKey"
                   | "controlkey"
                   | "convert"
                   | "create"
                   | "debug"
                   | "delete"
                   | "dial"
                   | "disable"
                   | "divide"
                   | "do"
                   | "doMenu"
                   | "domenu"
                   | "drag"
                   | "enable"
                   | "export"
                   | "find"
                   | "get"
                   | "go"
                   | "hide"
                   | "import"
                   | "keyDown"
                   | "keydown"
                   | "lock"
                   | "mark"
                   | "multiply"
                   | "next"
                   | "open"
                   | "palette"
                   | "picture"
                   | "play"
                   | "pop"
                   | "print"
                   | "push"
                   | "put"
                   | "read"
                   | "reply"
                   | "request"
                   | "reset"
                   | "save"
                   | "select"
                   | "send"
                   | "set"
                   | "show"
                   | "sort"
                   | "stop"
                   | "subtract"
                   | "type"
                   | "unlock"
                   | "ummark"
                   | "visual"
                   | "wait"
                   | "write"

                 ## Property names
                 :property_name <-
                   "address"
                   | "autohilite"
                   | "autoHilite"
                   | "autoselect"
                   | "autoSelect"
                   | "autotab"
                   | "autoTab"
                   | "blindtyping"
                   | "blindTyping"
                   | "bottomright"
                   | "bottomRight"
                   | "bottom"
                   | "brush"
                   | "cantabort"
                   | "cantAbort"
                   | "cantdelete"
                   | "cantDelete"
                   | "cantmodify"
                   | "cantModify"
                   | "cantpeek"
                   | "cantPeek"
                   | "centered"
                   | "checkmark"
                   | "checkMark"
                   | "commmandchar"
                   | "commmandChar"
                   | "cursor"
                   | "debugger"
                   | "dialingtime"
                   | "dialingTime"
                   | "dialingvolume"
                   | "dialingVolume"
                   | "dithering"
                   | "dontsearch"
                   | "dontSearch"
                   | "dontwrap"
                   | "dontWrap"
                   | "dragspeed"
                   | "dragSpeed"
                   | "editbkgnd"
                   | "editBkgnd"
                   | "enabled"
                   | "environment"
                   | "family"
                   | "filled"
                   | "fixedlineheight"
                   | "fixedLineHeight"
                   | "freesize"
                   | "freeSize"
                   | "globalloc"
                   | "globalLoc"
                   | "globalrect"
                   | "globalRect"
                   | "grid"
                   | "hbarloc"
                   | "hBarLoc"
                   | "height"
                   | "hideidle"
                   | "hideIdle"
                   | "hideunused"
                   | "hideUnused"
                   | "hilite"
                   | "icon"
                   | "id"
                   | "ID"
                   | "itemdelimiter"
                   | "itemDelimiter"
                   | "language"
                   | "left"
                   | "linesize"
                   | "lineSize"
                   | "location"
                   | "loc"
                   | "lockerrordialogs"
                   | "lockErrorDialogs"
                   | "lockmessages"
                   | "lockMessages"
                   | "lockrecent"
                   | "lockRecent"
                   | "lockscreen"
                   | "lockScreen"
                   | "locktext"
                   | "lockText"
                   | "longwindowtitles"
                   | "longWindowTitles"
                   | "markchar"
                   | "markChar"
                   | "marked"
                   | "menumessage"
                   | "menuMessage"
                   | "messagewatcher"
                   | "messageWatcher"
                   | "multiplelines"
                   | "multipleLines"
                   | "multispace"
                   | "multiSpace"
                   | "multiple"
                   | "name"
                   | "numberformat"
                   | "numberFormat"
                   | "number"
                   | "owner"
                   | "partnumber"
                   | "partNumber"
                   | "pattern"
                   | "polysides"
                   | "polySides"
                   | "powerkeys"
                   | "powerKeys"
                   | "printmargins"
                   | "printMargins"
                   | "printtextalign"
                   | "printTextAlign"
                   | "printtextfont"
                   | "printTextFont"
                   | "printtextheight"
                   | "printTextHeight"
                   | "printtextsize"
                   | "printTextSize"
                   | "printtextstyle"
                   | "printTextStyle"
                   | "rectangle"
                   | "rect"
                   | "reporttemplates"
                   | "reportTemplates"
                   | "right"
                   | "scale"
                   | "script"
                   | "scripteditor"
                   | "scriptEditor"
                   | "scriptinglanguage"
                   | "scriptingLanguage"
                   | "scripttextfont"
                   | "scriptTextFont"
                   | "scripttextsize"
                   | "scriptTextSize"
                   | "scroll"
                   | "sharedhilite"
                   | "sharedHilite"
                   | "sharedtext"
                   | "sharedText"
                   | "showlines"
                   | "showLines"
                   | "showname"
                   | "showName"
                   | "showpict"
                   | "showPict"
                   | "size"
                   | "stacksinuse"
                   | "stacksInUse"
                   | "style"
                   | "suspended"
                   | "textalign"
                   | "textAlign"
                   | "textarrows"
                   | "textArrows"
                   | "textfont"
                   | "textFont"
                   | "textheight"
                   | "textHeight"
                   | "textsize"
                   | "textSize"
                   | "textstyle"
                   | "textStyle"
                   | "titlewidth"
                   | "titleWidth"
                   | "top"
                   | "topleft"
                   | "topLeft"
                   | "tracedelay"
                   | "traceDelay"
                   | "userlevel"
                   | "userLevel"
                   | "usermodify"
                   | "userModify"
                   | "variablewatcher"
                   | "variableWatcher"
                   | "vbarloc"
                   | "vBarloc"
                   | "version"
                   | "visible"
                   | "widemargins"
                   | "wideMargins"
                   | "width"
                   | "zoom"
                   | "zoomed"

                 :global_property_name <-
                   "blindTyping"
                   | "blindtyping"
                   | "cursor"
                   | "debugger"
                   | "dialingTime"
                   | "dialingtime"
                   | "dialingVolume"
                   | "dialingvolume"
                   | "dragSpeed"
                   | "dragspeed"
                   | "editBkgnd"
                   | "editbkgnd"
                   | "environment"
                   | "itemDelimiter"
                   | "itemdelimiter"
                   | "language"
                   | "lockErrorDialogs"
                   | "lockerrordialogs"
                   | "lockMessages"
                   | "lockmessages"
                   | "lockRecent"
                   | "lockrecent"
                   | "lockScreen"
                   | "lockscreen"
                   | "longWindowTitles"
                   | "longwindowtitles"
                   | "messageWatcher"
                   | "messagewatcher"
                   | "numberFormat"
                   | "numberformat"
                   | "powerKeys"
                   | "powerkeys"
                   | "printMargins"
                   | "printmargins"
                   | "printTextAlign"
                   | "printtextalign"
                   | "printTextFont"
                   | "printtextfont"
                   | "printTextHeight"
                   | "printtextheight"
                   | "printTextSize"
                   | "printtextsize"
                   | "printTextStyle"
                   | "printtextstyle"
                   | "scriptEditor"
                   | "scripteditor"
                   | "scriptingLanguage"
                   | "scriptinglanguage"
                   | "scriptTextFont"
                   | "scripttextfont"
                   | "scriptTextSize"
                   | "scripttextsize"
                   | "stacksInUse"
                   | "stacksinuse"
                   | "suspended"
                   | "textArrows"
                   | "textarrows"
                   | "traceDelay"
                   | "tracedelay"
                   | "userLevel"
                   | "userlevel"
                   | "userModify"
                   | "usermodify"
                   | "variableWatcher"
                   | "variablewatcher"

                 :stack_prop_name <-
                   "cantAbort"
                   | "cantabort"
                   | "cantDelete"
                   | "cantdelete"
                   | "cantModify"
                   | "cantmodify"
                   | "cantPeek"
                   | "cantpeek"
                   | "freeSize"
                   | "freesize"
                   | "reportTemplates"
                   | "reporttemplates"
                   | "script"
                   | "scriptingLanguage"
                   | "scriptinglanguage"
                   | "size"
                   | "version"

                 :background_prop_name <-
                   "cantDelete"
                   | "cantdelete"
                   | "dontSearch"
                   | "dontsearch"
                   | "script"
                   | "scriptingLanguage"
                   | "scriptinglanguage"
                   | "showPict"
                   | "showpict"
                   | :id_prop_name

                 :card_prop_name <-
                   "cantDelete"
                   | "cantdelete"
                   | "dontSearch"
                   | "dontsearch"
                   | "marked"
                   | "owner"
                   | "rectangle"
                   | "rect"
                   | "script"
                   | "scriptingLanguage"
                   | "scriptinglanguage"
                   | "showPict"
                   | "showpict"
                   | :id_prop_name

                 :field_prop_name <-
                   "autoSelect"
                   | "autoselect"
                   | "autoTab"
                   | "autotab"
                   | "dontSearch"
                   | "dontsearch"
                   | "dontWrap"
                   | "dontwrap"
                   | "fixedLineHeight"
                   | "fixedlineheight"
                   | "lockText"
                   | "locktext"
                   | "location"
                   | "loc"
                   | "multipleLines"
                   | "multiplelines"
                   | "partNumber"
                   | "partnumber"
                   | "rectangle"
                   | "rect"
                   | "script"
                   | "scriptingLanguage"
                   | "scriptinglanguage"
                   | "scroll"
                   | "sharedText"
                   | "sharedtext"
                   | "showLines"
                   | "showlines"
                   | "style"
                   | "visible"
                   | "wideMargins"
                   | "widemargins"
                   | :id_prop_name
                   | :text_prop_name

                 :button_prop_name <-
                   "autoHilite"
                   | "autohilite"
                   | "enabled"
                   | "family"
                   | "hilite"
                   | "icon"
                   | "lockText"
                   | "locktext"
                   | "location"
                   | "loc"
                   | "partNumber"
                   | "partnumber"
                   | "rectangle"
                   | "rect"
                   | "script"
                   | "scriptingLanguage"
                   | "scriptinglanguage"
                   | "sharedHilite"
                   | "sharedhilite"
                   | "showName"
                   | "showname"
                   | "style"
                   | "titleWidth"
                   | "titlewidth"
                   | "visible"
                   | :id_prop_name
                   | :text_prop_name

                 :rectangle_prop_name <-
                   "bottomRight"
                   | "bottomright"
                   | "bottom"
                   | "height"
                   | "left"
                   | "right"
                   | "topLeft"
                   | "topleft"
                   | "top"
                   | "width"

                 :painting_prop_name <-
                   "brush"
                   | "centered"
                   | "filled"
                   | "grid"
                   | "lineSize"
                   | "linesize"
                   | "multiple"
                   | "multiSpace"
                   | "multispace"
                   | "pattern"
                   | "polySides"
                   | "polysides"
                   | :text_prop_name

                 :window_prop_name <-
                   "location"
                   | "loc"
                   | "owner"
                   | "rectangle"
                   | "rect"
                   | "scroll"
                   | "visible"
                   | "zoomed"
                   | :picture_window_prop_name
                   | :id_prop_name

                 :picture_window_prop_name <-
                   "globalRect"
                   | "globalrect"
                   | "globalLoc"
                   | "globalloc"
                   | "zoom"
                   | "scale"
                   | "dithering"

                 :menu_prop_name <-
                   "checkMark"
                   | "checkmark"
                   | "commmandChar"
                   | "commmandchar"
                   | "enabled"
                   | "markChar"
                   | "markchar"
                   | "menuMessage"
                   | "menumessage"
                   | "textStyle"
                   | "textStyle"

                 :watcher_prop_name <-
                   "hBarLoc"
                   | "hbarloc"
                   | "hideIdle"
                   | "hideidle"
                   | "hideUnused"
                   | "hideunused"
                   | "rectangle"
                   | "rect"
                   | "vBarLoc"
                   | "vBarloc"

                 :id_prop_name <-
                   "number"

                 :text_prop_name <-
                   "textAlign"
                   | "textalign"
                   | "textFont"
                   | "textfont"
                   | "textHeight"
                   | "textheight"
                   | "textSize"
                   | "textsize"
                   | "textStyle"
                   | "textstyle"

                 ## Function names
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

                 ## Common aliases and values
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
                   ) * fn [v | cs] -> [{:constant, v} | cs] end

                 :true_false <- "true" | "false"
                 :of <- "of" | "in"
                 :button <- "buttons" | "button" | "btns" | "btn"
                 :field <- "fields" | "field" | "flds" | "fld"
                 :card <- "card" | "cd"
                 :background <- "background" | "bkgnd"
                 :characters <- "characters" | "chars"
                 :character <- "character" | "char"
                 :chunk_type <- :characters | "words" | "lines" | "items"

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

                 :ordinal_value <-
                   "first"
                   | "second"
                   | "third"
                   | "fourth"
                   | "fifth"
                   | "sixth"
                   | "seventh"
                   | "eighth"
                   | "ninth"
                   | "tenth"
                   | "middle"
                   | "mid"
                   | "last"
                   | "any"

                 :position <-
                   "this" | opt("the" * Ws) * (:ordinal_value | "next" | "previous" | "prev")

                 # Basics
                 :id <- NonReserved | Identifier - Reserved

                 WordsToEol <- star(1 - Eol)
                 Nl <- opt(Ws) * opt(Comment) * "\n"
                 Comment <- "--" * star(1 - "\n")
                 Identifier <- AlphaLower * star(Alpha | Digit)
                 NonReserved <- Reserved * +(Alpha | Digit)
                 Alpha <- {~c"A"..~c"Z"} | AlphaLower
                 Digit <- {~c"0"..~c"9"}
                 AlphaLower <- {~c"a"..~c"z"}
               end)

  def peg_script, do: @peg_script
end
