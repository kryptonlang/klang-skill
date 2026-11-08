# Current Objective-K macOS Adapter

Use for AppKit application work after reading the layer/callback boundaries in
[objective-k.md](objective-k.md). These APIs ship in released macOS arm64
2.4.9. They are not a Windows/Linux parity claim; 2.4.8 is the older release.

## Establish The Actual Toolchain

From a Krypton checkout:

```sh
export KRYPTON_ROOT="$PWD"
./bootstrap/kcc_driver_macos_aarch64 examples/objk/table_filter.ks -o /tmp/objk-table-filter
```

Inspect `stdlib/objk.k` before inventing an API. Pin the intended `KRYPTON_ROOT`
and verify the 2.4.9 driver/frontend/stdlib together; a version string alone
does not identify every selected component. Prefer explicit compilation when
separating build/run failures. Older 2.4.8 drivers can obscure run failures.

## Exact Signatures

The current rebuilt macOS driver propagates `-r`/`-e` child status/streams,
keeps `--ir` diagnostics on stderr, and preserves old output on failed builds.
Use `scripts/check_macos_driver.ks` to prove that behavior in the target checkout;
older 2.4.8 binaries do not gain it through `KRYPTON_ROOT` alone. Function-only
modules support imports/IR; only executable builds need `just run`/`go run`.
Bare `void` is invalid: use `-> do`. Keyword binding/parameter names are errors,
not contextual aliases. macOS 2.4.9 fixes native padding/arity/module
precedence and signed conversion. Sorting and lossless splitting remain open.
Release packaging must be verified separately from source tests.

For Cortex-style panes, use `okScrollFrame(document,x,y,w,h)` and
`okScrollHidden(document,hidden)` on the enclosing scroll container; non-scroll
views return "0". `okViewWidth`/`okViewHeight` use the NSRect return ABI.
`okSameHandle(a,b)` compares pointer identity; generic equality is not safe for
native pointers. `okCopyText(text)` creates an independent Krypton snapshot;
`okObjectText(object)` copies the description (nil becomes empty). Copy before
mutation/pool drain and keep snapshots rooted in stack locals/globals. Raw
`sbToString` interior pointers can be reclaimed by `gcCollect`; this is not
fixed by merely retaining the text pointer, nor do snapshots add transitive GC.

| Function | Result / constraint |
| --- | --- |
| `okColumn(table,id,title,width)` | Borrowed column; reuse `"c0"` to replace its title/width, add another id for another column. 0 rejects invalid input. |
| `okColWidth(table,id,width)` | `"1"`/`"0"`; positive integer points, subject to native min/max. |
| `okRowHeight(table,height)` | `"1"`/`"0"`; positive integer points. |
| `okOnClick(table,funcptr(fn))` | Handler **`(table)`**, ignored result; 0 detaches. |
| `okOnDoubleClick(table,funcptr(fn))` | Separate **`(table)`** handler; can coexist with single click. |
| `okOnKeyDown(table,funcptr(fn))` | Handler `(table,event)`; nonzero consumes, 0 calls the native base method. |
| `okFieldOnChange(field,funcptr(fn))` | Handler `(field)`; ignored result; 0 detaches; refuses a foreign delegate. |
| `okMenuCheck(menu,title,on)` | Set checked state by title; missing item returns `"0"`. |
| `okMenuEnabled(menu,title,on)` | Set enabled state, **turning off auto-validation for the entire menu**. Missing item returns `"0"` without that side effect. |
| `okImageView(win,x,y,w,h)` | Native aspect-preserving image view. |
| `okImageFromFile(view,path)` | `"1"` on load, `"0"` on failure; failure preserves previous image. |
| `okFrameSave(win,key)` | Store geometry in this app's defaults; no lifecycle delegate installed. |
| `okFrameRestore(win,key)` | Native success result; missing key/nil/empty key or unavailable display fails. |
| `okWindowShouldClose(win,funcptr(fn))` | Handler `(win)`; integer 1 permits user close, 0 vetoes. |
| `okWindowOnClose(win,funcptr(fn))` | Handler `(win)`; notification only, ignored result. |
| `okAppOnOpenFile(app,funcptr(fn))` | Handler `(app,pathText)`; integer 1 handled, 0 rejected. |
| `okAppOnReopen(app,funcptr(fn))` | Handler `(app,hasVisibleWindows)`; integer 1 permits AppKit default handling, 0 fully handled. |

