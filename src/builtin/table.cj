package cjrxtui.builtin

import cjrxtui.component.{Action, Component, Context, KeyCode, Message, MouseEventKind, State, UiEvent}
import cjrxtui.node.{Div, Node}
import cjrxtui.style.{Border, BorderStyle, Color, Dimension, Style, TextStyle}

public class TableState <: State {
    public var selectedRow: Int64
    public var scrollOffset: Int64
    public var focused: Bool
    public var hovered: Bool

    public init() {
        selectedRow = 0
        scrollOffset = 0
        focused = false
        hovered = false
    }

    public init(selectedRow: Int64, scrollOffset: Int64, focused: Bool) {
        this.selectedRow = selectedRow
        this.scrollOffset = scrollOffset
        this.focused = focused
        this.hovered = false
    }
}

public class Table <: Component {
    private let headers: Array<String>
    private let rows: Array<Array<String>>
    private let columnWidths: Array<Int64>
    private let width: Int64
    private let height: Int64
    private let id: String

    public init(headers: Array<String>, rows: Array<Array<String>>, columnWidths: Array<Int64>, width: Int64, height: Int64, id: String) {
        this.headers = headers
        this.rows = rows
        this.columnWidths = columnWidths
        this.width = width
        this.height = height
        this.id = id
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let tableState = (state as TableState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            applyTableEvent(ctx, tableState, event, id, rows.size, height - 2)
        }
        Action.update(tableState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let tableState = (state as TableState).getOrThrow()
        let container = Div()
            .id(id)
            .focusable()
            .width(Dimension.Fixed(width))
            .height(Dimension.Fixed(height))
            .style(tableContainerStyle(tableState.focused, hovered: tableState.hovered))

        container.child(Node.text(renderTableRow(headers, columnWidths, width), tableHeaderStyle()))
        container.child(Node.text(renderTableSeparator(columnWidths, width), tableSeparatorStyle()))

        let viewportHeight = height - 2
        let visibleRows = tableVisibleRows(rows, tableState.scrollOffset, viewportHeight)
        for ((index, row) in visibleRows) {
            let isSelected = index == tableState.selectedRow
            container.child(Node.text(renderTableRow(row, columnWidths, width), tableRowStyle(isSelected, tableState.focused)))
        }

        Node.div(container)
    }
}

private func applyTableEvent(ctx: Context, state: TableState, event: UiEvent, id: String, rowCount: Int64, viewportHeight: Int64): Unit {
    match (event) {
        case UiEvent.Focus(nodeId) => if (nodeId == id) { state.focused = true }
        case UiEvent.Blur(nodeId) => if (nodeId == id) { state.focused = false }
        case UiEvent.HoverEnter(nodeId) => if (nodeId == id) { state.hovered = true }
        case UiEvent.HoverLeave(nodeId) => if (nodeId == id) { state.hovered = false }
        case UiEvent.Key(keyEvent) => if (state.focused) { applyTableKey(ctx, state, keyEvent.code, id, rowCount, viewportHeight) }
        case UiEvent.Mouse(mouseEvent) => if (state.focused) { applyTableMouse(state, mouseEvent.kind, rowCount, viewportHeight) }
        case _ => ()
    }
}

private func applyTableKey(ctx: Context, state: TableState, code: KeyCode, id: String, rowCount: Int64, viewportHeight: Int64): Unit {
    let maxIndex = tableMaxIndex(rowCount)
    match (code) {
        case KeyCode.Up => state.selectedRow = tableClamp(state.selectedRow - 1, 0, maxIndex)
        case KeyCode.Down => state.selectedRow = tableClamp(state.selectedRow + 1, 0, maxIndex)
        case KeyCode.PageUp => state.selectedRow = tableClamp(state.selectedRow - viewportHeight, 0, maxIndex)
        case KeyCode.PageDown => state.selectedRow = tableClamp(state.selectedRow + viewportHeight, 0, maxIndex)
        case KeyCode.Home => state.selectedRow = 0
        case KeyCode.End => state.selectedRow = maxIndex
        case KeyCode.Enter => ctx.send(BuiltinEvent.TableRowSelected(id, state.selectedRow))
        case _ => ()
    }
    ensureTableSelectionVisible(state, rowCount, viewportHeight)
}

private func applyTableMouse(state: TableState, kind: MouseEventKind, rowCount: Int64, viewportHeight: Int64): Unit {
    let maxIndex = tableMaxIndex(rowCount)
    match (kind) {
        case MouseEventKind.ScrollUp => state.selectedRow = tableClamp(state.selectedRow - 1, 0, maxIndex)
        case MouseEventKind.ScrollDown => state.selectedRow = tableClamp(state.selectedRow + 1, 0, maxIndex)
        case _ => ()
    }
    ensureTableSelectionVisible(state, rowCount, viewportHeight)
}

private func ensureTableSelectionVisible(state: TableState, rowCount: Int64, viewportHeight: Int64): Unit {
    let maxOffset = tableMaxScrollOffset(rowCount, viewportHeight)
    if (state.selectedRow < state.scrollOffset) {
        state.scrollOffset = state.selectedRow
    }
    if (state.selectedRow >= state.scrollOffset + viewportHeight) {
        state.scrollOffset = state.selectedRow - viewportHeight + 1
    }
    state.scrollOffset = tableClamp(state.scrollOffset, 0, maxOffset)
}

private func tableVisibleRows(rows: Array<Array<String>>, offset: Int64, viewportHeight: Int64): Array<(Int64, Array<String>)> {
    if (viewportHeight <= 0 || rows.size == 0) {
        return []
    }
    let start = tableClamp(offset, 0, tableMaxScrollOffset(rows.size, viewportHeight))
    let count = tableVisibleCount(rows.size, start, viewportHeight)
    Array<(Int64, Array<String>)>(count, { index => (start + index, rows[start + index]) })
}

private func renderTableRow(cells: Array<String>, columnWidths: Array<Int64>, totalWidth: Int64): String {
    var result = ""
    let colCount = if (cells.size < columnWidths.size) { cells.size } else { columnWidths.size }
    for (index in 0..colCount) {
        if (index > 0) {
            result += "|"
        }
        result += tablePadOrTrim(cells[index], columnWidths[index])
    }
    tablePadOrTrim(result, totalWidth)
}

private func renderTableSeparator(columnWidths: Array<Int64>, totalWidth: Int64): String {
    var result = ""
    for (index in 0..columnWidths.size) {
        if (index > 0) {
            result += "+"
        }
        result += tableRepeat("-", columnWidths[index])
    }
    tablePadOrTrim(result, totalWidth)
}

private func tableContainerStyle(focused: Bool, hovered!: Bool = false): Style {
    let borderColor = if (focused) { Color.BrightCyan } else if (hovered) { Color.Cyan } else { Color.BrightBlack }
    Style().withBorder(Border(BorderStyle.Single, borderColor)).withBackground(Color.Black)
}

private func tableHeaderStyle(): TextStyle {
    TextStyle().withForeground(Color.BrightCyan).withBold(true).withBackground(Color.Black)
}

private func tableSeparatorStyle(): TextStyle {
    TextStyle().withForeground(Color.BrightBlack).withBackground(Color.Black)
}

private func tableRowStyle(selected: Bool, focused: Bool): TextStyle {
    if (selected) {
        let bg = if (focused) { Color.Blue } else { Color.BrightBlack }
        let fg = if (focused) { Color.BrightWhite } else { Color.White }
        return TextStyle().withForeground(fg).withBackground(bg).withBold(true)
    }
    TextStyle().withForeground(Color.White).withBackground(Color.Black)
}

private func tableClamp(value: Int64, min: Int64, max: Int64): Int64 {
    if (value < min) { return min }
    if (value > max) { return max }
    value
}

private func tableMaxIndex(rowCount: Int64): Int64 {
    if (rowCount <= 0) { return 0 }
    rowCount - 1
}

private func tableMaxScrollOffset(rowCount: Int64, viewportHeight: Int64): Int64 {
    if (rowCount <= viewportHeight) { return 0 }
    rowCount - viewportHeight
}

private func tableVisibleCount(total: Int64, start: Int64, height: Int64): Int64 {
    if (height <= 0 || start >= total) { return 0 }
    let remaining = total - start
    if (remaining < height) { return remaining }
    height
}

private func tablePadOrTrim(text: String, width: Int64): String {
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

private func tableRepeat(text: String, count: Int64): String {
    var result = ""
    var index = Int64(0)
    while (index < count) {
        result += text
        index += 1
    }
    result
}
