package cjrxtui.style

public enum Color {
    | Black
    | Red
    | Green
    | Yellow
    | Blue
    | Magenta
    | Cyan
    | White
    | BrightBlack
    | BrightRed
    | BrightGreen
    | BrightYellow
    | BrightBlue
    | BrightMagenta
    | BrightCyan
    | BrightWhite
    | Rgb(UInt8, UInt8, UInt8)
}

public enum Direction {
    | Vertical
    | Horizontal
}

public enum Overflow {
    | Visible
    | Hidden
    | Scroll
    | Auto
}

public enum Position {
    | Relative
    | Absolute
}

public enum BorderStyle {
    | None
    | Single
    | Double
    | Rounded
    | Thick
}

public enum Dimension {
    | Fixed(Int64)
    | Percentage(Float64)
    | Auto
    | Content
}

public enum TextAlign {
    | Left
    | Center
    | Right
}

public enum TextWrap {
    | NoWrap
    | Character
    | Word
    | WordBreak
}

public enum Alignment {
    | Start
    | Center
    | End
}

public enum JustifyContent {
    | Start
    | Center
    | End
    | SpaceBetween
    | SpaceAround
}

public enum AlignSelf {
    | Auto
    | Start
    | Center
    | End
}

public enum SpinnerType {
    | Line
    | Dots
    | Circle
    | Arrow
    | Bounce
    | Hearts
    | Custom(Array<String>)
}

public struct BorderEdges {
    public let top: Bool
    public let right: Bool
    public let bottom: Bool
    public let left: Bool

    public init(top: Bool, right: Bool, bottom: Bool, left: Bool) {
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }

    public static func all(): BorderEdges {
        BorderEdges(true, true, true, true)
    }

    public static func none(): BorderEdges {
        BorderEdges(false, false, false, false)
    }

    public static func horizontal(): BorderEdges {
        BorderEdges(true, false, true, false)
    }

    public static func vertical(): BorderEdges {
        BorderEdges(false, true, false, true)
    }
}

public struct Spacing {
    public let top: Int64
    public let right: Int64
    public let bottom: Int64
    public let left: Int64

    public init(top: Int64, right: Int64, bottom: Int64, left: Int64) {
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }

    public static func zero(): Spacing {
        Spacing(0, 0, 0, 0)
    }

    public static func all(value: Int64): Spacing {
        Spacing(value, value, value, value)
    }

    public static func symmetric(horizontal: Int64, vertical: Int64): Spacing {
        Spacing(vertical, horizontal, vertical, horizontal)
    }
}

public struct Border {
    public let style: BorderStyle
    public let color: Color
    public let edges: BorderEdges

    public init(style: BorderStyle, color: Color) {
        this.style = style
        this.color = color
        this.edges = BorderEdges.all()
    }

    public init(style: BorderStyle, color: Color, edges: BorderEdges) {
        this.style = style
        this.color = color
        this.edges = edges
    }
}

public struct TextStyle {
    public let foreground: ?Color
    public let background: ?Color
    public let bold: Bool
    public let italic: Bool
    public let underline: Bool
    public let strikethrough: Bool
    public let align: TextAlign
    public let wrap: TextWrap

    public init() {
        this.foreground = None
        this.background = None
        this.bold = false
        this.italic = false
        this.underline = false
        this.strikethrough = false
        this.align = TextAlign.Left
        this.wrap = TextWrap.NoWrap
    }

    public init(
        foreground: Color,
        background: Color,
        bold: Bool,
        italic: Bool,
        underline: Bool,
        strikethrough: Bool,
        align: TextAlign
    ) {
        this.foreground = foreground
        this.background = background
        this.bold = bold
        this.italic = italic
        this.underline = underline
        this.strikethrough = strikethrough
        this.align = align
        this.wrap = TextWrap.NoWrap
    }

    public init(
        foreground: ?Color,
        background: ?Color,
        bold: Bool,
        italic: Bool,
        underline: Bool,
        strikethrough: Bool,
        align: TextAlign,
        wrap: TextWrap
    ) {
        this.foreground = foreground
        this.background = background
        this.bold = bold
        this.italic = italic
        this.underline = underline
        this.strikethrough = strikethrough
        this.align = align
        this.wrap = wrap
    }

    public func withForeground(color: Color): TextStyle {
        TextStyle(color, background, bold, italic, underline, strikethrough, align, wrap)
    }

    public func withBackground(color: Color): TextStyle {
        TextStyle(foreground, color, bold, italic, underline, strikethrough, align, wrap)
    }

    public func withBold(value: Bool): TextStyle {
        TextStyle(foreground, background, value, italic, underline, strikethrough, align, wrap)
    }

    public func withUnderline(value: Bool): TextStyle {
        TextStyle(foreground, background, bold, italic, value, strikethrough, align, wrap)
    }

    public func withWrap(mode: TextWrap): TextStyle {
        TextStyle(foreground, background, bold, italic, underline, strikethrough, align, mode)
    }
}

public struct Style {
    public let background: ?Color
    public let direction: Direction
    public let padding: Spacing
    public let margin: Spacing
    public let width: ?Dimension
    public let height: ?Dimension
    public let gap: Int64
    public let overflow: Overflow
    public let border: ?Border
    public let position: Position
    public let top: Int64
    public let right: Int64
    public let bottom: Int64
    public let left: Int64
    public let zIndex: Int64
    public let alignItems: Alignment
    public let justifyContent: JustifyContent
    public let alignSelf: AlignSelf

