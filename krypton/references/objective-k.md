# Objective-K: native apps in Krypton

Objective-K is Krypton's object and native-application layer. It is not a
separate compiler or interpreter. `.k` and `.ks` use the same `kcc`.

**Version boundary:** published macOS 2.4.8 contains `k:okui`, `k:objk`, and
the K-owned runtime (`k:objk_runtime_macos`). The table model/selection,
keyboard hooks, live-field changes, `okSegmented`, and
`k:objk_process_macos` in this document come from unreleased checkout work.
Use the checkout driver and stdlib for those, and verify symbols before
promising them. Check `kcc --version` first.

## Three layers

| Layer | Import / entry | Owns |
|---|---|---|
| K-owned object model | `k:objk_runtime_macos`, or `objk` declarations | Classes, protocols, dispatch, fields, owned/weak references, text, cleanup |
| App-facing facade | `k:okui` | Windows, controls, menus, events, theme, files, clipboard, URLs |
| macOS platform adapter | `k:choc_macos`, via `k:okui` | AppKit, Foundation, libobjc, native objects, IMP callbacks |

The K-owned model is not an AppKit object. Keep native window, control, and
table pointers out of K-owned integer fields. A K-owned model can drive a
native UI, but the UI does not become part of its arena or ownership system.

The core itself imports no Apple frameworks. Apps that import `k:okui` do link
Apple's `libobjc`, Foundation, and AppKit. Objective-K removes Objective-C
source and compilation, not Apple's system libraries.

## Build and run on macOS

From the Krypton checkout on macOS arm64:

```sh
export KRYPTON_ROOT="$PWD"
./bootstrap/kcc_driver_macos_aarch64 tutorial/macos/01_live_field.ks -o /tmp/objk-live-field
/tmp/objk-live-field
```

Use the explicit driver path; Apple ships an unrelated Kerberos `kcc`.

Compile checks that do not open a window:

```sh
KRYPTON_ROOT="$PWD" ./bootstrap/kcc_driver_macos_aarch64 -r tutorial/macos/02_owned_model.k
KRYPTON_ROOT="$PWD" ./bootstrap/kcc_driver_macos_aarch64 -r scripts/check_objk_runtime_macos.ks
KRYPTON_ROOT="$PWD" ./bootstrap/kcc_driver_macos_aarch64 -r scripts/check_okui.ks
```

`--gui` on `check_objk_runtime_macos.ks` adds a native window/button smoke
test. It requires a desktop session.

Bare compile:

```sh
KRYPTON_ROOT="$PWD" ./bootstrap/kcc_driver_macos_aarch64 \
  examples/objk/k_owned_counter_macos.ks -o /tmp/objk-counter
/tmp/objk-counter
```

Compiling produces a bare Mach-O executable. It does not create, sign, or
notarize a `.app` bundle. The checkout docs mention `scripts/build-objk-app.ks`,
but that helper is not present in the current tree; package the `.app` manually
or with your own release step. Do not claim a bundle was produced when only the
executable exists.

## App-facing API: `k:okui`

`k:okui` is the preferred app surface. On macOS it pulls in `k:objk`,
`k:choc_macos`, and `k:okui_core`. On Windows it pulls in `k:objkwin` and
`k:choc`. App code can often stay on the same words.

### Two API styles

`k:okui` exposes low-level `ok*` calls:

```krypton
let app = okApp()
let win = okWindow(app, "App", 460, 300)
let field = okField(win, 20, 180, 300, 28)
okPlaceholder(field, "Name")
let button = okButton(win, "Save", 330, 180, 100, 28)
```

`okui_core` adds readable layout and action words:

```krypton
app("App")
let win = window("App", 540, 300)
let root = page(540, 300, 24)
title(win, "Native UI without ceremony", top(root, 32))
let name = field(win, row(root, 1, 30, 14))
doPlaceholder(name, "Name")
let save = button(win, "Save", right(row(root, 1, 30, 14), 100))
doClick(save, "app.save", funcptr(onSave))
doShow(win)
doRun()
```

