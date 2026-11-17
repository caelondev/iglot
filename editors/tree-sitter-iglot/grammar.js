/**
 * @file A statically typed programming language focused on clarity, explicit control, and readability
 * @author caelondev <me@caelondev.net>
 * @license GNU AGPLV3
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

const PREC = {
  assign: 1,
  or: 2,
  and: 3,
  equality: 4,
  comparison: 5,
  additive: 6,
  multiplicative: 7,
  unary: 8,
  postfix: 9, // call, index, member
};

/** @type {[string, number][]} */
const BINARY_OPS = [
  ["==", PREC.equality],
  ["!=", PREC.equality],
  ["<", PREC.comparison],
  [">", PREC.comparison],
  ["<=", PREC.comparison],
  [">=", PREC.comparison],
  ["+", PREC.additive],
  ["-", PREC.additive],
  ["*", PREC.multiplicative],
  ["/", PREC.multiplicative],
];

/**
 * @param {RuleOrLiteral} rule
 */
function commaSep1(rule) {
  return seq(rule, repeat(seq(",", rule)), optional(","));
}

export default grammar({
  name: "iglot",
  extras: $ => [
    /\s/,
    $.comment,
  ],
  word: $ => $.identifier,
  rules: {
    source_file: $ => repeat($._declaration),

    _declaration: $ => choice(
      $.function_decl,
      $.struct_decl,
      $.variable_decl,
    ),
    function_decl: $ => seq(
      "fn",
      field("name", $.identifier),
      "(",
      field("parameters", optional($.params)),
      ")",
      field("return_type", $._type),
      field("body", $.block),
    ),
    parameter: $ => seq(
      field("name", $.identifier),
      "::",
      field("type", $._type),
    ),
    params: $ => commaSep1($.parameter),

    block: $ => prec(2, seq(
      ":",
      "{",
      repeat($._statement),
      "}",
    )),

    struct_decl: $ => seq("struct", $.identifier, $.type_block),
    type_decl: $ => seq(
      field("name", $.identifier),
      "::",
      field("type", $._type)
    ),
    type_block: $ => seq(":", "{", optional(commaSep1($.type_decl)), "}"),

    _type: $ => choice(
      alias($.identifier, $.type_identifier),
      $.primitive_type,
      $.nullable,
      $.array,
      $.final,
      $.constant,
    ),

    primitive_type: $ => choice(
      "int", "bigint", "float", "double",
      "bool", "string", "null", "void",
    ),

    constant: $ => prec(1, seq("const", $._type)),
    final: $ => prec(1, seq("fin", $._type)),

    nullable: $ => seq(
      "?",
      field("type", $._type),
    ),

    array: $ => seq("[", $._expression, "]", $._type),

    _statement: $ => choice(
      $.variable_decl,
      $.return_stmt,
      $.expression_stmt,
      $.break_stmt,
      $.if_stmt,
      $.loop,
      $.switch_stmt,
    ),

    expression_stmt: $ => seq(
      field("expression", $._expression),
      ";",
    ),

    variable_decl: $ => seq(
      field("name", $.identifier),
      "::",
      optional(field("type", $._type)),
      "=",
      field("value", $._expression),
      ";",
    ),

    return_stmt: $ => seq(
      "return",
      field("value", $._expression),
      ";",
    ),

    break_stmt: $ => seq("break", ";"),

    if_stmt: $ => prec.right(seq(
      "if",
      $._expression,
      choice($.block, seq(":", $._statement)),
      optional($.else_branch),
    )),

    else_branch: $ => seq(
      "else",
      choice(
        $._statement,
        seq(":", $.block),
      ),
    ),

    loop: $ => seq("loop", $.block),

    switch_stmt: $ => seq("switch", $._expression, $.switch_body),
    switch_body: $ => seq(":", "{", repeat($.switch_prong), "}"),
    switch_prong: $ => seq(
      field("pattern", choice($._expression, "else")),
      "=>",
      field("body", choice(
        seq($._expression, optional(",")),
        $.block,
      )),
    ),

    _expression: $ => choice(
      $.boolean,
      $.null,
      $.identifier,
      $.integer,
      $.float,
      $.string,
      $.group,
      $.call,
      $.builtin_call,
      $.binary_expression,
      $.bare_brace,
      $.index,
      $.member,
      $.assign,
    ),

    boolean: $ => choice("true", "false"),
    null: $ => "null",
    identifier: $ => /[a-zA-Z_][a-zA-Z0-9_]*/,
    integer: $ => /[0-9]+/,
    float: $ => /[0-9]+\.[0-9]+/,
    comment: _ => /--[^\n]*/,
    string: $ => /"([^"\\]|\\.)*"/,
    group: $ => seq("(", $._expression, ")"),
    call: $ => prec.left(PREC.postfix, seq(field("callee", $._expression), "(", optional(commaSep1($._expression)), ")")),

    tag: $ => "#",
    builtin_call: $ => prec.left(PREC.postfix, seq(field("callee", $.identifier), $.tag, "(", optional(commaSep1($._expression)), ")")),

    binary_expression: $ => choice(
      ...BINARY_OPS.map(([op, p]) =>
        prec.left(p, seq(
          field("left", $._expression),
          field("operator", op),
          field("right", $._expression),
        ))
      ),
    ),

    bare_brace: $ => seq(
      "{",
      optional(choice(
        commaSep1($._expression),
        commaSep1($.field_init),
      )),
      "}",
    ),

    field_init: $ => seq(
      ".",
      field("name", $.identifier),
      "=",
      field("value", $._expression),
    ),

    index: $ => prec.left(PREC.postfix, seq(
      field("left", $._expression),
      ".[",
      field("index", $._expression),
      "]",
    )),
    member: $ => prec.left(
      PREC.postfix,
      seq(
        field("object", $._expression),
        ".",
        field("property", $.identifier),
      ),
    ),
    assign: $ => prec.right(
      PREC.assign,
      seq(
        field("assignee", $._expression),
        "=",
        field("value", $._expression),
      )
    ),
  }
});
