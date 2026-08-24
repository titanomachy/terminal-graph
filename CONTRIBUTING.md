# Contributing

Contributions are welcome through focused issues and pull requests.

## Development

Install `terminal_style` 0.1.1 or use the sibling workspace checkout. With Nim
2.0.0 or newer, run from the package root:

```sh
nimble check
nimble test
nimble examples
nimble docs
```

Renderers must be deterministic for explicit dimensions and must not query or
mutate terminal state. Put new graph families in a focused submodule, export
them through `terminal_graph.nim`, and add tests, API comments, a finite
example, and the aggregate showcase entry. Streaming examples must remain
bounded and must restore cursor state.

By contributing, you agree that your contribution is licensed under the MIT
license in `LICENSE`. Do not submit code whose license is unknown or
incompatible; update `THIRD_PARTY_NOTICES.md` when incorporating third-party
material.