Both styles are valid. Prefer one style per file.

### App lifecycle

macOS uses an autorelease pool around the app:

```krypton
just run {
    let pool = okAutoreleasePool()
    let app = okApp()
    let win = okWindow(app, "Objective-K", 640, 420)
    // controls and callbacks
    okShow(win, app)
    okRun(app)          // blocks
    okDrainPool(pool)
}
```

`okRun` runs the native event loop. Quit through the app menu or `okQuit`.
Closing a window is not necessarily process termination.

The high-level words `app`, `window`, `doShow`, `doRun`, and `doQuit` wrap the
same lifecycle using a shared app. Use them for small apps.

### Controls

| Purpose | Calls |
|---|---|
| Window | `okWindow`, `okShow`, `okRun`, `okQuit`, `okTitle`, `okMinSize`, `okTransparentTitlebar` |
| Text | `okLabel`, `okBoxLabel`, `okTextView`, `okField`, `okPassword` |
| Actions | `okButton`, `okCheckbox`, `okSlider`, `okSegmented` |
| Progress | `okProgress`, `okSpinner`, `okSetProgress`, `okStart`, `okStop` |
| Choice | `okCombo`, `okComboAdd`, `okComboSelect`, `okComboIndex`, `okComboText` |
| Layout | `okFrame`, `okAutoresizing`, `okRemove`, `okSplit`, `okSplitAdd` |
| Text values | `okText`, `okSetText`, `okAppend`, `okTextViewText`, `okSetTextView`, `okPlaceholder` |
| State | `okState`, `okSetState`, `okEnabled`, `okHidden`, `okEditable` |

Portable high-level aliases: `label`, `title`, `field`, `password`, `button`,
`checkbox`, `textBox`, `progress`, `spinner`, `slider`, `choices`, `text`,
`state`, `choice`, `choiceIndex`, `doText`, `doTextBox`, `doAppend`,
`doPlaceholder`, `doEnable`, `doDisable`, `doHide`, `doShowView`, `doFrame`,
`doTip`, `doState`, `doProgress`, `doStart`, `doStop`, `doAddChoice`,
`doChoose`.

### Events and callbacks

`funcptr(name)` passes a named function as a native callback. It does not
capture locals and does not create a closure.

| Registration | Handler signature | Result |
|---|---|---|
| `okClick(control, funcptr(handler))` | `(self, command, sender)` | Native action result ignored |
| `okOn(control, key, funcptr(handler))` | `(self, command, sender)` | Keyed registration; use distinct keys |
| `okFieldOnChange(field, funcptr(handler))` | `(field)` | Ignored; read with `okText(field)` |
| `okOnKeyDown(table, funcptr(handler))` | `(table, event)` | `1` consumes, `0` preserves native handling |
| K-owned method | `(runtime, self, ...)` | Must match the registered contract |

All AppKit calls and callbacks require the main thread. Keep callbacks short.
Do not block a UI callback waiting for a long-running process.

Passing `0` detaches a key or field handler. `okSetText` does not synthesize a
user-edit notification.

Example:

```krypton
import "k:okui"

func showText(field) {
    let label = okGet(field, "tutorial.label")
    okSetText(label, okText(field))
    emit 0
}

just run {
    let pool = okAutoreleasePool()
    let app = okApp()
    let win = okWindow(app, "Live Field", 460, 160)
    let field = okField(win, 20, 92, 420, 28)
    let label = okLabel(win, "", 20, 44, 420, 28)
    okSet(field, "tutorial.label", label)
    if okFieldOnChange(field, funcptr(showText)) == "0" {
        printErr("Cannot register live field handler\n")
        exit("1")
    }
    okShow(win, app)
    okMakeFirstResponder(win, field)
    okRun(app)
    okDrainPool(pool)
}
```

### Associations and arrays

`okSet(obj, key, value)` and `okGet(obj, key)` attach values to native controls.
On macOS these are associated objects and retain the value. Avoid cycles: a
control should not strongly retain an object that strongly retains it.

