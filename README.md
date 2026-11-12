# Roulette

[![Build Status][build-badge]][build]
[![Scribble][docs-badge]][docs]

Roulette is an inference-aided host language, built on top of Rosette, that
provides first-class support for measurable values. The programmer-facing
interface to Roulette is nearly the same as Rosette, except values can be
associated with measures. Instead of an SMT solver for the backend, Roulette
uses specialized solvers intended for inference. See [the documentation][docs]
for information on how to install and use the software.

## Experimental tuple-table export

This branch uses Roulette's ordinary tuple inference to compute a normalized
joint distribution. No inference or BDD-engine code is changed.

```sh
racket -l roulette/example/blog/export -- model.blog joint.json
```

Use one final Boolean query statement, for example `query A, !B, A & B;`.
The JSON contains `queries` (consecutive query-column indices) and `outcomes`.
Each outcome has a Boolean `values` list and its normalized `probability`.
Only nonzero outcomes are written. Impossible evidence produces an empty list.

The ordinary inference path first forms possible tuple outcomes, including
zero-mass combinations, so compilation can grow as 2^k for k Boolean queries.
The output table can be much smaller when the queries are correlated.
The table is sufficient for a PC over these query variables, but does not
retain primitive-choice weights for later parameter changes.

The previous symbolic BDD exporter is preserved on `codex/symbolic-query-export`.

[build-badge]: https://github.com/camoy/roulette/actions/workflows/build.yml/badge.svg
[build]: https://github.com/camoy/roulette/actions/workflows/build.yml?query=workflow%3Abuild
[docs-badge]: https://img.shields.io/badge/Docs-Scribble-blue.svg
[docs]: https://docs.racket-lang.org/roulette
