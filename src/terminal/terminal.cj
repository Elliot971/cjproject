package cjrxtui.terminal

import std.collection.ArrayList
import std.convert.*
import std.io.*
import std.process.*
import std.time.DateTime
import cjrxtui.buffer.{Cell, CellStyle, CellUpdate}
import cjrxtui.style.Color

public struct TerminalSize {
    public let width: Int64
    public let height: Int64

    public init(width: Int64, height: Int64) {
        this.width = width
        this.height = height
    }
}

public interface TerminalSizeReader {
    func read(): ?TerminalSize
}

public class NoopTerminalSizeReader <: TerminalSizeReader {
    public init() {}

    public func read(): ?TerminalSize {
        None
    }
}

public class SttyTerminalSizeReader <: TerminalSizeReader {
    private var cachedSize: ?TerminalSize = None
    private var lastReadTimeNs: Int64 = 0
    private let cacheValidityNs: Int64 = 500 * 1000 * 1000  // 500ms
    private var consecutiveFailures: Int64 = 0

    public init() {}

    public func read(): ?TerminalSize {
        let now = DateTime.now().toUnixTimeStamp().toNanoseconds()
        if (now - lastReadTimeNs < cacheValidityNs) {
            return cachedSize
        }
        lastReadTimeNs = now

        let result = readFromStty()
        match (result) {
            case Some(_) => consecutiveFailures = 0
            case None => consecutiveFailures += 1
        }
        cachedSize = result ?? cachedSize
        cachedSize
    }

    private func readFromStty(): ?TerminalSize {
        match (readTerminalSizeFromCommand("sh", ["-lc", "stty size </dev/tty"])) {
            case Some(size) => return size
            case None => ()
        }
        readTerminalSizeFromCommand("stty", ["size"])
    }
}

public enum TerminalInputMode {
    | Canonical
    | Raw
}

public interface TerminalModeController {
    func enterRawMode(): Unit
    func restoreMode(): Unit
    func currentMode(): TerminalInputMode
}

public class NoopTerminalModeController <: TerminalModeController {
    public init() {}

    public func enterRawMode(): Unit {}

    public func restoreMode(): Unit {}

    public func currentMode(): TerminalInputMode {
        TerminalInputMode.Canonical
    }
}

public class SttyTerminalModeController <: TerminalModeController {
    private var savedState: ?String = None
    private var mode: TerminalInputMode = TerminalInputMode.Canonical

    public init() {}

    public func enterRawMode(): Unit {
        if (isRawMode()) {
            return
        }

        let previousState = readCurrentState()
        if (runStty(["raw", "-echo", "min", "1", "time", "0"])) {
            if (!previousState.isEmpty()) {
                savedState = previousState
            }
            mode = TerminalInputMode.Raw
        }
    }

    public func restoreMode(): Unit {
        if (!isRawMode()) {
            return
        }

        match (savedState) {
            case Some(state) =>
                let _ = runStty([state])
            case None =>
                let _ = runStty(["sane"])
        }

        savedState = None
        mode = TerminalInputMode.Canonical
    }

    public func currentMode(): TerminalInputMode {
        mode
    }

    private func isRawMode(): Bool {
        match (mode) {
            case TerminalInputMode.Raw => true
            case _ => false
        }
    }

    private func readCurrentState(): String {
        let (exitCode, stdOut, _) = executeWithOutput("sh", ["-c", "stty -g </dev/tty"])
        if (exitCode != 0) {
            return ""
        }
        bytesToString(stdOut).trimAscii()
    }

    private func runStty(arguments: Array<String>): Bool {
        var cmd = "stty"
        for (arg in arguments) {
            cmd += " " + arg
        }
        cmd += " </dev/tty"
        execute(
            "sh",
            ["-c", cmd],
            stdOut: ProcessRedirect.Discard,
            stdErr: ProcessRedirect.Discard
        ) == 0
    }
}

public enum TerminalCommand {
    | MoveTo(Int64, Int64)
    | SetForeground(Color)
    | ResetForeground
    | SetBackground(Color)
    | ResetBackground
    | SetStyle(CellStyle)
    | ResetStyle
    | Print(String)
}

public class TerminalRenderer {
    private var _cursorX: ?Int64 = None
    private var _cursorY: ?Int64 = None
    private var _foreground: ?Color = None
    private var _background: ?Color = None
    private var _style: CellStyle = CellStyle()

    public init() {}

    public func clearScreenAnsi(): String {
        esc("[2J") + esc("[H")
    }

