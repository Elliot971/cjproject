package cjrxtui.builtin

import cjrxtui.component.{ComponentId, Context}
import cjrxtui.component.{KeyCode, KeyEvent, KeyModifiers, UiEvent}
import cjrxtui.node.Node

@Test
func tableEnterSendsRowSelectedEvent() {
    let state = TableState(1, 0, true)
    let component = Table(
        ["Name", "Role"],
        [["Alice", "Dev"], ["Bob", "Ops"], ["Cara", "QA"]],
        [8, 8],
        20,
        5,
        "table"
    )
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Enter)), state)
    let messages = ctx.drainMessages()

    @Assert(messages.size, 1)
    if (let Some(event) <- (messages[0] as BuiltinEvent)) {
        match (event) {
            case BuiltinEvent.TableRowSelected(id, row) =>
                @Assert(id, "table")
                @Assert(row, 1)
            case _ => @Fail("expected table row selected event")
        }
    } else {
        @Fail("expected builtin event")
    }
}

@Test
func tableKeepsSelectionInViewportWhenScrolling() {
    let state = TableState()
    let component = Table(
        ["C1", "C2"],
        [["r0", "a"], ["r1", "b"], ["r2", "c"], ["r3", "d"], ["r4", "e"]],
        [6, 6],
        14,
        4,
        "table"
    )
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Focus("table"), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Down)), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Down)), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Down)), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Down)), state)

    @Assert(state.selectedRow, 4)
    @Assert(state.scrollOffset, 3)
}

@Test
func textAreaSupportsEditingAndMultilineInput() {
    let state = TextAreaState()
    let component = TextArea(10, 4, "ta")
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Focus("ta"), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Char(r'a'))), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Char(r'b'))), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Enter)), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Char(r'c'))), state)

    @Assert(state.cursorRow, 1)
    @Assert(state.cursorCol, 1)
    @Assert(state.getText(), "ab\nc")
}

@Test
func textAreaCtrlEnterSendsSubmitEvent() {
    let state = TextAreaState("hello")
    let component = TextArea(10, 4, "ta")
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Focus("ta"), state)
    let modifiers = KeyModifiers(true, false, false, false)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Enter, modifiers)), state)
    let messages = ctx.drainMessages()

    @Assert(messages.size, 1)
    if (let Some(event) <- (messages[0] as BuiltinEvent)) {
        match (event) {
            case BuiltinEvent.TextAreaSubmitted(id, text) =>
                @Assert(id, "ta")
                @Assert(text, "hello")
            case _ => @Fail("expected textarea submitted event")
        }
    } else {
        @Fail("expected builtin event")
    }
}

@Test
func selectOpenNavigateAndConfirmSendsEvent() {
    let state = SelectState(0)
    let component = Select(["Apple", "Banana", "Cherry"], 14, "sel")
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Focus("sel"), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Enter)), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Down)), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Enter)), state)
    let messages = ctx.drainMessages()

    @Assert(state.selectedIndex, 1)
    @Assert(state.open, false)
    @Assert(messages.size, 1)
    if (let Some(event) <- (messages[0] as BuiltinEvent)) {
        match (event) {
            case BuiltinEvent.SelectChanged(id, index, label) =>
                @Assert(id, "sel")
                @Assert(index, 1)
                @Assert(label, "Banana")
            case _ => @Fail("expected select changed event")
        }
    } else {
        @Fail("expected builtin event")
    }
}

@Test
func dividerRendersLabelInHorizontalMode() {
    let component = Divider(16, DividerDirection.Horizontal, "Group")
    let node = component.view(Context(ComponentId.root()), DividerState())

    match (node) {
        case DivNode(div) => match (div.childrenView[0]) {
            case TextNode(text) =>
                @Expect(text.content.contains("Group"))
            case _ => @Fail("expected divider text")
        }
        case _ => @Fail("expected divider node")
    }
}

@Test
func statusBarRendersSectionsIntoSingleLine() {
    let component = StatusBar(28, "status")
    let node = component.view(Context(ComponentId.root()), StatusBarState(["NORMAL", "users:12", "q quit"]))

    match (node) {
        case DivNode(div) => match (div.childrenView[0]) {
            case TextNode(text) =>
                @Expect(text.content.contains("NORMAL"))
                @Expect(text.content.contains("users:12"))
                @Expect(text.content.contains("q quit"))
            case _ => @Fail("expected status text")
        }
        case _ => @Fail("expected status bar node")
    }
}

@Test
func usageExampleBuildsDashboardLayoutNode() {
    let status = StatusBar(28, "status")
    let divider = Divider(28, DividerDirection.Horizontal, "Data")
    let table = Table(
        ["Name", "Value"],
        [["cpu", "12%"], ["mem", "34%"]],
        [12, 12],
        28,
        4,
        "table"
    )

    let root = Node.vstack([
        status.view(Context(ComponentId.root()), StatusBarState(["MONITOR", "F1 Help"])),
        divider.view(Context(ComponentId.root()), DividerState()),
        table.view(Context(ComponentId.root()), TableState(0, 0, true))
    ])

    match (root) {
        case DivNode(div) => @Assert(div.childrenView.size, 3)
        case _ => @Fail("expected dashboard root div")
    }
}
