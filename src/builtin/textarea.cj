package cjrxtui.builtin

import std.collection.ArrayList
import cjrxtui.component.{Action, Component, Context, KeyCode, KeyEvent, Message, State, UiEvent}
import cjrxtui.node.{Div, Node}
import cjrxtui.style.{Border, BorderStyle, Color, Dimension, Style, TextStyle}

public class TextAreaState <: State {
    public var lines: ArrayList<String>
    public var cursorRow: Int64
    public var cursorCol: Int64
    public var scrollRow: Int64
    public var focused: Bool

    public init() {
        lines = ArrayList<String>()
        lines.add("")
        cursorRow = 0
        cursorCol = 0
        scrollRow = 0
        focused = false
    }

    public init(text: String) {
        lines = splitLines(text)
        if (lines.isEmpty()) {
            lines.add("")
        }
        cursorRow = 0
        cursorCol = 0
        scrollRow = 0
        focused = false
    }

    public func getText(): String {
        var result = ""
        for ((index, line) in indexedLines(lines)) {
            if (index > 0) {
                result += "\n"
            }
            result += line
        }
        result
    }
}

public class TextArea <: Component {
    private let width: Int64
    private let height: Int64
    private let id: String

    public init(width: Int64, height: Int64, id: String) {
        this.width = width
        this.height = height
        this.id = id
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let taState = (state as TextAreaState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            applyTextAreaEvent(ctx, taState, event, id, height)
        }
        Action.update(taState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let taState = (state as TextAreaState).getOrThrow()
        let container = Div()
            .id(id)
            .focusable()
            .width(Dimension.Fixed(width))
            .height(Dimension.Fixed(height))
            .style(textAreaContainerStyle(taState.focused))

        let viewportHeight = height
        let startRow = taState.scrollRow
        var row = Int64(0)
        while (row < viewportHeight) {
            let lineIndex = startRow + row
            if (lineIndex < taState.lines.size) {
                let line = taState.lines[lineIndex]
                let displayLine = if (taState.focused && lineIndex == taState.cursorRow) {
                    taInsertCursor(line, taState.cursorCol)
                } else {
                    line
                }
                container.child(Node.text(taPadOrTrim(displayLine, width), textAreaLineStyle(taState.focused)))
            } else {
                container.child(Node.text(taPadOrTrim("~", width), textAreaEmptyLineStyle()))
            }
            row += 1
        }

        Node.div(container)
    }
}

private func applyTextAreaEvent(ctx: Context, state: TextAreaState, event: UiEvent, id: String, viewportHeight: Int64): Unit {
    match (event) {
        case UiEvent.Focus(nodeId) => if (nodeId == id) { state.focused = true }
        case UiEvent.Blur(nodeId) => if (nodeId == id) { state.focused = false }
        case UiEvent.Key(keyEvent) => if (state.focused) { applyTextAreaKey(ctx, state, keyEvent, id, viewportHeight) }
        case _ => ()
    }
}

private func applyTextAreaKey(ctx: Context, state: TextAreaState, keyEvent: KeyEvent, id: String, viewportHeight: Int64): Unit {
    let code = keyEvent.code
    match (code) {
        case KeyCode.Char(ch) =>
            let line = state.lines[state.cursorRow]
            state.lines[state.cursorRow] = taInsertRuneAt(line, state.cursorCol, ch)
            state.cursorCol += 1
        case KeyCode.Enter =>
            if (keyEvent.modifiers.ctrl) {
                ctx.send(BuiltinEvent.TextAreaSubmitted(id, state.getText()))
            } else {
                let line = state.lines[state.cursorRow]
                let before = taSubstring(line, 0, state.cursorCol)
                let after = taSubstring(line, state.cursorCol, taRuneCount(line))
                state.lines[state.cursorRow] = before
                state.lines = taInsertLineAfter(state.lines, state.cursorRow, after)
                state.cursorRow += 1
                state.cursorCol = 0
            }
        case KeyCode.Backspace =>
            if (state.cursorCol > 0) {
                let line = state.lines[state.cursorRow]
                state.lines[state.cursorRow] = taRemoveRuneAt(line, state.cursorCol - 1)
                state.cursorCol -= 1
            } else if (state.cursorRow > 0) {
                let prevLine = state.lines[state.cursorRow - 1]
                let currentLine = state.lines[state.cursorRow]
                state.cursorCol = taRuneCount(prevLine)
                state.lines[state.cursorRow - 1] = prevLine + currentLine
                state.lines.remove(state.cursorRow..state.cursorRow + 1)
                state.cursorRow -= 1
            }
        case KeyCode.Delete =>
            let line = state.lines[state.cursorRow]
            if (state.cursorCol < taRuneCount(line)) {
                state.lines[state.cursorRow] = taRemoveRuneAt(line, state.cursorCol)
            } else if (state.cursorRow + 1 < state.lines.size) {
                let nextLine = state.lines[state.cursorRow + 1]
                state.lines[state.cursorRow] = line + nextLine
                state.lines.remove((state.cursorRow + 1)..(state.cursorRow + 2))
            }
        case KeyCode.Left =>
            if (state.cursorCol > 0) {
                state.cursorCol -= 1
            } else if (state.cursorRow > 0) {
                state.cursorRow -= 1
                state.cursorCol = taRuneCount(state.lines[state.cursorRow])
            }
        case KeyCode.Right =>
            let lineLen = taRuneCount(state.lines[state.cursorRow])
            if (state.cursorCol < lineLen) {
                state.cursorCol += 1
            } else if (state.cursorRow + 1 < state.lines.size) {
                state.cursorRow += 1
                state.cursorCol = 0
            }
        case KeyCode.Up =>
            if (state.cursorRow > 0) {
                state.cursorRow -= 1
                let lineLen = taRuneCount(state.lines[state.cursorRow])
                if (state.cursorCol > lineLen) {
                    state.cursorCol = lineLen
                }
            }
        case KeyCode.Down =>
            if (state.cursorRow + 1 < state.lines.size) {
                state.cursorRow += 1
                let lineLen = taRuneCount(state.lines[state.cursorRow])
                if (state.cursorCol > lineLen) {
                    state.cursorCol = lineLen
                }
            }
        case KeyCode.Home => state.cursorCol = 0
        case KeyCode.End => state.cursorCol = taRuneCount(state.lines[state.cursorRow])
        case _ => ()
    }
    ensureTextAreaScrollVisible(state, viewportHeight)
}

private func ensureTextAreaScrollVisible(state: TextAreaState, viewportHeight: Int64): Unit {
    if (state.cursorRow < state.scrollRow) {
        state.scrollRow = state.cursorRow
    }
    if (state.cursorRow >= state.scrollRow + viewportHeight) {
        state.scrollRow = state.cursorRow - viewportHeight + 1
    }
    if (state.scrollRow < 0) {
        state.scrollRow = 0
    }
}

private func splitLines(text: String): ArrayList<String> {
    let result = ArrayList<String>()
    var current = ""
    for (ch in text.runes()) {
        if (ch == r'\n') {
            result.add(current)
            current = ""
        } else {
            current += ch.toString()
        }
    }
    result.add(current)
    result
}

private func taInsertLineAfter(lines: ArrayList<String>, index: Int64, line: String): ArrayList<String> {
    let result = ArrayList<String>()
    for (i in 0..lines.size) {
        result.add(lines[i])
        if (i == index) {
            result.add(line)
        }
    }
    result
}

private func indexedLines(lines: ArrayList<String>): Array<(Int64, String)> {
    Array<(Int64, String)>(lines.size, { index => (index, lines[index]) })
}

private func taInsertCursor(line: String, col: Int64): String {
    taInsertRuneAt(line, col, r'|')
}

private func taInsertRuneAt(text: String, index: Int64, ch: Rune): String {
    let count = taRuneCount(text)
    let clamped = if (index < 0) { 0 } else if (index > count) { count } else { index }
    taSubstring(text, 0, clamped) + ch.toString() + taSubstring(text, clamped, count)
}

private func taRemoveRuneAt(text: String, index: Int64): String {
    let count = taRuneCount(text)
    if (index < 0 || index >= count) { return text }
    taSubstring(text, 0, index) + taSubstring(text, index + 1, count)
}

private func taSubstring(text: String, start: Int64, endExclusive: Int64): String {
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

private func taRuneCount(text: String): Int64 {
    var count = Int64(0)
    for (_ in text.runes()) { count += 1 }
    count
}

private func taPadOrTrim(text: String, width: Int64): String {
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

private func textAreaContainerStyle(focused: Bool): Style {
    let borderColor = if (focused) { Color.BrightGreen } else { Color.BrightBlack }
    Style().withBorder(Border(BorderStyle.Single, borderColor)).withBackground(Color.Black)
}

private func textAreaLineStyle(focused: Bool): TextStyle {
    let fg = if (focused) { Color.BrightWhite } else { Color.White }
    TextStyle().withForeground(fg).withBackground(Color.Black)
}

private func textAreaEmptyLineStyle(): TextStyle {
    TextStyle().withForeground(Color.BrightBlack).withBackground(Color.Black)
}
