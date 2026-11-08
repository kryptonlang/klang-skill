---
name: krypton
description: >
  Write, build, debug, and review Krypton (.k/.ks/.htk), KryptScript,
  Objective-K, and native macOS applications using kcc/kr. Covers the
  macOS arm64 2.4.9 toolchain, AppKit callbacks, K-owned objects, native
  ABI bindings, imports, memory/ownership, app bundles, signing, testing,
  and platform boundaries. Use for Krypton projects, not generic Swift
  or Objective-C development. Pairs with caveman for terse output.
license: Apache-2.0
metadata:
  category: language
  language: krypton
  companion-skill: caveman
  macos-baseline: "2.4.9"
  verified-date: "2026-11-07"
---

# Krypton

Krypton, KryptScript, and Objective-K use the same self-hosted compiler.
Normal builds emit machine code, not C. Objective-K replaces Objective-C
source/compilation, not Apple's AppKit, Foundation, or libobjc runtime.

Verified baseline: **macOS arm64 2.4.9**. Published Linux x86_64 is 2.4.4,
Windows x86_64 is 2.3.0; editor VSIX is 2.4.8. These are separate versions,
not evidence of runtime/API parity. Recheck when targeting another revision.

Source: <https://github.com/t3m3d/krypton> · Site: <https://krypton-lang.org>

## Start Here

1. Identify the actual compiler and root before editing. `/usr/bin/kcc` is
   Apple's unrelated Kerberos tool. A version string alone does not establish
   which frontend, backend, or stdlib the driver will use.
2. Pin `KRYPTON_ROOT` to the intended checkout or installation. The raw macOS
   driver can otherwise prefer `~/Documents/GitHub/krypton` over an installed
   copy. Never silently compile against another project's uncommitted stdlib.
3. Read the reference for the work, not every file in this package:

| Task | Reference |
| --- | --- |
| Any macOS project: setup, imports, data, diagnostics, validation | [macos.md](references/macos.md) |
| Syntax, values, loops, functions, structs | [language.md](references/language.md) |
| CLI, scripts, multi-file projects, platform versions | [cli.md](references/cli.md) |
| Library selection and builtin contracts | [stdlib.md](references/stdlib.md) |
| Native UI and K-owned objects | [objective-k.md](references/objective-k.md) |
| AppKit controls, exact callback ABIs, lifetimes | [appkit-controls.md](references/appkit-controls.md) |
| New Apple bindings, native messages, graphics ABI | [macos-ffi.md](references/macos-ffi.md) |
| Bundles, signatures, notarization, release artifacts | [macos-release.md](references/macos-release.md) |
| Failure symptoms and older-release workarounds | [troubleshooting.md](references/troubleshooting.md) |

4. Compile and run the smallest relevant probe before integration. A function
   in a header/catalog is not proof its ABI is implemented or tested.
5. Keep source changes scoped. Do not scan a large compiler repo to answer an
   app question; start with the app imports, relevant module/header and tests.

## Compiler And Value Rules

- Use `just run { ... }` or `go run { ... }` for an executable. Function-only
  libraries need no entry block. Bare scripts require `kr` auto-wrapping.
- `emit` returns a value; `return` is an alias. No-result functions use
  `-> do`, not `-> void` or bare `void`.
- `print` is canonical output; `kp` remains a compatibility alias. `scan`
  reads a line; `get`/`getEcho` are key-input contracts, not file readers.
- Do not use keywords such as `callback`, `process`, `go`, `fn`, or `default`
  as bindings/parameters. Use `handlerBox`, `scanning`, or `fallback`.
- Values are **not all strings**: native integers, float boxes, buffers,
  function pointers, and Apple object handles coexist with text. Never apply
  text operations to a native pointer or persist that pointer as text.
- `+` can perform numeric addition on numeric-looking text. Build exact text
  using string fragments/builders, and convert integer values deliberately.
- Lists are legacy comma-delimited text, not lossless arrays. `split(list,i)`
  indexes that representation; it does not split text on an arbitrary delimiter.
- Text lengths/indices are bytes, not Unicode characters. Text is
  NUL-terminated; use buffers and `writeBytes` for embedded zero bytes.
- `sbToString` exposes builder storage. Do not retain that interior view across
  builder mutation or `gcCollect`. `okCopyText`/`okObjectText` make independent
  copies; keep copies rooted. This does not implement transitive/interior GC.
