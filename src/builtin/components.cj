package cjrxtui.builtin

import std.convert.*
import cjrxtui.component.{Action, Component, Context, KeyCode, Message, MouseEventKind, State, UiEvent}
import cjrxtui.node.{Div, Node}
import cjrxtui.style.{Border, BorderStyle, Color, Dimension, Direction, SpinnerType, Style, TextStyle}

public enum BuiltinEvent <: Message {
    | ListItemSelected(String, Int64, String)
    | TextInputSubmitted(String, String)
    | ButtonPressed(String, String)
    | CheckboxChanged(String, Bool)
    | RadioChanged(String, Int64, String)
    | TabChanged(String, Int64, String)
    | ModalDismissed(String)
    | TableRowSelected(String, Int64)
    | TextAreaSubmitted(String, String)
    | SelectChanged(String, Int64, String)
}

public class CheckboxState <: State {
    public var checked: Bool
    public var focused: Bool

    public init() {
        checked = false
        focused = false
    }

    public init(checked: Bool, focused: Bool) {
        this.checked = checked
        this.focused = focused
    }
}

public class RadioState <: State {
    public var selectedIndex: Int64
    public var focused: Bool

    public init() {
        selectedIndex = 0
        focused = false
    }

    public init(selectedIndex: Int64, focused: Bool) {
        this.selectedIndex = selectedIndex
        this.focused = focused
    }
}

public class TabsState <: State {
    public var selectedIndex: Int64
    public var focused: Bool

    public init() {
        selectedIndex = 0
        focused = false
    }

    public init(selectedIndex: Int64, focused: Bool) {
        this.selectedIndex = selectedIndex
        this.focused = focused
    }
}

public class SpinnerState <: State {
    public var frameIndex: Int64

    public init() {
        frameIndex = 0
    }

    public init(frameIndex: Int64) {
        this.frameIndex = frameIndex
    }
}

public class ModalState <: State {
    public var open: Bool
    public var focused: Bool

    public init() {
        open = true
        focused = false
    }

    public init(open: Bool, focused: Bool) {
        this.open = open
        this.focused = focused
    }
}

public class ButtonState <: State {
    public var focused: Bool
    public var pressed: Bool

    public init() {
        focused = false
        pressed = false
    }

    public init(focused: Bool, pressed: Bool) {
        this.focused = focused
        this.pressed = pressed
    }
}

public class LabelState <: State {
    public init() {}
}

public class ProgressBarState <: State {
    public var value: Int64

    public init() {
        value = 0
    }

    public init(value: Int64) {
        this.value = value
    }
}

public class FormState <: State {
    public let activeField: Int64

    public init() {
        activeField = 0
    }

    public init(activeField: Int64) {
        this.activeField = activeField
    }
}

public class ScrollableState <: State {
    public var offset: Int64
    public var focused: Bool

    public init() {
        offset = 0
        focused = false
    }

    public init(offset: Int64, focused: Bool) {
        this.offset = offset
        this.focused = focused
    }
}

public class Scrollable <: Component {
    private let lines: Array<String>
    private let width: Int64
    private let height: Int64
    private let id: String

    public init(lines: Array<String>, width: Int64, height: Int64) {
        this.lines = lines
        this.width = width
        this.height = height
        this.id = "scrollable"
    }

    public init(lines: Array<String>, width: Int64, height: Int64, id: String) {
        this.lines = lines
        this.width = width
        this.height = height
        this.id = id
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let _ = ctx
        let scrollState = (state as ScrollableState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            applyScrollableEvent(scrollState, event, id, maxScrollOffset(lines.size, height), height)
        }
        Action.update(scrollState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let scrollState = (state as ScrollableState).getOrThrow()
        let container = Div()
            .id(id)
            .focusable()
            .width(Dimension.Fixed(width))
            .height(Dimension.Fixed(height))
            .style(scrollableContainerStyle(scrollState.focused))

        for (line in visibleScrollableLines(lines, scrollState.offset, height)) {
            container.child(Node.text(line, scrollableTextStyle(scrollState.focused)))
        }

        Node.div(container)
    }
}

public class ListState <: State {
    public var selectedIndex: Int64
    public var scrollOffset: Int64
    public var focused: Bool

    public init() {
        selectedIndex = 0
        scrollOffset = 0
        focused = false
    }

    public init(selectedIndex: Int64, scrollOffset: Int64, focused: Bool) {
        this.selectedIndex = selectedIndex
        this.scrollOffset = scrollOffset
        this.focused = focused
    }
}

public class List <: Component {
    private let items: Array<String>
    private let width: Int64
    private let height: Int64
    private let id: String

    public init(items: Array<String>, width: Int64, height: Int64) {
        this.items = items
        this.width = width
        this.height = height
        this.id = "list"
    }

    public init(items: Array<String>, width: Int64, height: Int64, id: String) {
        this.items = items
        this.width = width
        this.height = height
        this.id = id
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let listState = (state as ListState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            applyListEvent(ctx, listState, event, id, items, height)
        }
        Action.update(listState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let listState = (state as ListState).getOrThrow()
        let container = Div()
            .id(id)
            .focusable()
            .width(Dimension.Fixed(width))
            .height(Dimension.Fixed(height))
            .style(listContainerStyle(listState.focused))

        let visibleItems = visibleListItems(items, listState, height)
        for ((index, line) in visibleItems) {
            container.child(
                Node.div(
                    Div()
                        .id(listItemId(id, index))
                        .focusable()
                        .width(Dimension.Fixed(width))
                        .height(Dimension.Fixed(1))
                        .child(Node.text(line, listLineStyle(index == listState.selectedIndex, listState.focused)))
                )
            )
        }

        Node.div(container)
    }
}

public class TextInputState <: State {
    public var value: String
    public var cursor: Int64
    public var focused: Bool
    public var viewOffset: Int64

