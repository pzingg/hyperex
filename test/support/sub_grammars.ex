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
             Whitespace <- " " | "\t"
             ConsumeLine <- star(1 - "\n")
             Comment <- "--" * ConsumeLine
             # Token delimeter
             :+ <- opt(Whitespace | Comment)

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

             NonReserved <- Reserved * +(Alpha | Digit)
             :id <- NonReserved | Word - Reserved

             # HyperTalk vocabulary
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
               "this" | opt("the") * :+ * (:ordinal_value | "next" | "previous" | "prev")

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

             :command_name <-
               "add"
               | "answer"
               | "arrowKey"
               | "arrowkey"
               | "ask"
               | "beep"
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
               | "enterInField"
               | "enterinfield"
               | "enterKey"
               | "enterkey"
               | "export"
               | "find"
               | "get"
               | "go"
               | "help"
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
               | "returnInField"
               | "returninfield"
               | "returnKey"
               | "returnkey"
               | "save"
               | "select"
               | "send"
               | "set"
               | "show"
               | "sort"
               | "stop"
               | "subtract"
               | "tabKey"
               | "tabkey"
               | "type"
               | "unlock"
               | "ummark"
               | "visual"
               | "wait"
               | "write"

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

             :program <- :+ * :id * :+
           end)

  def peg_test, do: @peg_test

  def peg_strings, do: @peg_strings

  def peg_id, do: @peg_id
end