    public func enterAlternateScreenAnsi(): String {
        esc("[?1049h")
    }

    public func leaveAlternateScreenAnsi(): String {
        esc("[?1049l")
    }

    public func hideCursorAnsi(): String {
        esc("[?25l")
    }

    public func showCursorAnsi(): String {
        esc("[?25h")
    }

    public func enableMouseCaptureAnsi(): String {
        esc("[?1003h") + esc("[?1006h")
    }

    public func disableMouseCaptureAnsi(): String {
        esc("[?1006l") + esc("[?1003l")
    }

    public func resetAnsi(): String {
        esc("[0m")
    }

    public func buildCommands(updates: Array<CellUpdate>): Array<TerminalCommand> {
        let commands = ArrayList<TerminalCommand>()

        for (update in updates) {
            match (update) {
                case CellUpdate.Single(x, y, cell) => appendCommandsForCell(commands, x, y, cell)
            }
        }

        return Array<TerminalCommand>(commands.size, { index => commands[index] })
    }

    public func renderToAnsi(updates: Array<CellUpdate>): String {
        let commands = buildCommands(updates)
        var output = ""
        for (command in commands) {
            output += toAnsi(command)
        }
        output
    }

    public func resetState(): Unit {
        _cursorX = None
        _cursorY = None
        _foreground = None
        _background = None
        _style = CellStyle()
    }

    private func appendCommandsForCell(commands: ArrayList<TerminalCommand>, x: Int64, y: Int64, cell: Cell): Unit {
        if (!isCursorAt(x, y)) {
            commands.add(TerminalCommand.MoveTo(x, y))
            _cursorX = x
            _cursorY = y
        }

        appendColorCommands(commands, cell)
        appendStyleCommands(commands, cell.style)
        commands.add(TerminalCommand.Print(cell.rune.toString()))
        _cursorX = x + 1
        _cursorY = y
    }

    private func appendColorCommands(commands: ArrayList<TerminalCommand>, cell: Cell): Unit {
        if (!sameOptionalColor(_foreground, cell.foreground)) {
            match (cell.foreground) {
                case Some(color) => commands.add(TerminalCommand.SetForeground(color))
                case None => commands.add(TerminalCommand.ResetForeground)
            }
            _foreground = cell.foreground
        }

        if (!sameOptionalColor(_background, cell.background)) {
            match (cell.background) {
                case Some(color) => commands.add(TerminalCommand.SetBackground(color))
                case None => commands.add(TerminalCommand.ResetBackground)
            }
            _background = cell.background
        }
    }

    private func appendStyleCommands(commands: ArrayList<TerminalCommand>, nextStyle: CellStyle): Unit {
        if (!sameStyle(_style, nextStyle)) {
            commands.add(TerminalCommand.SetStyle(nextStyle))
            _style = nextStyle
        }
    }

    private func isCursorAt(x: Int64, y: Int64): Bool {
        match (_cursorX) {
            case Some(cursorX) => match (_cursorY) {
                case Some(cursorY) => cursorX == x && cursorY == y
                case None => false
            }
            case None => false
        }
    }

    private func sameStyle(left: CellStyle, right: CellStyle): Bool {
        left.bold == right.bold &&
        left.italic == right.italic &&
        left.underline == right.underline &&
        left.strikethrough == right.strikethrough
    }

    private func sameOptionalColor(left: ?Color, right: ?Color): Bool {
        match (left) {
            case Some(a) => match (right) {
                case Some(b) => sameColor(a, b)
                case None => false
            }
            case None => match (right) {
                case Some(_) => false
                case None => true
            }
        }
    }

    private func sameColor(left: Color, right: Color): Bool {
        match (left) {
            case Color.Black => match (right) { case Color.Black => true case _ => false }
            case Color.Red => match (right) { case Color.Red => true case _ => false }
            case Color.Green => match (right) { case Color.Green => true case _ => false }
            case Color.Yellow => match (right) { case Color.Yellow => true case _ => false }
            case Color.Blue => match (right) { case Color.Blue => true case _ => false }
            case Color.Magenta => match (right) { case Color.Magenta => true case _ => false }
            case Color.Cyan => match (right) { case Color.Cyan => true case _ => false }
            case Color.White => match (right) { case Color.White => true case _ => false }
            case Color.BrightBlack => match (right) { case Color.BrightBlack => true case _ => false }
            case Color.BrightRed => match (right) { case Color.BrightRed => true case _ => false }
            case Color.BrightGreen => match (right) { case Color.BrightGreen => true case _ => false }
            case Color.BrightYellow => match (right) { case Color.BrightYellow => true case _ => false }
            case Color.BrightBlue => match (right) { case Color.BrightBlue => true case _ => false }
            case Color.BrightMagenta => match (right) { case Color.BrightMagenta => true case _ => false }
            case Color.BrightCyan => match (right) { case Color.BrightCyan => true case _ => false }
            case Color.BrightWhite => match (right) { case Color.BrightWhite => true case _ => false }
            case Color.Rgb(r1, g1, b1) => match (right) {
                case Color.Rgb(r2, g2, b2) => r1 == r2 && g1 == g2 && b1 == b2
                case _ => false
            }
        }
    }

