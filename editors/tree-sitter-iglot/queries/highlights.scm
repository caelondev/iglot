; keywords
"fn" @keyword

"return" @keyword

; symbols
"::" @operator

"=" @operator

";" @punctuation.delimiter

; primitives
(boolean) @boolean

(null) @boolean

(primitive_type) @type

(integer) @number

(float) @number

(string) @string

; decls
(function_decl
  name: (identifier) @function)

(variable_decl
  name: (identifier) @variable)
