# Krypton builtins and stdlib

Values are string-oriented, but native integers, float boxes and opaque buffers/
handles coexist with text. Do not apply string functions to a native pointer.
Builtins are called like ordinary functions. Stdlib modules are imported with
`import "k:<name>"`.

Check the actual exported names before use:

```bash
grep -E '^(export )?func ' "$KRYPTON_ROOT/stdlib/<name>.k"
```

## Core builtins

### Output and input

| Call | Result |
|---|---|
| `print(s)` / `kp(s)` | Print `s` and a newline |
| `printErr(s)` | Print to stderr |
| `readLine(prompt)` | Print prompt, read one line |
| `scan(prompt)` | Canonical line-input contract |
| `get()` / `getEcho()` | Single-key contracts; stdlib fallback reads a line |
| `input()` | Read a line with no prompt |

### Files and process

| Call | Result |
|---|---|
| `readFile(path)` | File text; `""` if missing |
| `writeFile(path, data)` | `"1"` on success, `"0"` on failure |
| `shellRun(cmd)` | Run shell command; returns exit code |
| `exec(cmd)` | Run shell command; returns stdout |
| `arg(n)` | Command-line argument, 0-based, program name skipped |
| `argCount()` | Number of arguments |
| `exit(code)` | Exit immediately |

For paths, directories, and portable file operations, use `k:fsx` and
`k:path` instead of hand-building strings.

### Strings

| Call | Result |
|---|---|
| `len(s)` | Byte length |
| `substring(s, start, end)` | End-exclusive slice |
| `s[i]` | One-byte character at index |
| `startsWith(s, prefix)` | `"1"` / `"0"` |
| `endsWith(s, suffix)` | `"1"` / `"0"` |
| `contains(s, sub)` | `"1"` / `"0"` |
| `indexOf(s, sub)` | Position or `"-1"` |
| `replace(s, old, new)` | Replace all |
| `trim(s)` | Native trimming is not a Unicode/CR/LF-normalization guarantee; explicitly chomp shell output |
| `toUpper(s)` / `toLower(s)` | Case conversion |
| `reverse(s)` | Byte reversal |
| `repeat(s, n)` | Repeat |
| `charCode(s)` / `fromCharCode(n)` | Byte/code conversion |
| `isDigit(s)` / `isAlpha(s)` | First-byte classification |

`k:string` has Python-shaped helpers: `upperk`, `lowerk`, `capitalizek`,
`stripk`, `splitk`, `joink`, `findk`, `startswithk`, `endswithk`,
`replacek`, `zfillk`, and more.

### Numbers

| Call | Result |
|---|---|
| `toInt(s)` / `parseInt(s)` | Parse numeric string |
| `abs(n)` | Absolute value |
| `pow(base, exp)` | Integer power |
| `range(start, end)` | End-exclusive comma list |
| `sqrt(n)` | Integer square root |
| `min(a, b)` / `max(a, b)` | Smaller / larger |
| `sign(n)` | `"-1"`, `"0"`, `"1"` |
| `clamp(val, lo, hi)` | Clamp |
| `hex(n)` / `bin(n)` | Base representation |
| Float helpers | `toFloat`, `fadd`, `fsub`, `fmul`, `fdiv`, `fformat`, `fsqrt`, `feq`, `flt`, `fgt` |

Native integer/pointer heuristics differ by operation and backend; do not infer
general 64-bit arithmetic from small-number tests. Keep large values as text or
use a verified sized-buffer operation. In particular, never parse a native
pointer or `NSNotFound` as text. K-owned fields have their own narrower range.

### Lists

Lists are comma-separated strings.

| Call | Result |
|---|---|
| `split(list, i)` | Item at index |
| `count(list)` / `length(list)` | Item count |
| `range(start, end)` | Comma list |
| `first(list)` / `last(list)` | First / last |
| `head(list, n)` / `tail(list, n)` | Prefix / suffix |
| `append(list, item)` | Append |
| `slice(list, start, end)` | End-exclusive slice |
| `sort(list)` | Numeric-aware sort |
| `unique(list)` | Deduplicate |
| `zip(a, b)` | Interleave |
| `listIndexOf(list, item)` | Position or `"-1"` |
| `sumList(list)` / `minList(list)` / `maxList(list)` | Reductions |

Library names are not guarantees: macOS `sort` has ineffective cases, and
comma-list sorting is not newline-record sorting. Test the representation and
output order before relying on a helper.

### Maps and structs

| Call | Result |
|---|---|
| `structNew()` | Empty dynamic struct |
| `setField(obj, name, val)` | Updated struct; always reassign |
| `getField(obj, name)` | Value or `""` |
| `hasField(obj, name)` | `"1"` / `"0"` |
| `structFields(obj)` | Comma list of names |
| `mapGet(map, key)` | Value |
| `mapSet(map, key, val)` | Updated map; reassign |
| `mapDel(map, key)` | Updated map |
| `keys(map)` / `values(map)` / `hasKey(map, key)` | Inspection |

