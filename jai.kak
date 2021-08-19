# https://golang.org/
#

# Detection
# ‾‾‾‾‾‾‾‾‾

hook global BufCreate .*\.jai %{
    set-option buffer filetype jai
}

# Initialization
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾

hook global WinSetOption filetype=jai %{
    require-module jai

    set-option window static_words %opt{jai_static_words}

    set-option window comment_line '//'
    set-option window comment_block_begin '/*'
    set-option window comment_block_end '*/'

    # cleanup trailing whitespaces when exiting insert mode
    hook window ModeChange pop:insert:.* -group jai-trim-indent %{ try %{ execute-keys -draft <a-x>s^\h+$<ret>d } }
    hook window InsertChar \n -group jai-indent jai-indent-on-new-line
    hook window InsertChar \{ -group jai-indent jai-indent-on-opening-curly-brace
    hook window InsertChar \} -group jai-indent jai-indent-on-closing-curly-brace
    hook window InsertChar \n -group jai-insert jai-insert-on-new-line

    alias window alt jai-alternative-file

    hook -once -always window WinSetOption filetype=.* %{
        remove-hooks window jai-.+
        unalias window alt jai-alternative-file
    }
}

hook -group jai-highlight global WinSetOption filetype=jai %{
    add-highlighter window/jai ref jai
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/jai }
}

provide-module jai %§

# Highlighters
# ‾‾‾‾‾‾‾‾‾‾‾‾

add-highlighter shared/jai regions
add-highlighter shared/jai/code default-region group
add-highlighter shared/jai/double_string region '"' (?<!\\)(\\\\)*" fill string
add-highlighter shared/jai/single_string region "'" (?<!\\)(\\\\)*' fill string
add-highlighter shared/jai/comment region /\* \*/ fill comment
add-highlighter shared/jai/comment_line region '//' $ fill comment

add-highlighter shared/jai/code/ regex %{-?([0-9]*\.(?!0[xX]))?\b([0-9]+|0[xX][0-9a-fA-F]+)\.?([eE][+-]?[0-9]+)?i?\b} 0:value

evaluate-commands %sh{
    # Grammar
    keywords='if else case ifx then for while continue break import defer return using'
    types = 'bool s8 u8 s16 u16 s32 u32 s64 u64 int float float32 float64 string struct Any'
    values='false true null'
    functions='append free memcpy size_of type_of New'

    join() { sep=$2; eval set -- $1; IFS="$sep"; echo "$*"; }

    # Add the language's grammar to the static completion list
    printf %s\\n "declare-option str-list jai_static_words $(join "${keywords} ${attributes} ${types} ${values} ${functions}" ' ')"

    # Highlight keywords
    printf %s "
        add-highlighter shared/jai/code/ regex \b($(join "${keywords}" '|'))\b 0:keyword
        add-highlighter shared/jai/code/ regex \b($(join "${attributes}" '|'))\b 0:attribute
        add-highlighter shared/jai/code/ regex \b($(join "${types}" '|'))\b 0:type
        add-highlighter shared/jai/code/ regex \b($(join "${values}" '|'))\b 0:value
        add-highlighter shared/jai/code/ regex \b($(join "${functions}" '|'))\b 0:builtin
        add-highlighter shared/jai/code/ regex := 0:attribute
    "
}

define-command -hidden jai-indent-on-new-line %~
    evaluate-commands -draft -itersel %=
        # preserve previous line indent
        try %{ execute-keys -draft <semicolon>K<a-&> }
        # indent after lines ending with { or (
        try %[ execute-keys -draft k<a-x> <a-k> [{(]\h*$ <ret> j<a-gt> ]
        # cleanup trailing white spaces on the previous line
        try %{ execute-keys -draft k<a-x> s \h+$ <ret>d }
        # align to opening paren of previous line
        try %{ execute-keys -draft [( <a-k> \A\([^\n]+\n[^\n]*\n?\z <ret> s \A\(\h*.|.\z <ret> '<a-;>' & }
        # copy // comments prefix
        try %{ execute-keys -draft <semicolon><c-s>k<a-x> s ^\h*\K/{2,} <ret> y<c-o>P<esc> }
        # indent after a switch's case/default statements
        try %[ execute-keys -draft k<a-x> <a-k> ^\h*(case|default).*:$ <ret> j<a-gt> ]
        # deindent closing brace(s) when after cursor
        try %[ execute-keys -draft <a-x> <a-k> ^\h*[})] <ret> gh / [})] <ret> m <a-S> 1<a-&> ]
    =
~

define-command -hidden jai-indent-on-opening-curly-brace %[
    # align indent with opening paren when { is entered on a new line after the closing paren
    try %[ execute-keys -draft -itersel h<a-F>)M <a-k> \A\(.*\)\h*\n\h*\{\z <ret> s \A|.\z <ret> 1<a-&> ]
]

define-command -hidden jai-indent-on-closing-curly-brace %[
    # align to opening curly brace when alone on a line
    try %[ execute-keys -itersel -draft <a-h><a-k>^\h+\}$<ret>hms\A|.\z<ret>1<a-&> ]
]

define-command -hidden jai-insert-on-new-line %[
    evaluate-commands -no-hooks -draft -itersel %[
        # Wisely add '}'.
        evaluate-commands -save-regs x %[
            # Save previous line indent in register x.
            try %[ execute-keys -draft k<a-x>s^\h+<ret>"xy ] catch %[ reg x '' ]
            try %[
                # Validate previous line and that it is not closed yet.
                execute-keys -draft k<a-x> <a-k>^<c-r>x.*\{\h*\(?\h*$<ret> j}iJ<a-x> <a-K>^<c-r>x\)?\h*\}<ret>
                # Insert closing '}'.
                execute-keys -draft o<c-r>x}<esc>
                # Delete trailing '}' on the line below the '{'.
                execute-keys -draft Xs\}$<ret>d
            ]
        ]
    ]
]

§