`okArray` returns a native array on macOS and a state-list handle on Windows.

```krypton
let items = okArray()
okArrayAdd(items, nsString("first"))
okArrayAdd(items, nsString("second"))
print(okArrayCount(items))
print(nsToStr(okArrayGet(items, 0)))
```

Keep values alive for as long as native controls reference them. Do not
stringify native handles.

### Menus

Portable callback menu:

```krypton
let bar = okMenuBar(app)
let menu = okMenuAdd(bar, "App")
okMenuAction(menu, "Quit", "q", funcptr(onQuit))
```

macOS selector menu:

```krypton
okMenuSelector(menu, "Quit", "q", "terminate:")
okMenuSeparator(menu)
okMenuSelector(edit, "Copy", "c", "copy:")
```

`okMenuSelector` uses AppKit selector names. It is macOS-specific. Use
`okMenuAction` for a callback that can work on both platforms.

### Theme, files, clipboard, defaults, URLs

| Purpose | Calls |
|---|---|
| Theme | `okDark`, `okAppearanceName`, `okAppearance`, `okSystemWindowBg`, `okSystemText`, `okSystemSecondaryText`, `okSystemTextBg` |
| Colors | `okColor`, `okRGB`, `okSetBg`, `okSetTextColor`, `okSetButtonTextColor`, `okSetWindowBg` |
| Fonts | `okMonoFont`, `okFontFamily`, `okSetFont` |
| Files | `okChooseFolder`, `okChooseFile`, `okSaveFile`, `okBundledExecutable`, `okBundledResource`, `okTemporaryDirectory` |
| Clipboard | `okClipboard`, `okSetClipboard` |
| Defaults | `okDefault`, `okSetDefault`, `okRemoveDefault` |
| URLs/paths | `okOpenURL`, `okOpenPath`, `okReveal` |
| Alerts | `okAlert(title, message)` |

Color values are backend-specific. Do not persist a raw color handle across
platforms. Use the theme words instead.

## macOS AppKit: tables, selection, keyboard

These APIs are macOS-specific and newer than published 2.4.8.

### Table model and selection

`okTable(win, x, y, w, h)` returns a document table in a scroll view.

| API | Contract |
|---|---|
| `okDataSource(table, source)` | Set and retain the native data source; `0` detaches |
| `okReload(table)` | Reload the current model |
| `okMultiSelect(table, enabled)` | Enable/disable multiple selection |
| `okSelectionNew()` | Autoreleased mutable index-set builder |
| `okSelectionAdd(rows, row)` | Add a nonnegative row; `"0"` for nil/immutable |
| `okSelection(table)` | Autoreleased immutable selection snapshot |
| `okSelectionCount(rows)` | Number of selected indexes |
| `okSelectionAt(rows, offset)` | Selected row at ordinal; empty if out of range |
| `okSelect(table, rows)` | Replace selection |
| `okSelectExtend(table, rows, extend)` | Replace or extend |
| `okSelectRow(table, row, extend)` | Select one valid row |
| `okSelectNone(table)` / `okSelectAll(table)` | Clear/select all |
| `okScrollTo(table, row)` | Scroll a valid row into view |

Selection inputs are native index-set handles, not comma-separated text.
Snapshots are autoreleased and do not change when the table selection changes.
Changing the model may invalidate row indexes; clear or remap selection before
`okReload`.

Data source methods use AppKit signatures and Objective-C type encodings:

```krypton
func tableRows(self, command, table) {
    emit okArrayCount(okGet(table, "demo.visible"))
}

func tableCell(self, command, table, column, row) {
    emit okArrayGet(okGet(table, "demo.visible"), row)
}

let sourceClass = okClass("KryptonTableSource")
okMethod(sourceClass, "numberOfRowsInTableView:", funcptr(tableRows), "q@:@")
okMethod(sourceClass, "tableView:objectValueForTableColumn:row:", funcptr(tableCell), "@@:@@q")
okRegister(sourceClass)
let source = okNew(sourceClass)
okDataSource(table, source)
```