    private func toAnsi(command: TerminalCommand): String {
        match (command) {
            case TerminalCommand.MoveTo(x, y) => esc("[${y + 1};${x + 1}H")
            case TerminalCommand.SetForeground(color) => foregroundAnsi(color)
            case TerminalCommand.ResetForeground => esc("[39m")
            case TerminalCommand.SetBackground(color) => backgroundAnsi(color)
            case TerminalCommand.ResetBackground => esc("[49m")
            case TerminalCommand.SetStyle(style) => styleAnsi(style)
            case TerminalCommand.ResetStyle => esc("[0m")
            case TerminalCommand.Print(text) => text
        }
    }

    private func styleAnsi(style: CellStyle): String {
        var joined = "0"
        if (style.bold) {
            joined += ";1"
        }
        if (style.italic) {
            joined += ";3"
        }
        if (style.underline) {
            joined += ";4"
        }
        if (style.strikethrough) {
            joined += ";9"
        }
        esc("[${joined}m")
    }

    private func foregroundAnsi(color: Color): String {
        colorAnsi(color, background: false)
    }

    private func backgroundAnsi(color: Color): String {
        colorAnsi(color, background: true)
    }

    private func colorAnsi(color: Color, background!: Bool): String {
        let base = if (background) { 40 } else { 30 }
        let brightBase = if (background) { 100 } else { 90 }

        match (color) {
            case Color.Black => esc("[${base}m")
            case Color.Red => esc("[${base + 1}m")
            case Color.Green => esc("[${base + 2}m")
            case Color.Yellow => esc("[${base + 3}m")
            case Color.Blue => esc("[${base + 4}m")
            case Color.Magenta => esc("[${base + 5}m")
            case Color.Cyan => esc("[${base + 6}m")
            case Color.White => esc("[${base + 7}m")
            case Color.BrightBlack => esc("[${brightBase}m")
            case Color.BrightRed => esc("[${brightBase + 1}m")
            case Color.BrightGreen => esc("[${brightBase + 2}m")
            case Color.BrightYellow => esc("[${brightBase + 3}m")
            case Color.BrightBlue => esc("[${brightBase + 4}m")
            case Color.BrightMagenta => esc("[${brightBase + 5}m")
            case Color.BrightCyan => esc("[${brightBase + 6}m")
            case Color.BrightWhite => esc("[${brightBase + 7}m")
            case Color.Rgb(r, g, b) => rgbAnsi(r, g, b, background: background)
        }
    }

    private func rgbAnsi(r: UInt8, g: UInt8, b: UInt8, background!: Bool): String {
        let prefix = if (background) { 48 } else { 38 }
        esc("[${prefix};2;${r};${g};${b}m")
    }

    private func esc(body: String): String {
        "\u{1b}${body}"
    }
}

private func bytesToString(bytes: Array<Byte>): String {
    let buffer = ByteBuffer()
    buffer.write(bytes)
    StringReader(buffer).readToEnd()
}

private func readTerminalSizeFromCommand(command: String, arguments: Array<String>): ?TerminalSize {
    try {
        let (exitCode, stdOut, _) = executeWithOutput(command, arguments)
        if (exitCode != 0) {
            return None
        }
        return parseTerminalSizeOutput(bytesToString(stdOut))
    } catch (_: Exception) {
        return None
    }
}

private func parseTerminalSizeOutput(output: String): ?TerminalSize {
    let normalized = output.trimAscii()
    if (normalized.isEmpty()) {
        return None
    }

    let parts = normalized.split(" ", removeEmpty: true)
    if (parts.size < 2) {
        return None
    }

    if (let Some(rows) <- Int64.tryParse(parts[0]) && let Some(cols) <- Int64.tryParse(parts[1])) {
        return TerminalSize(cols, rows)
    }
    None
}
