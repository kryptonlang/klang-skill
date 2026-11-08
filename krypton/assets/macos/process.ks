import "k:objk_process_macos"

just run {
    let pool = newPool()
    let args = okProcessArgs()
    doProcessArg(args, "%s")
    doProcessArg(args, "a b; $(not-a-command)")
    let result = okRunArgvCaptured("/usr/bin/printf", args)
    if result != "0\na b; $(not-a-command)" {
        print("[FAIL] literal argv capture"); exit(1)
    }
    let absent = okRunArgvCaptured("/krypton-skill-no-such-program", okProcessArgs())
    if !startsWith(absent, "-1\n") {
        print("[FAIL] launch failure"); exit(1)
    }
    drainPool(pool)
    print("[PASS] skill process")
}
