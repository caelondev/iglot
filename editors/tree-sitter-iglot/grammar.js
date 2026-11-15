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

    block: $ => seq(
      "{",
      optional(repeat($._statement)),
      "}",
    ),

    struct_decl: $ => seq("struct", $.identifier, $.type_block),
    type_decl: $ => seq(
      field("name", $.identifier),
      "::",
      field("type", $._type)
    ),
    type_block: $ => seq(":", "{", optional(commaSep1($.type_decl)), "}"),

    _type: $ => choice(
      $.primitive_type,
      alias($.identifier, $.type_identifier),
      $.nullable,
      $.array,
    ),

    primitive_type: $ => choice(
      "int", "bigint", "float", "double",
      "bool", "string", "null", "void",
    ),

    nullable: $ => seq(
      "?",
      field("type", $._type),
    ),

    array: $ => seq("[", $._expression, "]", $._type),

    _statement: $ => choice(
      $.variable_decl,
      $.return_stmt,
      $.expression_stmt,
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

    _expression: $ => choice(
      $.boolean,
      $.null,
      $.identifier,
      $.integer,
      $.float,
      $.string,
      $.group,
      $.call,
      $.binary_expression,
      $.bare_brace,
    ),

    boolean: $ => choice("true", "false"),
    null: $ => "null",
    identifier: $ => /[a-zA-Z_][a-zA-Z0-9_]*/,
    integer: $ => /[0-9]+/,
    float: $ => /[0-9]+\.[0-9]+/,
    comment: _ => /--[^\n]*/,
    string: $ => /"([^"\\]|\\.)*"/,
    group: $ => seq("(", $._expression, ")"),
    call: $ => seq(field("callee", $.identifier), "(", commaSep1($._expression), ")"),
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
  }
});