`okClass`, `okMethod`, `okRegister`, and `okNew` synthesize an Objective-C class
at runtime. This is macOS-specific. `okMethod` returns `"0"` on failure instead
of claiming success. Existing methods are not replaced. The callback signature
and type encoding are the caller's responsibility.

### Keyboard hook

```krypton
func tableKey(table, event) {
    let code = okKeyCode(event)
    if code == 53 {          // Escape
        okSelectNone(table)
        emit 1
    }
    if code == 36 {          // Return
        let selection = okSelection(table)
        if okSelectionCount(selection) > 0 {
            let row = okSelectionAt(selection, 0)
            print(row)
        }
        emit 1
    }
    emit 0                   // keep native arrows and type selection
}
```

`okOnKeyDown(table, funcptr(handler))` affects only that table. Return `1` to
consume, `0` to preserve NSTableView behavior. Key codes and modifier masks are
macOS event values, not portable constants. Do not keep an event beyond callback
scope.

### Live text changes

`okFieldOnChange(field, funcptr(handler))` installs an owned native text
delegate. The handler receives `(field)`, returns ignored, and should read
`okText(field)`. It does not replace the field's target/action, so Return
actions can remain separate. If a foreign delegate is installed, registration
returns `"0"` and leaves it alone. Passing `0` detaches.

## K-owned object model

Import `k:objk_runtime_macos` for direct runtime calls. Compiler `objk`
declarations auto-import it.

### Compiler declarations

```krypton
objk protocol Scoreable {
    require score() -> int
}

objk object Counter conforms Scoreable {
    method score() -> int = counterScore
}

func counterScore(runtime, self) {
    emit okKGet(runtime, self, "score")
}

just run {
    let counter = okKNew(__objkRuntime, Counter)
    doKSet(__objkRuntime, counter, "score", 42)
    print(okKSend(__objkRuntime, counter, "score"))
    doKRelease(__objkRuntime, counter)
}
```

Rules:

- One `extends` parent; one `conforms` protocol.
- 0..2 named, typed user arguments.
- Types: `any`, `do`, `int`/`integer`, `text`, or a previously declared
  object/protocol handle.
- Methods bind to ordinary functions with `(runtime, self)` before user args.
- Generated entry locals: `__objkRuntime` and each declaration name.
- Declarations currently belong in executable entry source. Imported modules
  should use direct runtime APIs.
- Inline method bodies, fields in declarations, ownership annotations,
  multiple conformances, and compile-time send checking are not implemented.
- Runtime checks are not compiler type checking and not automatic reference
  counting.

### Direct runtime

```krypton
import "k:objk_runtime_macos"

func value(runtime, self) {
    emit okKGet(runtime, self, "value")
}

just run {
    let runtime = okKRuntime(65536)
    let counter = okKClass(runtime, "Counter", 0)
    okKMethod(runtime, counter, "value", 0, funcptr(value))
    doKRegister(runtime, counter)

    let object = okKNew(runtime, counter)
    doKSet(runtime, object, "value", 42)
    print(okKSend(runtime, object, "value"))
    doKRelease(runtime, object)
}
```

`okKRuntime(capacity)` accepts 64..1048576 bytes. Keep the runtime buffer
reachable for every handle's lifetime. Handles are checked integer IDs, not raw
pointers. Do not mix handles from different runtimes.

### Dispatch

| Call | Use |
|---|---|
| `okKSend(runtime, obj, name)` | Zero user arguments |
| `okKSend1(runtime, obj, name, a)` | One user argument |
| `okKSend2(runtime, obj, name, a, b)` | Two user arguments |
| `okKSuper(runtime, obj, definingClass, name)` | Zero-argument super dispatch |
| `okKResponds(runtime, obj, name)` | Method lookup |
| `okKIsA(runtime, obj, class)` | Ancestry check |

