# faru

A statically-typed programming language designed for clarity and control.

faru prioritizes **simplicity**, **explicitness**, and **readability**.

> **Status**: Work in progress. Core language features are under active development.

## Quick Example

```faru
fn add(a :: int, b :: int) int {
    return a + b;
}

fn main() int {
    value :: fin int = 1000 * 5;
    return value;
}
```

## Features

- **Static typing**
- **Explicit syntax**
- **No operator overloading**
- **Zero ambiguity**

## Getting Started

### Prerequisites

- [Zig](https://ziglang.org/) 0.16.0 or newer

### Building from Source

```bash
git clone https://codeberg.org/caelondev/faru.git
cd faru
zig build
```

### Running faru

```bash
./zig-cache/bin/faru run yourfile.faru
```

## Language Tour

### Variables and Types

```faru
// Mutable binding
x :: int = 42;

// Final (const) binding
value :: fin int = 100;
```

### Functions

```faru
fn greet(name :: string) string {
    return "Hello, " + name;
}
```

### Control Flow

```faru
fn check(n :: int) string {
    if n > 0: {
        return "positive";
    } else if n < 0: {
        return "negative";
    } else {
        return "zero";
    }
}
```

## Contributing

Contributions are welcome. Please open an issue first to discuss major changes.

1. Fork the repository
2. Create your feature branch
3. Submit a pull request

## License

This project is licensed under the [LICENSE](./LICENSE) file.

---

Built with [Zig](https://ziglang.org/).