    public init() {
        value = ""
        cursor = 0
        focused = false
        viewOffset = 0
    }

    public init(value: String, cursor: Int64, focused: Bool, viewOffset: Int64) {
        this.value = value
        this.cursor = cursor
        this.focused = focused
        this.viewOffset = viewOffset
    }
}

public class TextInput <: Component {
    private let width: Int64
    private let id: String
    private let placeholder: String

    public init(width: Int64) {
        this.width = width
        this.id = "textinput"
        this.placeholder = ""
    }

    public init(width: Int64, id: String, placeholder: String) {
        this.width = width
        this.id = id
        this.placeholder = placeholder
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let inputState = (state as TextInputState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            applyTextInputEvent(ctx, inputState, event, id)
            normalizeTextInputWindow(inputState, width, placeholder)
        }
        Action.update(inputState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let inputState = (state as TextInputState).getOrThrow()
        let row = Div()
            .direction(Direction.Horizontal)
            .width(Dimension.Fixed(width))
            .height(Dimension.Fixed(1))

        for (cell in textInputFrame(inputState, width, placeholder, id)) {
            row.child(textInputCellNode(cell))
        }

        Node.div(
            Div()
                .id(id)
                .width(Dimension.Fixed(width))
                .height(Dimension.Fixed(1))
                .style(textInputContainerStyle(inputState.focused))
                .child(Node.div(row))
        )
    }
}

public class Label <: Component {
    private let text: String
    private let width: Int64

    public init(text: String, width: Int64) {
        this.text = text
        this.width = width
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let _ = ctx
        let _ = msg
        let labelState = (state as LabelState).getOrThrow()
        Action.update(labelState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let _ = state
        Node.text(padOrTrim(text, width), labelTextStyle())
    }
}

public class Button <: Component {
    private let label: String
    private let width: Int64
    private let id: String

    public init(label: String, width: Int64, id: String) {
        this.label = label
        this.width = width
        this.id = id
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let buttonState = (state as ButtonState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            applyButtonEvent(ctx, buttonState, event, id, label)
        }
        Action.update(buttonState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let buttonState = (state as ButtonState).getOrThrow()
        Node.div(
            Div()
                .id(id)
                .focusable()
                .width(Dimension.Fixed(width))
                .height(Dimension.Fixed(1))
                .style(buttonContainerStyle(buttonState.focused, buttonState.pressed))
                .child(Node.text(renderButtonLabel(label, width, buttonState.focused, buttonState.pressed), buttonTextStyle(buttonState.focused, buttonState.pressed)))
        )
    }
}

public class ProgressBar <: Component {
    private let width: Int64
    private let id: String
    private let maxValue: Int64

    public init(width: Int64, maxValue: Int64, id: String) {
        this.width = width
        this.maxValue = maxValue
        this.id = id
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let _ = ctx
        let _ = msg
        let progressState = (state as ProgressBarState).getOrThrow()
        progressState.value = clampInt64(progressState.value, 0, maxValue)
        Action.update(progressState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let progressState = (state as ProgressBarState).getOrThrow()
        Node.div(
            Div()
                .id(id)
                .width(Dimension.Fixed(width))
                .height(Dimension.Fixed(1))
                .style(progressBarContainerStyle())
                .child(Node.text(renderProgressBar(progressState.value, maxValue, width), progressBarTextStyle(progressState.value, maxValue)))
        )
    }
}

public class Form <: Component {
    private let title: String
    private let width: Int64
    private let id: String
    private let fields: Array<(String, Component)>

    public init(title: String, width: Int64, id: String, fields: Array<(String, Component)>) {
        this.title = title
        this.width = width
        this.id = id
        this.fields = fields
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let formState = (state as FormState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            match (event) {
                case UiEvent.Key(keyEvent) =>
                    match (keyEvent.code) {
                        case KeyCode.Tab =>
                            if (fields.size > 0) {
                                let nextField = (formState.activeField + 1) % fields.size
                                let (fieldId, _) = fields[nextField]
                                ctx.focus(fieldId)
                                return Action.update(FormState(nextField))
                            }
                        case _ => ()
                    }
                case _ => ()
            }
        }
        Action.update(formState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = state
        let container = Div()
            .id(id)
            .width(Dimension.Fixed(width))
            .style(formContainerStyle())
            .child(Node.text("+" + repeatString("=", width - 2) + "+", formTitleStyle()))
            .child(Node.text("|" + padOrTrim(title, width - 2) + "|", formTitleStyle()))

        for ((label, field) in fields) {
            container.child(Node.text("| " + padOrTrim(label, width - 4) + " |", formFieldLabelStyle()))
            container.child(field.view(ctx, state))
        }
        container.child(Node.text("+" + repeatString("=", width - 2) + "+", formTitleStyle()))
        Node.div(container)
    }
}

public class Checkbox <: Component {
    private let label: String
    private let id: String
    private let width: Int64

    public init(label: String, width: Int64, id: String) {
        this.label = label
        this.width = width
        this.id = id
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let checkboxState = (state as CheckboxState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            applyCheckboxEvent(ctx, checkboxState, event, id)
        }
        Action.update(checkboxState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let checkboxState = (state as CheckboxState).getOrThrow()
        Node.div(
            Div()
                .id(id)
                .focusable()
                .width(Dimension.Fixed(width))
                .height(Dimension.Fixed(1))
                .style(checkboxContainerStyle(checkboxState.focused, checkboxState.checked))
                .child(Node.text(renderCheckboxLabel(label, width, checkboxState.checked), checkboxTextStyle(checkboxState.focused, checkboxState.checked)))
        )
    }
}

public class Radio <: Component {
    private let options: Array<String>
    private let width: Int64
    private let id: String

