package cjrxtui.builtin

import cjrxtui.component.{Action, Component, Context, Message, State}
import cjrxtui.node.{Div, Node}
import cjrxtui.style.{Color, Dimension, Direction, TextStyle}

public class StatusBarState <: State {
    public var sections: Array<String>

    public init() {
        sections = []
    }

    public init(sections: Array<String>) {
        this.sections = sections
    }
}

public class StatusBar <: Component {
    private let width: Int64
    private let id: String
    private let background: Color
    private let foreground: Color

    public init(width: Int64, id: String) {
        this.width = width
        this.id = id
        this.background = Color.Blue
        this.foreground = Color.BrightWhite
    }

    public init(width: Int64, id: String, background: Color, foreground: Color) {
        this.width = width
        this.id = id
        this.background = background
        this.foreground = foreground
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let _ = ctx
        let _ = msg
        let barState = (state as StatusBarState).getOrThrow()
        Action.update(barState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let barState = (state as StatusBarState).getOrThrow()
        let content = renderStatusBar(barState.sections, width)
        Node.div(
            Div()
                .id(id)
                .width(Dimension.Fixed(width))
                .height(Dimension.Fixed(1))
                .direction(Direction.Horizontal)
                .child(Node.text(content, statusBarTextStyle(foreground, background)))
        )
    }
}

private func renderStatusBar(sections: Array<String>, width: Int64): String {
    if (sections.size == 0) {
        return statusBarPad("", width)
    }
    if (sections.size == 1) {
        return statusBarPad(sections[0], width)
    }

    let separator = " | "
    var joined = ""
    for (index in 0..sections.size) {
        if (index > 0) {
            joined += separator
        }
        joined += sections[index]
    }
    statusBarPad(joined, width)
}

private func statusBarTextStyle(fg: Color, bg: Color): TextStyle {
    TextStyle().withForeground(fg).withBackground(bg).withBold(true)
}

private func statusBarPad(text: String, width: Int64): String {
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
