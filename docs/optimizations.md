# Optimization passes (planned)

Operate on the existing IR (Module/Function/Instruction), post-build, pre-bytecode-emit.
Pipeline: build -> optimize (this list, roughly in order) -> emit bytecode.

## Core

- [ ] mem2reg — eliminate alloca/store/load where a local doesn't need a memory slot
- [ ] Constant folding
- [ ] CSE (common subexpression elimination)
- [ ] Dead code elimination (DCE)
- [ ] Unreachable block elimination

## Control flow

- [ ] Branch folding on constant conditions
- [ ] Block merging (single-predecessor straight-line blocks)
- [ ] Jump threading

## Arithmetic / value-level

- [ ] Strength reduction
- [ ] Algebraic simplification (x+0, x*1, x-x, etc.)
- [ ] Copy propagation

## Function-level

- [ ] Inlining
- [ ] Tail call optimization
- [ ] Dead function elimination

## Loop-related

- [ ] Loop-invariant code motion (LICM)
- [ ] Induction variable simplification