    public init(options: Array<String>, width: Int64, id: String) {
        this.options = options
        this.width = width
        this.id = id
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let radioState = (state as RadioState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            applyRadioEvent(ctx, radioState, event, id, options)
        }
        Action.update(radioState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let radioState = (state as RadioState).getOrThrow()
        let container = Div()
            .id(id)
            .focusable()
            .width(Dimension.Fixed(width))
            .style(radioContainerStyle(radioState.focused))

        for ((index, option) in indexedOptions(options)) {
            container.child(Node.text(renderRadioOption(option, index == radioState.selectedIndex), radioTextStyle(index == radioState.selectedIndex, radioState.focused)))
        }
        Node.div(container)
    }
}

public class Tabs <: Component {
    private let labels: Array<String>
    private let width: Int64
    private let id: String

    public init(labels: Array<String>, width: Int64, id: String) {
        this.labels = labels
        this.width = width
        this.id = id
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let tabsState = (state as TabsState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            applyTabsEvent(ctx, tabsState, event, id, labels)
        }
        Action.update(tabsState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let tabsState = (state as TabsState).getOrThrow()
        Node.div(
            Div()
                .id(id)
                .focusable()
                .width(Dimension.Fixed(width))
                .height(Dimension.Fixed(1))
                .style(tabsContainerStyle(tabsState.focused))
                .child(Node.text(renderTabs(labels, tabsState.selectedIndex), tabsTextStyle(tabsState.focused)))
        )
    }
}

public class Spinner <: Component {
    private let label: String
    private let width: Int64
    private let id: String
    private let spinnerType: SpinnerType

    public init(label: String, width: Int64, id: String) {
        this.label = label
        this.width = width
        this.id = id
        this.spinnerType = SpinnerType.Line
    }

    public init(label: String, width: Int64, id: String, spinnerType: SpinnerType) {
        this.label = label
        this.width = width
        this.id = id
        this.spinnerType = spinnerType
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let _ = ctx
        let spinnerState = (state as SpinnerState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            match (event) {
                case UiEvent.Tick => spinnerState.frameIndex = (spinnerState.frameIndex + 1) % spinnerFrames(spinnerType).size
                case _ => ()
            }
        }
        Action.update(spinnerState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let spinnerState = (state as SpinnerState).getOrThrow()
        Node.div(
            Div()
                .id(id)
                .width(Dimension.Fixed(width))
                .height(Dimension.Fixed(1))
                .style(spinnerContainerStyle())
                .child(Node.text(renderSpinner(label, spinnerState.frameIndex, width, spinnerType), spinnerTextStyle()))
        )
    }
}

public class Modal <: Component {
    private let title: String
    private let bodyLines: Array<String>
    private let width: Int64
    private let height: Int64
    private let id: String

