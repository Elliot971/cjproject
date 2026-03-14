package cjrxtui.buffer

import std.collection.ArrayList
import cjrxtui.style.{Color, TextStyle}

public struct CellStyle {
    public let bold: Bool
    public let italic: Bool
    public let underline: Bool
    public let strikethrough: Bool

    public init() {
        this.bold = false
        this.italic = false
        this.underline = false
        this.strikethrough = false
    }

    public init(bold: Bool, italic: Bool, underline: Bool, strikethrough: Bool) {
        this.bold = bold
        this.italic = italic
        this.underline = underline
        this.strikethrough = strikethrough
    }

    public static func fromTextStyle(textStyle: TextStyle): CellStyle {
        CellStyle(textStyle.bold, textStyle.italic, textStyle.underline, textStyle.strikethrough)
    }
}

public struct Cell {
    public let rune: Rune
    public let foreground: ?Color
    public let background: ?Color
    public let style: CellStyle

    public init(rune: Rune) {
        this.rune = rune
        this.foreground = None
        this.background = None
        this.style = CellStyle()
    }

    public init(rune: Rune, foreground: ?Color, background: ?Color, style: CellStyle) {
        this.rune = rune
        this.foreground = foreground
        this.background = background
        this.style = style
    }

    public static func empty(): Cell {
        Cell(r' ')
    }

    public func withForeground(color: Color): Cell {
        Cell(rune, color, background, style)
    }

    public func withBackground(color: Color): Cell {
        Cell(rune, foreground, color, style)
    }

    public func withStyle(nextStyle: CellStyle): Cell {
        Cell(rune, foreground, background, nextStyle)
    }
}

public class ScreenBuffer {
    private var _width: Int64
    private var _height: Int64
    private var _cells: Array<Array<Cell>>

    public init(width: Int64, height: Int64) {
        let safeWidth = if (width > 0) { width } else { 1 }
        let safeHeight = if (height > 0) { height } else { 1 }
        _width = safeWidth
        _height = safeHeight
        _cells = Array<Array<Cell>>(safeHeight, { _ => Array<Cell>(safeWidth, repeat: Cell.empty()) })
    }

    public prop width: Int64 {
        get() {
            _width
        }
    }

    public prop height: Int64 {
        get() {
            _height
        }
    }

    public func clear(): Unit {
        _cells = Array<Array<Cell>>(_height, { _ => Array<Cell>(_width, repeat: Cell.empty()) })
    }

    public func resize(width: Int64, height: Int64): Unit {
        let safeWidth = if (width > 0) { width } else { 1 }
        let safeHeight = if (height > 0) { height } else { 1 }
        _width = safeWidth
        _height = safeHeight
        _cells = Array<Array<Cell>>(safeHeight, { _ => Array<Cell>(safeWidth, repeat: Cell.empty()) })
    }

    public func getCell(x: Int64, y: Int64): ?Cell {
        if (!inBounds(x, y)) {
            return None
        }
        _cells[y][x]
    }

    public func setCell(x: Int64, y: Int64, cell: Cell): Unit {
        if (!inBounds(x, y)) {
            return
        }
        _cells[y][x] = cell
    }

    public func fillRect(x: Int64, y: Int64, width: Int64, height: Int64, cell: Cell): Unit {
        let clampedWidth = if (width > 0) { width } else { 1 }
        let clampedHeight = if (height > 0) { height } else { 1 }
        for (rowOffset in 0..clampedHeight) {
            for (columnOffset in 0..clampedWidth) {
                setCell(x + columnOffset, y + rowOffset, cell)
            }
        }
    }

    public func writeText(x: Int64, y: Int64, text: String): Unit {
        writeText(x, y, text, None, None, CellStyle())
    }

    public func writeText(
        x: Int64,
        y: Int64,
        text: String,
        foreground: ?Color,
        background: ?Color,
        style: CellStyle
    ): Unit {
        var cursorX = x
        var cursorY = y

        for (ch in text.runes()) {
            if (ch == r'\n') {
                cursorX = x
                cursorY += 1
            } else {
                setCell(cursorX, cursorY, Cell(ch, foreground, background, style))
                cursorX += 1
            }
        }
    }

    public func toString(): String {
        var result = ""
        for (rowIndex in 0.._height) {
            result += rowToString(rowIndex)
            if (rowIndex + 1 < _height) {
                result += "\n"
            }
        }
        result
    }

    private func rowToString(rowIndex: Int64): String {
        var line = ""
        for (columnIndex in 0.._width) {
            line += _cells[rowIndex][columnIndex].rune.toString()
        }
        rstrip(line)
    }

    private func inBounds(x: Int64, y: Int64): Bool {
        x >= 0 && y >= 0 && x < _width && y < _height
    }
    private func rstrip(text: String): String {
        var lastNonSpace = Int64(-1)
        var index = Int64(0)
        for (ch in text.runes()) {
            if (ch != r' ') {
                lastNonSpace = index
            }
            index += 1
        }

        if (lastNonSpace < 0) {
            return ""
        }

        var result = ""
        var limit = Int64(0)
        for (ch in text.runes()) {
            if (limit > lastNonSpace) {
                return result
            }
            result += ch.toString()
            limit += 1
        }
        result
    }
}

public enum CellUpdate {
    | Single(Int64, Int64, Cell)
}

public class DoubleBuffer {
    private let _front: ScreenBuffer
    private let _back: ScreenBuffer