- Generic equality is unsafe for native Apple pointer identity. Use
  `okSameHandle(a,b)`. Do not `toInt`/stringify `NSNotFound` or arbitrary 64-bit
  pointer-sized values; guard native bounds before converting them.
- Use `funcptr(namedFunction)` for callbacks, not closures/captured locals.
  General closures remain unsupported on this macOS baseline.
- macOS 2.4.9 fixes padding, signed conversion, URL character conversion,
  checked build outputs, and `-r`/`-e` status/streams. Sorting, lossless splitting,
  imported Objective-K declarations and richer diagnostics remain separate work.

## Working Program

```krypton
just run {
    print("Hello, Krypton!")
}
```

With a chosen checkout root:

```sh
export KRYPTON_ROOT="/absolute/path/to/krypton"
KCC="$KRYPTON_ROOT/bootstrap/kcc_driver_macos_aarch64"
"$KCC" --version
"$KCC" hello.ks -o /tmp/krypton-hello
/tmp/krypton-hello
```

`kcc -r file.ks [args...]` compiles/runs temporarily; on macOS 2.4.9 it
preserves literal/empty arguments and child exit status. Explicit `-o` is still
useful to separate compilation from execution. Never treat a stale executable
left after a failed compile as the newly built program.

## Native Applications

Use `import "k:okui"` as the app facade. Use `k:objk_runtime_macos` for
K-owned models and `k:objc` only when a verified low-level binding is needed.
Keep app code in Krypton: no `.m`/`.mm`, generated C, Clang or C fallback.

Start from [assets/macos/app.ks](assets/macos/app.ks): a live field, action,
semantic system colors, resizing and native Quit/Edit menus. It is a starter,
not a complete document framework or session manager. [objective-k.md](references/objective-k.md)
covers model objects, tables and native data sources.

Critical callback signatures:

| Registration | Named function receives | Result |
| --- | --- | --- |
| `okClick` / `okMenuAction` | `(self,command,sender)` | Usually ignored |
| `okFieldOnChange` | `(field)` | Ignored |
| `okOnClick` / `okOnDoubleClick` | `(table)` | Ignored |
| `okOnKeyDown` | `(table,event)` | Integer 1 consumes; 0 keeps native fallback |
| `okWindowShouldClose` | `(win)` | Integer 1 permits; 0 vetoes |
| `okWindowOnClose` | `(win)` | Notification; not Quit |
| `okAppOnOpenFile` | `(app,pathText)` | Integer 1 handled; 0 rejected |
| `okAppOnReopen` | `(app,visible)` | Integer 1 allows default handling |
| K-owned methods | `(runtime,self,...)` | Declared runtime contract |

Keep AppKit work on the main thread and callbacks short. Do not replace foreign
delegates or release an owner inside its callback. Borrowed callback arguments
need explicit lifetime handling. Native retain/release and K-owned retain/release
are different systems; native objects do not become arena objects.

Closing a window need not exit the app. Always provide Quit. Menus using native
selectors are macOS-specific. APIs named `ok*` are not automatically portable:
confirm the Windows/Linux adapter actually implements them before promising it.

## Verify Before Claiming Success

The package includes tested, copyable Krypton probes and a macOS-only runner:

```sh
KRYPTON_ROOT="/absolute/path/to/krypton" \
  ./krypton/scripts/check-macos.sh
```

Run from the skill repository, or use the runner's absolute path. It compiles
and executes data, model, process and Foundation probes, compile-checks the GUI,
and does not install software, sign releases, launch a GUI or contact a network.
Optional `--bundle` checks bundling when the chosen root has the helper source.

Validate actual interaction separately: type/edit/paste, click, resize, select
rows, test native arrow fallback and Quit as relevant. Report compile checks,
unit tests, real UI checks and packaging checks separately, including skips.
Never infer accessibility, IME, sandbox, Finder routing, async work, security
review or platform parity from a window merely opening.

## Communication

Use the companion caveman skill when requested/configured; its fallback is
[caveman-fallback.md](references/caveman-fallback.md). A user requesting
`caveman-ultra` controls response length, not implementation or verification.
Never compress code, paths, exact errors, security warnings or required steps.