Missing methods and wrong argument counts exit with an `Objective-K:`
diagnostic. Method callbacks are `(runtime, self, ...)` and the code pointer
must remain valid.

### Typed method contracts

```krypton
okKTypedMethod(runtime, klass, name, arity, funcptr(handler),
               firstType, secondType, resultType)
```

Constraints can be `okKTypeInteger()`, `okKTypeText()`, a class handle, a
sealed protocol handle, or `0` for unconstrained. Checks run before the callback
and after its result. Calls remain borrowed; no retain/release is added. This is
runtime checking, not compiler type checking or pointer-signature validation.

`okKObjectMethod` is a compatible alias for object-class constraints.

### Fields and ownership

| Call | Contract |
|---|---|
| `doKSet(runtime, obj, name, value)` | Borrowed integer/arena handle |
| `doKOwn(runtime, obj, name, child)` | Retain child; release previous; `0` clears |
| `doKWeak(runtime, obj, name, target)` | No retain; reads `0` after release |
| `okKText(runtime, text)` | Copy text into arena; one reference |
| `okKTextValue(runtime, textId)` | Read copied text |
| `doKText(runtime, obj, name, text)` | Own arena text in a field |
| `okKRetainText` / `doKReleaseText` / `okKTextRefCount` | Text references |
| `okKHas` / `okKGet` | Distinguish absent field from stored `0` / read |
| `okKRetain` / `doKRelease` / `okKRefCount` | Object references |

Fields hold integers in `[-1000000000, 1000000000]` or arena handles. Each new
object starts with reference count `1`. Final release tombstones the object;
later field access, messages, retain, or release are rejected.

Owned/weak fields keep their policy. Update them with `doKOwn`/`doKWeak`, not
`doKSet`. Assigning a borrowed slot with either reference API establishes its
policy. Strong cycles are not collected; break them explicitly or use weak
links.

```krypton
doKOwn(runtime, parent, "child", child)
doKWeak(runtime, child, "parent", parent)
doKRelease(runtime, child)
doKRelease(runtime, parent)
```

### Cleanup

```krypton
func modelCleanup(runtime, self) {
    // release external resources here
    emit 0
}

doKCleanup(runtime, klass, funcptr(modelCleanup))
```

Register before `doKRegister`. One cleanup hook per class. Final release runs
the most-derived hook first, then parent hooks, then releases owned children and
reclaims storage. During cleanup, reads work and owned children remain alive;
mutations and retain/release are rejected. Do not manually invoke parent
cleanup.

### Protocols

```krypton
func answer(runtime, self) { emit 42 }

just run {
    let runtime = okKRuntime(4096)
    let readable = okKProtocol(runtime, "Readable", 0)
    doKRequireMethod(runtime, readable, "answer", 0, 0, 0, 0)
    doKRegisterProtocol(runtime, readable)

    let model = okKClass(runtime, "Model", 0)
    okKMethod(runtime, model, "answer", 0, funcptr(answer))
    doKConform(runtime, model, readable)
    doKRegister(runtime, model)

    let object = okKNew(runtime, model)
    print(okKConforms(runtime, object, readable))
    print(okKSend(runtime, object, "answer"))
    doKRelease(runtime, object)
}
```

Sealing checks required methods, arity, and exact class constraints using
effective inherited lookup. Subclass sealing rechecks inherited conformance.
Matching methods alone do not confer adoption; call `doKConform`. This is not
Objective-C protocol interop.

## macOS process capture

Import `k:objk_process_macos` for synchronous Foundation-backed process calls.

```krypton
import "k:objk_process_macos"

just run {
    let pool = newPool()
    let args = okProcessArgs()
    doProcessArg(args, "a b")
    let result = okRunArgvCaptured("/bin/echo", args)
    print(result)          // "0\na b\n"
    drainPool(pool)
}
```

- `executable` is a path, not a PATH lookup or shell command.
- Args are literal; add each separately.
- Result is `<status>\n<combined stdout/stderr>`.
- `okRunCaptured(cmd)` explicitly uses `/bin/sh -c`.
- Calls block and buffer output. Do not run them on the GUI main thread for
  long-running work.

