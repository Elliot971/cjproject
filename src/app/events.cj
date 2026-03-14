package cjrxtui.app

import std.convert.*
import cjrxtui.component.{KeyCode, KeyEvent, KeyModifiers, MouseButton, MouseEvent, MouseEventKind, ResizeEvent, UiEvent}

public struct ParsedInputLine {
    public let event: ?RuntimeEvent
    public let shouldContinue: Bool

    public init(event: ?RuntimeEvent, shouldContinue: Bool) {
        this.event = event
        this.shouldContinue = shouldContinue
    }
}

public struct ParsedRawInput {
    public let event: ?RuntimeEvent
    public let consumed: Int64

    public init(event: ?RuntimeEvent, consumed: Int64) {
        this.event = event
        this.consumed = consumed
    }
}

// Force-flush an incomplete ESC buffer by interpreting the leading ESC as a standalone Esc key.
public func forceFlushEsc(text: String): ParsedRawInput {
    if (text.isEmpty()) {
        return ParsedRawInput(None, 0)
    }
    let runes = text.toRuneArray()
    if (runes[0] == r'\u{1b}') {
        return ParsedRawInput(RuntimeEvent.Key("esc"), 1)
    }
    // Should not happen, but parse normally
    parseRawInput(text)
}

public func normalizeKeyName(name: String): KeyEvent {
    // Handle modifier-prefixed key names: ctrl+X, alt+X
    if (name.startsWith("ctrl+") && name.size > 5) {
        let base = name[5..name.size]
        return KeyEvent(normalizeNamedKey(base).code, KeyModifiers(true, false, false, false))
    }
    if (name.startsWith("alt+") && name.size > 4) {
        let base = name[4..name.size]
        return KeyEvent(normalizeNamedKey(base).code, KeyModifiers(false, true, false, false))
    }
    match (name) {
        case "up" => KeyEvent(KeyCode.Up)
        case "down" => KeyEvent(KeyCode.Down)
        case "left" => KeyEvent(KeyCode.Left)
        case "right" => KeyEvent(KeyCode.Right)
        case "enter" => KeyEvent(KeyCode.Enter)
        case "esc" => KeyEvent(KeyCode.Esc)
        case "tab" => KeyEvent(KeyCode.Tab)
        case "backtab" => KeyEvent(KeyCode.BackTab)
        case "backspace" => KeyEvent(KeyCode.Backspace)
        case "home" => KeyEvent(KeyCode.Home)
        case "end" => KeyEvent(KeyCode.End)
        case "pageup" => KeyEvent(KeyCode.PageUp)
        case "pagedown" => KeyEvent(KeyCode.PageDown)
        case "insert" => KeyEvent(KeyCode.Insert)
        case "delete" => KeyEvent(KeyCode.Delete)
        case _ => normalizeNamedKey(name)
    }
}

public func normalizeRuntimeEvent(event: RuntimeEvent): ?UiEvent {
    match (event) {
        case RuntimeEvent.Tick => UiEvent.Tick
        case RuntimeEvent.Key(name) => UiEvent.Key(normalizeKeyName(name))
        case RuntimeEvent.Mouse(mouseEvent) => UiEvent.Mouse(mouseEvent)
        case RuntimeEvent.Resize(width, height) => UiEvent.Resize(ResizeEvent(width, height))
        case RuntimeEvent.Stop => None
    }
}

public func parseInputLine(line: String): ParsedInputLine {
    let normalized = line.trimAscii()
    if (normalized.isEmpty()) {
        return ParsedInputLine(None, true)
    }

    let parts = normalized.split(" ", removeEmpty: true)
    match (parts[0].toAsciiLower()) {
        case "tick" => ParsedInputLine(RuntimeEvent.Tick, true)
        case "key" => parseKeyInput(parts)
        case "resize" => parseResizeInput(parts)
        case "stop" => ParsedInputLine(RuntimeEvent.Stop, true)
        case "quit" => ParsedInputLine(None, false)
        case _ => ParsedInputLine(None, true)
    }
}

