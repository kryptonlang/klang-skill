objk protocol SkillReadable {
    require value() -> int
}

objk object SkillCounter conforms SkillReadable {
    method value() -> int = skillCounterValue
}

func skillCounterValue(runtime, self) {
    emit okKGet(runtime, self, "value")
}

just run {
    let object = okKNew(__objkRuntime, SkillCounter)
    doKSet(__objkRuntime, object, "value", 42)
    if okKSend(__objkRuntime, object, "value") != 42 {
        print("[FAIL] model dispatch"); exit(1)
    }
    if okKConforms(__objkRuntime, object, SkillReadable) != 1 {
        print("[FAIL] model conformance"); exit(1)
    }
    doKText(__objkRuntime, object, "title", "Counter")
    if okKTextValue(__objkRuntime, okKGet(__objkRuntime, object, "title")) != "Counter" {
        print("[FAIL] model text ownership"); exit(1)
    }
    doKRelease(__objkRuntime, object)
    if argCount() > 0 && arg(0) == "--released" { okKAlive(__objkRuntime, object) }
    print("[PASS] skill model")
}