## Windows: same shape, different backend

Windows uses `k:okui` too. `stdlib/okui_win.k` routes through `k:objkwin` and
`k:choc` (Win32). The app-facing words are similar, but the implementations and
limits differ.

| Area | macOS | Windows |
|---|---|---|
| Backend | AppKit/Foundation/libobjc via `k:choc_macos` | Win32 via `k:choc`/`k:objkwin` |
| K-owned runtime | `k:objk_runtime_macos` | Not available in this stage |
| Tables | NSTableView; data source/delegate, NSIndexSet selection, key hook | `chocList`; simpler list control |
| Menus | `okMenuSelector` uses AppKit selectors; `okMenuAction` callbacks | `okMenuAction`/`chocMenuAction`; selector calls are stubs |
| Custom classes/views | `okClass`/`okMethod`/`okRegister`/`okNew`, `okCustomView` | Stubs; use `k:gui`/Choc controls |
| Window helpers | `okMinSize`, `okMakeFirstResponder`, split view, frame/tooltip/editable | Several are no-ops or limited |
| Colors | Native color handles | `okRGB` returns `0xRRGGBB` |
| Arrays | NSArray/native handles | State-list handles |
| Defaults/clipboard | NSUserDefaults/NSPasteboard | Partial/no-op in `objkwin.k` |
| Build command | `./bootstrap/kcc_driver_macos_aarch64` | `kcc.exe` |

Do not import `k:objk_runtime_macos` on Windows. Do not assume NSIndexSet,
NSArray, selector strings, or Objective-C class synthesis on Windows.

Portable app skeleton:

```krypton
import "k:okui"

func onSave(self, cmd, sender) {
    let win = sender
    let status = okGet(win, "app.status")
    okSetText(status, "Saved")
    emit "1"
}

just run {
    let app = okApp()
    let win = okWindow(app, "Portable Objective-K", 520, 260)
    let status = okLabel(win, "Ready", 24, 24, 300, 24)
    let save = okButton(win, "Save", 24, 70, 120, 32)
    okSet(save, "app.status", status)
    okClick(save, funcptr(onSave))
    okShow(win, app)
    okRun(app)
}
```

On macOS, add the autorelease pool and any AppKit-specific tables, key hooks,
or live-field delegates. On Windows, keep to controls and callbacks that
`objkwin.k` implements, or branch to `k:gui`/Choc.

## Examples and references

Runnable source:

- `tutorial/macos/01_live_field.ks` — live field
- `tutorial/macos/02_owned_model.k` — K-owned model, no GUI
- `examples/objk/table_filter.ks` — table, filter, selection, keyboard
- `examples/objk/human_ui.ks` — readable layout words
- `examples/objk/k_owned_counter_macos.ks` — K-owned model + native controls
- `examples/objk/controls.ks` — `ok*` controls
- `examples/objk/windows_controls.ks` — Windows `ok*` controls
- `examples/objk/objective_k_focus.ks` — protocols, ownership, cleanup

Docs:

- `docs/objective_k.md`
- `docs/objk_runtime_macos.md`
- `docs/objk_appkit_events_macos.md`
- `docs/spec/gui.md`
- `spec.md`

## Objective-K rules

1. Use `k:okui` for app code. Use `k:objk_runtime_macos` only on macOS.
2. Keep native handles native. Never stringify them or store them in K-owned
   integer fields.
3. Use `funcptr(namedFunction)`. No closures or captured locals.
4. Match the callback signature to the registration exactly.
5. Run UI work on the main thread. Keep callbacks short.
6. Balance object retain/release. Break cycles with weak links or `doKOwn(..., 0)`.
7. Keep the runtime arena reachable for all handle lifetimes.
8. Do not mix handles from different runtimes.
9. Test the exact checkout and release. Published 2.4.8 lacks the new AppKit
   APIs.
10. Do not claim Windows parity for macOS-only APIs.
