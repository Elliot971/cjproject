package cjrxtui.layout

import std.collection.ArrayList
import cjrxtui.node.{Div, Node, RichText}
import cjrxtui.style.{Alignment, AlignSelf, Border, Dimension, Direction, JustifyContent, Overflow, Spacing, TextStyle, TextWrap}

public enum LayoutKind {
    | Empty
    | Div
    | Text
    | RichText
}

public struct Size {
    public let width: Int64
    public let height: Int64

    public init(width: Int64, height: Int64) {
        this.width = width
        this.height = height
    }
}

public struct Rect {
    public let x: Int64
    public let y: Int64
    public let width: Int64
    public let height: Int64

    public init(x: Int64, y: Int64, width: Int64, height: Int64) {
        this.x = x
        this.y = y
        this.width = width
        this.height = height
    }
}

public class LayoutBox {
    private let _kind: LayoutKind
    private var _frame: Rect
    private var _contentFrame: Rect
    private var _textContent: ?String = None
    private var _textStyle: ?TextStyle = None
    private var _richText: ?RichText = None
    private var _focusable: Bool = false
    private var _nodeId: ?String = None
    private var _border: ?Border = None
    private var _overflow: Overflow = Overflow.Visible
    private var _margin: Spacing = Spacing.zero()
    private var _alignSelf: AlignSelf = AlignSelf.Auto
    private let _children = ArrayList<LayoutBox>()

    public init(kind: LayoutKind, frame: Rect, contentFrame: Rect) {
        _kind = kind
        _frame = frame
        _contentFrame = contentFrame
    }

    public prop kind: LayoutKind {
        get() {
            _kind
        }
    }

    public prop frame: Rect {
        get() {
            _frame
        }
    }

    public prop contentFrame: Rect {
        get() {
            _contentFrame
        }
    }

    public prop childrenView: ArrayList<LayoutBox> {
        get() {
            _children
        }
    }

    public prop textContent: ?String {
        get() {
            _textContent
        }
    }

    public prop textStyle: ?TextStyle {
        get() {
            _textStyle
        }
    }

    public prop richText: ?RichText {
        get() {
            _richText
        }
    }

    public prop focusable: Bool {
        get() {
            _focusable
        }
    }

    public prop nodeId: ?String {
        get() {
            _nodeId
        }
    }

    public prop border: ?Border {
        get() {
            _border
        }
    }

    public prop overflow: Overflow {
        get() {
            _overflow
        }
    }

    public func setFrame(frame: Rect): Unit {
        _frame = frame
    }

    public func setContentFrame(frame: Rect): Unit {
        _contentFrame = frame
    }

    public func addChild(child: LayoutBox): Unit {
        _children.add(child)
    }

    public func setTextContent(content: String): Unit {
        _textContent = content
    }

    public func setTextStyle(style: TextStyle): Unit {
        _textStyle = style
    }

    public func setRichText(richText: RichText): Unit {
        _richText = richText
    }

    public func setFocusable(value: Bool): Unit {
        _focusable = value
    }

    public func setNodeId(nodeId: String): Unit {
        _nodeId = nodeId
    }

    public func setBorder(border: Border): Unit {
        _border = border
    }

    public func setOverflow(overflow: Overflow): Unit {
        _overflow = overflow
    }

    public prop margin: Spacing {
        get() {
            _margin
        }
    }

    public func setMargin(margin: Spacing): Unit {
        _margin = margin
    }

    public prop alignSelf: AlignSelf {
        get() {
            _alignSelf
        }
    }

    public func setAlignSelf(alignSelf: AlignSelf): Unit {
        _alignSelf = alignSelf
    }

    public func moveTo(x: Int64, y: Int64): Unit {
        let deltaX = x - _frame.x
        let deltaY = y - _frame.y
        _frame = Rect(x, y, _frame.width, _frame.height)
        _contentFrame = Rect(
            _contentFrame.x + deltaX,
            _contentFrame.y + deltaY,
            _contentFrame.width,
            _contentFrame.height
        )

        for (child in _children) {
            child.moveTo(child.frame.x + deltaX, child.frame.y + deltaY)
        }
    }

    public func contains(x: Int64, y: Int64): Bool {
        if (_frame.width <= 0 || _frame.height <= 0) {
            return false
        }
        x >= _frame.x && y >= _frame.y && x < _frame.x + _frame.width && y < _frame.y + _frame.height
    }

    public func deepestFocusableAt(x: Int64, y: Int64): ?LayoutBox {
        if (!contains(x, y)) {
            return None
        }

        var index = _children.size - 1
        while (index >= 0) {
            match (_children[index].deepestFocusableAt(x, y)) {
                case Some(found) => return found
                case None => ()
            }
            index -= 1
        }

        if (_focusable && _nodeId != None) {
            return this
        }
        None
    }

