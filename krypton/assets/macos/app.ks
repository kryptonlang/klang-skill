import "k:okui"

func skillFieldChanged(field) {
    let label = okGet(field, "skill.label")
    okSetText(label, okText(field))
    emit 0
}

func skillClear(self, command, sender) {
    let field = okGet(sender, "skill.field")
    okSetText(field, "")
    skillFieldChanged(field)
    emit 0
}

just run {
    let pool = okAutoreleasePool()
    let application = okApp()
    let win = okWindow(application, "Krypton", 520, 220)
    okMinSize(win, 360, 220)
    okSetWindowBg(win, okSystemWindowBg())
    let bar = okMenuBar(application)
    let applicationMenu = okMenuAdd(bar, "Krypton")
    okMenuSelector(applicationMenu, "Quit", "q", "terminate:")
    let editMenu = okMenuAdd(bar, "Edit")
    okMenuSelector(editMenu, "Cut", "x", "cut:")
    okMenuSelector(editMenu, "Copy", "c", "copy:")
    okMenuSelector(editMenu, "Paste", "v", "paste:")
    okMenuSelector(editMenu, "Select All", "a", "selectAll:")
    let field = okField(win, 24, 140, 472, 28)
    let label = okLabel(win, "", 24, 90, 472, 28)
    let clearButton = okButton(win, "Clear", 24, 32, 96, 30)
    okPlaceholder(field, "Name")
    okSetTextColor(field, okSystemText())
    okSetTextColor(label, okSystemSecondaryText())
    okAutoresizing(field, 2)
    okAutoresizing(label, 2)
    okSet(field, "skill.label", label)
    okSet(clearButton, "skill.field", field)
    if okFieldOnChange(field, funcptr(skillFieldChanged)) == "0" {
        print("[FAIL] live field registration"); exit(1)
    }
    okClick(clearButton, funcptr(skillClear))
    okShow(win, application)
    okMakeFirstResponder(win, field)
    okRun(application)
    okDrainPool(pool)
}
