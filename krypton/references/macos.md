# macOS Workflows (2.4.9)

## Contents

- Choose a toolchain/root
- Project/import layout
- Data, processes and memory
- Native app workflow
- Diagnostics and regression gates
- Boundaries and security

## Choose One Toolchain

Supported release host: macOS Apple Silicon (`Darwin`, `arm64`), not Intel
macOS or Rosetta merely because a binary has `x64` in its name. Do not run the
Linux ELF compiler on a Mac. Desktop builds and iOS targets are different.

```sh
uname -s
uname -m
type -a kcc
```

Choose a complete root and driver explicitly:

```sh
# Source checkout
export KRYPTON_ROOT="/absolute/path/to/krypton"
KCC="$KRYPTON_ROOT/bootstrap/kcc_driver_macos_aarch64"

# Signed pkg installation: use these instead, not both roots
# export KRYPTON_ROOT=/usr/local/krypton
# KCC="$KRYPTON_ROOT/bootstrap/kcc_driver_macos_aarch64"

# Homebrew installation: use these instead
# export KRYPTON_ROOT="$(brew --prefix krypton)/libexec"
# KCC="$KRYPTON_ROOT/bootstrap/kcc_driver_macos_aarch64"

"$KCC" --version
```

Expect `kcc version 2.4.9` on this baseline. `/usr/bin/kcc` is a Kerberos
utility. PATH, shell command caches and duplicate Homebrew/pkg installs can
select another program; inspect before unlinking or removing anything.

The 2.4.9 raw driver searches `KRYPTON_ROOT`, then a conventional home checkout,
then `/usr/local/krypton`. Pin the root even when testing a copied installation.
A Homebrew wrapper normally pins its libexec root. Setting `KRYPTON_ROOT` does
not rebuild the driver binary you invoked; keep driver, frontend, backend and
stdlib matched. Do not silently choose an unrelated user's development tree.

Useful source paths, relative to the selected Krypton checkout:

| Path | Responsibility |
| --- | --- |
| `kcc.ks` | Driver CLI, root discovery, output staging, run/eval |
| `compiler/compile.k` | Frontend: syntax/imports to IR |
| `compiler/macos_arm64/kcc-arm64` | Compiled frontend |
| `compiler/macos_arm64/macho_arm64_self.k` | Native ARM64 Mach-O/ABI emitter |
| `compiler/macos_arm64/macho_host` | Executable backend |
| `bootstrap/*macos_aarch64` | Matching bootstrap frontend/driver/backend seeds |
| `stdlib/objk.k`, `choc_macos.k`, `okui_core.k` | Native facade and adapters |
| `stdlib/objk_runtime_macos.k` | Separate K-owned object arena |
| `headers/*.krh` | Foreign declarations, not C headers |

`./build.sh` copies prebuilt seeds and smoke-tests; it is not a full frontend
self-host rebuild. Root `Makefile`/old comments may still mention removed C
flows. Do not use `--c`, `--gcc`, `--llvm`, generated C or Clang as a workaround.
Editing an emitter can trigger an expensive native self-host rebuild. Preserve
working seeds; do not overwrite release artifacts during app development.

## Projects And Imports

```text
project/
  app.ks
  lib/model.k
```

```krypton
// lib/model.k
module model
func modelTitle() { emit "My App" }
```

```krypton
// app.ks
import "lib/model.k"
import "k:okui"
just run { print(modelTitle()) }
```

`k:name` resolves to `stdlib/name.k`; `head:name` resolves to
`headers/name.krh`. Relative imports resolve against their importing file.
Keep reusable modules without entry blocks. One executable entry file owns
`just run`/`go run`. Module declarations are useful, not package namespaces or
permission to duplicate every symbol. Use distinct helper names: imports can
expose functions in a flat lookup space.

Imported globals initialize before entry work within the frontend's import
walker's limits. Explicitly import dependencies used by the entry file when
nested imports are not discovered. Never copy an entire stdlib into an app or
build a symlink overlay to hide a missing published module. Put reusable
bindings in Krypton and app-specific formats/storage policy in the app; verify
both roots and licenses when moving code between repositories.

Compiler `objk object`/`objk protocol` declarations currently belong in the
executable source. Use direct K-owned runtime functions inside helper modules;
do not promise imported declaration initialization works.

## Data, Processes And Memory

- Text uses byte indices and NUL termination. Ordinary concatenation is not
  binary-safe. `writeBytes(path,hex)` uses `xHH`-encoded bytes; the example
  `examples/wasm/hello_wasm.htk` demonstrates this without a C compiler.
- `split`/`count` operate on comma lists. They cannot preserve arbitrary names
  containing commas, empty records or embedded separators. Use an appropriate
  structured representation and test its parser; do not invent `splitStr`.
- `trim` does not imply Unicode/CR/LF stripping. Use an explicit whitespace
  loop when shell output must lose trailing newlines.
- `padLeft`/`padRight` take exactly three arguments, operate on byte width,
  preserve over-width input, and stop on empty padding. Declared module/user
  implementations take precedence on macOS 2.4.9. `sort` remains unverified/
  ineffective in relevant cases; a round trip is not proof of ordering.
