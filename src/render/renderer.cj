package cjrxtui.render

import cjrxtui.buffer.{Cell, CellStyle, CellUpdate, DoubleBuffer, ScreenBuffer}
import cjrxtui.layout.{LayoutBox, LayoutEngine, LayoutKind}
import std.collection.ArrayList
import cjrxtui.node.{Node, RichText, TextSpan}
import cjrxtui.style.{BorderEdges, BorderStyle, Color, Overflow, TextAlign, TextStyle}
import cjrxtui.terminal.TerminalRenderer

public class RenderBuffer {
    private let screenBuffer: ScreenBuffer

    public init(width: Int64, height: Int64) {
        screenBuffer = ScreenBuffer(width, height)
    }

    public func setCell(x: Int64, y: Int64, cell: Cell): Unit {
        screenBuffer.setCell(x, y, cell)
    }

    public func writeText(x: Int64, y: Int64, text: String): Unit {
        screenBuffer.writeText(x, y, text)
    }

    public func fillRect(x: Int64, y: Int64, width: Int64, height: Int64, cell: Cell): Unit {
        screenBuffer.fillRect(x, y, width, height, cell)
    }

    public func toString(): String {
        screenBuffer.toString()
    }

    public func screen(): ScreenBuffer {
        screenBuffer
    }
}

public struct FrameResult {
    public let frame: String
    public let updates: Array<CellUpdate>

    public init(frame: String, updates: Array<CellUpdate>) {
        this.frame = frame
        this.updates = updates
    }
}

private struct BorderGlyphs {
    let horizontal: Rune
    let vertical: Rune
    let topLeft: Rune
    let topRight: Rune
    let bottomLeft: Rune
    let bottomRight: Rune

    init(horizontal: Rune, vertical: Rune, topLeft: Rune, topRight: Rune, bottomLeft: Rune, bottomRight: Rune) {
        this.horizontal = horizontal
        this.vertical = vertical
        this.topLeft = topLeft
        this.topRight = topRight
        this.bottomLeft = bottomLeft
        this.bottomRight = bottomRight
    }
}

public class FramePipeline {
    private let renderer: Renderer
    private let terminalRenderer: TerminalRenderer
    private let buffers: DoubleBuffer

    public init(width: Int64, height: Int64) {
        renderer = Renderer()
        terminalRenderer = TerminalRenderer()
        buffers = DoubleBuffer(width, height)
    }

    public func renderFrame(node: Node): FrameResult {
        let rendered = renderer.renderToScreenBuffer(node)
        syncBackBuffer(rendered.screen())
        let updates = buffers.diff()
        let frame = terminalRenderer.renderToAnsi(updates)
        buffers.swap()
        FrameResult(frame, updates)
    }

    public func reset(): Unit {
        terminalRenderer.resetState()
        buffers.reset()
    }

    public func resize(width: Int64, height: Int64): Unit {
        terminalRenderer.resetState()
        buffers.resize(width, height)
        buffers.reset()
    }

    private func syncBackBuffer(source: ScreenBuffer): Unit {
        buffers.backBuffer().resize(source.width, source.height)
        buffers.clearBack()

        for (y in 0..source.height) {
            for (x in 0..source.width) {
                match (source.getCell(x, y)) {
                    case Some(cell) => buffers.backBuffer().setCell(x, y, cell)
                    case None => ()
                }
            }
        }
    }
}

public class Renderer {
    private let layoutEngine: LayoutEngine

    public init() {
        layoutEngine = LayoutEngine()
    }

    public func render(node: Node): String {
        let layoutRoot = layoutEngine.layout(node)
        render(layoutRoot)
    }

    public func renderToScreenBuffer(node: Node): RenderBuffer {
        let layoutRoot = layoutEngine.layout(node)
        renderToScreenBuffer(layoutRoot)
    }

    public func render(layoutRoot: LayoutBox): String {
        let buffer = renderToScreenBuffer(layoutRoot)
        buffer.toString()
    }

    public func renderToScreenBuffer(layoutRoot: LayoutBox): RenderBuffer {
        let buffer = RenderBuffer(layoutRoot.frame.width, layoutRoot.frame.height)
        paintLayout(layoutRoot, buffer)
        buffer
    }

    private func paintLayout(node: LayoutBox, buffer: RenderBuffer): Unit {
        match (node.kind) {
            case LayoutKind.Empty => ()
            case LayoutKind.Div => paintDiv(node, buffer)
            case LayoutKind.Text => paintTextNode(node, buffer)
            case LayoutKind.RichText => paintRichTextNode(node, buffer)
        }

        for (child in node.childrenView) {
            paintLayout(child, buffer)
        }
    }

