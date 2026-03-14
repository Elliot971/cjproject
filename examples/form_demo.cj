package examples

import cjrxtui.*

class FormDemoState <: State {
    let nameInput: TextInputState
    let emailInput: TextInputState
    let submitButton: ButtonState
    var activeField: Int64
    var result: String

    public init() {
        nameInput = TextInputState()
        emailInput = TextInputState()
        submitButton = ButtonState()
        activeField = 0
        result = "No submission yet"
    }
}

class FormDemoComponent <: Component {
    private let nameInput: TextInput
    private let emailInput: TextInput
    private let submitButton: Button

    public init() {
        nameInput = TextInput(24, "form.name", "Jane Doe")
        emailInput = TextInput(24, "form.email", "jane@example.com")
        submitButton = Button("Submit", 12, "form.submit")
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let formState = (state as FormDemoState).getOrThrow()

        if (let Some(event) <- (msg as BuiltinEvent)) {
            match (event) {
                case BuiltinEvent.ButtonPressed(_, _) =>
                    formState.result = "Saved ${formState.nameInput.value} <${formState.emailInput.value}>"
                    return Action.update(formState)
                case BuiltinEvent.TextInputSubmitted(_, value) =>
                    formState.result = "Submitted field ${value}"
                    return Action.update(formState)
                case _ => ()
            }
        }

        if (let Some(event) <- (msg as UiEvent)) {
            match (event) {
                case UiEvent.Key(keyEvent) =>
                    match (keyEvent.code) {
                        case KeyCode.Esc => return Action.exit()
                        case KeyCode.Tab =>
                            formState.activeField = (formState.activeField + 1) % 3
                            focusFormField(ctx, formState.activeField)
                            return Action.update(formState)
                        case _ => ()
                    }
                case _ => ()
            }
        }

        let _ = nameInput.update(ctx, msg, formState.nameInput)
        let _ = emailInput.update(ctx, msg, formState.emailInput)
        let _ = submitButton.update(ctx, msg, formState.submitButton)
        Action.update(formState)
    }

    public func view(ctx: Context, state: State): Node {
        let demo = (state as FormDemoState).getOrThrow()
        if (ctx.isFirstRender()) {
            focusFormField(ctx, demo.activeField)
        }

        Node.div(
            Div()
                .width(Dimension.Fixed(36))
                .child(Node.text("Form demo"))
                .child(Node.text("Tab moves focus, Enter submits"))
                .child(Node.text("+==================================+"))
                .child(Node.text("| Profile form                     |"))
                .child(Node.text("| Name                             |"))
                .child(nameInput.view(ctx, demo.nameInput))
                .child(Node.text("| Email                            |"))
                .child(emailInput.view(ctx, demo.emailInput))
                .child(Node.text("| Action                           |"))
                .child(submitButton.view(ctx, demo.submitButton))
                .child(Node.text("+==================================+"))
                .child(Node.text("Result: ${demo.result}"))
        )
    }
}

private func focusFormField(ctx: Context, activeField: Int64): Unit {
    match (activeField) {
        case 0 => ctx.focus("form.name")
        case 1 => ctx.focus("form.email")
        case _ => ctx.focus("form.submit")
    }
}

main() {
    App.runInteractive(FormDemoComponent(), FormDemoState(), 36, 16)
}