    public init(width: Int64, height: Int64) {
        _front = ScreenBuffer(width, height)
        _back = ScreenBuffer(width, height)
    }

    public func frontBuffer(): ScreenBuffer {
        _front
    }

    public func backBuffer(): ScreenBuffer {
        _back
    }

    public func clearBack(): Unit {
        _back.clear()
    }

    public func reset(): Unit {
        _front.clear()
        _back.clear()
    }

    public func resize(width: Int64, height: Int64): Unit {
        _front.resize(width, height)
        _back.resize(width, height)
    }

    public func swap(): Unit {
        let width = _front.width
        let height = _front.height

        for (y in 0..height) {
            for (x in 0..width) {
                match (_back.getCell(x, y)) {
                    case Some(cell) => _front.setCell(x, y, cell)
                    case None => ()
                }
            }
        }
    }

    public func diff(): Array<CellUpdate> {
        let updates = ArrayList<CellUpdate>()
        let width = _front.width
        let height = _front.height

        for (y in 0..height) {
            for (x in 0..width) {
                let frontCell = _front.getCell(x, y)
                let backCell = _back.getCell(x, y)
                if (cellsDiffer(frontCell, backCell)) {
                    match (backCell) {
                        case Some(cell) => updates.add(CellUpdate.Single(x, y, cell))
                        case None => ()
                    }
                }
            }
        }

        Array<CellUpdate>(updates.size, { index => updates[index] })
    }

    private func cellsDiffer(left: ?Cell, right: ?Cell): Bool {
        match (left) {
            case Some(a) => match (right) {
                case Some(b) => !cellsEqual(a, b)
                case None => true
            }
            case None => match (right) {
                case Some(_) => true
                case None => false
            }
        }
    }

    private func cellsEqual(left: Cell, right: Cell): Bool {
        left.rune == right.rune &&
        colorsEqual(left.foreground, right.foreground) &&
        colorsEqual(left.background, right.background) &&
        left.style.bold == right.style.bold &&
        left.style.italic == right.style.italic &&
        left.style.underline == right.style.underline &&
        left.style.strikethrough == right.style.strikethrough
    }

    private func colorsEqual(left: ?Color, right: ?Color): Bool {
        match (left) {
            case Some(a) => match (right) {
                case Some(b) => colorEquals(a, b)
                case None => false
            }
            case None => match (right) {
                case Some(_) => false
                case None => true
            }
        }
    }

    private func colorEquals(left: Color, right: Color): Bool {
        match (left) {
            case Color.Black => isSameSimpleColor(right, Color.Black)
            case Color.Red => isSameSimpleColor(right, Color.Red)
            case Color.Green => isSameSimpleColor(right, Color.Green)
            case Color.Yellow => isSameSimpleColor(right, Color.Yellow)
            case Color.Blue => isSameSimpleColor(right, Color.Blue)
            case Color.Magenta => isSameSimpleColor(right, Color.Magenta)
            case Color.Cyan => isSameSimpleColor(right, Color.Cyan)
            case Color.White => isSameSimpleColor(right, Color.White)
            case Color.BrightBlack => isSameSimpleColor(right, Color.BrightBlack)
            case Color.BrightRed => isSameSimpleColor(right, Color.BrightRed)
            case Color.BrightGreen => isSameSimpleColor(right, Color.BrightGreen)
            case Color.BrightYellow => isSameSimpleColor(right, Color.BrightYellow)
            case Color.BrightBlue => isSameSimpleColor(right, Color.BrightBlue)
            case Color.BrightMagenta => isSameSimpleColor(right, Color.BrightMagenta)
            case Color.BrightCyan => isSameSimpleColor(right, Color.BrightCyan)
            case Color.BrightWhite => isSameSimpleColor(right, Color.BrightWhite)
            case Color.Rgb(r1, g1, b1) => match (right) {
                case Color.Rgb(r2, g2, b2) => r1 == r2 && g1 == g2 && b1 == b2
                case _ => false
            }
        }
    }

    private func isSameSimpleColor(candidate: Color, expected: Color): Bool {
        match (expected) {
            case Color.Black => match (candidate) { case Color.Black => true case _ => false }
            case Color.Red => match (candidate) { case Color.Red => true case _ => false }
            case Color.Green => match (candidate) { case Color.Green => true case _ => false }
            case Color.Yellow => match (candidate) { case Color.Yellow => true case _ => false }
            case Color.Blue => match (candidate) { case Color.Blue => true case _ => false }
            case Color.Magenta => match (candidate) { case Color.Magenta => true case _ => false }
            case Color.Cyan => match (candidate) { case Color.Cyan => true case _ => false }
            case Color.White => match (candidate) { case Color.White => true case _ => false }
            case Color.BrightBlack => match (candidate) { case Color.BrightBlack => true case _ => false }
            case Color.BrightRed => match (candidate) { case Color.BrightRed => true case _ => false }
            case Color.BrightGreen => match (candidate) { case Color.BrightGreen => true case _ => false }
            case Color.BrightYellow => match (candidate) { case Color.BrightYellow => true case _ => false }
            case Color.BrightBlue => match (candidate) { case Color.BrightBlue => true case _ => false }
            case Color.BrightMagenta => match (candidate) { case Color.BrightMagenta => true case _ => false }
            case Color.BrightCyan => match (candidate) { case Color.BrightCyan => true case _ => false }
            case Color.BrightWhite => match (candidate) { case Color.BrightWhite => true case _ => false }
            case Color.Rgb(_, _, _) => false
        }
    }
}
