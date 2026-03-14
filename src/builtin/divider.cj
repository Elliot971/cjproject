package cjrxtui.builtin

import cjrxtui.component.{Action, Component, Context, Message, State}
import cjrxtui.node.{Div, Node}
import cjrxtui.style.{Color, Dimension, Direction, TextStyle}

public class DividerState <: State {
    public init() {}
}

public enum DividerDirection {
    | Horizontal
    | Vertical
}

public class Divider <: Component {
    private let length: Int64
    private let dir: DividerDirection
    private let label: ?String
    private let color: Color

    public init(length: Int64) {
        this.length = length
        this.dir = DividerDirection.Horizontal
        this.label = None
        this.color = Color.BrightBlack
    }

    public init(length: Int64, dir: DividerDirection) {
        this.length = length
        this.dir = dir
        this.label = None
        this.color = Color.BrightBlack
    }

    public init(length: Int64, dir: DividerDirection, label: String) {
        this.length = length
        this.dir = dir
        this.label = label
        this.color = Color.BrightBlack
    }

    public init(length: Int64, dir: DividerDirection, label: String, color: Color) {
        this.length = length
        this.dir = dir
        this.label = label
        this.color = color
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let _ = ctx
        let _ = msg
        let dividerState = (state as DividerState).getOrThrow()
        Action.update(dividerState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let _ = state
        match (dir) {
            case DividerDirection.Horizontal => viewHorizontal()
            case DividerDirection.Vertical => viewVertical()
        }
    }

    private func viewHorizontal(): Node {
        let line = match (label) {
            case Some(text) => renderHorizontalWithLabel(text, length)
            case None => dividerRepeat("\u{2500}", length)
        }
        Node.div(
            Div()
                .width(Dimension.Fixed(length))
                .height(Dimension.Fixed(1))
                .child(Node.text(line, dividerStyle(color)))
        )
    }

    private func viewVertical(): Node {
        let container = Div()
            .width(Dimension.Fixed(1))
            .height(Dimension.Fixed(length))
            .direction(Direction.Vertical)

        for (_ in 0..length) {
            container.child(Node.text("\u{2502}", dividerStyle(color)))
        }
        Node.div(container)
    }
}

private func renderHorizontalWithLabel(label: String, length: Int64): String {
    let labelLen = dividerRuneCount(label)
    if (length < labelLen + 4) {
        return dividerRepeat("\u{2500}", length)
    }
    let leftLen = (length - labelLen - 2) / 2
    let rightLen = length - leftLen - labelLen - 2
    dividerRepeat("\u{2500}", leftLen) + " " + label + " " + dividerRepeat("\u{2500}", rightLen)
}

private func dividerStyle(color: Color): TextStyle {
    TextStyle().withForeground(color)
}

private func dividerRepeat(text: String, count: Int64): String {
    var result = ""
    var index = Int64(0)
    while (index < count) {
        result += text
        index += 1
    }
    result
}

private func dividerRuneCount(text: String): Int64 {
    var count = Int64(0)
    for (_ in text.runes()) { count += 1 }
    count
}
