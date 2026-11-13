# pnpm transitive deduplication reproduction

Two registry packages depend on overlapping ranges of the same child:

```text
repro-narrow@1.0.0 → repro-child ~1.0.0
repro-wide@1.0.0   → repro-child ^1.0.0
```

The registry offers child versions **1.0.0** and **1.1.0**. Only **1.0.0** satisfies both ranges. This checks whether `autoDedupe: true` converges both transitive dependencies on that version.

## Run

Requires Bash, pnpm, and pnpr on `PATH`. Tested with pnpm **12.18.0** and **12.20.0**, pnpr **0.1.0-alpha.19**, and Node **24.22.0** on macOS arm64. Native pnpr binaries are available in its [release](https://github.com/pnpm/pnpm/releases/tag/pnpr%400.1.0-alpha.19).

```sh
./repro.sh
```

To select binaries or another loopback port:

```sh
PNPM_BIN=/path/to/pnpm PNPR_BIN=/path/to/pnpr PNPR_PORT=17677 ./repro.sh
```

The script starts a temporary local pnpr registry, publishes the four fixture versions directly from their tracked directories, and runs `pnpm install --lockfile-only` followed by `pnpm dedupe --check`. pnpr's resolver is disabled; pnpm resolves the dependencies locally. No upstream registry or credentials are used. `minimumReleaseAge: 0` admits the freshly seeded versions. Fixture files stay in place; the registry and consumer project remain temporary and are cleaned up on exit.

## Result

On both tested pnpm versions, dedupe check exits **0**, then the independent assertion exits **1**:

```text
Expected child versions: 1.0.0
Actual child versions:
1.0.0
1.1.0
```

The assertion passes if only 1.0.0 remains. There are no peers, overrides, workspace/file dependency specifiers, or pre-existing lockfile.
