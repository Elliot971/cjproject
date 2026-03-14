package cjrxtui.builtin

import cjrxtui.component.{KeyCode, KeyEvent, MouseButton, MouseEvent, MouseEventKind, UiEvent}
import cjrxtui.component.{ComponentId, Context}
import cjrxtui.node.Node

@Test
func scrollableRespondsToKeyboardAndMouseScrolling() {
    let state = ScrollableState()
    let component = Scrollable(["a", "b", "c", "d", "e"], 10, 2, "scroll")
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Focus("scroll"), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Down)), state)
    let _ = component.update(ctx, UiEvent.Mouse(MouseEvent(0, 0, MouseEventKind.ScrollDown)), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.End)), state)

    @Assert(state.offset, 3)
}

@Test
func scrollableViewShowsWindowFromOffset() {
    let state = ScrollableState(1, true)
    let component = Scrollable(["one", "two", "three"], 10, 2, "scroll")
    let ctx = Context(ComponentId.root())
    let node = component.view(ctx, state)

    match (node) {
        case DivNode(div) =>
            @Assert(div.childrenView.size, 2)
            match (div.childrenView[0]) {
                case TextNode(text) => @Assert(text.content, "|two                   ^")
                case _ => @Fail("expected first visible text")
            }
            match (div.childrenView[1]) {
                case TextNode(text) => @Assert(text.content, "|three                 |")
                case _ => @Fail("expected second visible text")
            }
        case _ => @Fail("expected scrollable div")
    }
}

@Test
func listMaintainsSelectionVisibility() {
    let state = ListState()
    let component = List(["a", "b", "c", "d", "e"], 12, 2, "list")
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Focus("list"), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Down)), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Down)), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Down)), state)

    @Assert(state.selectedIndex, 3)
    @Assert(state.scrollOffset, 2)
}

@Test
func listViewMarksSelectedItem() {
    let state = ListState(1, 0, true)
    let component = List(["alpha", "beta", "gamma"], 12, 3, "list")
    let ctx = Context(ComponentId.root())
    let node = component.view(ctx, state)

    match (node) {
        case DivNode(div) =>
            match (div.childrenView[1]) {
                case DivNode(row) => match (row.childrenView[0]) {
                    case TextNode(text) => @Assert(text.content, "> beta <")
                    case _ => @Fail("expected selected list text")
                }
                case _ => @Fail("expected selected list line")
            }
        case _ => @Fail("expected list div")
    }
}

@Test
func listClickSelectsTargetItem() {
    let state = ListState()
    let component = List(["alpha", "beta", "gamma"], 12, 3, "list")
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Click("list.item.2", MouseEvent(0, 2, MouseEventKind.Down(MouseButton.Left))), state)

    @Assert(state.selectedIndex, 2)
    @Assert(state.focused, true)
}

@Test
func listEnterSendsSelectionEvent() {
    let state = ListState(1, 0, true)
    let component = List(["alpha", "beta", "gamma"], 12, 3, "list")
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Enter)), state)
    let messages = ctx.drainMessages()

    @Assert(messages.size, 1)
    if (let Some(event) <- (messages[0] as BuiltinEvent)) {
        match (event) {
            case BuiltinEvent.ListItemSelected(id, index, label) =>
                @Assert(id, "list")
                @Assert(index, 1)
                @Assert(label, "beta")
            case BuiltinEvent.TextInputSubmitted(_, _) => @Fail("expected list selection event")
            case BuiltinEvent.ButtonPressed(_, _) => @Fail("expected list selection event")
            case BuiltinEvent.CheckboxChanged(_, _) => @Fail("expected list selection event")
            case BuiltinEvent.RadioChanged(_, _, _) => @Fail("expected list selection event")
            case BuiltinEvent.TabChanged(_, _, _) => @Fail("expected list selection event")
            case BuiltinEvent.ModalDismissed(_) => @Fail("expected list selection event")
        }
    } else {
        @Fail("expected builtin event")
    }
}

@Test
func textInputEditsAndMovesCursor() {
    let state = TextInputState()
    let component = TextInput(6, "input", "hint")
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Focus("input"), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Char(r'a'))), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Char(r'b'))), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Left)), state)
    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Char(r'X'))), state)

    @Assert(state.value, "aXb")
    @Assert(state.cursor, 2)
}

@Test
func textInputViewShowsCursorAndScrollsWindow() {
    let state = TextInputState("abcdef", 6, true, 0)
    let component = TextInput(4, "input", "")
    let ctx = Context(ComponentId.root())
    let _ = component.update(ctx, UiEvent.Focus("input"), state)
    let node = component.view(ctx, state)

    match (node) {
        case DivNode(div) =>
            match (div.childrenView[0]) {
                case DivNode(row) =>
                    match (row.childrenView[0]) {
                        case DivNode(cell) => match (cell.childrenView[0]) {
                            case TextNode(text) => @Assert(text.content, "d")
                            case _ => @Fail("expected first cell text")
                        }
                        case _ => @Fail("expected first cell")
                    }
                    match (row.childrenView[3]) {
                        case DivNode(cell) => match (cell.childrenView[0]) {
                            case TextNode(text) => @Assert(text.content, "|")
                            case _ => @Fail("expected cursor cell text")
                        }
                        case _ => @Fail("expected cursor cell")
                    }
                case _ => @Fail("expected text input display")
            }
        case _ => @Fail("expected text input div")
    }
}