Generic **`okClick(control,funcptr(fn))` takes `(self,command,sender)`**, unlike
`okOnClick(table,...)`. Never swap these signatures. Table hooks require an
`okTable` instance and refuse a foreign action target. Do not mix typed table
hooks with generic `okClick` or keyed `okOn` on that same table. Native
double-click processing may also produce a single action; keep single actions
non-destructive and make double actions safe to follow them.

## Native Values And Ownership

- Selection uses NSIndexSet, not a text list. `okSelection(table)` is an
  autoreleased immutable snapshot. `okSelectionNew`/`okSelectionAdd` builds a
  mutable set; `okSelectionAt` returns a row index or empty text out of range.
- `okDataSource` retains its source; passing 0 detaches. Avoid a source retaining
  its own table. Table columns and loaded images are retained by their owner.
- Event, field, and table callback arguments are borrowed. Keep work on the
  AppKit main thread, keep an autorelease pool, and do not block UI callbacks.
- `okClass`/`okViewClass` reuse pending class names created by the adapter before
  registration, reject a conflicting pending parent, and reuse registered names
  with diagnostics. `okRegister` guards conflicting handles. Native class
  creation is main-thread-only; this is not a concurrent class registry.
- Menu state uses existing titles, not menu-item ids. Renaming/removing an item
  changes lookup. Manual menu validation is a deliberate responsibility change.
- Frame helpers save/restore only geometry; lifecycle hooks are separate APIs.
  They do not add single-instance policy, bundling or notarization.

## Lifecycle Boundaries

Window hooks share one retained delegate per window; app hooks share one per
application. Pointer 0 detaches one hook; the final paired detach clears and
releases the delegate. Rebinding and callback self-detachment are supported;
foreign delegates are refused, not forwarded or overwritten. Owners retain
proxies, proxies do not retain owners. Never release an owner inside a callback.

Direct native `close` bypasses `okWindowShouldClose`; normal `performClose:`
consults it. Close notification is not a Quit/termination callback. Save on Quit
separately. To reopen the same window, retain it and set
`msg_1(win,"setReleasedWhenClosed:",0)` before closing, then use `okShow` from the
reopen handler. No automatic reconstruction or session manager is supplied.

Register app hooks before `okRun`/`okFinish` to receive launch events. Open-file
paths are borrowed UTF-8 text, not native NSString handles. Finder routing also
needs `CFBundleDocumentTypes`; these APIs do not add bundle metadata, sandbox
access, security-scoped resources, NSDocument integration, multi-file or URL
delegates. Direct delegate tests are not proof of Finder routing. Missing open
handlers reject files; missing close/reopen decision handlers allow default
behavior. Boolean callbacks must return integer 0 or 1, not arbitrary text.

## Verification And Honest Boundaries

```sh
./bootstrap/kcc_driver_macos_aarch64 -r scripts/check_objk_runtime_macos.ks
```

Native tests cover column geometry, independent actions, nil/duplicate class
guards, pending-name reuse, menu validation and image-load failure preservation.
Frame persistence needs a desktop display; tests explicitly skip it when none
is available. Check for skips and rerun with display access before claiming it
verified. Target/action tests alone do not prove real double-click gesture timing;
the two-column demo's actual single/double clicks and retained-window close/reopen
were verified separately. Open-file tests invoke the delegate directly, not Finder.

Public source docs: `docs/objective_k.md`, `docs/objk_appkit_events_macos.md`,
`docs/objk_runtime_macos.md` and `spec.md`. Local handoffs are not a public API
reference; a requested signature is not proof of implementation.

Still open unless proven in the target revision: drag/drop, termination/session
restoration, Finder document routing, async/cancellable processes, imported
`objk object`/`objk protocol`
declarations, richer source-location diagnostics, sorting and lossless
splitting. Native padding is fixed in 2.4.9. Do not add Objective-C/C source or an external compiler to hide
missing support; implement or diagnose the missing Krypton adapter/API.
