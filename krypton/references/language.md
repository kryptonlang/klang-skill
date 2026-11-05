# Krypton language reference

Krypton is a dynamic, string-valued language. `.k` and `.ks` share the same
syntax and compiler. The extension is a naming convention:

- `.k` — library or compiled program. Use a `module` declaration and an
  explicit `just run { ... }` entry point.
- `.ks` — KryptScript. Intended to run directly. `kr` auto-wraps a bare
  script in `just run { ... }`. `kcc` does not.

Useful source files in the repository:

- `grammar/krypton.ebnf` — single-page grammar
- `docs/spec/types.md` — value model, smart-int, closures, typed pointers
- `docs/spec/functions.md` — builtins
- `tutorial/01_hello_world.k` … `34_browser_hn.k` — runnable lessons
- `examples/` and `algorithms/` — larger programs

## Program shape

```krypton
module mymodule          // optional; required for multi-file projects
import "k:map"           // optional imports

struct Point {           // optional declarations
    let x
    let y
}

func add(a, b) {         // functions
    emit toInt(a) + toInt(b) + ""
}

just run {               // entry point; exactly one per program
    print(add("2", "3"))
}
```

`just run` and `go run` are equivalent. Library modules omit the entry block.

For a multi-file project, put the entry block in `run.k` and give files the
same `module` name:

```text
myproject/
  run.k        module myproject
  parser.k     module myproject
  render.k     module myproject
```

Single-file scripts without a `module` declaration are exempt from the
`run.k` convention.

## Values

All runtime values are strings. Two opt-in escapes exist: typed pointers and
closures.

```krypton
let x = 42          // "42"
let name = "Krypton"
let flag = true     // "true"
let no = false      // "false"
let nothing = null
```

Numeric strings are detected as an optional leading `-` followed by digits.
`+` adds when both operands are numeric; otherwise it concatenates.

```krypton
10 + 20          // "30"
"10" + "20"      // "30"
"hello" + "!"    // "hello!"
10 + " items"    // "10 items"
```

This is a common footgun:

```krypton
"" + 1 + "0"     // numeric 1, not "10"
```

Use a StringBuilder when concatenating digit-only tokens as text:

```krypton
let sb = sbNew()
sb = sbAppend(sb, "1")
sb = sbAppend(sb, "0")
print(sbToString(sb))   // "10"
```

### Truthiness

Falsy values: `""`, `"0"`, `"false"`, and integer `0`. Everything else is
truthy, including `"1"`, `"true"`, and any other non-empty string.

`if`, `while`, and loops apply these rules automatically.

```krypton
if ""        { }   // no
if "0"       { }   // no
if "false"   { }   // no
if true      { }   // yes
if "hi"      { }   // yes
if !false    { }   // yes
```

Comparisons and logical operators return `"1"` or `"0"`:

```krypton
5 > 3        // "1"
5 < 3        // "0"
true         // "true"
true == (5 > 3)          // "0" — different string forms
isTruthy(true) == isTruthy(5 > 3)   // "1"
```

Use `isTruthy(v)` or `k:booleans` helpers (`bool`, `boolEq`) when normalizing.

### Smart-int limit

On native backends, values below `0x40000000` (1 GiB) are small integers;
higher values are string pointers. Do not use integers at or above 1 GiB
without the 64-bit helpers. This is rarely relevant for scripts.

## Variables and operators

```krypton
let x = "42"
const pi = "3.14159"

x = "43"
x += 1
x -= 1
x *= 2
x /= 2
x %= 2
x++
--x
```

Operators: `+ - * / %`, `== != < > <= >=`, `&& || !`, and ternary
`cond ? a : b`.

Type annotations are optional and mostly document intent:

```krypton
let n: int = "42"
let name: string = "Krypton"

func add(a: int, b: int) -> int {
    emit toInt(a) + toInt(b) + ""
}

func logLine(msg: string) -> do {
    print(msg)
}
```

`do` means no result. `void` is rejected.

## Functions

```krypton
func add(a, b) {
    emit a + b
}

fn multiply(a, b) {
    emit a * b
}

func noResult(msg) -> do {
    print(msg)
}
```

- `emit expr` returns a value. `return expr` is an alias.
- A function without `emit` falls through.
- `func` and `fn` are equivalent.
- Nested named functions are hoisted to file scope; they are siblings, not
  closures.
- There are no default arguments, overloads, or keyword arguments.
- Recursion works normally.

```krypton
func factorial(n) {
    if n <= 1 {
        emit 1
    }
    emit n * factorial(n - 1)
}
```

## Lambdas and closures

The docs describe first-class lambdas and `cb: closure` receivers:

```krypton
let double = func(x) { emit toInt(x) * 2 }
```

On the 2.4.8 compiler this currently fails with errors such as:

```text
macho_arm64_self: unknown function 'double' called from '__main__'
macho_arm64_self: unknown function 'cb' called from 'apply'
```

For portable code, use named functions and explicit loops. `k:fp` and other
helpers that take lambdas are affected. Treat closure examples as
version-dependent and test them before shipping.

## Control flow

### if / else

```krypton
if x > 10 {
    print("big")
} else if x > 5 {
    print("medium")
} else {
    print("small")
}
```

Braces are required. Conditions are truthiness-checked.

### while

