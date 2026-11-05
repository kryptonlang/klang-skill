# Krypton troubleshooting

## Fast triage

1. Reproduce with a tiny file.
2. Compile with an explicit output: `kcc probe.ks -o /tmp/probe`.
3. Check the exit code and both output streams.
4. Add prints before and after the suspect call.
5. If a stdlib call is suspect, remove it and re-run.
6. Check `kcc --version`; behavior differs between releases.

## Compiler errors

### `cannot find install root (set KRYPTON_ROOT)`

The driver cannot resolve `k:` imports.

```bash
export KRYPTON_ROOT="$PWD"       # source checkout
kcc hello.ks -o /tmp/hello
```

For an installed build, confirm the install is complete and `kcc --version`
works.

### `no __main__ function found in IR`

`kcc` did not find an entry block.

- Add `just run { ... }` (or `go run { ... }`).
- Or run the bare `.ks` with `kr file.ks`.

`kr` auto-wraps bare statements; `kcc` does not.

### `unknown function 'cb' called from '...'`

A function typed `cb: closure` is being called. The 2.4.8 compiler does not
lower this correctly.

- Replace the higher-order helper with a named function plus an explicit
  loop.
- Avoid `k:fp` and any helper that takes a lambda.
- Re-test on a newer compiler before using closures.

### `unknown function 'f' called from '__main__'`

A lambda stored in a local is being called. Same closure limitation as above.

```krypton
// Fails on 2.4.8
let f = func(x) { emit x * 2 }
print(f(5))
```

Use a named function:

```krypton
func double(x) { emit toInt(x) * 2 }
print(double(5))
```

### `unknown function 'GetTickCount64' called from 'timek'`

`k:time` reached a Windows-only implementation on macOS. Replace it with
`k:datetime`, `k:clock`-style code, or platform-specific logic.

### `unknown function 'X'`

Usually one of:

- Missing `import "k:x"`.
- Typo in the function name.
- The function exists in a newer/older release.
- The function is platform-specific.

Check the module exports:

```bash
grep -E '^(export )?func ' "$KRYPTON_ROOT/stdlib/<name>.k"
```

### `-> void` rejected

Use `-> do` for a no-result function.

```krypton
func logLine(msg) -> do {
    print(msg)
}
```

### Compile error but exit status is 0

On 2.4.8, `kcc -r` may return `0` after a codegen error. Use:

```bash
kcc probe.ks -o /tmp/probe && /tmp/probe
```

Inspect stderr for lines beginning with the backend name, for example
`macho_arm64_self:`, `elf:`, or `x64:`.

### `macho_arm64_self: wrote ...` but nothing runs

That line is success output. If the program produced no output, the failure
is at runtime. Add prints and bisect.

## Runtime failures

### Program stops with no error message

A called stdlib function may have crashed the process. Common 2.4.8 suspects:

- `k:random.randomString`
- `k:url.urlEncode`
- closure-based helpers

Bisect:

```krypton
just run {
    print("before")
    // suspected call here
    print("after")
}
```

If `before` prints and `after` does not, the suspect call killed the process.

### Numeric text collapses

`+` performs numeric addition whenever both operands look numeric.

```krypton
print("" + 1 + "0")     // 1, not 10
```

Use a StringBuilder:

```krypton
let sb = sbNew()
sb = sbAppend(sb, "1")
sb = sbAppend(sb, "0")
print(sbToString(sb))
```

### `true == (5 > 3)` is false

`true` is the string `"true"`. Comparisons return `"1"` / `"0"`.

Use:

```krypton
if isTruthy(true) && isTruthy(5 > 3) { ... }
```

Or normalize with `k:booleans`.

### Struct field update does not stick

`setField` is functional on native backends. Assign the result:

```krypton
cfg = setField(cfg, "debug", "1")
```

The same applies to maps: `m = mapSet(m, "k", "v")`.

### `for` does not iterate characters

`for x in "abc"` splits on commas, not bytes. Use an index:

```krypton
let i = 0
while i < len(s) {
    print(s[i])
    i += 1
}
```

For lines, use `lineCount` and `getLine`:

```krypton
let i = 0
while i < lineCount(text) {
    print(getLine(text, i))
    i += 1
}
```

### Integers above 1 GiB misbehave

Native backends store small integers directly and use the same value range
for pointers. Avoid values at or above `0x40000000` unless using the 64-bit
helpers.

## Import problems

### Stdlib import not found

