package cjrxtui.builtin

import cjrxtui.component.{Action, Component, Context, KeyCode, Message, State, UiEvent}
import cjrxtui.node.{Div, Node}
import cjrxtui.style.{Border, BorderStyle, Color, Dimension, Style, TextStyle}

public class SelectState <: State {
    public var selectedIndex: Int64
    public var open: Bool
    public var highlightIndex: Int64
    public var focused: Bool
    public var hovered: Bool

    public init() {
        selectedIndex = 0
        open = false
        highlightIndex = 0
        focused = false
        hovered = false
    }

    public init(selectedIndex: Int64) {
        this.selectedIndex = selectedIndex
        this.open = false
        this.highlightIndex = selectedIndex
        this.focused = false
        this.hovered = false
    }
}

public class Select <: Component {
    private let options: Array<String>
    private let width: Int64
    private let maxVisibleItems: Int64
    private let id: String

    public init(options: Array<String>, width: Int64, id: String) {
        this.options = options
        this.width = width
        this.maxVisibleItems = 5
        this.id = id
    }

    public init(options: Array<String>, width: Int64, maxVisibleItems: Int64, id: String) {
        this.options = options
        this.width = width
        this.maxVisibleItems = maxVisibleItems
        this.id = id
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let selectState = (state as SelectState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            applySelectEvent(ctx, selectState, event, id, options)
        }
        Action.update(selectState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let selectState = (state as SelectState).getOrThrow()
        let displayHeight = if (selectState.open) {
            let itemCount = if (options.size < maxVisibleItems) { options.size } else { maxVisibleItems }
            1 + itemCount
        } else {
            1
        }

        let container = Div()
            .id(id)
            .focusable()
            .width(Dimension.Fixed(width))
            .height(Dimension.Fixed(displayHeight))
            .style(selectContainerStyle(selectState.focused, selectState.open, hovered: selectState.hovered))

        let selectedLabel = if (selectState.selectedIndex >= 0 && selectState.selectedIndex < options.size) {
            options[selectState.selectedIndex]
        } else {
            ""
        }
        let arrow = if (selectState.open) { "^" } else { "v" }
        container.child(Node.text(selectPadOrTrim("${selectedLabel} ${arrow}", width), selectHeaderStyle(selectState.focused)))

        if (selectState.open) {
            let visibleCount = if (options.size < maxVisibleItems) { options.size } else { maxVisibleItems }
            let scrollStart = selectScrollStart(selectState.highlightIndex, options.size, visibleCount)
            var index = Int64(0)
            while (index < visibleCount) {
                let optionIndex = scrollStart + index
                if (optionIndex < options.size) {
                    let isHighlighted = optionIndex == selectState.highlightIndex
                    let prefix = if (isHighlighted) { "> " } else { "  " }
                    container.child(Node.text(selectPadOrTrim("${prefix}${options[optionIndex]}", width), selectOptionStyle(isHighlighted)))
                }
                index += 1
            }
        }

        Node.div(container)
    }
}

private func applySelectEvent(ctx: Context, state: SelectState, event: UiEvent, id: String, options: Array<String>): Unit {
    match (event) {
        case UiEvent.Focus(nodeId) => if (nodeId == id) { state.focused = true }
        case UiEvent.Blur(nodeId) => if (nodeId == id) {
            state.focused = false
            state.open = false
        }
        case UiEvent.HoverEnter(nodeId) => if (nodeId == id) { state.hovered = true }
        case UiEvent.HoverLeave(nodeId) => if (nodeId == id) { state.hovered = false }
        case UiEvent.Key(keyEvent) => if (state.focused) { applySelectKey(ctx, state, keyEvent.code, id, options) }
        case _ => ()
    }
}

private func applySelectKey(ctx: Context, state: SelectState, code: KeyCode, id: String, options: Array<String>): Unit {
    let maxIndex = selectMaxIndex(options.size)
    if (state.open) {
        match (code) {
            case KeyCode.Up => state.highlightIndex = selectClamp(state.highlightIndex - 1, 0, maxIndex)
            case KeyCode.Down => state.highlightIndex = selectClamp(state.highlightIndex + 1, 0, maxIndex)
            case KeyCode.Enter =>
                state.selectedIndex = state.highlightIndex
                state.open = false
                emitSelectChanged(ctx, id, options, state.selectedIndex)
            case KeyCode.Esc => state.open = false
            case _ => ()
        }
    } else {
        match (code) {
            case KeyCode.Enter =>
                state.open = true
                state.highlightIndex = state.selectedIndex
            case KeyCode.Char(ch) =>
                if (ch == r' ') {
                    state.open = true
                    state.highlightIndex = state.selectedIndex
                }
            case KeyCode.Up => state.selectedIndex = selectClamp(state.selectedIndex - 1, 0, maxIndex)
            case KeyCode.Down => state.selectedIndex = selectClamp(state.selectedIndex + 1, 0, maxIndex)
            case _ => ()
        }
    }
}

private func emitSelectChanged(ctx: Context, id: String, options: Array<String>, index: Int64): Unit {
    if (index >= 0 && index < options.size) {
        ctx.send(BuiltinEvent.SelectChanged(id, index, options[index]))
    }
}

private func selectScrollStart(highlight: Int64, total: Int64, visible: Int64): Int64 {
    if (total <= visible) { return 0 }
    let maxStart = total - visible
    var start = highlight - visible / 2
    if (start < 0) { start = 0 }
    if (start > maxStart) { start = maxStart }
    start
}

private func selectContainerStyle(focused: Bool, open: Bool, hovered!: Bool = false): Style {
    let borderColor = if (open) { Color.BrightYellow } else if (focused) { Color.BrightCyan } else if (hovered) { Color.Cyan } else { Color.BrightBlack }
    Style().withBorder(Border(BorderStyle.Rounded, borderColor)).withBackground(Color.Black)
}

private func selectHeaderStyle(focused: Bool): TextStyle {
    let fg = if (focused) { Color.BrightWhite } else { Color.White }
    TextStyle().withForeground(fg).withBackground(Color.Black).withBold(focused)
}

private func selectOptionStyle(highlighted: Bool): TextStyle {
    if (highlighted) {
        return TextStyle().withForeground(Color.BrightYellow).withBackground(Color.Blue).withBold(true)
    }
    TextStyle().withForeground(Color.White).withBackground(Color.Black)
}

private func selectClamp(value: Int64, min: Int64, max: Int64): Int64 {
    if (value < min) { return min }
    if (value > max) { return max }
    value
}

private func selectMaxIndex(count: Int64): Int64 {
    if (count <= 0) { return 0 }
    count - 1
}

private func selectPadOrTrim(text: String, width: Int64): String {
    if (width <= 0) { return "" }
    var count = Int64(0)
    var result = ""
    for (ch in text.runes()) {
        if (count >= width) { return result }
        result += ch.toString()
        count += 1
    }
    while (count < width) {
        result += " "
        count += 1
    }
    result
}
