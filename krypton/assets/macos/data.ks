import "k:string_utils"
import "k:url"

func skillCheck(condition, label) {
    if !condition { print("[FAIL] " + label); exit(1) }
}

just run {
    skillCheck(toInt(-15) == -15 && toInt("-15") == -15, "signed conversion")
    skillCheck(padLeft("7", 4, "0") == "0007", "padding")
    skillCheck(padRight("x", 4, "ab") == "xaba", "partial padding")
    skillCheck(padLeft("x", 4, "") == "x", "empty padding")
    skillCheck(urlEncode("hi mom") == "hi%20mom", "URL encoding")
    skillCheck(urlBuild("/api", "q=hi mom") == "/api?q=hi+mom", "URL query")
    let builder = sbNew()
    builder = sbAppend(builder, "1")
    builder = sbAppend(builder, "0")
    skillCheck(sbToString(builder) == "10", "exact text")
    let bytes = bufNew(4)
    bufSetByte(bytes, 0, 65)
    bufSetByte(bytes, 1, 0)
    bufSetByte(bytes, 2, 66)
    skillCheck(bufGetByte(bytes, 1) == 0 && bufGetByte(bytes, 2) == 66, "binary NUL")
    print("[PASS] skill data")
}
