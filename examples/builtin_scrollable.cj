package examples

import cjrxtui.*

class ScrollableDemoComponent <: Component {
    private let scrollable: Scrollable

    public init() {
        scrollable = Scrollable(scrollableSampleLines(), 38, 6, "scroll-demo")
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let _ = ctx
        if (let Some(event) <- (msg as UiEvent)) {
            match (event) {
                case UiEvent.Key(keyEvent) =>
                    match (keyEvent.code) {
                        case KeyCode.Esc => return Action.exit()
                        case _ => ()
                    }
                case _ => ()
            }
        }
        scrollable.update(ctx, msg, state)
    }

    public func view(ctx: Context, state: State): Node {
        if (ctx.isFirstRender()) {
            ctx.focus("scroll-demo")
        }

        Node.div(
            Div()
                .width(Dimension.Fixed(40))
                .child(Node.text("Scrollable demo"))
                .child(Node.text("Up/Down/Page keys or wheel"))
                .child(Node.text("Esc to quit"))
                .child(scrollable.view(ctx, state))
        )
    }

}

private func scrollableSampleLines(): Array<String> {
    [
        "line 01 - intro",
        "line 02 - event routing",
        "line 03 - keyboard scroll",
        "line 04 - mouse wheel scroll",
        "line 05 - focus aware",
        "line 06 - reusable state",
        "line 07 - viewport clipping",
        "line 08 - offset tracking",
        "line 09 - page movement",
        "line 10 - home/end support",
        "line 11 - minimal API",
        "line 12 - done"
    ]
}

main() {
    App.runInteractive(ScrollableDemoComponent(), ScrollableState(), 40, 10)
}