public func parseRawInput(text: String): ParsedRawInput {
    let runes = text.toRuneArray()
    if (runes.isEmpty()) {
        return ParsedRawInput(None, 0)
    }

    let first = runes[0]
    if (first == r'\u{03}' || first == r'\u{04}') {
        return ParsedRawInput(RuntimeEvent.Stop, 1)
    }
    if (first == r'\n' || first == r'\r') {
        return ParsedRawInput(RuntimeEvent.Key("enter"), 1)
    }
    if (first == r'\t') {
        return ParsedRawInput(RuntimeEvent.Key("tab"), 1)
    }
    if (first == r'\u{7f}' || first == r'\b') {
        return ParsedRawInput(RuntimeEvent.Key("backspace"), 1)
    }
    // Ctrl+letter: raw bytes 0x01-0x1A not already handled above
    if (first == r'\u{01}') { return ParsedRawInput(RuntimeEvent.Key("ctrl+a"), 1) }
    if (first == r'\u{02}') { return ParsedRawInput(RuntimeEvent.Key("ctrl+b"), 1) }
    if (first == r'\u{05}') { return ParsedRawInput(RuntimeEvent.Key("ctrl+e"), 1) }
    if (first == r'\u{06}') { return ParsedRawInput(RuntimeEvent.Key("ctrl+f"), 1) }
    if (first == r'\u{0b}') { return ParsedRawInput(RuntimeEvent.Key("ctrl+k"), 1) }
    if (first == r'\u{0c}') { return ParsedRawInput(RuntimeEvent.Key("ctrl+l"), 1) }
    if (first == r'\u{0e}') { return ParsedRawInput(RuntimeEvent.Key("ctrl+n"), 1) }
    if (first == r'\u{10}') { return ParsedRawInput(RuntimeEvent.Key("ctrl+p"), 1) }
    if (first == r'\u{12}') { return ParsedRawInput(RuntimeEvent.Key("ctrl+r"), 1) }
    if (first == r'\u{15}') { return ParsedRawInput(RuntimeEvent.Key("ctrl+u"), 1) }
    if (first == r'\u{17}') { return ParsedRawInput(RuntimeEvent.Key("ctrl+w"), 1) }
    if (first == r'\u{19}') { return ParsedRawInput(RuntimeEvent.Key("ctrl+y"), 1) }
    if (first == r'\u{1b}') {
        return parseEscapeSequence(runes)
    }
    ParsedRawInput(RuntimeEvent.Key(first.toString()), 1)
}

private func normalizeNamedKey(name: String): KeyEvent {
    match (functionKeyNumber(name)) {
        case Some(number) => KeyEvent(KeyCode.Function(number))
        case None => normalizeNamedOrCharKey(name)
    }
}

private func normalizeNamedOrCharKey(name: String): KeyEvent {
    if (name.size == 1) {
        for (ch in name.runes()) {
            return KeyEvent(KeyCode.Char(ch))
        }
    }
    KeyEvent(KeyCode.Named(name))
}

private func parseKeyInput(parts: Array<String>): ParsedInputLine {
    if (parts.size < 2) {
        return ParsedInputLine(None, true)
    }
    ParsedInputLine(RuntimeEvent.Key(parts[1].toAsciiLower()), true)
}

private func parseResizeInput(parts: Array<String>): ParsedInputLine {
    if (parts.size < 3) {
        return ParsedInputLine(None, true)
    }

    if (let Some(width) <- Int64.tryParse(parts[1]) && let Some(height) <- Int64.tryParse(parts[2])) {
        return ParsedInputLine(RuntimeEvent.Resize(width, height), true)
    }
    ParsedInputLine(None, true)
}

private func functionKeyNumber(name: String): ?Int64 {
    if (!name.startsWith("f") || name.size <= 1) {
        return None
    }
    Int64.tryParse(name[1..name.size])
}

private func parseEscapeSequence(runes: Array<Rune>): ParsedRawInput {
    if (runes.size == 1) {
        // ESC alone — need more data to distinguish ESC key from ESC sequence
        return ParsedRawInput(None, 0)
    }

    let second = runes[1]
    if (second == r'[') {
        return parseCsiSequence(textFromRunes(runes), runes)
    }
    if (second == r'O') {
        return parseSs3Sequence(runes)
    }
    // Alt+letter: ESC followed by a printable character
    if (second >= r'!' && second <= r'~') {
        return ParsedRawInput(RuntimeEvent.Key("alt+" + second.toString()), 2)
    }
    ParsedRawInput(RuntimeEvent.Key("esc"), 1)
}

private func parseCsiSequence(text: String, runes: Array<Rune>): ParsedRawInput {
    if (runes.size < 3) {
        // Have ESC[ but need at least one more char
        return ParsedRawInput(None, 0)
    }

    match (runes[2]) {
        case r'<' => parseMouseSequence(text, runes)
        case r'A' => ParsedRawInput(RuntimeEvent.Key("up"), 3)
        case r'B' => ParsedRawInput(RuntimeEvent.Key("down"), 3)
        case r'C' => ParsedRawInput(RuntimeEvent.Key("right"), 3)
        case r'D' => ParsedRawInput(RuntimeEvent.Key("left"), 3)
        case r'H' => ParsedRawInput(RuntimeEvent.Key("home"), 3)
        case r'F' => ParsedRawInput(RuntimeEvent.Key("end"), 3)
        case r'Z' => ParsedRawInput(RuntimeEvent.Key("backtab"), 3)
        case r'2' => parseTildeSequence(runes, "insert")
        case r'3' => parseTildeSequence(runes, "delete")
        case r'5' => parseTildeSequence(runes, "pageup")
        case r'6' => parseTildeSequence(runes, "pagedown")
        case _ => ParsedRawInput(RuntimeEvent.Key("esc"), 1)
    }
}