`k:map` is the small map module. `k:dict` provides Python-shaped
`dictsetk`, `dictgetk`, `dictkeysk`, `dictvaluesk`, and related helpers.

### StringBuilder

| Call | Result |
|---|---|
| `sbNew()` | New builder |
| `sbAppend(sb, s)` | Append; returns builder |
| `sbToString(sb)` | Final text |

Use a builder for append-heavy loops and exact text fragments. `sbAppend`
expects text; use interpolation such as `` `{number}` `` when converting a raw
integer, not an assumed `toStr` serializer. `sbToString` borrows interior storage;
copy with `okCopyText` before mutation/collection when persistent text is needed.

### Lines

| Call | Result |
|---|---|
| `lineCount(s)` | Newline count with Krypton's trailing-newline rule |
| `getLine(s, i)` | 0-based line |

`lineCount("a\nb\n")` is `2`; `lineCount("")` is `0`.

### Truth and conversion

| Call | Result |
|---|---|
| `isTruthy(s)` | `"1"` / `"0"` |
| `toStr(s)` | Identity |
| `bool(v)` / `boolToInt(v)` / `boolEq(a, b)` | `k:booleans` normalization |

## Stdlib catalog

This is a discovery catalog, not an all-platform or all-functions test result.
Check `stdlib/<name>.k` and compile a probe on the actual 2.4.9 macOS root.
Some entries below are platform-specific or have historical defects.

### Data structures

| Import | Useful exports |
|---|---|
| `k:map` | `mapNew`, `mapSet`, `mapGet`, `mapHas`, `mapRemove`, `mapSize`, `mapKeys` |
| `k:dict` | `emptydictk`, `dictsetk`, `dictgetk`, `dictkeysk`, `dictvaluesk`, `indictk`, `dictpopk` |
| `k:set` | `setNew`, `setAdd`, `setRemove`, `setContains`, `setSize`, `setUnion`, `setIntersect` |
| `k:list` | `emptylistk`, `appendk`, `extendk`, `insertk`, `removek`, `slicek`, `listGetk`, `listSetk` |
| `k:list_utils` | `listNew`, `listAppend`, `listGet`, `listReverse`, `listUnique`, `listSum` |
| `k:collections` | `mapDouble`, `mapSquare`, `filterEven`, `reduceSum`, `zip`, `listSlice`, `listIntersect`, `listUnion` |
| `k:sort` | `bubbleSortNum`, `selectionSortNum`, `insertionSortNum`, `sortStrings`, `listMin`, `listMax` |
| `k:range` | `rangeList`, `rangeStep`, `rangeDown`, `evens`, `odds`, `fibs`, `primes` |
| `k:stack` / `k:queue` | Stack and queue helpers |
| `k:counter` | Frequency helpers |

### Text and formats

| Import | Useful exports |
|---|---|
| `k:string` | Python-shaped string helpers |
| `k:string_utils` | `padLeft`, `padRight`, `trimLeft`, `trimRight`, `countOccurrences`, `join`, `camelCase`, `snakeCase`, `escapeHtml`, `truncate`, `levenshtein` |
| `k:format` | `zeroPad`, `formatNumber`, `center`, `formatKV`, `formatPercent`, `tableRow`, `formatBytes`, `fmt` |
| `k:lines` | `filterEmpty`, `unique`, `reverseLines`, `takeLines`, `dropLines`, `joinLines`, `safeGetLine`, `trimLines` |
| `k:csv` | `parseLine`, `fieldAt`, `fieldCount`, `makeLine`, `parseCSV`, `getCell`, `rowCount`, `getColumn` |
| `k:json_emit` | `jeStr`, `jeNum`, `jeBool`, `jeNull`, `jeObj`, `jeObj2`, `jeArr`, `jeArrFrom` |
| `k:json_parse` | Parser state and helpers: `jpNew`, `jpParse`, `jpGet`, `jpTypeOf`, `jpHas`, `jpArrLen`, `jpObjKeys` |
| `k:base64` | `b64Encode`, `b64Decode`, URL-safe variants |
| `k:hexenc` | `strToHex`, `hexToStr`, `toHex`, `fromHex` |
| `k:url` | `urlEncode`, `urlDecode`, `urlParseQuery`, `urlBuild` |
| `k:slug` | `slugify`, `kebab`, `snake`, `screamingSnake`, `dotted` |
| `k:validate` | `isEmail`, `isIPv4`, `isURL`, `isUUID`, `isNumeric`, `isHex`, `isPrintableAscii` |
| `k:semver` | `semverCmp`, `semverEq`, `semverLt`, `semverGt`, `semverSatisfiesCaret` |
| `k:mime` | `mimeFromExt`, `mimeFromPath`, `isImage`, `isAudio`, `isVideo`, `isText` |

### Files, OS, and process