    public func collectFocusableNodeIds(): ArrayList<String> {
        let result = ArrayList<String>()
        collectFocusableNodeIdsInternal(result)
        result
    }

    private func collectFocusableNodeIdsInternal(result: ArrayList<String>): Unit {
        if (_focusable) {
            match (_nodeId) {
                case Some(id) => result.add(id)
                case None => ()
            }
        }
        for (child in _children) {
            child.collectFocusableNodeIdsInternal(result)
        }
    }
}

public class LayoutEngine {
    public init() {}

    public func layout(node: Node): LayoutBox {
        layoutInternal(node, 0, 0, None, None)
    }

    public func layout(node: Node, availableWidth: Int64, availableHeight: Int64): LayoutBox {
        layoutInternal(node, 0, 0, availableWidth, availableHeight)
    }

    private func layoutInternal(
        node: Node,
        x: Int64,
        y: Int64,
        availableWidth: ?Int64,
        availableHeight: ?Int64
    ): LayoutBox {
        match (node) {
            case Empty => emptyBox(x, y)
            case TextNode(text) => textBox(text.content, text.style, x, y, availableWidth)
            case RichTextNode(richText) => richTextBox(richText, x, y)
            case DivNode(div) => layoutDiv(div, x, y, availableWidth, availableHeight)
        }
    }

    private func layoutDiv(
        div: Div,
        x: Int64,
        y: Int64,
        availableWidth: ?Int64,
        availableHeight: ?Int64
    ): LayoutBox {
        let style = div.styleView
        let padding = style.padding
        let margin = style.margin

        let marginAvailableWidth = subtractOption(availableWidth, margin.left + margin.right)
        let marginAvailableHeight = subtractOption(availableHeight, margin.top + margin.bottom)
        let innerAvailableWidth = subtractOption(marginAvailableWidth, padding.left + padding.right)
        let innerAvailableHeight = subtractOption(marginAvailableHeight, padding.top + padding.bottom)

        let box = LayoutBox(LayoutKind.Div, Rect(x, y, 0, 0), Rect(x, y, 0, 0))
        let measuredChildren = ArrayList<LayoutBox>()

        for (child in div.childrenView) {
            let childLayout = layoutInternal(child, 0, 0, innerAvailableWidth, innerAvailableHeight)
            measuredChildren.add(childLayout)
            box.addChild(childLayout)
        }

        let childSize = stackChildren(measuredChildren, style.direction, style.gap)
        let contentWidth = childSize.width
        let contentHeight = childSize.height
        let paddedWidth = contentWidth + padding.left + padding.right
        let paddedHeight = contentHeight + padding.top + padding.bottom

        let resolvedWidth = resolveDimension(style.width, marginAvailableWidth, paddedWidth)
        let resolvedHeight = resolveDimension(style.height, marginAvailableHeight, paddedHeight)
        let innerWidth = clampNonNegative(resolvedWidth - padding.left - padding.right)
        let innerHeight = clampNonNegative(resolvedHeight - padding.top - padding.bottom)

        // frame = border box (excluding margin); margin handled by parent during positioning
        box.setFrame(Rect(x, y, resolvedWidth, resolvedHeight))
        box.setContentFrame(Rect(x + padding.left, y + padding.top, innerWidth, innerHeight))
        box.setMargin(margin)
        box.setAlignSelf(style.alignSelf)
        box.setFocusable(div.focusableView)
        match (style.border) {
            case Some(border) => box.setBorder(border)
            case None => ()
        }
        box.setOverflow(style.overflow)
        match (div.idView) {
            case Some(value) => box.setNodeId(value)
            case None => ()
        }

        positionChildren(box, style.direction, style.gap, style.alignItems, style.justifyContent)
        box
    }

