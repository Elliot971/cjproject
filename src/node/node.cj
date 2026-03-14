package cjrxtui.node

import std.collection.ArrayList
import cjrxtui.style.{Alignment, AlignSelf, Dimension, Direction, JustifyContent, Spacing, Style, TextStyle}

public struct Text {
    public let content: String
    public let style: ?TextStyle

    public init(content: String) {
        this.content = content
        this.style = None
    }

    public init(content: String, style: ?TextStyle) {
        this.content = content
        this.style = style
    }
}

public struct TextSpan {
    public let content: String
    public let style: ?TextStyle

    public init(content: String) {
        this.content = content
        this.style = None
    }

    public init(content: String, style: ?TextStyle) {
        this.content = content
        this.style = style
    }
}

public struct RichText {
    public let spans: ArrayList<TextSpan>
    public let style: ?TextStyle

    public init(spans: ArrayList<TextSpan>) {
        this.spans = spans
        this.style = None
    }

    public init(spans: ArrayList<TextSpan>, style: ?TextStyle) {
        this.spans = spans
        this.style = style
    }

    public static func fromText(content: String): RichText {
        let spans = ArrayList<TextSpan>()
        spans.add(TextSpan(content))
        RichText(spans)
    }
}

public class Div {
    private let _children = ArrayList<Node>()
    private var _style: Style = Style()
    private var _focusable: Bool = false
    private var _id: ?String = None

    public init() {}

    public func child(node: Node): Div {
        _children.add(node)
        this
    }

    public func children(nodes: Array<Node>): Div {
        _children.add(all: nodes)
        this
    }

    public func style(style: Style): Div {
        _style = style
        this
    }

    public func direction(direction: Direction): Div {
        _style = _style.withDirection(direction)
        this
    }

    public func padding(padding: Spacing): Div {
        _style = _style.withPadding(padding)
        this
    }

    public func gap(value: Int64): Div {
        _style = _style.withGap(value)
        this
    }

    public func margin(margin: Spacing): Div {
        _style = _style.withMargin(margin)
        this
    }

    public func alignItems(align: Alignment): Div {
        _style = _style.withAlignItems(align)
        this
    }

    public func justifyContent(justify: JustifyContent): Div {
        _style = _style.withJustifyContent(justify)
        this
    }

    public func alignSelf(align: AlignSelf): Div {
        _style = _style.withAlignSelf(align)
        this
    }

    public func width(width: Dimension): Div {
        _style = _style.withWidth(width)
        this
    }

    public func height(height: Dimension): Div {
        _style = _style.withHeight(height)
        this
    }

    public func focusable(): Div {
        _focusable = true
        this
    }

    public func focusable(value: Bool): Div {
        _focusable = value
        this
    }

    public func id(value: String): Div {
        _id = value
        this
    }

    public prop childrenView: ArrayList<Node> {
        get() {
            _children
        }
    }

    public prop styleView: Style {
        get() {
            _style
        }
    }

    public prop focusableView: Bool {
        get() {
            _focusable
        }
    }

    public prop idView: ?String {
        get() {
            _id
        }
    }
}

public enum Node {
    | Empty
    | DivNode(Div)
    | TextNode(Text)
    | RichTextNode(RichText)

    public static func div(div: Div): Node {
        Node.DivNode(div)
    }

    public static func text(content: String): Node {
        Node.TextNode(Text(content))
    }

    public static func text(content: String, style: ?TextStyle): Node {
        Node.TextNode(Text(content, style))
    }

    public static func richText(richText: RichText): Node {
        Node.RichTextNode(richText)
    }
}