| Import | Useful exports |
|---|---|
| `k:path` | `pathJoin`, `normalizePath`, `isAbsolute`, `parentDir`, `stem`, `extension`, `basename`, `changeExt` |
| `k:fsx` | `exists`, `isDir`, `isFile`, `listDir`, `listFiles`, `listDirs`, `glob`, `mkdirp`, `rm`, `rmrf`, `cp`, `mv`, `readText`, `writeText`, `appendText`, `cwd`, `home` |
| `k:os` | `osgetcwdk`, `osgetenvk`, `ospathjoink`, `ospathexistsk`, `oslistdirk`, `osmkdirk`, `osremovek`, `osrenamek` |
| `k:env` | `env`, `hasEnv`, `envOr`, `envInt`, `envBool`, `pathDirs` |
| `k:args` | `argN`, `hasFlag`, `optValue`, `positional`, `countPositional`, `restFrom`, `allArgs` |
| `k:proc` | Process helper names; inspect platform bindings before using on macOS, prefer `k:objk_process_macos` for verified synchronous capture |
| `k:settings` | Existing implementation reaches Windows APIs; not a drop-in macOS settings module. Use native defaults or an app-owned format |

### Math, time, and randomness

| Import | Notes |
|---|---|
| `k:math_utils` | `max`, `min`, `power`, `factorial`, `gcd`, `lcm`, `isPrime`, `fibonacci`, `clamp`, `isqrt`, `sign`, `choose` |
| `k:math` | Broader math surface: `mathpik`, `mathsqrtk`, `mathsink`, `mathcosk`, `mathlogk`, and related |
| `k:datetime` | UTC-only date helpers. Check expected input format before use |
| `k:random` | `nextRandom`, `randomInRange`, `randomList`, `shuffle`, `randomChoice`, `randomString`, `randomBool` |
| `k:time` | Time helpers. Some paths are Windows-specific; test on macOS/Linux |

### Errors and assertions

| Import | Useful exports |
|---|---|
| `k:result` | `ok`, `err`, `isOk`, `isErr`, `unwrap`, `unwrapOr`, `resultMap` |
| `k:option` | `optSome`, `optNone`, `isSome`, `isNone`, `optUnwrap`, `optUnwrapOr`, `optMap` |
| `k:assert` | `assertEqual`, `assertTrue`, `assertFalse`, `assertContains`, `reportResults` |

### Terminal, UI, and network

| Import | Notes |
|---|---|
| `k:ansi` | ANSI colors and cursor control: `red`, `green`, `bold`, `underline`, `rgb`, `strip` |
| `k:logging` | `logDebug`, `logInfo`, `logWarn`, `logError` |
| `k:terminal` | Raw mode, key reads, terminal size |
| `k:httpc` | Minimal HTTP client in pure Krypton |
| `k:server_native` | HTTP server on macOS arm64 via BSD sockets |
| `k:http` | Windows/curl-backed HTTP client |
| `k:gui`, `k:okui`, `k:cocoa`, `k:objk` | Native UI layers; platform-specific |
| `k:winsock`, `k:conpty_win` | Windows-only |

### Objective-K

| Import | Platform | Notes |
|---|---|---|
| `k:okui` | macOS + Windows | App facade. Use this in app code |
| `k:objk` | macOS | Low-level window/control/table/menu calls |
| `k:objkwin` | Windows | Windows facade over `k:choc` |
| `k:objk_runtime_macos` | macOS | K-owned classes, fields, ownership, cleanup |
| `k:objk_process_macos` | macOS | Synchronous Foundation process capture |
| `k:choc_macos` / `k:choc` | macOS / Windows | Native adapters behind `k:okui` |
| `k:objk_layout` | macOS + Windows | Layout rectangle helpers |

`k:okui` is the app facade, not a platform-parity promise. Released macOS 2.4.9
includes table model/selection, key/live-field hooks, segmented controls,
lifecycle hooks, scroll layout, text snapshots and process capture. See
`objective-k.md` and `appkit-controls.md` for the exact contracts.

## Version-specific warnings

Historical observations below came from 2.4.8. Keep them separate from verified
2.4.9 fixes; do not carry an old workaround forward without a probe.

| Area | Symptom | Workaround |
|---|---|---|
| Closures / `k:fp` | `unknown function 'cb'` or `'f'` | Use named functions and loops |
| `k:random.randomString` | Process dies after the first print | Avoid, or implement with `k:math_utils` and a seed |
| `k:url.urlEncode` | Earlier corrupted character conversion | Fixed/tested on macOS 2.4.9; use the shipped module, not a handwritten encoder |
| `k:datetime.dtYear("2026-11-05")` | Returns `1970` | Pass the expected ISO datetime form, or parse manually |
| `k:time` | `unknown function 'GetTickCount64'` on macOS | Use `k:datetime` or platform-specific code |
| `k:json_parse.jpGet(jpParse(...))` | Empty result for a simple object | Follow the module's parser-state API, or use `k:json_emit` for output |

## Choosing a module

1. Start with core builtins.
2. Add the smallest stdlib module that fits.
3. Compile and run a one-call probe.
4. Only then integrate it into the larger program.

Do not import a platform-specific module in portable code without a guard.
