# Iglot Cheatsheet

A quick reference for Iglot syntax to start writing code.

## Contents

1. [Hello, World & Comments](#1-hello-world--comments)
   - [Hello, World](#hello-world)
   - [Comments](#comments)
2. [Modules & Imports](#2-modules--imports)
   - [The module header](#the-module-header)
   - [Importing](#importing)
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
7. [Control Flow](#7-control-flow)
   - [If / else](#if--else)
   - [Loops](#loops)
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
println#({ ":)" }); -- this is a comment
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
sum :: fn (int, int) int = math.add;
println#({ sum(50, 100) });   -- 150
```

### Aliases

Give an import a different local name with `::`, the same operator you use for declarations:

```iglot
import m :: math;

fn main() void: {
  println#({ m.add(1, 2) });
}
```

The alias goes on the left, and the module name on the right. Once aliased, only the alias exists: after `import m :: math;` the name `math` is not bound.

### Module rules

- **One file is one module.** Imports are looked up by name next to the importing file: `import math;` loads `math.iglot` from the same directory.
- **Each module is loaded once.** If two files import the same module, they share it. Its top-level variables are initialized once, before the importing module's own.
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
x :: int = 10;   -- explicit type
x ::= 10;        -- inferred type
x = 20;          -- reassign
```

---

## 5. Literals

```iglot
10; -100;        -- integers
10.0; -50.5;     -- floats
"strings";       -- strings
true; false;     -- booleans
null;            -- null
```

---

## 6. Operators

### Arithmetic

```iglot
1 + 1;   -- addition
1 - 1;   -- subtraction
1 * 1;   -- multiplication
1 / 1;   -- division
```

### Comparison

```iglot
1 > 1;    -- greater than
1 < 1;    -- less than
1 >= 1;   -- greater than or equal to
1 <= 1;   -- less than or equal to
1 == 1;   -- equal to
1 != 1;   -- not equal to
```

### Logical

```iglot
!false           -- NOT
true and true    -- AND
true or false    -- OR
```

---

## 7. Control Flow

### If / else

```iglot
if x != null: {
  -- do something
} else if 10 == 50: {
  -- do this
} else: {
  -- something else
}
```

One-liners work too:

```iglot
if cond: x = 10;
else if cond_2: return false;
else: return true;
```

### Loops

Iglot has one loop: `loop`. It runs forever until you `break`.

```iglot
loop: {
  println#({ "THIS RUNS FOREVERRRRRRR!!!" });
  break; -- only allowed inside loops
}
```

---

## 8. Functions

### Declaring

```iglot
fn main() void: {
  -- we're in a function
}

fn add(x :: int, y :: int) int: {
  return x + y;
}
```

### Returning

`return` is only allowed inside functions. It's optional in `void` functions.

```iglot
fn main() void: {}
fn add(a :: int, b :: int) int: {
    return a + b;
}
```

### Calling

```iglot
add(1, 2);
```

Functions from an imported module are called through the module name (or its alias):

```iglot
math.add(1, 2);
```

---

## 9. Arrays

Arrays have a fixed size and are zero-indexed. Access elements with `.[i]`.

```iglot
[3]int{ 1, 2, 3 };               -- array literal

x :: [5]int = { 10, 20, 30, 40, 50 };
println#({ x.[2] });             -- 30
```

### Bare braces

`{ ... }` is a type-sensitive container. The declared type decides whether it becomes an array or a struct. Trailing commas are allowed.

```iglot
array :: [3]int = {
  1,
  2,
  3,
};
```

---

## 10. Structs

### Declaring

```iglot
struct Person: {
  name :: string,
  age :: int,
}
```

### Creating

```iglot
p :: Person = {
  .name = "Bob",
  .age = 30,
};
```

### Reading and writing members

```iglot
println#({ p.name });   -- Bob
p.name = "Alice";
```

---

## 11. Nullables

Put `?` in front of a type to allow `null`. Use `.?` to unwrap.

```iglot
p :: ?Person = {
  .name = "Bob",
  .age = 30,
};

println#({ p.?, p.?.name });   -- unwrap the value, or a member through it

p = null;
println#({ p.? });             -- Crash!!! (unwrapping null)
```

Check before you unwrap:

```iglot
if p != null: {
  println#({ p.?.name });
}
```

---

## 12. Built-in Functions

Built-ins are called with a `#` after the name.

```iglot
println#({ "Hello, World!" });         -- fn ([UNBOUNDED]any) void
print#({ "Hello!", "Bye!" });          -- fn ([UNBOUNDED]any) void
prompt#("Say something! ");            -- fn (string) string

parse_to_int#("123");                  -- fn (string) int
parse_to_wideint#("123");              -- fn (string) wideint
parse_to_float#("3.14");               -- fn (string) float
parse_to_double#("3.1415926535");      -- fn (string) double

fetch#("https://example.com");         -- fn (string) ?FetchResult

type_of#(123);                         -- fn (any) string
```

---

## 13. Compiler-Internal Types

You'll mostly see these in error messages. They aren't types you write yourself.

| Type     | Purpose                                                                        |
| -------- | ------------------------------------------------------------------------------ |
| `any`      | Used by built-ins that accept any non-void type                                |
| `err`      | Poison type for declarations that failed, which prevents cascading type errors |
| `number`   | Special type used for error messages                                           |