```krypton
let i = 0
while i < 10 {
    print(i)
    i += 1
}
```

### do / while

```krypton
let i = 0
do {
    print(i)
    i += 1
} while i < 3
```

### for-in

`for` iterates over comma-separated lists. There is no C-style `for`.

```krypton
for item in "a,b,c" {
    print(item)
}

for n in range(1, 5) {
    print(n)          // 1, 2, 3, 4
}

let i = 0
while i < lineCount(text) {
    print(getLine(text, i))
    i += 1
}
```

`range(start, end)` is end-exclusive. `for` does not iterate over individual
characters of a string; index with `s[i]` instead.

### match

```krypton
match color {
    "red"  { print("warm") }
    "blue" { print("cool") }
    else   { print("other") }
}
```

Arm values are expressions, not patterns. Use `else` as the default.

### try / catch / throw

```krypton
try {
    throw "boom"
} catch e {
    print("caught: " + e)
}
```

The catch variable is optional. `throw("message")` also parses as a call, but
the keyword form is the portable one.

## Structs

Struct names must start with an uppercase letter. Fields are dynamic
name/value pairs, not statically typed slots.

```krypton
struct Point {
    let x
    let y
}

let p = Point { x: "3", y: "4" }
print(p.x)
p.x = "5"

let q = Point()      // constructor form; fields start empty
q.x = "1"
```

Dynamic structs without a declaration:

```krypton
let cfg = structNew()
cfg = setField(cfg, "debug", "1")
print(getField(cfg, "debug"))
print(hasField(cfg, "debug"))
print(structFields(cfg))
```

Native `setField` is functional: always assign the result back. The old C
runtime mutated in place, but that path was removed in 2.3.

## Lists and maps

Lists are comma-separated strings:

```krypton
let xs = "apple,banana,cherry"
print(count(xs))          // 3
print(split(xs, 1))       // "banana"

for x in xs {
    print(x)
}
```

Build lists by appending commas, or use `k:list` / `k:list_utils` helpers.

Maps are interleaved key/value strings or use `k:map` / `k:dict`:

```krypton
import "k:map"

let ages = mapNew()
ages = mapSet(ages, "alice", "30")
print(mapGet(ages, "alice"))
```

Map operations return a new map. Reassign the variable each time.

## Strings

```krypton
let s = "Hello, Krypton!"

print(len(s))                 // bytes
print(s[0])                   // "H"
print(substring(s, 0, 5))     // "Hello"
print(startsWith(s, "Hello")) // "1"
print(contains(s, "Krypton"))
print(replace(s, "Krypton", "World"))
print(`Hello, {name}!`)       // interpolation
```

Escape sequences: `\n`, `\t`, `\r`, `\\`, `\"`, `\'`.

Backtick strings interpolate `{expr}`:

```krypton
print(`1 + 1 = {1 + 1}`)
```

Use `lineCount(text)` and `getLine(text, i)` for newline-oriented strings.
`lineCount("a\nb\n")` returns `2`, not `3`.

## Imports

```krypton
import "k:map"          // <KRYPTON_ROOT>/stdlib/map.k
import "core:map"       // long alias for k:
import "head:user32"    // <KRYPTON_ROOT>/headers/user32.krh
import "util.k"         // relative to this file
import "../shared/log.k"
```

`k:` / `core:` resolve stdlib. `head:` / `headers:` resolve C-binding headers.
A plain relative path resolves against the importing file. Legacy forms such
as `import "stdlib/gui.k"` still work.

Do not add `.k` to `k:` imports. `import "k:map"` is correct;
`import "k:map.k"` is not.

## Typed pointers

Typed pointers are an opt-in escape hatch for raw buffers:

```krypton
let p: *u8 = "hello"
print(p[0])              // 104

struct Vec3 {
    let x
    let y
    let z
}

let v: *Vec3 = bufNew(sizeOf("Vec3"))
v.x = 1
v.y = 2
v.z = 3
```

Supported widths: `*u8`, `*i8`, `*u16`, `*i16`, `*u32`, `*i32`, `*u64`,
`*i64`, and `*StructName`.

`let local Vec3 v` allocates a heap-backed buffer shaped like a local.

Typed pointers are not the default value model. Use them only for buffers,
binary formats, or low-level code.

## KryptScript specifics

`kr` adds two conveniences:

1. Auto-wrap a bare script in `just run { ... }`.
2. REPL when invoked with no file.

```bash
kr script.ks
kr                # REPL
```

A shebang works on POSIX:

```krypton
#!/usr/bin/env kr
print("runs directly")
```

```bash
chmod +x script.ks
./script.ks
```

`kcc` recognizes the shebang but does not auto-wrap. Include `just run` in
files that will be compiled with `kcc`.

## Common mistakes

| Wrong | Right |
|---|---|
| `let p = point { ... }` | Struct names start uppercase: `Point` |
| `func f() -> void` | `func f() -> do` |
| `for (i = 0; i < n; i++)` | `while` or `for x in range(...)` |
| `import "k:map.k"` | `import "k:map"` |
| `print(true == (5 > 3))` expecting true | Compare `isTruthy` values |
| `"" + 1 + "0"` expecting `"10"` | Use `sbAppend` |
| Bare `.ks` with `kcc -r` | Add `just run`, or use `kr` |
| `cfg = setField(...)` omitted | Always assign the returned struct |