    public init() {
        this.background = None
        this.direction = Direction.Vertical
        this.padding = Spacing.zero()
        this.margin = Spacing.zero()
        this.width = None
        this.height = None
        this.gap = 0
        this.overflow = Overflow.Visible
        this.border = None
        this.position = Position.Relative
        this.top = 0
        this.right = 0
        this.bottom = 0
        this.left = 0
        this.zIndex = 0
        this.alignItems = Alignment.Start
        this.justifyContent = JustifyContent.Start
        this.alignSelf = AlignSelf.Auto
    }

    public init(
        background: ?Color,
        direction: Direction,
        padding: Spacing,
        margin: Spacing,
        width: ?Dimension,
        height: ?Dimension,
        gap: Int64,
        overflow: Overflow,
        border: ?Border,
        position: Position,
        top: Int64,
        right: Int64,
        bottom: Int64,
        left: Int64,
        zIndex: Int64,
        alignItems: Alignment,
        justifyContent: JustifyContent,
        alignSelf: AlignSelf
    ) {
        this.background = background
        this.direction = direction
        this.padding = padding
        this.margin = margin
        this.width = width
        this.height = height
        this.gap = gap
        this.overflow = overflow
        this.border = border
        this.position = position
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
        this.zIndex = zIndex
        this.alignItems = alignItems
        this.justifyContent = justifyContent
        this.alignSelf = alignSelf
    }

    public func withBackground(color: Color): Style {
        Style(color, direction, padding, margin, width, height, gap, overflow, border, position, top, right, bottom, left, zIndex, alignItems, justifyContent, alignSelf)
    }

    public func withDirection(nextDirection: Direction): Style {
        Style(background, nextDirection, padding, margin, width, height, gap, overflow, border, position, top, right, bottom, left, zIndex, alignItems, justifyContent, alignSelf)
    }

    public func withPadding(nextPadding: Spacing): Style {
        Style(background, direction, nextPadding, margin, width, height, gap, overflow, border, position, top, right, bottom, left, zIndex, alignItems, justifyContent, alignSelf)
    }

    public func withMargin(nextMargin: Spacing): Style {
        Style(background, direction, padding, nextMargin, width, height, gap, overflow, border, position, top, right, bottom, left, zIndex, alignItems, justifyContent, alignSelf)
    }

    public func withGap(nextGap: Int64): Style {
        Style(background, direction, padding, margin, width, height, nextGap, overflow, border, position, top, right, bottom, left, zIndex, alignItems, justifyContent, alignSelf)
    }

    public func withWidth(nextWidth: Dimension): Style {
        Style(background, direction, padding, margin, nextWidth, height, gap, overflow, border, position, top, right, bottom, left, zIndex, alignItems, justifyContent, alignSelf)
    }

    public func withHeight(nextHeight: Dimension): Style {
        Style(background, direction, padding, margin, width, nextHeight, gap, overflow, border, position, top, right, bottom, left, zIndex, alignItems, justifyContent, alignSelf)
    }

    public func withBorder(nextBorder: Border): Style {
        Style(background, direction, padding, margin, width, height, gap, overflow, nextBorder, position, top, right, bottom, left, zIndex, alignItems, justifyContent, alignSelf)
    }

    public func withOverflow(nextOverflow: Overflow): Style {
        Style(background, direction, padding, margin, width, height, gap, nextOverflow, border, position, top, right, bottom, left, zIndex, alignItems, justifyContent, alignSelf)
    }

    public func withAlignItems(nextAlign: Alignment): Style {
        Style(background, direction, padding, margin, width, height, gap, overflow, border, position, top, right, bottom, left, zIndex, nextAlign, justifyContent, alignSelf)
    }

    public func withJustifyContent(nextJustify: JustifyContent): Style {
        Style(background, direction, padding, margin, width, height, gap, overflow, border, position, top, right, bottom, left, zIndex, alignItems, nextJustify, alignSelf)
    }

    public func withAlignSelf(nextAlignSelf: AlignSelf): Style {
        Style(background, direction, padding, margin, width, height, gap, overflow, border, position, top, right, bottom, left, zIndex, alignItems, justifyContent, nextAlignSelf)
    }

    public func withPosition(nextPosition: Position): Style {
        Style(background, direction, padding, margin, width, height, gap, overflow, border, nextPosition, top, right, bottom, left, zIndex, alignItems, justifyContent, alignSelf)
    }

    public func withZIndex(nextZIndex: Int64): Style {
        Style(background, direction, padding, margin, width, height, gap, overflow, border, position, top, right, bottom, left, nextZIndex, alignItems, justifyContent, alignSelf)
    }

    public func withTop(nextTop: Int64): Style {
        Style(background, direction, padding, margin, width, height, gap, overflow, border, position, nextTop, right, bottom, left, zIndex, alignItems, justifyContent, alignSelf)
    }

    public func withRight(nextRight: Int64): Style {
        Style(background, direction, padding, margin, width, height, gap, overflow, border, position, top, nextRight, bottom, left, zIndex, alignItems, justifyContent, alignSelf)
    }

    public func withBottom(nextBottom: Int64): Style {
        Style(background, direction, padding, margin, width, height, gap, overflow, border, position, top, right, nextBottom, left, zIndex, alignItems, justifyContent, alignSelf)
    }

    public func withLeft(nextLeft: Int64): Style {
        Style(background, direction, padding, margin, width, height, gap, overflow, border, position, top, right, bottom, nextLeft, zIndex, alignItems, justifyContent, alignSelf)
    }
}
