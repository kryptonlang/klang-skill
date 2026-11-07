---
name: krypton
description: >
  Use when writing, running, debugging, reviewing, or explaining Krypton
  (.k/.ks) programs, KryptScript, the kcc/kr CLI, the Krypton stdlib, or
  Objective-K native macOS/Windows apps. Covers syntax, the string-value
  model, native builds, imports, common errors, 2.4.x behavior, the
  k:okui app facade, AppKit tables and events, and the K-owned object
  runtime. Pairs with the caveman skill for terse output.
license: Apache-2.0
metadata:
  category: language
  language: krypton
  companion-skill: caveman
---

# Krypton

Krypton is a self-hosting language with string-oriented values and native
guarded integers, float boxes, and opaque handles. It
compiles directly to native ELF, PE, or Mach-O. No C compiler is involved
for normal builds. Current release line: **2.4.x** (2.4.9 on macOS arm64,
2.4.4 on Linux x86_64, 2.3.0 on Windows; editor extension remains 2.4.8).

Source: <https://github.com/t3m3d/krypton> · Docs: <https://krypton-lang.org>

## Pair with caveman

This skill is designed to run together with the `caveman` skill.

1. At the start of the turn, load `caveman` with your agent's skill mechanism:
   OpenCode/Freebuff `skill` tool, Claude Code skill tool, Codex `$caveman`,
   or the installed `caveman/SKILL.md`.
2. If `caveman` is not installed, follow `references/caveman-fallback.md`.
3. Unless the user says "normal mode" or "stop caveman", keep caveman style
   for prose. Never compress code, commands, paths, API names, or exact error
   strings.
4. Drop caveman temporarily for security warnings, destructive operations,
   and multi-step instructions where fragment order could mislead.

The two skills are independent. Do not copy caveman rules into Krypton code
or comments.

## First moves

1. Resolve the compiler path and inspect its version text. On macOS, prefer
   `/usr/local/bin/kcc` or the checkout driver: `/usr/bin/kcc` is Apple's
   unrelated Kerberos tool. Exit status alone does not distinguish them.
2. If working in a source checkout, set `KRYPTON_ROOT` to that checkout.
3. Read only the reference needed for the task:
   - Language/syntax: `references/language.md`
   - CLI/build/run: `references/cli.md`
   - Builtins and modules: `references/stdlib.md`
   - Native apps and Objective-K: `references/objective-k.md`
   - Current macOS controls/events/lifecycle APIs: `references/appkit-controls.md`
   - Failures and version bugs: `references/troubleshooting.md`
4. Write the smallest program that proves the behavior, then compile and run
   it before editing more code.
5. Prefer known-good core builtins. Test unusual stdlib modules before relying
   on them.

## Non-negotiable rules

- **Do not confuse text with native values.** User-facing APIs are often
  string-oriented, but native backends also carry guarded integers, float
  boxes, code pointers and object handles. Native handles are not text.
- **`emit` returns a value.** `return` is an alias. Use `-> do` for no result;
  `-> void` is an error.
- **Entry point is `just run { ... }`** (or `go run { ... }`). A bare `.ks`
  script is auto-wrapped only by `kr`, not by `kcc`.
- **Use `kcc file -o out` when exit status matters.** On 2.4.8, `kcc -r`
  can print a compile error and still exit 0.
- **Lists are comma-separated strings.** `"a,b,c"` plus `split`, `count`,
  `range`, and `for x in list`.
- **Struct names start uppercase.** Fields are dynamic name/value pairs.
- **Imports use prefixes:** `import "k:map"` for stdlib, or a relative path
  such as `import "util.k"`.
- **Do not assume closures work.** On 2.4.8, documented lambdas and
  `cb: closure` parameters fail with `unknown function 'cb'`/`'f'`.
  Use named functions and explicit loops for portable code.
- **Do not trust `true == (5 > 3)`.** `true` is `"true"`; comparisons return
  `"1"`/`"0"`. Use `isTruthy` when only truthiness matters.
- **Avoid numeric tokens in chained `+` when you need text.** `"" + 1 + "0"`
  becomes numeric `1`, not `"10"`. Use `sbAppend` for guaranteed text.
- **Objective-K app code uses `import "k:okui"`.** It is the cross-platform
  facade. `k:objk` is the macOS surface; `k:objkwin` is the Windows surface.
  Do not import the backend module directly in app code.
- **Native handles are opaque.** Never stringify an `ok*` handle, store it in a
  K-owned integer field, or persist it across platform boundaries.
- **UI callbacks are `funcptr(namedFunction)`.** They are not closures and
  cannot capture locals. Match the exact callback signature.
- **Do not name bindings/parameters `callback`, `process`, `go`, `fn` or
  `default`.** These are keywords. The development frontend rejects them;
  older frontends can silently substitute empty text. Use `handlerBox`,
  `scanning` or `fallback`. Rebuild the frontend/driver, not only stdlib.
