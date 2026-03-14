package examples

import cjrxtui.*

class CounterState <: State {
    var count: Int64

    public init() {
        count = 0
    }
}

class CounterComponent <: Component {
    public func update(ctx: Context, msg: Message, state: State): Action {
        let _ = ctx
        let counter = (state as CounterState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            match (event) {
                case UiEvent.Key(keyEvent) =>
                    match (keyEvent.code) {
                        case KeyCode.Up =>
                            counter.count += 1
                            return Action.update(counter)
                        case KeyCode.Down =>
                            counter.count -= 1
                            return Action.update(counter)
                        case KeyCode.Esc => return Action.exit()
                        case _ => ()
                    }
                case UiEvent.Mouse(mouseEvent) =>
                    match (mouseEvent.kind) {
                        case MouseEventKind.ScrollUp =>
                            counter.count += 1
                            return Action.update(counter)
                        case MouseEventKind.ScrollDown =>
                            counter.count -= 1
                            return Action.update(counter)
                        case _ => ()
                    }
                case _ => ()
            }
        }
        Action.none()
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let counter = (state as CounterState).getOrThrow()
        Node.div(
            Div()
                .id("counter")
                .focusable()
                .width(Dimension.Fixed(32))
                .child(Node.text("Counter: ${counter.count}"))
                .child(Node.text("Up/Down or wheel to change"))
                .child(Node.text("Esc to quit"))
        )
    }
}

main() {
    App.runInteractive(CounterComponent(), CounterState(), 40, 8)
}
