; keywords
"fn" @keyword

"return" @keyword.special

"struct" @keyword.special

"const" @keyword.special

"fin" @keyword.special

; comments
(comment) @comment

; symbols
"::" @operator

"=" @operator

";" @punctuation.delimiter

":" @punctuation

"{" @punctuation.bracket

"}" @punctuation.bracket

"[" @punctuation.bracket

".[" @punctuation.bracket

"]" @punctuation.bracket

"(" @punctuation.bracket

")" @punctuation.bracket

"?" @punctuation

; "!" @punctuation
; "," @punctuation
; "." @punctuation
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
