<vdiv align="center">

  <h1><strong>iglot</strong></h1>

  <br>

[Repository](https://codeberg.org/caelondev/iglot) · [Issues](https://codeberg.org/caelondev/iglot/issues)
</div>

Iglot is a statically-typed programming language built around clarity and control.

> **Status:** Work in progress. The language and compiler are still changing quite a bit.

## Quick Start

### Requirements

- [Zig](https://ziglang.org/) 0.17.0 or newer

### Build from source

```bash
git clone https://codeberg.org/caelondev/iglot.git
cd iglot
zig build -Doptimize=ReleaseFast
```

Run a Iglot program with:

```bash
./zig-cache/bin/iglot run yourfile.iglot
```

## What is Iglot?

Iglot is a statically-typed programming language designed for everyday use, from quick scripts and small utilities to larger programs.

It is built around three simple goals: fast, type-safe, and boring.

Iglot favors explicit behavior, predictable semantics, and a small amount of language magic. The syntax is intended to stay simple and readable without getting in the way of writing real programs.

Although scripting and small utilities are an important use case, Iglot is not intended to be limited to them. The language and runtime are being designed to grow into something capable of handling day-to-day programming more broadly.

## Examples

Hello, World!

A simple program that prints a message to the console.

```
fn main() void {
  println({ "Hello, World!" });
}
```

Fibonacci Sequence

Calculate the 20th Fibonacci number using recursion, with type inference for the result.

```
fn fib(n :: int) int {
  if n <= 1: return n;
  return fib(n - 1) + fib(n - 2);
}

fn main() void {
  value ::= fib(20);
  println({ value });
}
```

## Development

Iglot is actively developed and is still a work in progress. The language, compiler, and runtime are evolving as the project grows.

The architecture is intentionally kept modular to leave room for future optimizations, runtime features, and compilation backends.

## Contributing

Bug reports, ideas, and pull requests are welcome.

For larger changes, opening an issue first is a good way to discuss the idea and approach before writing a bunch of code.

## License

Iglot is licensed under the [GNU Affero General Public License v3.0](./LICENSE).

---

<div align="center">
  Built with <a href="https://ziglang.org/">Zig</a>.
</div>