- **2.4.8 ships `k:okui`, `k:objk`, and `k:objk_runtime_macos`.** Checkout-only
  additions include table model/selection hooks, `okOnKeyDown`, live-field
  changes, segmented controls, columns, independent table actions, menu/image/
  frame helpers, window-close/app open-file/reopen hooks, and
  `k:objk_process_macos`. Do not promise those on
  2.4.8; use the checkout driver or gate the feature.

## Minimal working program

```krypton
// hello.ks
just run {
    print("Hello, Krypton!")
}
```

```sh
kcc -r hello.ks
```

Bare KryptScript, with no entry block:

```krypton
// script.ks
print("Hello from kr")
```

```sh
kr script.ks
```

## Workflow

1. Put experiments in a temporary `.ks` file with `just run` so both `kcc`
   and `kr` can run it.
2. Compile with an explicit output when checking for errors:
   `kcc /tmp/probe.ks -o /tmp/probe && /tmp/probe`.
3. For a quick run: `kcc -r /tmp/probe.ks`. Inspect stderr anyway.
4. If output stops before an expected print, bisect by adding prints around
   the suspect call. A crashing stdlib call may terminate silently.
5. Delete generated binaries and probe files when done.

## Objective-K quick start (macOS first)

Objective-K is Krypton's native app layer. Same compiler, same syntax. It is
not Objective-C: no `.m`, no generated C, no Clang at build time. Apps call
AppKit/Foundation/libobjc through the compiler's native ABI.

Three layers:

| Layer | Import | Role |
|---|---|---|
| App facade | `k:okui` | Windows, controls, menus, events. Preferred app surface |
| K-owned runtime | `k:objk_runtime_macos` | Classes, fields, ownership, cleanup. No Apple frameworks |
| Platform adapter | `k:choc_macos` | AppKit/Foundation/libobjc. Reached through `k:okui` |

Minimal app:

```krypton
import "k:okui"

func showText(field) {
    let label = okGet(field, "demo.label")
    okSetText(label, okText(field))
    emit 0
}

just run {
    let pool = okAutoreleasePool()
    let app = okApp()
    let win = okWindow(app, "Objective-K", 460, 160)
    let bar = okMenuBar(app)
    let menu = okMenuAdd(bar, "Objective-K")
    okMenuSelector(menu, "Quit", "q", "terminate:")
    let field = okField(win, 20, 92, 420, 28)
    let label = okLabel(win, "", 20, 44, 420, 28)
    okSet(field, "demo.label", label)
    if okFieldOnChange(field, funcptr(showText)) == "0" {
        printErr("Cannot register handler\n")
        exit("1")
    }
    okShow(win, app)
    okMakeFirstResponder(win, field)
    okRun(app)
    okDrainPool(pool)
}
```

Build from a macOS arm64 checkout:

```sh
export KRYPTON_ROOT="$PWD"
./bootstrap/kcc_driver_macos_aarch64 app.ks -o /tmp/app
/tmp/app
```

Use the explicit driver path. Apple ships an unrelated `kcc` (Kerberos).

2.4.8 includes `k:okui`, `k:objk`, and the K-owned runtime. The live-field
handler below needs a checkout newer than 2.4.8. On 2.4.8, use target/action
callbacks (`okClick`) instead. Never advertise checkout-only APIs as released.

Rules that prevent most Objective-K bugs:

- One `k:okui` style per file. Mixing `ok*` and `okui_core` words is legal but
  confusing.
- Callbacks take `(self, command, sender)` for actions, `(field)` for live
  field changes, `(table, event)` for key hooks. Return `"1"`/`1` to consume
  when the contract says so.
- Register `doKCleanup` before `doKRegister`.
- Balance `okKRetain`/`doKRelease`. Strong cycles are not collected.
- `okRun` blocks on the native event loop. Quit through the menu or `okQuit`.
- Compiling makes an executable, not a signed `.app` bundle.

Windows uses the same `k:okui` words through `k:objkwin` + `k:choc` (Win32).
Controls and callbacks mostly port. These do not:

- `k:objk_runtime_macos` and `k:objk_process_macos` — macOS only.
- `okMenuSelector` AppKit selector names — Windows stubs.
- `okClass`/`okMethod`/`okRegister`/`okNew` — macOS runtime class synthesis.
- NSIndexSet selection, NSArray handles, `okMultiSelect`, key hooks currently
  have no Windows equivalent.

Use `okMenuAction` instead of `okMenuSelector` for portable menus. Guard
platform-specific calls before shipping a cross-platform app.

Full API contracts, table and selection details, ownership rules, and Windows
differences: `references/objective-k.md`.

## Syntax at a glance

