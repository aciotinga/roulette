# Roulette

[![Build Status][build-badge]][build]
[![Scribble][docs-badge]][docs]

Roulette is an inference-aided host language, built on top of Rosette, that
provides first-class support for measurable values. The programmer-facing
interface to Roulette is nearly the same as Rosette, except values can be
associated with measures. Instead of an SMT solver for the backend, Roulette
uses specialized solvers intended for inference. See [the documentation][docs]
for information on how to install and use the software.

## Export a joint Boolean-query BDD

With this checkout installed as `roulette` and `roulette-lib`, run the separate
export command:

```sh
racket -l roulette/example/blog/export -- model.blog joint.json
```

Use one query statement, for example `query A, !B, A & B;`. Export mode
compiles each Boolean expression separately and introduces a query variable
constrained to equal it. It does not enumerate joint tuple outcomes. The query
must be the final statement and earlier query statements are rejected. Ordinary
query evaluation and printing are unchanged; there is no environment switch.

The JSON contains:

- `bdd`: native RSDD `nodes` and a single `roots` entry representing the
  model evidence and all query equivalences.
- `weights`: literal weights named `v0`, `v1`, ... in BDD-label order;
  each pair is `[false, true]`.
- `queries`: the BDD labels of the introduced query variables, in query order.
  Their weights are `[1.0, 1.0]`; all other labels denote primitive choices.

The artifact describes an unnormalized joint distribution over primitive
choices and query results. Sum out the primitive choices to get query joint
masses, then normalize by the total mass to account for evidence. Impossible
evidence produces a zero-mass BDD. Query equivalences preserve correlations,
including repeated or dependent queries. The BDD can still grow exponentially.

Export currently accepts Boolean queries and normalized numeric probability
weights. Other semirings and importance weights from sampling are rejected.
The Racket API is `(export-query-bdd queries [evidence])` from
`roulette/engine/rsdd`; it returns the same JSON-compatible data without writing
a file. Export uses a temporary BDD manager, leaving inference state untouched.

[build-badge]: https://github.com/camoy/roulette/actions/workflows/build.yml/badge.svg
[build]: https://github.com/camoy/roulette/actions/workflows/build.yml?query=workflow%3Abuild
[docs-badge]: https://img.shields.io/badge/Docs-Scribble-blue.svg
[docs]: https://docs.racket-lang.org/roulette
