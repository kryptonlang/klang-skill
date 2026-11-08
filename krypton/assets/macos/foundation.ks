import "k:objk"

let skillSavedText = ""

func skillSnapshot() {
    let pool = okAutoreleasePool()
    let snapshot = okObjectText(nsString("retained native text"))
    okDrainPool(pool)
    emit snapshot
}

just run {
    skillSavedText = skillSnapshot()
    gcCollect()
    let i = 0
    while i < 100 {
        let builder = sbNew()
        builder = sbAppend(builder, "reused buffer")
        i += 1
    }
    if skillSavedText != "retained native text" || okObjectText(0) != "" {
        print("[FAIL] independent text snapshot"); exit(1)
    }
    let pool = okAutoreleasePool()
    let first = allocInit("NSObject")
    let second = allocInit("NSObject")
    if !okSameHandle(first, first) || okSameHandle(first, second) {
        print("[FAIL] native identity"); exit(1)
    }
    msg(first, "release")
    msg(second, "release")
    okDrainPool(pool)
    print("[PASS] skill foundation")
}
