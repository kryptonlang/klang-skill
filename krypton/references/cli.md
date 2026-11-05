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

| Command | Purpose |
|---|---|
| `kcc file.k` | Compile to a native binary named after the source file |
| `kcc file.k -o out` | Compile to an explicit output path |
| `kcc -r file.ks` | Compile, run, delete. Quick experiments |
| `kcc -e 'print("hi")'` | Compile and run an inline snippet |
| `kcc --ir file.k` | Emit Krypton IR to stdout |
| `kcc --aarch64 file.k -o out` | Linux: cross-compile to static aarch64 ELF |
| `kcc --target T file.k` | Target `ios-sim-arm64`, `ios-device-arm64`, or `windows-x86_64` |
| `kcc --subsystem console\|windows` | Windows subsystem |
| `kr file.ks` | Run a KryptScript file; auto-wraps bare statements |
| `kr` | Interactive REPL |

The default pipeline is native:

- Linux: ELF64, direct syscalls, static
- Windows: PE/COFF, kernel32 only
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

## Exit status gotcha

On 2.4.8, `kcc -r` can print a compiler error and still exit `0`. Use an
explicit output path when automation depends on success:

```bash
kcc probe.ks -o /tmp/probe && /tmp/probe
```

`kcc probe.ks -o /tmp/probe` returns non-zero on codegen failure. Always read
stderr as well; the backend prefix is usually `macho_arm64_self:`,
`elf:`, or `x64:`.

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

Use one `module` declaration on every file and put the entry block in
`run.k`:

```text
myproject/
  run.k        module myproject
  parser.k     module myproject
  render.k     module myproject
```

`run.k`:

```krypton
module myproject
import "parser.k"

just run {
    print(parseThing("input"))
}
```

Single-file scripts without a `module` declaration can keep the entry block
in the same file.

## Imports and roots

```krypton
import "k:map"           // <KRYPTON_ROOT>/stdlib/map.k
import "head:user32"     // <KRYPTON_ROOT>/headers/user32.krh
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
| macOS arm64 | Current 2.4.8 | Native Mach-O, ad-hoc signing |
| Linux x86_64 | 2.4.4 | Native ELF, static, direct syscalls |
| Windows x86_64 | 2.3.0 | Native PE/COFF, kernel32 only |
| Linux arm64 | C path only | No native ELF arm64 backend; cross-compile with `--aarch64` from x86_64 |

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

For a repository test suite (compiler development), use `./build.sh test`.
That is outside normal language use.

## Cleaning up

`kcc -r` and `kcc -e` use temporary paths and clean up. `kcc file.k` writes a
binary next to the source using the source basename. Remove generated
binaries before committing:

```bash
rm -f hello hello.exe
```