    private func paintDiv(node: LayoutBox, buffer: RenderBuffer): Unit {
        let frame = node.frame
        paintBackground(node, buffer)
        if (!shouldDrawContainer(node)) {
            return
        }

        let borderGlyphs = resolveBorderGlyphs(node)
        let edges = match (node.border) {
            case Some(border) => border.edges
            case None => BorderEdges.all()
        }

        // Draw horizontal edges
        if (edges.top) {
            drawHorizontalLine(buffer, frame.y, frame.x, frame.width, borderGlyphs.horizontal)
        }
        if (edges.bottom) {
            drawHorizontalLine(buffer, frame.y + frame.height - 1, frame.x, frame.width, borderGlyphs.horizontal)
        }
        // Draw vertical edges
        if (edges.left) {
            drawVerticalLine(buffer, frame.x, frame.y, frame.height, borderGlyphs.vertical)
        }
        if (edges.right) {
            drawVerticalLine(buffer, frame.x + frame.width - 1, frame.y, frame.height, borderGlyphs.vertical)
        }
        // Draw corners (only where adjacent edges meet)
        if (edges.top && edges.left) {
            setChar(buffer, frame.x, frame.y, borderGlyphs.topLeft)
        }
        if (edges.top && edges.right) {
            setChar(buffer, frame.x + frame.width - 1, frame.y, borderGlyphs.topRight)
        }
        if (edges.bottom && edges.left) {
            setChar(buffer, frame.x, frame.y + frame.height - 1, borderGlyphs.bottomLeft)
        }
        if (edges.bottom && edges.right) {
            setChar(buffer, frame.x + frame.width - 1, frame.y + frame.height - 1, borderGlyphs.bottomRight)
        }

        let label = divLabel(node)
        if (label.size > 0 && frame.width > 2) {
            drawStyledText(buffer, frame.x + 1, frame.y, truncate(label, frame.width - 2), borderLabelStyle(node))
        }
    }

    private func paintTextNode(node: LayoutBox, buffer: RenderBuffer): Unit {
        match (node.textContent) {
            case Some(content) => drawMultilineText(node, buffer, content, node.textStyle)
            case None => ()
        }
    }

    private func paintRichTextNode(node: LayoutBox, buffer: RenderBuffer): Unit {
        match (node.richText) {
            case Some(richText) => drawRichText(node, buffer, richText)
            case None => paintTextNode(node, buffer)
        }
    }

    private func drawRichText(node: LayoutBox, buffer: RenderBuffer, richText: RichText): Unit {
        let spans = flattenRichTextSpans(richText)
        var x = node.frame.x
        let y = node.frame.y
        let limit = node.frame.x + node.frame.width
        for (span in spans) {
            let style = mergeTextStyles(richText.style, span.style)
            for (ch in span.content.runes()) {
                if (x >= limit) {
                    return
                }
                drawStyledText(buffer, x, y, ch.toString(), style)
                x += 1
            }
        }
    }

    private func drawMultilineText(node: LayoutBox, buffer: RenderBuffer, content: String, textStyle: ?TextStyle): Unit {
        let y = node.frame.y
        let width = node.frame.width
        let height = node.frame.height
        if (width <= 0 || height <= 0) {
            return
        }

        var currentLine = ""
        var lineIndex = Int64(0)

        for (ch in content.runes()) {
            if (ch == r'\n') {
                if (lineIndex >= height) {
                    return
                }
                drawAlignedLine(node, buffer, y + lineIndex, truncate(currentLine, width), textStyle)
                currentLine = ""
                lineIndex += 1
            } else {
                currentLine += ch.toString()
            }
        }

        if (lineIndex < height) {
            drawAlignedLine(node, buffer, y + lineIndex, truncate(currentLine, width), textStyle)
        }
    }

    private func drawAlignedLine(node: LayoutBox, buffer: RenderBuffer, y: Int64, line: String, textStyle: ?TextStyle): Unit {
        let x = alignedX(node.frame.x, node.frame.width, line, textStyle)
        let clipped = clipText(node, line)
        drawStyledText(buffer, x, y, clipped, textStyle)
    }

    private func drawHorizontalLine(buffer: RenderBuffer, y: Int64, startX: Int64, width: Int64, ch: Rune): Unit {
        for (offset in 0..width) {
            setChar(buffer, startX + offset, y, ch)
        }
    }

    private func drawVerticalLine(buffer: RenderBuffer, x: Int64, startY: Int64, height: Int64, ch: Rune): Unit {
        for (offset in 0..height) {
            setChar(buffer, x, startY + offset, ch)
        }
    }