    private func positionChildren(box: LayoutBox, direction: Direction, gap: Int64,
        alignItems: Alignment, justifyContent: JustifyContent): Unit {
        let content = box.contentFrame
        let children = box.childrenView
        if (children.size == 0) {
            return
        }

        // Calculate total children size along main axis (including margins)
        var totalMainSize = Int64(0)
        for (child in children) {
            let m = child.margin
            match (direction) {
                case Direction.Vertical => totalMainSize += child.frame.height + m.top + m.bottom
                case Direction.Horizontal => totalMainSize += child.frame.width + m.left + m.right
            }
        }
        let totalGap = gap * Int64(children.size - 1)
        totalMainSize += totalGap

        // Determine main-axis available space and starting offset
        let mainAvailable = match (direction) {
            case Direction.Vertical => content.height
            case Direction.Horizontal => content.width
        }
        let freeSpace = clampNonNegative(mainAvailable - totalMainSize)

        var mainOffset: Int64 = 0
        var extraGap: Int64 = 0

        match (justifyContent) {
            case JustifyContent.Start => ()
            case JustifyContent.Center => mainOffset = freeSpace / 2
            case JustifyContent.End => mainOffset = freeSpace
            case JustifyContent.SpaceBetween =>
                if (children.size > 1) {
                    extraGap = freeSpace / Int64(children.size - 1)
                }
            case JustifyContent.SpaceAround =>
                if (children.size > 0) {
                    let slice = freeSpace / Int64(children.size)
                    mainOffset = slice / 2
                    extraGap = slice
                }
        }

        // Cross-axis available space
        let crossAvailable = match (direction) {
            case Direction.Vertical => content.width
            case Direction.Horizontal => content.height
        }

        var cursorX = content.x
        var cursorY = content.y

        match (direction) {
            case Direction.Vertical => cursorY += mainOffset
            case Direction.Horizontal => cursorX += mainOffset
        }

        for (child in children) {
            let m = child.margin

            // Cross-axis alignment (accounting for child margin)
            // Use child's alignSelf if not Auto, otherwise fall back to parent's alignItems
            let effectiveAlign = match (child.alignSelf) {
                case AlignSelf.Auto => alignItems
                case AlignSelf.Start => Alignment.Start
                case AlignSelf.Center => Alignment.Center
                case AlignSelf.End => Alignment.End
            }
            let childCross = match (direction) {
                case Direction.Vertical => child.frame.width + m.left + m.right
                case Direction.Horizontal => child.frame.height + m.top + m.bottom
            }
            let crossOffset = match (effectiveAlign) {
                case Alignment.Start => Int64(0)
                case Alignment.Center => clampNonNegative(crossAvailable - childCross) / 2
                case Alignment.End => clampNonNegative(crossAvailable - childCross)
            }

            match (direction) {
                case Direction.Vertical =>
                    child.moveTo(cursorX + crossOffset + m.left, cursorY + m.top)
                    cursorY += child.frame.height + m.top + m.bottom + gap + extraGap
                case Direction.Horizontal =>
                    child.moveTo(cursorX + m.left, cursorY + crossOffset + m.top)
                    cursorX += child.frame.width + m.left + m.right + gap + extraGap
            }
        }
    }

    private func stackChildren(children: ArrayList<LayoutBox>, direction: Direction, gap: Int64): Size {
        if (children.size == 0) {
            return Size(0, 0)
        }

        match (direction) {
            case Direction.Vertical => stackVertical(children, gap)
            case Direction.Horizontal => stackHorizontal(children, gap)
        }
    }

    private func stackVertical(children: ArrayList<LayoutBox>, gap: Int64): Size {
        var width = Int64(0)
        var height = Int64(0)

        for (child in children) {
            let m = child.margin
            let childOuterWidth = child.frame.width + m.left + m.right
            if (childOuterWidth > width) {
                width = childOuterWidth
            }
            height += child.frame.height + m.top + m.bottom
        }

        Size(width, height + gap * Int64(children.size - 1))
    }

    private func stackHorizontal(children: ArrayList<LayoutBox>, gap: Int64): Size {
        var width = Int64(0)
        var height = Int64(0)

        for (child in children) {
            let m = child.margin
            let childOuterHeight = child.frame.height + m.top + m.bottom
            if (childOuterHeight > height) {
                height = childOuterHeight
            }
            width += child.frame.width + m.left + m.right
        }

        Size(width + gap * Int64(children.size - 1), height)
    }

    private func resolveDimension(dimension: ?Dimension, available: ?Int64, content: Int64): Int64 {
        match (dimension) {
            case Some(value) => match (value) {
                case Dimension.Fixed(size) => size
                case Dimension.Percentage(ratio) => match (available) {
                    case Some(limit) => Int64(Float64(limit) * ratio)
                    case None => content
                }
                case Dimension.Auto => match (available) {
                    case Some(limit) => limit
                    case None => content
                }
                case Dimension.Content => content
            }
            case None => content
        }
    }

    private func subtractOption(value: ?Int64, amount: Int64): ?Int64 {
        match (value) {
            case Some(limit) => clampNonNegative(limit - amount)
            case None => None
        }
    }

    private func clampNonNegative(value: Int64): Int64 {
        if (value < 0) {
            return 0
        }
        value
    }

    private func emptyBox(x: Int64, y: Int64): LayoutBox {
        LayoutBox(LayoutKind.Empty, Rect(x, y, 0, 0), Rect(x, y, 0, 0))
    }