@Test
func textInputShowsPlaceholderWhenEmptyAndBlurred() {
    let state = TextInputState()
    let component = TextInput(10, "input", "hint")
    let ctx = Context(ComponentId.root())
    let node = component.view(ctx, state)

    match (node) {
        case DivNode(div) =>
            match (div.childrenView[0]) {
                case DivNode(row) => match (row.childrenView[0]) {
                    case DivNode(cell) => match (cell.childrenView[0]) {
                        case TextNode(text) => @Assert(text.content, "<")
                        case _ => @Fail("expected placeholder cell text")
                    }
                    case _ => @Fail("expected placeholder cell")
                }
                case _ => @Fail("expected placeholder text")
            }
        case _ => @Fail("expected text input div")
    }
}

@Test
func textInputClickMovesCursorToSlot() {
    let state = TextInputState("abcdef", 6, false, 0)
    let component = TextInput(6, "input", "")
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Click("input.slot.2", MouseEvent(2, 0, MouseEventKind.Down(MouseButton.Left))), state)

    @Assert(state.focused, true)
    @Assert(state.cursor, 2)
}

@Test
func textInputEnterSendsSubmitEvent() {
    let state = TextInputState("draft", 5, true, 0)
    let component = TextInput(10, "input", "")
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Enter)), state)
    let messages = ctx.drainMessages()

    @Assert(messages.size, 1)
    if (let Some(submitted) <- (messages[0] as BuiltinEvent)) {
        match (submitted) {
            case BuiltinEvent.TextInputSubmitted(id, value) =>
                @Assert(id, "input")
                @Assert(value, "draft")
            case BuiltinEvent.ListItemSelected(_, _, _) => @Fail("expected submitted event")
            case BuiltinEvent.ButtonPressed(_, _) => @Fail("expected submitted event")
            case BuiltinEvent.CheckboxChanged(_, _) => @Fail("expected submitted event")
            case BuiltinEvent.RadioChanged(_, _, _) => @Fail("expected submitted event")
            case BuiltinEvent.TabChanged(_, _, _) => @Fail("expected submitted event")
            case BuiltinEvent.ModalDismissed(_) => @Fail("expected submitted event")
        }
    } else {
        @Fail("expected submitted event")
    }
}

@Test
func labelRendersFixedWidthText() {
    let component = Label("hello", 8)
    let node = component.view(Context(ComponentId.root()), LabelState())

    match (node) {
        case TextNode(text) => @Assert(text.content, "hello   ")
        case _ => @Fail("expected label text node")
    }
}

@Test
func buttonEnterSendsPressedEvent() {
    let state = ButtonState(true, false)
    let component = Button("Save", 12, "save-btn")
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Enter)), state)
    let messages = ctx.drainMessages()

    @Assert(messages.size, 1)
    if (let Some(event) <- (messages[0] as BuiltinEvent)) {
        match (event) {
            case BuiltinEvent.ButtonPressed(id, label) =>
                @Assert(id, "save-btn")
                @Assert(label, "Save")
            case _ => @Fail("expected button pressed event")
        }
    } else {
        @Fail("expected builtin event")
    }
}

@Test
func progressBarRendersPercentage() {
    let component = ProgressBar(12, 100, "progress")
    let node = component.view(Context(ComponentId.root()), ProgressBarState(50))

    match (node) {
        case DivNode(div) => match (div.childrenView[0]) {
            case TextNode(text) => @Expect(text.content.contains("50%"))
            case _ => @Fail("expected progress text")
        }
        case _ => @Fail("expected progress div")
    }
}

@Test
func checkboxToggleSendsChangedEvent() {
    let state = CheckboxState(false, true)
    let component = Checkbox("Enable logs", 16, "checkbox")
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Enter)), state)
    let messages = ctx.drainMessages()

    @Assert(state.checked, true)
    @Assert(messages.size, 1)
}

@Test
func radioEnterSendsSelectionEvent() {
    let state = RadioState(1, true)
    let component = Radio(["A", "B", "C"], 12, "radio")
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Enter)), state)
    let messages = ctx.drainMessages()

    @Assert(messages.size, 1)
}

@Test
func tabsMoveSelectionRight() {
    let state = TabsState(0, true)
    let component = Tabs(["Home", "Logs", "Help"], 18, "tabs")
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Right)), state)

    @Assert(state.selectedIndex, 1)
}

@Test
func spinnerAdvancesOnTick() {
    let state = SpinnerState(0)
    let component = Spinner("Loading", 12, "spinner")
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Tick, state)

    @Assert(state.frameIndex, 1)
}

@Test
func modalDismissesOnEscape() {
    let state = ModalState(true, true)
    let component = Modal("Alert", ["Danger zone"], 20, 4, "modal")
    let ctx = Context(ComponentId.root())

    let _ = component.update(ctx, UiEvent.Key(KeyEvent(KeyCode.Esc)), state)
    let messages = ctx.drainMessages()

    @Assert(state.open, false)
    @Assert(messages.size, 1)
}