private func parseMouseSequence(text: String, runes: Array<Rune>): ParsedRawInput {
    let terminatorIndex = findMouseTerminator(runes)
    if (terminatorIndex < 0) {
        return ParsedRawInput(None, 0)
    }

    let body = text[3..terminatorIndex]
    let parts = body.split(";", removeEmpty: false)
    if (parts.size != 3) {
        return ParsedRawInput(RuntimeEvent.Key("esc"), 1)
    }

    if (let Some(code) <- Int64.tryParse(parts[0]) && let Some(column) <- Int64.tryParse(parts[1]) && let Some(row) <- Int64.tryParse(parts[2])) {
        let event = buildMouseEvent(code, column, row, runes[terminatorIndex])
        return ParsedRawInput(event, terminatorIndex + 1)
    }

    ParsedRawInput(RuntimeEvent.Key("esc"), 1)
}

private func parseSs3Sequence(runes: Array<Rune>): ParsedRawInput {
    if (runes.size < 3) {
        // Have ESC O but need one more char
        return ParsedRawInput(None, 0)
    }

    match (runes[2]) {
        case r'P' => ParsedRawInput(RuntimeEvent.Key("f1"), 3)
        case r'Q' => ParsedRawInput(RuntimeEvent.Key("f2"), 3)
        case r'R' => ParsedRawInput(RuntimeEvent.Key("f3"), 3)
        case r'S' => ParsedRawInput(RuntimeEvent.Key("f4"), 3)
        case _ => ParsedRawInput(RuntimeEvent.Key("esc"), 1)
    }
}

private func parseTildeSequence(runes: Array<Rune>, keyName: String): ParsedRawInput {
    if (runes.size >= 4 && runes[3] == r'~') {
        return ParsedRawInput(RuntimeEvent.Key(keyName), 4)
    }
    ParsedRawInput(RuntimeEvent.Key("esc"), 1)
}

private func findMouseTerminator(runes: Array<Rune>): Int64 {
    var index: Int64 = 3
    while (index < runes.size) {
        if (runes[index] == r'M' || runes[index] == r'm') {
            return index
        }
        index += 1
    }
    -1
}

private func buildMouseEvent(code: Int64, column: Int64, row: Int64, terminator: Rune): ?RuntimeEvent {
    let modifiers = mouseModifiers(code)
    let x = normalizeMouseCoordinate(column)
    let y = normalizeMouseCoordinate(row)

    if ((code & 64) != 0) {
        let wheelCode = code & 1
        if (wheelCode == 0) {
            return RuntimeEvent.Mouse(MouseEvent(x, y, MouseEventKind.ScrollUp, modifiers))
        }
        if (wheelCode == 1) {
            return RuntimeEvent.Mouse(MouseEvent(x, y, MouseEventKind.ScrollDown, modifiers))
        }
        return None
    }

    let baseCode = code & 3
    let motion = (code & 32) != 0
    if (motion) {
        match (mouseButton(baseCode)) {
            case Some(button) => return RuntimeEvent.Mouse(MouseEvent(x, y, MouseEventKind.Drag(button), modifiers))
            case None => return RuntimeEvent.Mouse(MouseEvent(x, y, MouseEventKind.Move, modifiers))
        }
    }

    if (terminator == r'm' || baseCode == 3) {
        match (mouseButton(baseCode)) {
            case Some(button) => return RuntimeEvent.Mouse(MouseEvent(x, y, MouseEventKind.Up(button), modifiers))
            case None => return RuntimeEvent.Mouse(MouseEvent(x, y, MouseEventKind.Move, modifiers))
        }
    }

    match (mouseButton(baseCode)) {
        case Some(button) => RuntimeEvent.Mouse(MouseEvent(x, y, MouseEventKind.Down(button), modifiers))
        case None => None
    }
}

private func mouseButton(code: Int64): ?MouseButton {
    match (code) {
        case 0 => MouseButton.Left
        case 1 => MouseButton.Middle
        case 2 => MouseButton.Right
        case _ => None
    }
}

private func mouseModifiers(code: Int64): KeyModifiers {
    KeyModifiers((code & 16) != 0, (code & 8) != 0, (code & 4) != 0, false)
}

private func normalizeMouseCoordinate(value: Int64): Int64 {
    if (value <= 0) {
        return 0
    }
    value - 1
}

private func textFromRunes(runes: Array<Rune>): String {
    var text = ""
    for (rune in runes) {
        text += rune.toString()
    }
    text
}