    public init(title: String, bodyLines: Array<String>, width: Int64, height: Int64, id: String) {
        this.title = title
        this.bodyLines = bodyLines
        this.width = width
        this.height = height
        this.id = id
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let modalState = (state as ModalState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            applyModalEvent(ctx, modalState, event, id)
        }
        Action.update(modalState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let modalState = (state as ModalState).getOrThrow()
        if (!modalState.open) {
            return Node.text("")
        }

        let container = Div()
            .id(id)
            .focusable()
            .width(Dimension.Fixed(width))
            .height(Dimension.Fixed(height))
            .style(modalContainerStyle(modalState.focused))
            .child(Node.text(padOrTrim(" ${title} ", width), modalTitleStyle()))

        for (line in bodyLines) {
            container.child(Node.text(padOrTrim(line, width), modalBodyStyle()))
        }
        container.child(Node.text(padOrTrim("Press Esc to close", width), modalHintStyle()))
        Node.div(container)
    }
}

private func applyScrollableEvent(
    state: ScrollableState,
    event: UiEvent,
    id: String,
    maxOffset: Int64,
    pageSize: Int64
): Unit {
    match (event) {
        case UiEvent.Focus(nodeId) => if (nodeId == id) { state.focused = true }
        case UiEvent.Blur(nodeId) => if (nodeId == id) { state.focused = false }
        case UiEvent.Key(keyEvent) => if (state.focused) { applyScrollKey(state, keyEvent.code, maxOffset, pageSize) }
        case UiEvent.Mouse(mouseEvent) => if (state.focused) { applyScrollMouse(state, mouseEvent.kind, maxOffset) }
        case _ => ()
    }
}

private func applyScrollKey(state: ScrollableState, code: KeyCode, maxOffset: Int64, pageSize: Int64): Unit {
    match (code) {
        case KeyCode.Up => state.offset = clampInt64(state.offset - 1, 0, maxOffset)
        case KeyCode.Down => state.offset = clampInt64(state.offset + 1, 0, maxOffset)
        case KeyCode.PageUp => state.offset = clampInt64(state.offset - pageSize, 0, maxOffset)
        case KeyCode.PageDown => state.offset = clampInt64(state.offset + pageSize, 0, maxOffset)
        case KeyCode.Home => state.offset = 0
        case KeyCode.End => state.offset = maxOffset
        case _ => ()
    }
}

private func applyScrollMouse(state: ScrollableState, kind: MouseEventKind, maxOffset: Int64): Unit {
    match (kind) {
        case MouseEventKind.ScrollUp => state.offset = clampInt64(state.offset - 1, 0, maxOffset)
        case MouseEventKind.ScrollDown => state.offset = clampInt64(state.offset + 1, 0, maxOffset)
        case _ => ()
    }
}

private func applyListEvent(ctx: Context, state: ListState, event: UiEvent, id: String, items: Array<String>, height: Int64): Unit {
    let itemCount = items.size
    match (event) {
        case UiEvent.Focus(nodeId) => if (isListNodeId(id, nodeId)) { state.focused = true }
        case UiEvent.Blur(nodeId) => if (isListNodeId(id, nodeId)) { state.focused = false }
        case UiEvent.Key(keyEvent) => if (state.focused) { applyListKey(ctx, state, keyEvent.code, id, items, height) }
        case UiEvent.Mouse(mouseEvent) => if (state.focused) { applyListMouse(state, mouseEvent.kind, itemCount, height) }
        case UiEvent.Click(nodeId, _) => applyListClick(ctx, state, id, nodeId, items, height)
        case _ => ()
    }
}

private func applyListClick(ctx: Context, state: ListState, id: String, nodeId: String, items: Array<String>, height: Int64): Unit {
    let itemCount = items.size
    match (parseListItemIndex(id, nodeId)) {
        case Some(index) =>
            state.selectedIndex = clampInt64(index, 0, maxSelectedIndex(itemCount))
            ensureListSelectionVisible(state, itemCount, height)
            state.focused = true
            emitListSelection(ctx, id, items, state.selectedIndex)
        case None => ()
    }
}

private func applyListKey(ctx: Context, state: ListState, code: KeyCode, id: String, items: Array<String>, height: Int64): Unit {
    let itemCount = items.size
    let maxIndex = maxSelectedIndex(itemCount)
    match (code) {
        case KeyCode.Up => state.selectedIndex = clampInt64(state.selectedIndex - 1, 0, maxIndex)
        case KeyCode.Down => state.selectedIndex = clampInt64(state.selectedIndex + 1, 0, maxIndex)
        case KeyCode.PageUp => state.selectedIndex = clampInt64(state.selectedIndex - height, 0, maxIndex)
        case KeyCode.PageDown => state.selectedIndex = clampInt64(state.selectedIndex + height, 0, maxIndex)
        case KeyCode.Home => state.selectedIndex = 0
        case KeyCode.End => state.selectedIndex = maxIndex
        case KeyCode.Enter => emitListSelection(ctx, id, items, state.selectedIndex)
        case _ => ()
    }
    ensureListSelectionVisible(state, itemCount, height)
}

private func applyListMouse(state: ListState, kind: MouseEventKind, itemCount: Int64, height: Int64): Unit {
    let maxIndex = maxSelectedIndex(itemCount)
    match (kind) {
        case MouseEventKind.ScrollUp => state.selectedIndex = clampInt64(state.selectedIndex - 1, 0, maxIndex)
        case MouseEventKind.ScrollDown => state.selectedIndex = clampInt64(state.selectedIndex + 1, 0, maxIndex)
        case _ => ()
    }
    ensureListSelectionVisible(state, itemCount, height)
}

private func ensureListSelectionVisible(state: ListState, itemCount: Int64, height: Int64): Unit {
    let maxOffset = maxScrollOffset(itemCount, height)
    if (state.selectedIndex < state.scrollOffset) {
        state.scrollOffset = state.selectedIndex
    }
    if (state.selectedIndex >= state.scrollOffset + height) {
        state.scrollOffset = state.selectedIndex - height + 1
    }
    state.scrollOffset = clampInt64(state.scrollOffset, 0, maxOffset)
}

private func applyTextInputEvent(ctx: Context, state: TextInputState, event: UiEvent, id: String): Unit {
    match (event) {
        case UiEvent.Focus(nodeId) => if (isTextInputNodeId(id, nodeId)) { state.focused = true }
        case UiEvent.Blur(nodeId) => if (isTextInputNodeId(id, nodeId)) { state.focused = false }
        case UiEvent.Key(keyEvent) => if (state.focused) { applyTextInputKey(ctx, state, keyEvent.code, id) }
        case UiEvent.Click(nodeId, _) => applyTextInputClick(state, id, nodeId)
        case _ => ()
    }
}

private func applyTextInputClick(state: TextInputState, id: String, nodeId: String): Unit {
    match (parseTextInputSlotIndex(id, nodeId)) {
        case Some(index) =>
            state.focused = true
            state.cursor = clampInt64(state.viewOffset + index, 0, runeCount(state.value))
        case None => ()
    }
}

private func applyTextInputKey(ctx: Context, state: TextInputState, code: KeyCode, id: String): Unit {
    match (code) {
        case KeyCode.Char(ch) =>
            state.value = insertRuneAt(state.value, state.cursor, ch)
            state.cursor += 1
        case KeyCode.Backspace =>
            if (state.cursor > 0) {
                state.value = removeRuneAt(state.value, state.cursor - 1)
                state.cursor -= 1
            }
        case KeyCode.Delete =>
            if (state.cursor < runeCount(state.value)) {
                state.value = removeRuneAt(state.value, state.cursor)
            }
        case KeyCode.Left => state.cursor = clampInt64(state.cursor - 1, 0, runeCount(state.value))
        case KeyCode.Right => state.cursor = clampInt64(state.cursor + 1, 0, runeCount(state.value))
        case KeyCode.Home => state.cursor = 0
        case KeyCode.End => state.cursor = runeCount(state.value)
        case KeyCode.Enter => ctx.send(BuiltinEvent.TextInputSubmitted(id, state.value))
        case _ => ()
    }
}

private func applyButtonEvent(ctx: Context, state: ButtonState, event: UiEvent, id: String, label: String): Unit {
    match (event) {
        case UiEvent.Focus(nodeId) => if (nodeId == id) { state.focused = true }
        case UiEvent.Blur(nodeId) => if (nodeId == id) { state.focused = false; state.pressed = false }
        case UiEvent.Key(keyEvent) => if (state.focused) { applyButtonKey(ctx, state, keyEvent.code, id, label) }
        case UiEvent.Click(nodeId, _) => if (nodeId == id) { emitButtonPressed(ctx, state, id, label) }
        case _ => ()
    }
}

private func applyButtonKey(ctx: Context, state: ButtonState, code: KeyCode, id: String, label: String): Unit {
    match (code) {
        case KeyCode.Enter => emitButtonPressed(ctx, state, id, label)
        case KeyCode.Char(ch) => if (ch == r' ') { emitButtonPressed(ctx, state, id, label) }
        case _ => ()
    }
}

private func applyCheckboxEvent(ctx: Context, state: CheckboxState, event: UiEvent, id: String): Unit {
    match (event) {
        case UiEvent.Focus(nodeId) => if (nodeId == id) { state.focused = true }
        case UiEvent.Blur(nodeId) => if (nodeId == id) { state.focused = false }
        case UiEvent.Key(keyEvent) => if (state.focused) { applyCheckboxKey(ctx, state, keyEvent.code, id) }
        case UiEvent.Click(nodeId, _) => if (nodeId == id) { toggleCheckbox(ctx, state, id) }
        case _ => ()
    }
}

private func applyCheckboxKey(ctx: Context, state: CheckboxState, code: KeyCode, id: String): Unit {
    match (code) {
        case KeyCode.Enter => toggleCheckbox(ctx, state, id)
        case KeyCode.Char(ch) => if (ch == r' ') { toggleCheckbox(ctx, state, id) }
        case _ => ()
    }
}

private func applyRadioEvent(ctx: Context, state: RadioState, event: UiEvent, id: String, options: Array<String>): Unit {
    match (event) {
        case UiEvent.Focus(nodeId) => if (nodeId == id) { state.focused = true }
        case UiEvent.Blur(nodeId) => if (nodeId == id) { state.focused = false }
        case UiEvent.Key(keyEvent) => if (state.focused) { applyRadioKey(ctx, state, keyEvent.code, id, options) }
        case _ => ()
    }
}

private func applyRadioKey(ctx: Context, state: RadioState, code: KeyCode, id: String, options: Array<String>): Unit {
    let maxIndex = maxSelectedIndex(options.size)
    match (code) {
        case KeyCode.Left => state.selectedIndex = clampInt64(state.selectedIndex - 1, 0, maxIndex)
        case KeyCode.Up => state.selectedIndex = clampInt64(state.selectedIndex - 1, 0, maxIndex)
        case KeyCode.Right => state.selectedIndex = clampInt64(state.selectedIndex + 1, 0, maxIndex)
        case KeyCode.Down => state.selectedIndex = clampInt64(state.selectedIndex + 1, 0, maxIndex)
        case KeyCode.Enter => emitRadioChanged(ctx, id, options, state.selectedIndex)
        case _ => ()
    }
}

private func applyTabsEvent(ctx: Context, state: TabsState, event: UiEvent, id: String, labels: Array<String>): Unit {
    match (event) {
        case UiEvent.Focus(nodeId) => if (nodeId == id) { state.focused = true }
        case UiEvent.Blur(nodeId) => if (nodeId == id) { state.focused = false }
        case UiEvent.Key(keyEvent) => if (state.focused) { applyTabsKey(ctx, state, keyEvent.code, id, labels) }
        case _ => ()
    }
}

private func applyTabsKey(ctx: Context, state: TabsState, code: KeyCode, id: String, labels: Array<String>): Unit {
    let maxIndex = maxSelectedIndex(labels.size)
    match (code) {
        case KeyCode.Left => state.selectedIndex = clampInt64(state.selectedIndex - 1, 0, maxIndex)
        case KeyCode.Right => state.selectedIndex = clampInt64(state.selectedIndex + 1, 0, maxIndex)
        case KeyCode.Enter => emitTabChanged(ctx, id, labels, state.selectedIndex)
        case _ => ()
    }
}

private func applyModalEvent(ctx: Context, state: ModalState, event: UiEvent, id: String): Unit {
    match (event) {
        case UiEvent.Focus(nodeId) => if (nodeId == id) { state.focused = true }
        case UiEvent.Blur(nodeId) => if (nodeId == id) { state.focused = false }
        case UiEvent.Key(keyEvent) => if (state.focused) { applyModalKey(ctx, state, keyEvent.code, id) }
        case UiEvent.Click(nodeId, _) => if (nodeId == id) { dismissModal(ctx, state, id) }
        case _ => ()
    }
}

private func applyModalKey(ctx: Context, state: ModalState, code: KeyCode, id: String): Unit {
    match (code) {
        case KeyCode.Esc => dismissModal(ctx, state, id)
        case KeyCode.Enter => dismissModal(ctx, state, id)
        case _ => ()
    }
}

private func visibleScrollableLines(lines: Array<String>, offset: Int64, height: Int64): Array<String> {
    let start = clampInt64(offset, 0, maxScrollOffset(lines.size, height))
    let count = visibleItemCount(lines.size, start, height)
    Array<String>(count, { index => formatScrollableLine(lines[start + index], index, count, start > 0, start + count < lines.size) })
}

private func visibleListItems(items: Array<String>, state: ListState, height: Int64): Array<(Int64, String)> {
    let start = clampInt64(state.scrollOffset, 0, maxScrollOffset(items.size, height))
    let count = visibleItemCount(items.size, start, height)
    Array<(Int64, String)>(count, { index => (start + index, formatListLine(items, start + index, state.selectedIndex, state.focused)) })
}

private func formatListLine(items: Array<String>, index: Int64, selectedIndex: Int64, focused: Bool): String {
    if (index == selectedIndex) {
        if (focused) {
            return "> ${items[index]} <"
        }
        return "[${items[index]}]"
    }
    "  ${items[index]}"
}

private func formatScrollableLine(line: String, index: Int64, count: Int64, hasAbove: Bool, hasBelow: Bool): String {
    let marker = scrollMarker(index, count, hasAbove, hasBelow)
    "|" + padOrTrim(line, 22) + marker
}

private func textInputContent(state: TextInputState, placeholder: String): String {
    if (state.focused) {
        return insertRuneAt(state.value, state.cursor, r'|')
    }
    if (state.value.isEmpty()) {
        if (placeholder.isEmpty()) {
            return ""
        }
        return "<${placeholder}>"
    }
    state.value
}

private struct TextInputCell {
    let nodeId: String
    let text: String

