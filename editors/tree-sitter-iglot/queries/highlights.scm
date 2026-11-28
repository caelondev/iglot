; keywords
"fn" @keyword
"and" @keyword
"or" @keyword
"or_else" @keyword
"struct" @keyword
"module" @keyword
"import" @keyword
"return" @keyword.special
"const" @keyword.special
"fin" @keyword.special
"if" @keyword.special
"else" @keyword.special
"loop" @keyword.special
"switch" @keyword.special
(break_expr) @keyword.special
(continue_expr) @keyword.special

; comments
(comment) @comment

; symbols
"=" @operator
";" @punctuation.delimiter
":" @punctuation
"::" @punctuation
"{" @punctuation.bracket
"}" @punctuation.bracket
"[" @punctuation.bracket
".[" @punctuation.bracket
"]" @punctuation.bracket
"(" @punctuation.bracket
")" @punctuation.bracket
"?" @punctuation
"@" @punctuation
; "!" @punctuation
"," @punctuation
"." @punctuation
"+" @punctuation
"-" @punctuation
"*" @punctuation
"/" @punctuation
">" @punctuation
"<" @punctuation
">=" @punctuation
"<=" @punctuation
"==" @punctuation
"!=" @punctuation
"=>" @punctuation
(tag) @punctuation

; primitives
(boolean) @boolean
(null) @boolean

; types
(primitive_type) @type.builtin
(type_identifier) @type

; expression
(integer) @number
(float) @number
(string) @string

(member
  property: (identifier) @property)

(call
  callee: (identifier) @function)

((builtin_call
  callee: (identifier) @function
  (tag) @function)
  (#set! priority 110))

((call
  callee: (member
    property: (identifier) @function.method))
  (#set! priority 110))

(bare_brace
  (field_init
    name: (identifier) @property))

(member
  property: (identifier) @property)

; decls
(function_decl
  name: (identifier) @function)

(variable_decl
  name: (identifier) @variable)

(struct_decl
  (identifier) @type
  (type_block
    (type_decl
      name: (identifier) @property)))

; modules
(import_path
  name: (identifier) @module)

(import_decl
  alias: (identifier) @module)

(import_path
  name: (identifier) @module .)

(import_path
  root: "@" @keyword)

(import_path "/" @punctuation.delimiter)

; module member paths (a.b.c)
(module_member
  (identifier) @module)

(module_member
  (identifier) @property .)

(module_member
  "." @punctuation.delimiter)
