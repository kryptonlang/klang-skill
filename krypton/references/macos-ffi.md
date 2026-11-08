# macOS Native ABI And New Bindings

Use only when the high-level `k:okui`/`k:objk` adapter lacks the required API.
Baseline: ARM64 Mach-O 2.4.9; do not generalize its register ABI to Intel,
Windows, Linux or arbitrary structures.

## Find The Existing Boundary

Application -> `k:okui`/`k:objk` -> Krypton macOS adapter -> Apple's ABI and
system frameworks. Implementation remains Krypton. Calling system dylibs is
allowed; writing/compiling Objective-C or C is not the replacement strategy.

Inspect only the relevant facade function, `stdlib/objc.k`, `headers/objc.krh`
or the named platform header, then the matching lowering in
`compiler/macos_arm64/macho_arm64_self.k`. Read `tests/macos/test_objk_graphics_abi.k`
and `test_callptr.k` for existing regression patterns.

```krypton
import "k:objc"
just run {
    let pool = newPool()
    let value = nsString("hello")
    print(nsToStr(value))
    drainPool(pool)
}
```

`cls(name)` looks up a native class; `sel(name)` creates a selector handle.
`msg` helpers accept a **selector-name string**, not the result of `sel`.
`nsString(text)` returns an autoreleased NSString. `nsToStr(object)` borrows
the object's description UTF-8; nil becomes empty text. Copy before pool drain
with `okObjectText`, or `okCopyText` for already-borrowed UTF-8.

## Exact Message Forms

These are library helper signatures; they do not infer an Objective-C method's
types. Verify the actual target method's ABI before selecting one.

| Helper | Shape / limitation |
| --- | --- |
| `msg(obj,name)` | No explicit argument; object/integer/pointer-register result |
| `msg_1` through `msg_6` | 1..6 explicit integer/object/pointer arguments |
| `msg_frame(obj,name,x,y,w,h)` | NSRect argument in floating-point registers |
| `msg_rect(obj,name,x,y,w,h,mask,backing,deferF)` | Window initializer's NSRect plus trailing integer arguments |
| `msg_d1(obj,name,n)` | One integer converted to CGFloat |
| `msg_d2(obj,name,a,b)` | Two converted coordinates, e.g. point/size |
| `msg_d3(obj,name,a,b,c)` | Three converted CGFloat values |
| `msg_rectp(obj,name,x,y,w,h,p)` | NSRect plus pointer argument |
| `msg_pd1(obj,name,p,n)` | Pointer plus converted CGFloat |
| `msg_rounded(obj,name,x,y,w,h,rx,ry)` | Rounded-path rect and radii |
| `msg_rgb(obj,name,r,g,b)` | RGB integers 0..255, opaque alpha |
| `msg_rgba(obj,name,r,g,b,a)` | RGBA integers 0..255, **not alpha 0..1** |
| `msg_timer(obj,name,ms,target,actionName,info,repeats)` | Milliseconds converted to seconds, named action selector |
| `msgPointX/Y(obj,name,relativeTo)` | Point-return message with pointer argument; chosen component converted to integer |
| `msgRectWidth/Height(obj,name)` | NSRect-return message; chosen dimension converted to integer |

On ARM64, these point/rect homogeneous-floating-aggregate returns use d0..d3,
not a raw integer/pointer result. The component helpers truncate to integers;
they are not complete struct values or lossless fractional geometry.

The CGFloat argument helpers convert native integer values, not arbitrary
Krypton float boxes. A name such as `msg_fp` being declared does **not** prove
arbitrary floating returns are correctly lowered. Inspect/test that exact form;
do not substitute `msg` for a floating/struct-returning method or assume all
mixed-register permutations exist.

`okRGBA`, `okPathMove`, `okPathLine`, `okRoundedPath`, `okGradient`,
`okGradientPath`, `okImage`, `okImageBegin/End`, `okImagePNG` and graphics-state
helpers cover existing drawing paths. Balance drawing contexts, graphics saves
and native object ownership; do not introduce a Clang icon-rendering helper.

## Native Classes And Callbacks

`okClass`/`okViewClass` allocate or reuse native classes. Add methods with
`okMethod(class,selectorName,funcptr(handler),encoding)`, check the result,
register with `okRegister`, then instantiate with `okNew`. Pending names are
tracked; a conflicting superclass or registration fails. Native class creation
is main-thread-only. Existing methods are not automatically replaced.

Native IMP callbacks receive `(self,command,...)`; a table data source method
therefore receives `(self,command,table,...)`. This differs from typed facade
events such as `(table,event)` and K-owned `(runtime,self,...)` methods.
Encodings such as `q@:@` and `@@:@@q` are ABI contracts, not comments. A wrong
encoding, argument count or result convention can crash outside Krypton checks.
Do not register an ordinary integer-returning function for an unimplemented
floating/vector/struct-return callback ABI.

`callPtr(pointer,...)` supports zero through eight Krypton arguments on this
macOS baseline. Null pointers trap before invocation. A nonzero arbitrary
pointer is not necessarily executable, owned or type-safe. This is not a
universal callback bridge or a substitute for a foreign-call ABI form.

## Adding A Foreign Function

1. Confirm Apple's documented signature, availability, ownership, pointer and
   buffer lengths, integer widths and framework. Use Apple's docs/SDK headers.
2. Add a `jxt { func Name(...) }` declaration to the correct `.krh` only if
   absent. A header contains Krypton declarations, not C source.
3. Check the emitter's symbol-to-dylib allowlist, argument limits/register
   lowering, result convention and instruction counts. New headers alone do
   not implement imports. Unknown Objective-C ABI suffixes must diagnose rather
   than silently using the wrong convention.
4. Keep runtime/app helpers in an appropriately macOS-named module. Preserve
   public names/compatibility or update every caller deliberately. Do not add
   an unrelated platform's DLL import to fix a missing macOS symbol.
5. Use synthetic known-answer tests, boundary/failure paths and `otool -L`.
   Rebuild the native backend/frontend only when their implementation changed;
   a stdlib-only addition does not justify replacing release binaries.

Observe actual diagnostics. Unsupported arity, framework imports, blocks,
variadic methods, general structures and automatic signature checking are not
capabilities to assume. If missing support is out of scope, identify it instead
of writing an Objective-C/C shim.
