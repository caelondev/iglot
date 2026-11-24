# Iglot Cheatsheet

A quick reference for Iglot syntax to start writing code.

## Contents

1. [Hello, World & Comments](#1-hello-world--comments)
   - [Hello, World](#hello-world)
   - [Comments](#comments)
2. [Types](#2-types)
   - [Primitive types](#primitive-types)
   - [Non-primitive types](#non-primitive-types)
3. [Variables](#3-variables)
4. [Literals](#4-literals)
5. [Operators](#5-operators)
   - [Arithmetic](#arithmetic)
   - [Comparison](#comparison)
   - [Logical](#logical)
6. [Control Flow](#6-control-flow)
   - [If / else](#if--else)
   - [Loops](#loops)
7. [Functions](#7-functions)
   - [Declaring](#declaring)
   - [Returning](#returning)
   - [Calling](#calling)
8. [Arrays](#8-arrays)
   - [Bare braces](#bare-braces)
9. [Structs](#9-structs)
   - [Declaring](#declaring-1)
   - [Creating](#creating)
   - [Reading and writing members](#reading-and-writing-members)
10. [Nullables](#10-nullables)
11. [Built-in Functions](#11-built-in-functions)
12. [Compiler-Internal Types](#12-compiler-internal-types)

---

## 1. Hello, World & Comments

### Hello, World

```iglot
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

## 2. Types

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

## 3. Variables

```iglot
x :: int = 10;   -- explicit type
x :: const int = 10;   -- constant variable
x :: fin int = 10;   -- final variable
x ::= 10;        -- inferred type
x = 20;          -- reassign
```

---

## 4. Literals

```iglot
10; -100;        -- integers
10.0; -50.5;     -- floats
"strings";       -- strings
true; false;     -- booleans
null;            -- null
```

---

## 5. Operators

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

## 6. Control Flow

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

## 7. Functions

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

---

## 8. Arrays

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

## 9. Structs

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

## 10. Nullables

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

## 11. Built-in Functions

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

## 12. Compiler-Internal Types

You'll mostly see these in error messages. They aren't types you write yourself.

| Type     | Purpose                                                                        |
| -------- | ------------------------------------------------------------------------------ |
| `any`      | Used by built-ins that accept any non-void type                                |
| `err`      | Poison type for declarations that failed, which prevents cascading type errors |
| `number`   | Special type used for error messages                                           |
