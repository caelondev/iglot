# Iglot Cheatsheet

A quick reference for Iglot syntax to start writing code.

## Contents

1. [Hello, World & Comments](#1-hello-world--comments)
   - [Hello, World](#hello-world)
   - [Comments](#comments)
2. [Modules & Imports](#2-modules--imports)
   - [The module header](#the-module-header)
   - [Importing](#importing)
   - [Nested imports](#nested-imports)
   - [Root imports](#root-imports)
   - [Aliases](#aliases)
   - [Module rules](#module-rules)
3. [Types](#3-types)
   - [Primitive types](#primitive-types)
   - [Non-primitive types](#non-primitive-types)
4. [Variables](#4-variables)
5. [Literals](#5-literals)
6. [Operators](#6-operators)
   - [Arithmetic](#arithmetic)
   - [Comparison](#comparison)
   - [Logical](#logical)
   - [Nullable fallback](#nullable-fallback)
7. [Control Flow](#7-control-flow)
   - [If / else](#if--else)
   - [Loops](#loops)
   - [Break and return are expressions](#break-and-return-are-expressions)
8. [Functions](#8-functions)
   - [Declaring](#declaring)
   - [Returning](#returning)
   - [Calling](#calling)
9. [Arrays](#9-arrays)
   - [Bare braces](#bare-braces)
10. [Structs](#10-structs)
    - [Declaring](#declaring-1)
    - [Creating](#creating)
    - [Reading and writing members](#reading-and-writing-members)
11. [Nullables](#11-nullables)
    - [Unwrapping with `.?`](#unwrapping-with-)
    - [Defaulting with `or_else`](#defaulting-with-or_else)
    - [Diverging with `or_else`](#diverging-with-or_else)
    - [`or_else` rules](#or_else-rules)
12. [Built-in Functions](#12-built-in-functions)
13. [Compiler-Internal Types](#13-compiler-internal-types)

---

## 1. Hello, World & Comments

### Hello, World

Every file starts with a `module` header (see [Modules & Imports](#2-modules--imports)). The file you run is the entry module, and it is named `main`:

```iglot
module main;

fn main() void: {
  println#({ "Hello, World!" });
}
```

### Comments

Comments start with a double dash:

```iglot
module main;

fn main() void: {
  println#({ ":)" }); -- this is a comment
}
```

---

## 2. Modules & Imports

Every Iglot file is a module. A module has its own scope, so two files can both define a function called `helper` without clashing. To use code from another file, import it.

### The module header

The first statement of every file declares its name:

```iglot
module math;
```

- It must come before everything else (comments above it are fine).
- It is required in every file.
- The name must match the filename without the extension. `math.iglot` must say `module math;`, otherwise you get a name mismatch error.
- Files must end in `.iglot`.

### Importing

`import` goes right after the header, before any declarations.

```iglot
-- math.iglot
module math;

fn add(a :: int, b :: int) int: {
  return a + b;
}
```

```iglot
-- main.iglot
module main;

import math;

fn main() void: {
  println#({ math.add(1, 2) });   -- 3
}
```

`import math;` binds the name `math`, and you reach things inside it with a dot: `math.add`. You never write a bare `add`, so imports can't collide with your own names.

Imported functions are ordinary values, so they work anywhere a function does:

```iglot
module main;

import math;

fn main() void: {
  sum :: fn (int, int) int = math.add;
  println#({ sum(50, 100) });   -- 150
}
```

### Nested imports

Modules can live in directories. Separate each directory and the file with `/`:

```iglot
-- tests/main.iglot
module main;

import utils/math/arithmetic;   -- loads utils/math/arithmetic.iglot

fn main() void: {
  arithmetic.sum_of(100, 2);
}
```

- The last segment is the file, and every segment before it is a directory.
- The binding name is the last segment, so the module above is used as `arithmetic`, not `utils` or `utils/math/arithmetic`.
- A bare path (no `@/`) is looked up from the directory of the file that contains the import.
- The module name in the file header must match the last segment: `arithmetic.iglot` says `module arithmetic;`.
- There is no `..`. A bare path can only go down, never up. To reach something outside the current directory, use a [root import](#root-imports).

### Root imports

Prefix a path with `@/` to start from the **root** instead of the current directory. The root is the directory of the entry file, which is the file you passed to the cli. Running `iglot run src/main.iglot` makes `src/` the root, no matter where you run it from.

```iglot
-- utils/math/arithmetic.iglot
module arithmetic;

import @/utils/printer;   -- always resolves from the root

fn sum_of(a :: int, b :: int) void: {
  printer.format("sum:", a + b);
}
```

A root import means the same thing from every file, so you can move a file around without breaking it.

Using `@/` in a file that already sits in the root directory is an error, because a bare path there already starts at the root:

```iglot
-- main.iglot, in the root directory
module main;

import @/utils/printer;   -- error: redundant "@/" prefix
import utils/printer;     -- correct
```

### Aliases

Give an import a different local name with `::`, the same operator you use for declarations:

```iglot
module main;

import m :: math;
import arith :: utils/math/arithmetic;
import p :: @/utils/printer;

fn main() void: {
  println#({ m.add(1, 2) });
  arith.sum_of(1, 2);
}
```

The alias goes on the left, and the module path on the right. Once aliased, only the alias exists: after `import m :: math;` the name `math` is not bound. Aliases are also how you import two modules that share a last segment (`a/util` and `b/util`), since both would otherwise bind `util`.

### Module rules

- **One file is one module.** `import math;` loads `math.iglot` from the same directory as the importing file, and `import @/math;` loads it from the root.
- **Each module is loaded once.** If two files import the same module, they share it, even if one writes the path as a bare import and the other uses `@/`. Its top-level variables are initialized once, before the importing module's own.
- **Everything at the top level is importable** (functions, variables and structs). Visibility modifiers are planned.
- **No import cycles.** If `a` imports `b` and `b` imports `a`, the compiler reports the cycle and shows the chain.
- **A module is a namespace, not a value.** `x ::= math;` is an error. Always use it as `math.something`.
- **Missing names are errors.** `math.nope` reports that the module has no such member, and importing a file that doesn't exist reports that the module can't be found.
- **Two imports can't bind the same name.** Use an alias to tell them apart.
- **Built-ins need no import.** `println#()`, `prompt#()` and friends belong to the compiler, not to any module.
- **Only functions and variables are reachable through a module for now.** Using another module's struct as a type (`math.Vec`) is not supported yet.

---

## 3. Types

### Primitive types

| Type      | Meaning         |
| --------- | --------------- |
| `int`       | 64-bit integer  |
| `wideint`   | 128-bit integer |
| `float`     | 32-bit float    |
| `double`    | 64-bit float    |
| `bool`      |   `true` / `false`  |
| `string`    | Text            |

### Non-primitive types

| Type     | Meaning                                                                |
| -------- | ---------------------------------------------------------------------- |
| `void`     | Return type of functions that return nothing                           |
| `[n]T`     | Array of `n` elements of type `T` (size known at compile time)             |
| `fn (...)` | Function type, carried by identifiers that are functions               |
| `const T`  | Constant                                                               |
| `fin T`    | Final                                                                  |
| `?T`       | Nullable `T`                                                             |
| `null`     | The type of the `null` value                                             |

Function types look like this:

```iglot
fn (type, type, ...) ret_type
```

---

## 4. Variables

```iglot
module main;

fn main() void: {
  x :: int = 10;   -- explicit type
  x :: const int = 10;   -- constant variable
  x :: fin int = 10;   -- final variable
  x ::= 10;        -- inferred type
  x = 20;          -- reassign
}
```

---

## 5. Literals

```iglot
module main;

fn main() void: {
  10; -100;        -- integers
  10.0; -50.5;     -- floats
  "strings";       -- strings
  true; false;     -- booleans
  null;            -- null
}
```

---

## 6. Operators

### Arithmetic

```iglot
module main;

fn main() void: {
  1 + 1;   -- addition
  1 - 1;   -- subtraction
  1 * 1;   -- multiplication
  1 / 1;   -- division
}
```

### Comparison

```iglot
module main;

fn main() void: {
  1 > 1;    -- greater than
  1 < 1;    -- less than
  1 >= 1;   -- greater than or equal to
  1 <= 1;   -- less than or equal to
  1 == 1;   -- equal to
  1 != 1;   -- not equal to
}
```

### Logical

```iglot
module main;

fn main() void: {
  !false;           -- NOT
  true and true;    -- AND
  true or false;    -- OR
}
```

### Nullable fallback

`or_else` takes a nullable on the left and gives back its value, or the right side if it is `null`. The result is the plain, non-nullable type.

```iglot
module main;

fn main() void: {
  x :: ?int = null;
  y ::= x or_else 5;   -- 5
  println#({ y });
}
```

It binds tighter than comparisons and looser than arithmetic, so `a or_else b + 1` means `a or_else (b + 1)`, and `a or_else 1 > 2` means `(a or_else 1) > 2`.

See [Nullables](#11-nullables) for the full rules.

---

## 7. Control Flow

### If / else

```iglot
module main;

fn main() void: {
  if x != null: {
    -- do something
  } else if 10 == 50: {
    -- do this
  } else: {
    -- something else
  }
}
```

One-liners work too. Any statement is valid after the `:`, not just an expression:

```iglot
module main;

fn if_statements() bool: {
  if cond: x = 10;
  else if cond_2: return false;
  else: return true;
}
```

### Loops

Iglot has one loop: `loop`. It runs forever until you `break`.

```iglot
module main;

fn main() void: {
  loop: {
    println#({ "THIS RUNS FOREVERRRRRRR!!!" });
    break; -- only allowed inside loops
  }
}
```

A `break` belongs to the innermost loop around it. In nested loops, it only leaves the inner one.

### Break and return are expressions

`break` and `return` are expressions, not statements. That means they can appear anywhere an expression is allowed, not only on a line of their own.

```iglot
module main;

fn pointless() ?int: {
  x ::= return null; -- works, but pointless as-is
}

fn main() void: {
  loop: {
    x ::= break; -- same thing here
  }
}
```

The placement rules still apply:

- `break` is only allowed inside a loop.
- `return` is only allowed inside a function.

A few things follow from this:

- `break` leaves the loop, so code after it in the same block never runs.
- `return` leaves the whole function, even from inside a loop. A loop that can only be left by `return` never lets control continue past it, so a function ending in such a loop doesn't need a `return` after it:

```iglot
module main;

fn first_big(limit :: int) int: {
  i ::= 0;
  loop: {
    if i > limit: return i;
    i = i + 1;
  }
  -- no return needed here, the loop can only be left by `return`
}

fn main() void: {
  println#({ first_big(5) });   -- 6
}
```

Because they are expressions, `break` and `return` also work as the right side of [`or_else`](#diverging-with-or_else).

---

## 8. Functions

### Declaring

```iglot
module main;

fn main() void: {
  -- we're in a function
}

fn add(x :: int, y :: int) int: {
  return x + y;
}
```

### Returning

`return` is an expression that exits the current function. It is only allowed inside functions, and it is optional in `void` functions.

```iglot
module main;

fn main() void: {}

fn add(a :: int, b :: int) int: {
  return a + b;
}
```

See [Break and return are expressions](#break-and-return-are-expressions) for where else it can appear.

### Calling

```iglot
module main;

fn add(x :: int, y :: int) int: {
  return x + y;
}

fn main() void: {
  add(1, 2);
}
```

Functions from an imported module are called through the module name (or its alias):

```iglot
module main;

import math;

fn main() void: {
  math.add(1, 2);
}
```

---

## 9. Arrays

Arrays have a fixed size and are zero-indexed. Access elements with `.[i]`.

```iglot
module main;

fn main() void: {
  a ::= [3]int{ 1, 2, 3 }; -- array literal
  x :: [5]int = { 10, 20, 30, 40, 50 };
  println#({ x.[2] }); -- 30
}
```

### Bare braces

`{ ... }` is a type-sensitive container. The declared type decides whether it becomes an array or a struct. Trailing commas are allowed.

```iglot
module main;

fn main() void: {
  array :: [3]int = {
    1,
    2,
    3,
  };
}
```

---

## 10. Structs

### Declaring

```iglot
module main;

struct Person: {
  name :: string,
  age :: int,
}

fn main() void: {}
```

### Creating

```iglot
module main;

struct Person: {
  name :: string,
  age :: int,
}

fn main() void: {
  p :: Person = {
    .name = "Bob",
    .age = 30,
  };
}
```

### Reading and writing members

```iglot
module main;

struct Person: {
  name :: string,
  age :: int,
}

fn main() void: {
  p :: Person = {
    .name = "Bob",
    .age = 30,
  };

  println#({ p.name });   -- Bob
  p.name = "Alice";
}
```

---

## 11. Nullables

Put `?` in front of a type to allow `null`. Use `.?` to unwrap, or `or_else` to fall back to another value.

### Unwrapping with `.?`

```iglot
module main;

struct Person: {
  name :: string,
  age :: int,
}

fn main() void: {
  p :: ?Person = {
    .name = "Bob",
    .age = 30,
  };

  println#({ p.?, p.?.name }); -- unwrap the value, or a member through it

  p = null;
  println#({ p.? }); -- Crash!!! (unwrapping null)
}
```

Check before you unwrap:

```iglot
module main;

struct Person: {
  name :: string,
  age :: int,
}

fn main() void: {
  p :: ?Person = {
    .name = "Bob",
    .age = 30,
  };

  if p != null: {
    println#({ p.?.name });
  }
}
```

### Defaulting with `or_else`

`left or_else right` evaluates to `left` if it isn't `null`, and to `right` otherwise. The result has the unwrapped type, so there is no `.?` needed afterwards, and it can never crash.

```iglot
module main;

fn main() void: {
  maybe :: ?int = null;
  value ::= maybe or_else 42;   -- 42, and `value` is a plain int
  println#({ value });
}
```

This is the usual way to handle the built-in parsers, which return nullables:

```iglot
module main;

fn main() void: {
  n ::= parse_to_int#(prompt#("Enter a number: ")) or_else 0;
  println#({ "You entered:", n });
}
```

The right side only runs when the left side is `null`.

### Diverging with `or_else`

The right side is allowed to leave instead of producing a value. Since `return` and `break` are [expressions](#break-and-return-are-expressions), you can bail out right where the `null` shows up:

```iglot
module main;

fn read_number() int: {
  n ::= parse_to_int#(prompt#("Enter a number: ")) or_else return -1;
  return n * 2;
}

fn main() void: {
  println#({ read_number() });
}
```

```iglot
module main;

fn main() void: {
  loop: {
    n ::= parse_to_int#(prompt#("Enter a number (or anything else to stop): ")) or_else break;
    println#({ "Got:", n });
  }
}
```

After the `or_else`, `n` is a plain `int`, because the only way to get past that line is for the value to have been non-null.

### `or_else` rules

- **The left side must be nullable.** `5 or_else 1` is an error: `left side of 'or_else' must be nullable`.
- **The right side must match the unwrapped type.** `?int or_else "hi"` is a type mismatch. The exception is a right side that diverges (`return`, `break`), which is always allowed.
- **The result is the unwrapped type.** `?int or_else 0` is an `int`.
- **Precedence.** It binds tighter than comparisons and looser than arithmetic. Use parentheses if you're unsure.

---

## 12. Built-in Functions

Built-ins are called with a `#` after the name.

```iglot
module main;

fn main() void: {
  println#({ "Hello, World!" }); -- fn ([UNBOUNDED]any) void
  print#({ "Hello!", "Bye!" }); -- fn ([UNBOUNDED]any) void
  prompt#("Say something! "); -- fn (string) string

  parse_to_int#("123"); -- fn (string) ?int
  parse_to_wideint#("123"); -- fn (string) ?wideint
  parse_to_float#("3.14"); -- fn (string) ?float
  parse_to_double#("3.1415926535"); -- fn (string) ?double

  fetch#("https://example.com"); -- fn (string) ?FetchResult

  type_of#(123); -- fn (any) string
}
```

The `parse_to_*` functions return a nullable, so a string that isn't a valid number gives `null`. Handle that with [`or_else`](#defaulting-with-or_else) or check before you unwrap with `.?`.

---

## 13. Compiler-Internal Types

You'll mostly see these in error messages. They aren't types you write yourself.

| Type     | Purpose                                                                        |
| -------- | ------------------------------------------------------------------------------ |
| `any`      | Used by built-ins that accept any non-void type                                |
| `err`      | Poison type for declarations that failed, which prevents cascading type errors |
| `number`   | Special type used for error messages                                           |

