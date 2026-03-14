import cjrxtui.*

class DashboardState <: State {
    public var table: TableState
    public var select: SelectState
    public var input: TextAreaState

    public init() {
        table = TableState(0, 0, true)
        select = SelectState(0)
        input = TextAreaState("type notes here")
    }
}

class DashboardComponent <: Component {
    private let table = Table(
        ["Service", "Status"],
        [["api", "ok"], ["db", "warn"], ["cache", "ok"], ["queue", "down"]],
        [12, 10],
        24,
        6,
        "table"
    )

    private let filter = Select(["all", "ok", "warn", "down"], 24, "filter")
    private let notes = TextArea(24, 4, "notes")
    private let sep = Divider(24, DividerDirection.Horizontal, "Details")
    private let bar = StatusBar(24, "status")

    public func update(ctx: Context, msg: Message, state: State): Action {
        let s = (state as DashboardState).getOrThrow()

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

        let _ = table.update(ctx, msg, s.table)
        let _ = filter.update(ctx, msg, s.select)
        let _ = notes.update(ctx, msg, s.input)
        Action.update(s)
    }

    public func view(ctx: Context, state: State): Node {
        let s = (state as DashboardState).getOrThrow()
        Node.vstack([
            bar.view(ctx, StatusBarState(["MONITOR", "Esc Quit"])),
            filter.view(ctx, s.select),
            table.view(ctx, s.table),
            sep.view(ctx, DividerState()),
            notes.view(ctx, s.input)
        ])
    }
}

main() {
    App.runInteractive(DashboardComponent(), DashboardState(), 24, 14)
}