    private func textBox(content: String, style: ?TextStyle, x: Int64, y: Int64, availableWidth: ?Int64): LayoutBox {
        let wrapMode = match (style) {
            case Some(s) => s.wrap
            case None => TextWrap.NoWrap
        }
        let wrappedContent = match (availableWidth) {
            case Some(w) => match (wrapMode) {
                case Character => wrapText(content, w, wrapMode)
                case Word => wrapText(content, w, wrapMode)
                case WordBreak => wrapText(content, w, wrapMode)
                case _ => content
            }
            case _ => content
        }
        let size = measureText(wrappedContent)
        let box = LayoutBox(LayoutKind.Text, Rect(x, y, size.width, size.height), Rect(x, y, size.width, size.height))
        box.setTextContent(wrappedContent)
        match (style) {
            case Some(value) => box.setTextStyle(value)
            case None => ()
        }
        box
    }

    private func richTextBox(richText: RichText, x: Int64, y: Int64): LayoutBox {
        let size = measureRichText(richText)
        let box = LayoutBox(LayoutKind.RichText, Rect(x, y, size.width, size.height), Rect(x, y, size.width, size.height))
        box.setTextContent(flattenRichText(richText))
        box.setRichText(richText)
        match (richText.style) {
            case Some(value) => box.setTextStyle(value)
            case None => ()
        }
        box
    }

    private func measureRichText(richText: RichText): Size {
        measureText(flattenRichText(richText))
    }

    private func flattenRichText(richText: RichText): String {
        var content = ""
        for (span in richText.spans) {
            content += span.content
        }
        content
    }

    private func wrapText(content: String, maxWidth: Int64, mode: TextWrap): String {
        if (maxWidth <= 0) {
            return content
        }
        var result = ""
        let lines = content.split("\n", removeEmpty: false)
        for (i in 0..lines.size) {
            if (i > 0) {
                result += "\n"
            }
            let line = lines[i]
            let runes = line.toRuneArray()
            if (Int64(runes.size) <= maxWidth) {
                result += line
                continue
            }
            match (mode) {
                case Character =>
                    var col = Int64(0)
                    for (r in runes) {
                        if (col >= maxWidth) {
                            result += "\n"
                            col = 0
                        }
                        result += r.toString()
                        col += 1
                    }
                case Word =>
                    var col = Int64(0)
                    var wordBuf = ""
                    var wordLen = Int64(0)
                    for (r in runes) {
                        if (r == r' ') {
                            if (col + wordLen > maxWidth && col > 0) {
                                result += "\n"
                                col = 0
                            }
                            result += wordBuf
                            col += wordLen
                            wordBuf = ""
                            wordLen = 0
                            if (col < maxWidth) {
                                result += " "
                                col += 1
                            }
                        } else {
                            wordBuf += r.toString()
                            wordLen += 1
                        }
                    }
                    if (wordLen > 0) {
                        if (col + wordLen > maxWidth && col > 0) {
                            result += "\n"
                        }
                        result += wordBuf
                    }
                case WordBreak =>
                    var col = Int64(0)
                    var wordBuf = ""
                    var wordLen = Int64(0)
                    for (r in runes) {
                        if (r == r' ') {
                            if (col + wordLen > maxWidth && col > 0) {
                                result += "\n"
                                col = 0
                            }
                            result += wordBuf
                            col += wordLen
                            wordBuf = ""
                            wordLen = 0
                            if (col < maxWidth) {
                                result += " "
                                col += 1
                            }
                        } else {
                            wordBuf += r.toString()
                            wordLen += 1
                            if (wordLen >= maxWidth) {
                                if (col > 0 && col + wordLen > maxWidth) {
                                    result += "\n"
                                    col = 0
                                }
                                result += wordBuf
                                col += wordLen
                                wordBuf = ""
                                wordLen = 0
                                if (col >= maxWidth) {
                                    result += "\n"
                                    col = 0
                                }
                            }
                        }
                    }
                    if (wordLen > 0) {
                        if (col + wordLen > maxWidth && col > 0) {
                            result += "\n"
                        }
                        result += wordBuf
                    }
                case _ => result += line
            }
        }
        result
    }

    private func measureText(content: String): Size {
        var lineWidth = Int64(0)
        var maxWidth = Int64(0)
        var lineCount = Int64(1)

        for (ch in content.runes()) {
            if (ch == r'\n') {
                if (lineWidth > maxWidth) {
                    maxWidth = lineWidth
                }
                lineWidth = 0
                lineCount += 1
            } else {
                lineWidth += 1
            }
        }

        if (lineWidth > maxWidth) {
            maxWidth = lineWidth
        }

        Size(maxWidth, lineCount)
    }
}
