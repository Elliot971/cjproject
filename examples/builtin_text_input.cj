package examples

import cjrxtui.*

class TextInputDemoComponent <: Component {
    private let input: TextInput

    public init() {
        input = TextInput(28, "input-demo", "type here")
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
        input.update(ctx, msg, state)
    }

    public func view(ctx: Context, state: State): Node {
        if (ctx.isFirstRender()) {
            ctx.focus("input-demo")
        }

        let inputState = (state as TextInputState).getOrThrow()
        let preview = if (inputState.value.isEmpty()) { "<empty>" } else { inputState.value }
        Node.div(
            Div()
                .width(Dimension.Fixed(30))
                .child(Node.text("TextInput demo"))
                .child(Node.text("Type, edit, Home/End, Backspace"))
                .child(Node.text("Esc to quit"))
                .child(input.view(ctx, state))
                .child(Node.text("Value: ${preview}"))
        )
    }
}

main() {
    App.runInteractive(TextInputDemoComponent(), TextInputState(), 30, 8)
}