    private func drawStyledText(buffer: RenderBuffer, x: Int64, y: Int64, text: String, textStyle: ?TextStyle): Unit {
        match (textStyle) {
            case Some(style) => buffer.screen().writeText(x, y, text, style.foreground, style.background, CellStyle.fromTextStyle(style))
            case None => buffer.writeText(x, y, text)
        }
    }

    private func setChar(buffer: RenderBuffer, x: Int64, y: Int64, ch: Rune): Unit {
        let style: ?TextStyle = None
        setStyledChar(buffer, x, y, ch, style)
    }

    private func setStyledChar(buffer: RenderBuffer, x: Int64, y: Int64, ch: Rune, textStyle: ?TextStyle): Unit {
        match (textStyle) {
            case Some(style) => buffer.setCell(x, y, Cell(ch, style.foreground, style.background, CellStyle.fromTextStyle(style)))
            case None => buffer.setCell(x, y, Cell(ch))
        }
    }

    private func divLabel(node: LayoutBox): String {
        var label = "div"
        match (node.nodeId) {
            case Some(value) => label += "#" + value
            case None => ()
        }
        if (node.focusable) {
            label += "*"
        }
        label
    }

    private func shouldDrawContainer(node: LayoutBox): Bool {
        let frame = node.frame
        let content = node.contentFrame
        if (frame.width <= 1 || frame.height <= 1) {
            return false
        }
        match (node.border) {
            case Some(_) => return true
            case None => ()
        }
        frame.width > content.width && frame.height > content.height
    }

    private func paintBackground(node: LayoutBox, buffer: RenderBuffer): Unit {
        match (node.border) {
            case Some(border) =>
                let background = if (node.focusable) { Color.BrightBlack } else { Color.Black }
                let style = TextStyle().withForeground(border.color).withBackground(background)
                buffer.fillRect(node.frame.x, node.frame.y, node.frame.width, node.frame.height, Cell(r' ', style.foreground, style.background, CellStyle.fromTextStyle(style)))
            case None => ()
        }
    }

    private func resolveBorderGlyphs(node: LayoutBox): BorderGlyphs {
        match (node.border) {
            case Some(border) => match (border.style) {
                case BorderStyle.Double => BorderGlyphs(r'=', r'|', r'#', r'#', r'#', r'#')
                case BorderStyle.Rounded => BorderGlyphs(r'~', r':', r'/', r'/', r'\\', r'\\')
                case BorderStyle.Thick => BorderGlyphs(r'=', r'#', r'@', r'@', r'@', r'@')
                case BorderStyle.None => BorderGlyphs(r'-', r'|', r'+', r'+', r'+', r'+')
                case _ => BorderGlyphs(r'-', r'|', r'+', r'+', r'+', r'+')
            }
            case None => BorderGlyphs(r'-', r'|', r'+', r'+', r'+', r'+')
        }
    }

    private func borderLabelStyle(node: LayoutBox): ?TextStyle {
        match (node.border) {
            case Some(border) =>
                let background = if (node.focusable) { Color.BrightBlack } else { Color.Black }
                Some(TextStyle().withForeground(border.color).withBackground(background).withBold(true))
            case None => None
        }
    }

    private func truncate(text: String, limit: Int64): String {
        if (limit <= 0) {
            return ""
        }

        var result = ""
        var count = Int64(0)
        for (ch in text.runes()) {
            if (count >= limit) {
                return result
            }
            result += ch.toString()
            count += 1
        }
        result
    }

    private func clipText(node: LayoutBox, text: String): String {
        match (node.overflow) {
            case Overflow.Hidden => truncate(text, node.frame.width)
            case _ => truncate(text, node.frame.width)
        }
    }

    private func alignedX(x: Int64, width: Int64, text: String, textStyle: ?TextStyle): Int64 {
        let textWidth = text.size
        match (textStyle) {
            case Some(style) => match (style.align) {
                case TextAlign.Center => x + maxInt64((width - textWidth) / 2, 0)
                case TextAlign.Right => x + maxInt64(width - textWidth, 0)
                case _ => x
            }
            case None => x
        }
    }

    private func maxInt64(left: Int64, right: Int64): Int64 {
        if (left > right) {
            return left
        }
        right
    }

    private func flattenRichTextSpans(richText: RichText): ArrayList<TextSpan> {
        let spans = ArrayList<TextSpan>()
        for (span in richText.spans) {
            spans.add(span)
        }
        spans
    }

    private func mergeTextStyles(base: ?TextStyle, override: ?TextStyle): ?TextStyle {
        match (override) {
            case Some(style) => Some(style)
            case None => base
        }
    }

}
