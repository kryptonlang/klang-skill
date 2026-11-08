# Krypton CLI and build workflow

## Install

End users do not need a C compiler.

```bash
# macOS / Linux
brew tap t3m3d/krypton
brew install krypton

# or from source
git clone https://github.com/t3m3d/krypton
cd krypton
./build.sh
./install.sh        # optional; symlinks kcc into /usr/local/bin
```

Windows: `choco install krypton`, or run `bootstrap.bat` from a checkout.

Verify:

```bash
kcc --version
krypton --version   # alias where installed
kr                  # REPL
```

## Commands

The macOS 2.4.9 release preserves `-r` argument boundaries, empty arguments
and literal shell syntax. It propagates child status/streams. Older drivers do
not gain these fixes through a stdlib override; rebuild or install the driver.

| Command | Purpose |
|---|---|
| `kcc file.k` | Compile to a native binary named after the source file |
| `kcc file.k -o out` | Compile to an explicit output path |
| `kcc -r file.ks` | Compile, run, delete. Quick experiments |
| `kcc -e 'print("hi")'` | Compile and run an inline snippet |
| `kcc --ir file.k` | Emit Krypton IR to stdout |
| `kcc --aarch64 file.k -o out` | Linux: cross-compile to static aarch64 ELF |
| `kcc --target T file.k` | Target selection; support/SDK requirements differ by host, see macOS notes |
| `kcc --subsystem console\|windows` | Windows subsystem |
| `kr file.ks` | Run a KryptScript file; auto-wraps bare statements |
| `kr` | Interactive REPL |

The default pipeline is native:

- Linux: ELF64, direct syscalls, static
- Windows: PE/COFF with backend-supported Windows DLL imports
- macOS arm64: Mach-O, ad-hoc signed, no clang at user-compile time

The old C escape hatches (`--c`, `--gcc`, `--llvm`) were removed in 2.3 and
now hard-error.

## `.k` vs `.ks`

```krypton
// hello.k
just run {
    print("Hello")
}
```

```krypton
// hello.ks — still fine with an explicit entry block
just run {
    print("Hello")
}
```

```krypton
// script.ks — bare statements; requires kr, not kcc
print("Hello from kr")
```

`kr` auto-wraps bare scripts. `kcc` requires `just run`/`go run`. A shebang
makes a `.ks` file directly executable on POSIX:

```krypton
#!/usr/bin/env kr
print("direct")
```

```bash
chmod +x script.ks
./script.ks
```

## Exit Status By Version

On 2.4.8, `kcc -r` can print a compiler error and still exit `0`. Use an
explicit output path when automation depends on success:

```bash
kcc probe.ks -o /tmp/probe && /tmp/probe
```

`kcc probe.ks -o /tmp/probe` returns non-zero on codegen failure. Always read
stderr as well; the backend prefix is usually `macho_arm64_self:`,
`elf:`, or `x64:`.

Released macOS 2.4.9 fixes this: `-r`/`-e` preserve child status and streams;
`-r` preserves spaces, quotes, empty arguments and literal shell syntax. Failed
compiles preserve earlier output binaries, so execute only after a successful
compile. IR mode keeps frontend diagnostics on stderr, not in the IR stream.

## Source checkout

When compiling from a clone, point the driver at the checkout so `k:`
imports resolve to that tree:

```bash
export KRYPTON_ROOT="$PWD"
./bootstrap/kcc_driver_macos_aarch64 hello.ks -o /tmp/hello
/tmp/hello
```

On Linux, use `bootstrap/kcc_driver_linux_x86_64`. On Windows,
`bootstrap\kcc_driver_windows_x86_64.exe`.

`./build.sh` copies the platform seed into place and runs a smoke test. It
does not rebuild the compiler from source; that is a compiler-development
task.

## Multi-file projects

Put the entry block in one executable file and functions in imported libraries.
Module names are optional annotations, not a requirement to use the same name
in every file or a general package namespace. One possible layout is:

```text
myproject/
  run.k        executable entry
  parser.k     module parser
  render.k     module render
```

`run.k`:

```krypton
module myproject
import "parser.k"

just run {
    print(parseThing("input"))
}
```

Function-only modules import and emit IR without an entry point. Compiling one
as an executable diagnoses the missing entry. Keep compiler `objk` declarations
in the executable file; imported declarations are a separate unsupported case.

## Imports and roots

```krypton
import "k:map"           // <KRYPTON_ROOT>/stdlib/map.k
import "head:objc"       // macOS: <KRYPTON_ROOT>/headers/objc.krh
import "lib/util.k"      // relative to the importing file
```

If stdlib imports fail:

- Installed build: confirm `kcc --version` and that the install is complete.
- Source checkout: set `KRYPTON_ROOT` to the checkout root.
- Confirm the module exists in `stdlib/` or `headers/`.
- Use the name without `.k` after `k:`.

## Platform notes

| Platform | Status | Notes |
|---|---|---|
| macOS arm64 | Released 2.4.9 | Native Mach-O; compiler outputs are ad-hoc signed; release artifacts use Developer ID |
| Linux x86_64 | 2.4.4 | Native ELF, static, direct syscalls |
| Windows x86_64 | 2.3.0 | Native PE/COFF; no claim of macOS adapter parity |
| Linux arm64 | Cross target | Use the supported Linux x86_64 cross pipeline; no claim of a shipped native arm64-host install |

Platform-specific stdlib modules exist (`k:cocoa`, `k:okui` on macOS,
`k:winsock`, `k:conpty_win` on Windows). Do not import them in portable code
without a platform check.

## Testing a program

```bash
# Quick
kcc -r /tmp/probe.ks

# Reliable error status
kcc /tmp/probe.ks -o /tmp/probe && /tmp/probe

# Inspect generated IR
kcc --ir /tmp/probe.ks | head -40
```

For macOS compiler development, use the strict gates
`scripts/check_macos_native.ks`, `scripts/check_macos_driver.ks` and
`scripts/check_objk_runtime_macos.ks`. The older `build.sh test` tolerates some
nonzero exits and is not equivalent. This is separate from testing an app.

Root selection, installed layouts, `kr`, iOS boundaries and CLI probes:
[macos.md](macos.md). Bundles/signing: [macos-release.md](macos-release.md).

## Cleaning up

`kcc -r` and `kcc -e` use temporary paths and clean up. `kcc file.k` writes a
binary next to the source using the source basename. Remove generated
binaries before committing:

```bash
rm -f hello hello.exe
```