    init(nodeId: String, text: String) {
        this.nodeId = nodeId
        this.text = text
    }
}

private func textInputFrame(state: TextInputState, width: Int64, placeholder: String, id: String): Array<TextInputCell> {
    let slotCount = textInputSlotCount(width)
    if (slotCount <= 0) {
        return []
    }

    let content = textInputContent(state, placeholder)
    let visible = substringRunes(content, state.viewOffset, state.viewOffset + slotCount)
    Array<TextInputCell>(slotCount, { index => TextInputCell(textInputSlotId(id, index), textInputCellText(visible, index)) })
}

private func textInputCellNode(cell: TextInputCell): Node {
    Node.div(
        Div()
            .id(cell.nodeId)
            .focusable()
            .width(Dimension.Fixed(1))
            .height(Dimension.Fixed(1))
            .child(Node.text(cell.text, textInputCellStyle(cell.text)))
    )
}

private func textInputCellText(text: String, index: Int64): String {
    let cell = substringRunes(text, index, index + 1)
    if (cell.isEmpty()) {
        return "_"
    }
    cell
}

private func listItemId(id: String, index: Int64): String {
    "${id}.item.${index}"
}

private func textInputSlotId(id: String, index: Int64): String {
    "${id}.slot.${index}"
}

private func isListNodeId(id: String, nodeId: String): Bool {
    nodeId == id || nodeId.startsWith("${id}.item.")
}

private func isTextInputNodeId(id: String, nodeId: String): Bool {
    nodeId == id || nodeId.startsWith("${id}.slot.")
}

private func parseListItemIndex(id: String, nodeId: String): ?Int64 {
    if (!nodeId.startsWith("${id}.item.")) {
        return None
    }
    Int64.tryParse(nodeId[id.size + 6..nodeId.size])
}

private func parseTextInputSlotIndex(id: String, nodeId: String): ?Int64 {
    if (!nodeId.startsWith("${id}.slot.")) {
        return None
    }
    Int64.tryParse(nodeId[id.size + 6..nodeId.size])
}

private func normalizeTextInputWindow(state: TextInputState, width: Int64, placeholder: String): Unit {
    let content = textInputContent(state, placeholder)
    let contentLength = runeCount(content)
    let slotCount = textInputSlotCount(width)
    let maxOffset = maxScrollOffset(contentLength, slotCount)
    if (!state.focused) {
        state.viewOffset = clampInt64(state.viewOffset, 0, maxOffset)
        return
    }

    let anchor = state.cursor
    var nextOffset = clampInt64(state.viewOffset, 0, maxOffset)
    if (anchor < nextOffset) {
        nextOffset = anchor
    }
    if (anchor >= nextOffset + slotCount) {
        nextOffset = anchor - slotCount + 1
    }
    state.viewOffset = clampInt64(nextOffset, 0, maxOffset)
}

private func insertRuneAt(text: String, index: Int64, ch: Rune): String {
    let clamped = clampInt64(index, 0, runeCount(text))
    let prefix = substringRunes(text, 0, clamped)
    let suffix = substringRunes(text, clamped, runeCount(text))
    prefix + ch.toString() + suffix
}

private func removeRuneAt(text: String, index: Int64): String {
    let count = runeCount(text)
    if (index < 0 || index >= count) {
        return text
    }
    substringRunes(text, 0, index) + substringRunes(text, index + 1, count)
}

private func substringRunes(text: String, start: Int64, endExclusive: Int64): String {
    let normalizedStart = if (start < 0) { 0 } else { start }
    let normalizedEnd = if (endExclusive < normalizedStart) { normalizedStart } else { endExclusive }
    var result = ""
    var index = Int64(0)
    for (ch in text.runes()) {
        if (index >= normalizedStart && index < normalizedEnd) {
            result += ch.toString()
        }
        index += 1
    }
    result
}

private func runeCount(text: String): Int64 {
    var count = Int64(0)
    for (_ in text.runes()) {
        count += 1
    }
    count
}

private func visibleItemCount(total: Int64, start: Int64, height: Int64): Int64 {
    if (height <= 0 || start >= total) {
        return 0
    }
    let remaining = total - start
    if (remaining < height) {
        return remaining
    }
    height
}

private func maxSelectedIndex(itemCount: Int64): Int64 {
    if (itemCount <= 0) {
        return 0
    }
    itemCount - 1
}

private func maxScrollOffset(itemCount: Int64, viewportSize: Int64): Int64 {
    if (itemCount <= viewportSize) {
        return 0
    }
    itemCount - viewportSize
}

private func emitListSelection(ctx: Context, id: String, items: Array<String>, selectedIndex: Int64): Unit {
    if (selectedIndex < 0 || selectedIndex >= items.size) {
        return
    }
    ctx.send(BuiltinEvent.ListItemSelected(id, selectedIndex, items[selectedIndex]))
}

private func emitButtonPressed(ctx: Context, state: ButtonState, id: String, label: String): Unit {
    state.pressed = true
    ctx.send(BuiltinEvent.ButtonPressed(id, label))
}

private func toggleCheckbox(ctx: Context, state: CheckboxState, id: String): Unit {
    state.checked = !state.checked
    ctx.send(BuiltinEvent.CheckboxChanged(id, state.checked))
}

private func emitRadioChanged(ctx: Context, id: String, options: Array<String>, index: Int64): Unit {
    if (index < 0 || index >= options.size) {
        return
    }
    ctx.send(BuiltinEvent.RadioChanged(id, index, options[index]))
}

private func emitTabChanged(ctx: Context, id: String, labels: Array<String>, index: Int64): Unit {
    if (index < 0 || index >= labels.size) {
        return
    }
    ctx.send(BuiltinEvent.TabChanged(id, index, labels[index]))
}

private func dismissModal(ctx: Context, state: ModalState, id: String): Unit {
    state.open = false
    state.focused = false
    ctx.send(BuiltinEvent.ModalDismissed(id))
}

private func textInputSlotCount(width: Int64): Int64 {
    if (width <= 0) {
        return 0
    }
    width
}

private func scrollMarker(index: Int64, count: Int64, hasAbove: Bool, hasBelow: Bool): String {
    if (count <= 0) {
        return "|"
    }
    if (index == 0 && hasAbove) {
        return "^"
    }
    if (index == count - 1 && hasBelow) {
        return "v"
    }
    "|"
}

private func padOrTrim(text: String, width: Int64): String {
    if (width <= 0) {
        return ""
    }
    let trimmed = substringRunes(text, 0, width)
    let padding = width - runeCount(trimmed)
    if (padding <= 0) {
        return trimmed
    }
    trimmed + repeatString(" ", padding)
}

private func repeatString(text: String, count: Int64): String {
    var result = ""
    var index = Int64(0)
    while (index < count) {
        result += text
        index += 1
    }
    result
}

private func renderButtonLabel(label: String, width: Int64, focused: Bool, pressed: Bool): String {
    let body = if (pressed) {
        "! ${label} !"
    } else if (focused) {
        "> ${label} <"
    } else {
        "[ ${label} ]"
    }
    padOrTrim(body, width)
}

private func renderProgressBar(value: Int64, maxValue: Int64, width: Int64): String {
    if (width <= 0) {
        return ""
    }
    let clampedMax = if (maxValue <= 0) { 1 } else { maxValue }
    let clampedValue = clampInt64(value, 0, clampedMax)
    let trackWidth = if (width <= 6) { width } else { width - 6 }
    let filled = Int64(Float64(trackWidth) * Float64(clampedValue) / Float64(clampedMax))
    let bar = repeatString("#", filled) + repeatString("-", trackWidth - filled)
    if (width <= 6) {
        return padOrTrim(bar, width)
    }
    let percent = Int64(Float64(clampedValue) * 100.0 / Float64(clampedMax))
    "[${bar}] ${percent}%"
}

private func renderCheckboxLabel(label: String, width: Int64, checked: Bool): String {
    let marker = if (checked) { "[x]" } else { "[ ]" }
    padOrTrim("${marker} ${label}", width)
}

private func renderRadioOption(option: String, selected: Bool): String {
    let marker = if (selected) { "(*)" } else { "( )" }
    "${marker} ${option}"
}

private func renderTabs(labels: Array<String>, selectedIndex: Int64): String {
    var result = ""
    for ((index, label) in indexedOptions(labels)) {
        if (index > 0) {
            result += " "
        }
        if (index == selectedIndex) {
            result += "<${label}>"
        } else {
            result += " ${label} "
        }
    }
    result
}

private func renderSpinner(label: String, frameIndex: Int64, width: Int64, spinnerType: SpinnerType): String {
    let frames = spinnerFrames(spinnerType)
    let index = clampInt64(frameIndex, 0, frames.size - 1)
    padOrTrim("${frames[index]} ${label}", width)
}

private func indexedOptions(options: Array<String>): Array<(Int64, String)> {
    Array<(Int64, String)>(options.size, { index => (index, options[index]) })
}

private func spinnerFrames(spinnerType: SpinnerType): Array<String> {
    match (spinnerType) {
        case SpinnerType.Line => ["-", "\\", "|", "/"]
        case SpinnerType.Dots => ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        case SpinnerType.Circle => ["◐", "◓", "◑", "◒"]
        case SpinnerType.Arrow => ["←", "↖", "↑", "↗", "→", "↘", "↓", "↙"]
        case SpinnerType.Bounce => ["⠁", "⠂", "⠄", "⡀", "⢀", "⠠", "⠐", "⠈"]
        case SpinnerType.Hearts => ["\u{1F49B}", "\u{1F499}", "\u{1F49C}", "\u{1F49A}", "\u{2764}"]
        case SpinnerType.Custom(frames) => frames
    }
}

private func scrollableContainerStyle(focused: Bool): Style {
    let borderColor = if (focused) { Color.BrightCyan } else { Color.BrightBlack }
    Style().withBorder(Border(BorderStyle.Rounded, borderColor)).withBackground(Color.Black)
}

private func scrollableTextStyle(focused: Bool): TextStyle {
    let foreground = if (focused) { Color.BrightWhite } else { Color.BrightBlack }
    TextStyle().withForeground(foreground).withBackground(Color.Black)
}

private func listContainerStyle(focused: Bool): Style {
    let borderColor = if (focused) { Color.BrightGreen } else { Color.BrightBlack }
    Style().withBorder(Border(BorderStyle.Single, borderColor)).withBackground(Color.Black)
}

private func listLineStyle(selected: Bool, focused: Bool): TextStyle {
    if (selected) {
        let background = if (focused) { Color.Blue } else { Color.BrightBlack }
        let foreground = if (focused) { Color.BrightWhite } else { Color.White }
        return TextStyle().withForeground(foreground).withBackground(background).withBold(true)
    }
    TextStyle().withForeground(Color.White).withBackground(Color.Black)
}

private func textInputContainerStyle(focused: Bool): Style {
    let borderColor = if (focused) { Color.BrightYellow } else { Color.BrightBlack }
    Style().withBorder(Border(BorderStyle.Single, borderColor)).withBackground(Color.Black)
}

private func textInputCellStyle(text: String): TextStyle {
    if (text == "|") {
        return TextStyle().withForeground(Color.Black).withBackground(Color.BrightYellow).withBold(true)
    }
    if (text == "<" || text == ">") {
        return TextStyle().withForeground(Color.BrightBlack).withBackground(Color.Black)
    }
    if (text == "_") {
        return TextStyle().withForeground(Color.BrightBlack).withBackground(Color.Black)
    }
    TextStyle().withForeground(Color.BrightWhite).withBackground(Color.Black)
}

private func labelTextStyle(): TextStyle {
    TextStyle().withForeground(Color.BrightWhite)
}

private func buttonContainerStyle(focused: Bool, pressed: Bool): Style {
    let borderColor = if (pressed) {
        Color.BrightRed
    } else if (focused) {
        Color.BrightMagenta
    } else {
        Color.BrightBlack
    }
    let background = if (pressed) { Color.Red } else { Color.Black }
    Style().withBorder(Border(BorderStyle.Rounded, borderColor)).withBackground(background)
}

private func buttonTextStyle(focused: Bool, pressed: Bool): TextStyle {
    if (pressed) {
        return TextStyle().withForeground(Color.BrightWhite).withBackground(Color.Red).withBold(true)
    }
    if (focused) {
        return TextStyle().withForeground(Color.BrightMagenta).withBold(true)
    }
    TextStyle().withForeground(Color.White)
}

private func progressBarContainerStyle(): Style {
    Style().withBorder(Border(BorderStyle.Single, Color.BrightBlue)).withBackground(Color.Black)
}

private func progressBarTextStyle(value: Int64, maxValue: Int64): TextStyle {
    let accent = if (value >= maxValue) { Color.BrightGreen } else { Color.BrightBlue }
    TextStyle().withForeground(accent).withBold(true)
}

private func formContainerStyle(): Style {
    Style().withBorder(Border(BorderStyle.Double, Color.BrightCyan)).withBackground(Color.Black)
}

private func formTitleStyle(): TextStyle {
    TextStyle().withForeground(Color.BrightCyan).withBold(true)
}

private func formFieldLabelStyle(): TextStyle {
    TextStyle().withForeground(Color.BrightYellow).withBold(true)
}

private func checkboxContainerStyle(focused: Bool, checked: Bool): Style {
    let borderColor = if (checked) { Color.BrightGreen } else if (focused) { Color.BrightYellow } else { Color.BrightBlack }
    Style().withBorder(Border(BorderStyle.Single, borderColor)).withBackground(Color.Black)
}

private func checkboxTextStyle(focused: Bool, checked: Bool): TextStyle {
    let foreground = if (checked) { Color.BrightGreen } else if (focused) { Color.BrightYellow } else { Color.White }
    TextStyle().withForeground(foreground).withBold(focused || checked)
}

private func radioContainerStyle(focused: Bool): Style {
    let borderColor = if (focused) { Color.BrightMagenta } else { Color.BrightBlack }
    Style().withBorder(Border(BorderStyle.Rounded, borderColor)).withBackground(Color.Black)
}

private func radioTextStyle(selected: Bool, focused: Bool): TextStyle {
    if (selected) {
        return TextStyle().withForeground(Color.BrightMagenta).withBold(true)
    }
    if (focused) {
        return TextStyle().withForeground(Color.White)
    }
    TextStyle().withForeground(Color.BrightBlack)
}

private func tabsContainerStyle(focused: Bool): Style {
    let borderColor = if (focused) { Color.BrightBlue } else { Color.BrightBlack }
    Style().withBorder(Border(BorderStyle.Single, borderColor)).withBackground(Color.Black)
}

private func tabsTextStyle(focused: Bool): TextStyle {
    let foreground = if (focused) { Color.BrightBlue } else { Color.White }
    TextStyle().withForeground(foreground).withBold(focused)
}

private func spinnerContainerStyle(): Style {
    Style().withBorder(Border(BorderStyle.Single, Color.BrightCyan)).withBackground(Color.Black)
}

private func spinnerTextStyle(): TextStyle {
    TextStyle().withForeground(Color.BrightCyan).withBold(true)
}

private func modalContainerStyle(focused: Bool): Style {
    let borderColor = if (focused) { Color.BrightRed } else { Color.BrightMagenta }
    Style().withBorder(Border(BorderStyle.Double, borderColor)).withBackground(Color.BrightBlack)
}

private func modalTitleStyle(): TextStyle {
    TextStyle().withForeground(Color.BrightWhite).withBackground(Color.BrightMagenta).withBold(true)
}

private func modalBodyStyle(): TextStyle {
    TextStyle().withForeground(Color.White).withBackground(Color.BrightBlack)
}

private func modalHintStyle(): TextStyle {
    TextStyle().withForeground(Color.BrightYellow).withBackground(Color.BrightBlack).withBold(true)
}

private func clampInt64(value: Int64, min: Int64, max: Int64): Int64 {
    if (value < min) {
        return min
    }
    if (value > max) {
        return max
    }
    value
}