```krypton
import "k:map"

struct Point {
    let x
    let y
}

func add(a, b) -> int {
    emit toInt(a) + toInt(b) + ""
}

func logLine(msg) -> do {
    print(msg)
}

just run {
    let name = "Krypton"
    let p = Point { x: "3", y: "4" }
    let nums = "1,2,3"

    print(`{name}: {p.x},{p.y}`)
    print("sum=" + add("2", "3"))

    for n in nums {
        if toInt(n) % 2 == 0 {
            print("even " + n)
        } else {
            print("odd " + n)
        }
    }

    let i = 0
    while i < 2 {
        logLine("tick " + i)
        i += 1
    }

    match name {
        "Krypton" { print("match") }
        else      { print("other") }
    }

    try {
        throw "boom"
    } catch e {
        print("caught: " + e)
    }

    let m = mapNew()
    m = mapSet(m, "k", "v")
    print("map=" + mapGet(m, "k"))
}
```

More detail: `references/language.md`.

## Common builtins

| Area | Calls |
|---|---|
| Output | `print(s)`, `kp(s)`, `printErr(s)` |
| Strings | `len`, `substring`, `startsWith`, `endsWith`, `contains`, `indexOf`, `replace`, `trim`, `toUpper`, `toLower`, `s[i]` |
| Numbers | `toInt`, `abs`, `pow`, `range`, `sqrt`, `min`, `max` |
| Lists | `split`, `count`, `length`, `first`, `last`, `sort`, `slice` |
| I/O | `readFile`, `writeFile`, `readLine`, `scan`, `shellRun`, `exec` |
| Args | `arg(n)`, `argCount()` |
| Structs | `structNew`, `setField`, `getField`, `hasField`, `structFields` |
| Strings | `sbNew`, `sbAppend`, `sbToString` |
| Lines | `lineCount`, `getLine` |
| Truth | `isTruthy`, `toStr` |

This table lists names, not platform guarantees. In particular, macOS `sort`
and padding have known defects; `split` is legacy list indexing, not string
splitting. Check `references/troubleshooting.md` and prove behavior before use.

## Stdlib imports

Use `import "k:<name>"` for `stdlib/<name>.k`.

Reliable on 2.4.8 for common work: `k:map`, `k:dict`, `k:set`, `k:result`,
`k:option`, `k:list`, `k:string`, `k:path`, `k:fsx`, `k:json_emit`,
`k:csv`, `k:collections`, `k:math_utils`, `k:args`, `k:env`, `k:ansi`.

Test before relying on: `k:sort`, padding, `k:fp` and any closure-based helper (broken with
2.4.8 closures), `k:time`, `k:random`, `k:url`, `k:datetime`, and
platform-specific modules such as `k:cocoa`, `k:okui`, `k:winsock`.

Objective-K modules:

| Import | Platform | Notes |
|---|---|---|
| `k:okui` | macOS + Windows | App facade. Use this in app code |
| `k:objk` | macOS | Low-level `ok*` calls; newer APIs need a checkout |
| `k:objkwin` | Windows | Windows `ok*` facade over `k:choc` |
| `k:objk_runtime_macos` | macOS | K-owned classes, fields, ownership, cleanup |
| `k:objk_process_macos` | macOS | Synchronous Foundation process capture |
| `k:choc_macos` / `k:choc` | macOS / Windows | Platform adapters. Usually indirect |

Full catalog and APIs: `references/stdlib.md`.

## Failure quick guide

| Symptom | Likely fix |
|---|---|
| `cannot find install root` | `export KRYPTON_ROOT="$PWD"` in a source checkout |
| `no __main__ function found in IR` | Add `just run { ... }`, or run bare `.ks` with `kr` |
| `unknown function 'cb'` / `'f'` | Closures unsupported on 2.4.8; use named functions/loops |
| `unknown function 'GetTickCount64'` | Windows-only module on macOS; replace it |
| `unknown function 'X'` | Missing import, typo, or version-specific API |
| Compile error but exit 0 | Use `kcc file -o out` and check its exit code |
| Program prints nothing | A called stdlib function crashed; bisect with prints |
| `-> void` rejected | Use `-> do` |
| Numeric text collapses | Use `sbAppend`, not chained `+` |
| `unknown function 'okFieldOnChange'` | Published 2.4.8 lacks the API; use the checkout driver |
| `Objective-K:` at runtime | Bad handle, unknown method, or wrong argument count |
| Window opens, controls dead | Callback signature or `funcptr` registration is wrong |
| App exits after last control | `okRun` not called, or `okShow` before setup |
| Native crash in a callback | Check signature, borrowed object lifetime, native pointers, and unsupported captures |
| Windows app fails on `k:objk_runtime_macos` | Import is macOS-only; branch or guard |

More: `references/troubleshooting.md`.
More Objective-K: `references/objective-k.md`.

## References

- `references/language.md` — syntax, values, control flow, structs, imports
- `references/cli.md` — `kcc`, `kr`, flags, project layout, platforms
- `references/stdlib.md` — builtins and stdlib module catalog
- `references/objective-k.md` — Objective-K, `k:okui`, AppKit, ownership, Windows
- `references/appkit-controls.md` — current macOS columns, actions, images, menus, frames
- `references/troubleshooting.md` — error messages and 2.4.x gotchas
- `references/caveman-fallback.md` — terse style when caveman is unavailable
