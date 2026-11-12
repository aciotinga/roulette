# Symbolic versus explicit tuple export

Measured November 12, 2026. Both methods use the same BLOG programs and query
expressions, with no approximate inference or learned parameters.

## Preserved implementations

- [Symbolic consistency-BDD export](https://github.com/aciotinga/roulette/tree/codex/symbolic-query-export), benchmarked at `c432cc0b733d85b424049bee5a6e0bbf8ff53d02`.
- [Ordinary tuple-inference export](https://github.com/aciotinga/roulette/tree/codex/tuple-enumeration-export), benchmarked at `a89616e04404ff08a405f8433ce07cfedcc8b53e`.

The symbolic branch adds 51 lines to two existing runtime files and a 43-line
export command. The tuple branch adds a 51-line export command, with no changes
to existing runtime files. Tests and documentation are excluded from these counts.

The symbolic pipeline exports primitive weights and a single constraint BDD
for the model evidence and query equivalences. Its PC retains the primitive
variables and query variables. The tuple pipeline uses existing tuple inference
to export the nonzero joint probabilities, then builds a PC over query variables
only. Both answer the same query marginal and conditional requests for a fixed model.
The tuple table does not retain primitive parameters for later reweighting.

## Method

- Windows 11, Racket 9.3, Python 3.13.2, Cirkit 0.3.1, Torch 2.11.0. CPU-only;
  Cirkit evaluations use one Torch thread and float64.
- Every export and PC profile runs in a fresh process. Export times below include
  parsing, symbolic model execution, export/inference, and JSON serialization,
  but exclude loading Racket modules (typically another 2–3 seconds).
- Three export trials for up to eight queries, reporting the median; one trial
  for larger cases. PC construction is measured once. Evaluation is the median
  of five warmed batches, each computing four probabilities: Q0, Q1, Q0 AND Q1,
  and all query variables true. Input construction and IntegrateQuery dispatch
  are included in this evaluation measurement.
- The main sweep has a 20-second wall-clock budget per child, including startup,
  and stops a child when its observed peak working set exceeds 1024 MiB. Larger
  PC cases in a family are skipped after the first PC limit; export tests continue.
  Memory polling can overshoot the threshold before termination.
- Extended runs give independent_12 and shared_20 a 90-second budget, retaining
  the same memory threshold. These clarify whether a pipeline timeout means
  failure to construct a PC or merely expensive repeated evaluation.
- `independent_k`: k independent Boolean atoms and k atom queries. Priors repeat
  0.20, 0.35, 0.50, 0.65.
- `shared_k`: four independent atoms A–D, queried individually and through AND,
  OR, and negation expressions. For k >= 4 there are exactly 16 feasible query
  tuples, although ordinary tuple flattening considers up to 2^k combinations.
- `repeated_k`: the same Bernoulli(0.25) variable queried k times. There are
  exactly two feasible tuples.
- `airlift`: the existing two airlift expressions combined into one tuple query:
  both deliveries, and cargo 42 arriving on path A. There are three feasible tuples.

## Export measurements

Times are milliseconds, excluding module startup. Timeout denotes the overall
20-second process budget, not an observed 20 seconds of internal export time.
JSON sizes are KiB, symbolic / tuple. The tuple outcome count is the number of
nonzero rows written, not the number of candidate tuples considered.

| Case | Symbolic ms | Tuple ms | BDD nodes | Nonzero tuple rows | JSON KiB (S / T) |
|---|---:|---:|---:|---:|---:|
| airlift | 56.9 | 56.7 | 13 | 3 | 1.43 / 0.20 |
| independent_4 | 37.1 | 34.4 | 44 | 16 | 3.50 / 1.07 |
| independent_8 | 75.7 | 77.4 | 764 | 256 | 58.95 / 23.20 |
| independent_10 | 97.4 | 68.2 | 3068 | 1024 | 240.29 / 103.96 |
| independent_12 | 167.6 | 145.3 | 12284 | 4096 | 971.46 / 459.39 |
| independent_14 | 455.5 | 562.3 | 49148 | 16384 | 3932.81 / 2009.53 |
| independent_16 | 1977.9 | 2740.7 | 196604 | 65536 | 15892.41 / 8723.94 |
| shared_4 | 41.2 | 37.3 | 44 | 16 | 3.50 / 1.07 |
| shared_8 | 44.4 | 79.0 | 91 | 16 | 6.70 / 1.38 |
| shared_12 | 93.9 | 85.1 | 150 | 16 | 10.78 / 1.73 |
| shared_16 | 68.3 | 1554.9 | 212 | 16 | 15.10 / 2.13 |
| shared_20 | 60.7 | timeout | 300 | — | 21.18 / — |
| repeated_4 | 70.4 | 64.1 | 8 | 2 | 0.69 / 0.14 |
| repeated_8 | 47.7 | 35.4 | 16 | 2 | 1.29 / 0.19 |
| repeated_12 | 56.2 | 51.3 | 24 | 2 | 1.91 / 0.24 |
| repeated_16 | 53.5 | 310.4 | 32 | 2 | 2.52 / 0.30 |
| repeated_20 | 61.8 | 8237.2 | 40 | 2 | 3.14 / 0.35 |
| repeated_40 | 116.1 | timeout | 80 | — | 6.23 / — |

The repeated_20 table is only 360 bytes and has two rows, but takes 8.24 seconds
to export, versus 61.8 ms for the symbolic representation. Dropping zero outcomes
at the end does not eliminate the intermediate enumeration cost.

In the extended shared_20 run, symbolic export took 56.4 ms with a 255 MiB peak
working set. Tuple inference crossed the memory threshold after 34.6 seconds;
the sampled peak was 1097 MiB, and the process was stopped before export completed.
The model still has only four random atoms and 16 feasible query tuples.

## Cirkit measurements

Each cell is symbolic / tuple. Build+compile excludes Python/Torch imports.
For independent_12, the table uses the successful 90-second extended profiles.

| Case | PC layers (S / T) | Build+compile ms (S / T) | Four-marginal batch ms (S / T) |
|---|---:|---:|---:|
| airlift | 97 / 8 | 8.4 / 2.0 | 21.26 / 2.39 |
| independent_8 | 1308 / 273 | 145.6 / 21.7 | 143.09 / 21.64 |
| independent_12 | 20524 / 4121 | 1978.0 / 384.2 | 2337.35 / 209.77 |
| shared_16 | 284 / 49 | 49.4 / 7.2 | 34.99 / 16.49 |
| repeated_20 | 86 / 43 | 8.8 / 7.0 | 28.83 / 22.55 |

All 33 completed PC profiles matched the independently calculated model
probabilities, including the complete query joint for cases with at most six
queries. The maximum normalization error was 4.49e-14. The airlift joint
for query tuples (00, 01, 10, 11) was
`[0.2778544, 0.1353705255936, 0, 0.5867750744064]` in both pipelines.

The main independent_12 symbolic PC profile hit its 20-second total budget.
The extended profile confirms that the PC does construct: about 1.98 seconds
for build+compile, with roughly 2.34 seconds per four-marginal batch. Five timed
batches plus warm-up, normalization, and process startup explain the earlier limit.
The independent_16 tuple PC profile also exceeded the main 20-second budget;
that does not mean its tuple export failed.

The PC comparison includes a representation difference: the current symbolic
converter retains latent primitive variables, while the table PC has only query
variables. No additional factoring, latent elimination, or compiler optimization
was added to either converter for this comparison.

## Interpretation

1. For a small exposed query interface, explicit tuple export is simpler and
   produces smaller, faster PCs. It is a reasonable choice for a fixed joint
   over a few atoms that many sequent trees reuse.
2. For many correlated or repeated queries, tuple enumeration becomes expensive
   even when the final table is tiny. The symbolic exporter avoids that explicit
   outcome table and remained small on these cases.
3. The current symbolic representation is not universally compact. It orders all
   primitive variables before all query variables. For independent queries this
   equality-constraint BDD grows exponentially too: 44 nodes at k=4, 764 at k=8,
   and 196,604 at k=16. This is a variable-ordering limitation of the current
   implementation, not a proof that every BDD ordering has this cost.
4. If many leaves use formulas over A,B,C,D, exporting the joint of those four
   atoms is preferable to making every leaf formula a separate tuple coordinate.
   The former has at most 16 outcomes and supports all conjunction-of-literals
   leaf requests over those atoms, including ratios for conditionals.

## Reproduction

Create separate checkouts of the two branches, then run from the parent project:

```powershell
python benchmarks/compare_query_exports.py --symbolic <symbolic-checkout> --tuple <tuple-checkout> --output docs/tuple_export_comparison.json
python benchmarks/compare_query_exports.py --symbolic <symbolic-checkout> --tuple <tuple-checkout> --output independent12.json --case independent_12 --timeout 90
python benchmarks/compare_query_exports.py --symbolic <symbolic-checkout> --tuple <tuple-checkout> --output shared20.json --case shared_20 --timeout 90
```

The benchmark JSON records exact source commits, per-trial measurements, resource
limits, and the temporary directory containing generated BLOG inputs and exports.
The archived JSON also includes the two extended runs under `supplementary`.
The parent project's `bdd_to_cirkit.py` consumes symbolic exports;
`tuple_to_cirkit.py` consumes tuple-table exports. Neither accepts arbitrary input formats.
