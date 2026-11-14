/**
 * @file A statically typed programming language focused on clarity, explicit control, and readability
 * @author caelondev <me@caelondev.net>
 * @license GNU AGPLV3
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

function commaSep1(rule) {
  return seq(rule, repeat(seq(',', rule)));
}

export default grammar({
  name: "iglot",

  rules: {
    source_file: $ => repeat($._declaration),

    _declaration: $ => choice(
      $.function_decl,
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

    _type: $ => choice(
      "int",
      "bigint",
      "float",
      "double",
      "bool",
      "string",
      "null",
      "void",
      $.nullable,
    ),

    nullable: $ => seq(
      "?",
      field("type", $._type),
    ),

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
      "true",
      "false",
      "null",
      $.identifier,
      $.integer,
      $.float,
      $.string,
    ),

    identifier: $ => /[a-zA-Z_][a-zA-Z0-9_]*/,
    integer: $ => /[0-9]+/,
    float: $ => /[0-9]+\.[0-9]+/,
    string: $ => /"([^"\\]|\\.)*"/,
  }
});