- `import "k:map"` resolves to `<KRYPTON_ROOT>/stdlib/map.k`.
- Do not write `import "k:map.k"`.
- Set `KRYPTON_ROOT` in a source checkout.
- Confirm the file exists: `ls "$KRYPTON_ROOT/stdlib"`.

### Relative import not found

Relative imports resolve against the importing file:

```krypton
import "lib/util.k"
import "../shared/log.k"
```

Use the exact path and include the `.k` extension for relative imports.

### Multi-file project warnings

Give every file the same `module` name and put `just run` in `run.k`.
Single-file scripts without `module` are exempt.

## Objective-K failures

### `unknown function 'okFieldOnChange'` or another `ok*` name

The published compiler/stdlib is older than the API. Check `kcc --version`.
The newer AppKit table, selection, key-hook, live-field, and K-owned runtime
APIs need the source checkout:

```sh
export KRYPTON_ROOT="$PWD"
./bootstrap/kcc_driver_macos_aarch64 app.ks -o /tmp/app
```

Confirm the symbol exists in the checkout:

```sh
grep -E '^(export )?func ' "$KRYPTON_ROOT/stdlib/okui.k"
grep -E '^(export )?func ' "$KRYPTON_ROOT/stdlib/objk.k"
```

### App compiles but no window appears

- Call `okShow(win, app)`, then `okRun(app)`. `okRun` blocks.
- Missing `okApp()` or `okWindow(...)` leaves no app object.
- Closing the window is not process termination on macOS; quit through the
  app menu or `okQuit`.

### Controls render but never react

- Registration used a lambda or captured local. Use
  `okClick(button, funcptr(namedHandler))`.
- Handler signature is wrong. Actions are `(self, command, sender)`.
  Live fields are `(field)`. Key hooks are `(table, event)`.
- The handler returns early before doing work, or returns `0` where the
  contract needs `1` to consume the event.

### `Objective-K:` diagnostic at runtime

The K-owned runtime rejected a handle, field, method, or argument count.

- Do not use a handle after `doKRelease`.
- Do not mix handles from different runtimes.
- Dispatch with the matching arity: `okKSend` for zero user args,
  `okKSend1` for one, `okKSend2` for two.
- Register methods and cleanup hooks before `doKRegister`.
- Keep the runtime arena value reachable for every live handle.

### Native crash inside a callback

- Callback used a closure or captured a local. `funcptr` takes named functions
  only.
- Callback kept an event or native handle past callback scope.
- Callback blocked the main thread on long work.

### Table selection is empty or stale

Selection values are native index-set handles, not comma text. Use
`okSelection(table)`, `okSelectionCount`, and `okSelectionAt`. After changing
the model, clear or remap selection before `okReload`.

### Windows build fails on an Objective-K import

- `k:objk_runtime_macos` and `k:objk_process_macos` are macOS only.
- `okMenuSelector` is a macOS AppKit selector API. Use `okMenuAction` for
  portable menus.
- `okClass`/`okMethod`/`okRegister`/`okNew`, NSIndexSet selection, and key
  hooks are macOS-only in this stage.
- Guard platform-specific code, or keep the Windows app on controls and
  callbacks that `k:objkwin` implements.

### App bundle not produced

Compiling creates a bare executable. It does not create a `.app` bundle. The
checkout docs mention `scripts/build-objk-app.ks`, but that helper is not
present in the current tree. Package the bundle manually or with your own
release step.

```sh
KRYPTON_ROOT="$PWD" ./bootstrap/kcc_driver_macos_aarch64 \
  examples/objk/k_owned_counter_macos.ks -o /tmp/objk-counter
```

Signing and notarization remain separate steps.

## Platform issues

| Symptom | Cause |
|---|---|
| Windows-only function missing on macOS | Imported a Windows module |
| macOS-only framework missing on Linux | Imported `k:cocoa`/`k:okui`/`k:objk` |
| `--aarch64` fails on macOS | Cross-compile is a Linux x86_64 feature |
| Executable not created | Wrong output path or codegen failure; use `-o` and check status |

## Version checks

```bash
kcc --version
kcc --help
```

Release-specific limits in this skill were observed on **2.4.8** (macOS
arm64). A newer checkout may fix closures, stdlib bugs, or import behavior.
Re-test before carrying a workaround forward.

## Debug checklist

- [ ] Tiny reproduction file
- [ ] `kcc --version` recorded
- [ ] `KRYPTON_ROOT` set if using a checkout
- [ ] `kcc file -o out` exit code checked
- [ ] stderr read, not just stdout
- [ ] prints bisect the failure
- [ ] suspect stdlib call removed or replaced
- [ ] platform-specific imports guarded
- [ ] generated binaries removed