- Native integer/pointer discrimination is not a fully tagged 64-bit model.
  Signed conversion was fixed, not arbitrary pointer-sized integer support.
  Keep `NSNotFound`/large native indexes out of text conversion and verify range
  guards before indexing. K-owned integer fields have their own narrower range.
- `exec(cmd)` captures stdout. `shellRun(cmd)` inherits output and returns exit
  status text; it does not capture output. Never swap these contracts.
- [process.ks](../assets/macos/process.ks) uses `okRunArgvCaptured` for literal
  argument arrays. It returns `<status>\n<combined UTF-8 output>`; launch failure
  is `-1`, invalid UTF-8 is `-2`, signal termination is `128 + signal`.
- Capture is synchronous and unbounded. It is not a job queue, async API,
  streaming logger, timeout/cancellation API or binary-output transport. Do not
  call it for long work in a GUI callback.
- Borrowed native UTF-8 and builder views need copying before their owner
  changes/drains. `okCopyText`/`okObjectText` snapshots must remain rooted in
  locals/globals across collection. No claim of general transitive/interior GC.
- Native `retain`/`release`, autorelease pools and K-owned `doKOwn`/`doKRelease`
  are different ownership systems. Never exchange their handles.

Do not build a shell command by concatenating an untrusted path/password.
Prefer the argv capture API for subprocesses. `k:sh.q` is only a double-quote
wrapper on this baseline, not a general shell-escaping guarantee. The driver's
2.4.9 `-r` argument fix does not make arbitrary `exec` strings safe.

## Native App Workflow

1. Read [objective-k.md](objective-k.md) and [appkit-controls.md](appkit-controls.md).
2. Copy [app.ks](../assets/macos/app.ks) as a starting point; compile with an
   explicit output before launching. It includes Quit and Edit menus.
3. Build UI on the main thread, under an autorelease pool. Associate state with
   native controls using retained native objects, not stringified pointers.
4. Use semantic colors (`okSystemText`, `okSystemTextBg`, etc.) and test both
   appearances. Do not override system appearance unless requested. Text views
   may need both current and insertion/typing colors; verify actual typed text.
5. AppKit view coordinates use native points and usually a bottom-left origin;
   do not assume browser CSS coordinates. `okAutoresizing` uses native masks.
   `okTextView`/`okTable` return document views: resize/hide the enclosing scroll
   container with `okScrollFrame`/`okScrollHidden`.
6. A real table needs its data source methods and live model, not just columns.
   Selection is NSIndexSet. Clear/remap stale selection after filtering; return
   0 from unhandled key callbacks to keep native navigation.
7. Close, Quit and Dock reopen are separate. Save on Quit separately from close
   notifications. Native document routing needs bundle metadata, not just a
   delegate callback. See [macos-release.md](macos-release.md) before bundling.
8. Test actual interaction and duplicate instances, not only class method calls.

## Diagnostics And Tests

Capture both streams and status. `-o` failures preserve an earlier executable;
use a fresh temporary path or only execute after a successful compile.
Diagnostics identify files and unresolved functions, but full source-line/
excerpt/debug mapping is not implemented. Never invent a `--check`/formatter
flag or promise compiler-checked callback signatures.

From the chosen source checkout, the release gates are:

```sh
"$KCC" -r scripts/check_macos_native.ks
"$KCC" -r scripts/check_macos_driver.ks
"$KCC" -r scripts/check_objk_runtime_macos.ks
```

Recorded 2.4.9 gates: 71 native pass / 8 named skips; 19 driver checks; 109
Objective-K checks. These counts describe a revision, not a future guarantee.
Some AppKit geometry tests require desktop access. `--gui` adds a window smoke
path to the Objective-K checker; inspect the target script before using flags.
Do not run the old permissive `build.sh test` in place of the strict native gate.

This skill's [check-macos.sh](../scripts/check-macos.sh) works with a selected
checkout **or unpacked release root**, with no app installation or network use.
For UI work, separately test live typing, selection, resize, appearance and Quit.
Do not delete another agent's output, run live deploys or rewrite signed bundles
to make a smoke test green.

## Security And Boundaries

Use system cryptography, secure random sources and secret-storage APIs where
actually bound/tested. `k:crypto` is a Windows CNG wrapper, not a portable macOS
crypto package. Headers may declare CommonCrypto calls whose ABI/arity is not
supported by the backend; declaration presence alone is insufficient. Never
promote prototype vault formats/KDFs or a round-trip test as security review.
Use known-answer, malformed-input, wrong-key and authenticated-metadata tests.

Keep credentials out of source, CLI argument logs, screenshots and test output.
Use synthetic test data, not a user's real vault. Do not change format/KDF policy
or re-encrypt stored data during a library move without an explicit migration.

iOS simulator/device targets need separate SDK, signing and runtime checks.
Neither their presence in `--target` nor a macOS GUI passing proves iOS,
Windows, Linux, BSD, App Store sandbox or cross-platform feature parity.
