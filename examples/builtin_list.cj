package examples

import cjrxtui.*

class ListDemoComponent <: Component {
    private let items: Array<String>
    private let list: List

    public init() {
        items = [
            "Alpha release",
            "Beta release",
            "Canary build",
            "Desktop profile",
            "Embedded target",
            "Fast render path",
            "GPU experiment",
            "Hot reload"
        ]
        list = List(items, 30, 5, "list-demo")
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
        list.update(ctx, msg, state)
    }

    public func view(ctx: Context, state: State): Node {
        if (ctx.isFirstRender()) {
            ctx.focus("list-demo")
        }

        let listState = (state as ListState).getOrThrow()
        let selected = items[listState.selectedIndex]
        Node.div(
            Div()
                .width(Dimension.Fixed(32))
                .child(Node.text("List demo"))
                .child(Node.text("Move with arrows or wheel"))
                .child(Node.text("Selected: ${selected}"))
                .child(Node.text("Esc to quit"))
                .child(list.view(ctx, state))
        )
    }
}

main() {
    App.runInteractive(ListDemoComponent(), ListState(), 32, 10)
}
