package examples

import std.collection.ArrayList
import cjrxtui.*

class FlagshipDemoState <: State {
    let tabsState: TabsState
    let listState: ListState
    let scrollState: ScrollableState
    let inputState: TextInputState
    let buttonState: ButtonState
    let checkboxState: CheckboxState
    let radioState: RadioState
    let spinnerState: SpinnerState
    let modalState: ModalState
    let progressState: ProgressBarState
    var activePane: Int64
    var status: String
    var submitted: String
    var deploymentRunning: Bool
    var focusedWidget: String

    public init() {
        tabsState = TabsState(0, false)
        listState = ListState()
        scrollState = ScrollableState()
        inputState = TextInputState()
        buttonState = ButtonState()
        checkboxState = CheckboxState(true, false)
        radioState = RadioState(0, false)
        spinnerState = SpinnerState()
        modalState = ModalState(false, false)
        progressState = ProgressBarState(0)
        activePane = 0
        status = "Press Deploy to launch an async workflow"
        submitted = "<none>"
        deploymentRunning = false
        focusedWidget = "flag.tabs"
    }
}

class FlagshipPulseMessage <: Message {
    public init() {}
}

class FlagshipCompleteMessage <: Message {
    let command: String

    public init(command: String) {
        this.command = command
    }
}

class FlagshipDemoComponent <: Component {
    private let tabs: Tabs
    private let tasks: List
    private let logs: Scrollable
    private let input: TextInput
    private let runButton: Button
    private let featureToggle: Checkbox
    private let themeRadio: Radio
    private let spinner: Spinner
    private let modal: Modal
    private let progress: ProgressBar

    public init() {
        tabs = Tabs(["Overview", "Widgets", "Logs", "Modal"], 52, "flag.tabs")
        tasks = List(flagshipTasks(), 24, 7, "flag.list")
        logs = Scrollable(flagshipLogs(), 30, 7, "flag.scroll")
        input = TextInput(28, "flag.input", "type command")
        runButton = Button("Deploy", 12, "flag.button")
        featureToggle = Checkbox("Enable live sync", 24, "flag.checkbox")
        themeRadio = Radio(["Ocean", "Sand", "Mono"], 24, "flag.radio")
        spinner = Spinner("Streaming frames", 22, "flag.spinner")
        modal = Modal("Async workflow complete", ["The background effect flushed without extra input", "Esc or Enter closes this modal"], 34, 5, "flag.modal")
        progress = ProgressBar(24, 100, "flag.progress")
    }

    public func update(ctx: Context, msg: Message, state: State): Action {
        let demo = (state as FlagshipDemoState).getOrThrow()

        if (msg is FlagshipPulseMessage) {
            if (!demo.deploymentRunning) {
                return Action.none()
            }
            let _ = spinner.update(ctx, UiEvent.Tick, demo.spinnerState)
            demo.progressState.value = clampPercent(demo.progressState.value + 10)
            demo.status = "Async deploy running ${demo.progressState.value}%"
            return Action.update(demo)
        }

        if (let Some(completeMessage) <- (msg as FlagshipCompleteMessage)) {
            demo.deploymentRunning = false
            demo.progressState.value = 100
            demo.status = "Async deploy complete: ${completeMessage.command}"
            demo.modalState.open = true
            demo.modalState.focused = true
            ctx.focus("flag.modal")
            return Action.update(demo)
        }

        if (let Some(event) <- (msg as BuiltinEvent)) {
            match (event) {
                case BuiltinEvent.TabChanged(_, _, label) =>
                    demo.status = "Switched to ${label}"
                    return Action.update(demo)
                case BuiltinEvent.ListItemSelected(_, _, label) =>
                    demo.status = "Task selected: ${label}"
                    demo.progressState.value = clampPercent(demo.progressState.value + 8)
                    return Action.update(demo)
                case BuiltinEvent.TextInputSubmitted(_, value) =>
                    demo.submitted = value
                    return startDeployment(demo)
                case BuiltinEvent.ButtonPressed(_, _) =>
                    return startDeployment(demo)
                case BuiltinEvent.CheckboxChanged(_, checked) =>
                    demo.status = if (checked) { "Live sync enabled" } else { "Live sync disabled" }
                    return Action.update(demo)
                case BuiltinEvent.RadioChanged(_, _, label) =>
                    demo.status = "Theme preset: ${label}"
                    return Action.update(demo)
                case BuiltinEvent.ModalDismissed(_) =>
                    demo.modalState.open = false
                    demo.modalState.focused = false
                    focusFlagshipPane(ctx, demo.activePane)
                    demo.status = "Modal dismissed"
                    return Action.update(demo)
            }
        }

        if (let Some(event) <- (msg as UiEvent)) {
            match (event) {
                case UiEvent.Key(keyEvent) =>
                    match (keyEvent.code) {
                        case KeyCode.Esc =>
                            if (demo.modalState.open) {
                                let _ = modal.update(ctx, msg, demo.modalState)
                                return Action.update(demo)
                            }
                            return Action.exit()
                        case KeyCode.Tab =>
                            if (demo.modalState.open) {
                                return Action.update(demo)
                            }
                            demo.activePane = (demo.activePane + 1) % 6
                            focusFlagshipPane(ctx, demo.activePane)
                            demo.status = "Focus moved to ${paneName(demo.activePane)}"
                            return Action.update(demo)
                        case _ => ()
                    }
                case UiEvent.Tick =>
                    let _ = spinner.update(ctx, msg, demo.spinnerState)
                    return Action.update(demo)
                case UiEvent.Focus(nodeId) =>
                    demo.focusedWidget = nodeId
                    demo.status = "Focused ${nodeId}"
                    return Action.update(demo)
                case UiEvent.Click(nodeId, _) =>
                    demo.status = "Clicked ${nodeId}"
                    return Action.update(demo)
                case _ => ()
            }
        }

        let _ = tabs.update(ctx, msg, demo.tabsState)
        let _ = tasks.update(ctx, msg, demo.listState)
        let _ = logs.update(ctx, msg, demo.scrollState)
        let _ = input.update(ctx, msg, demo.inputState)
        let _ = runButton.update(ctx, msg, demo.buttonState)
        let _ = featureToggle.update(ctx, msg, demo.checkboxState)
        let _ = themeRadio.update(ctx, msg, demo.radioState)
        let _ = progress.update(ctx, msg, demo.progressState)
        if (demo.modalState.open) {
            let _ = modal.update(ctx, msg, demo.modalState)
        }
        Action.update(demo)
    }

    public func view(ctx: Context, state: State): Node {
        let demo = (state as FlagshipDemoState).getOrThrow()
        if (ctx.isFirstRender()) {
            focusFlagshipPane(ctx, demo.activePane)
        }

        let selectedTask = flagshipTasks()[demo.listState.selectedIndex]
        let submittedValue = if (demo.submitted.isEmpty()) { "<none>" } else { demo.submitted }
        let asyncStatus = if (demo.deploymentRunning) { "running" } else { "idle" }

        let hero = RichText(heroSpans(), TextStyle().withForeground(Color.BrightWhite))

        let root = Div()
            .width(Dimension.Fixed(86))
            .padding(Spacing.all(1))
            .child(Node.richText(hero))
            .child(Node.text("cjrxtui 综合演示 - 全部 12 个内置组件"))
            .child(Node.text("Tab switches focus, Enter activates widgets, Esc closes modal or exits"))
            .child(Node.text("Deploy triggers async progress, spinner updates, and a completion modal"))
            .child(tabs.view(ctx, demo.tabsState))
            .child(Node.text("Status: ${demo.status}"))
            .child(Node.text("Focused widget: ${demo.focusedWidget}"))
            .child(Node.text("Async worker: ${asyncStatus}"))
            .child(
                Node.div(
                    Div()
                        .direction(Direction.Horizontal)
                        .gap(2)
                        .child(
                            Node.div(
                                Div()
                                    .width(Dimension.Fixed(26))
                                    .child(Node.text("Tasks"))
                                    .child(tasks.view(ctx, demo.listState))
                                    .child(Node.text("Selected: ${selectedTask}"))
                            )
                        )
                        .child(
                            Node.div(
                                Div()
                                    .width(Dimension.Fixed(32))
                                    .child(Node.text("Activity log"))
                                    .child(logs.view(ctx, demo.scrollState))
                                    .child(Node.text("Latest command: ${submittedValue}"))
                                    .child(spinner.view(ctx, demo.spinnerState))
                            )
                        )
                        .child(
                            Node.div(
                                Div()
                                    .width(Dimension.Fixed(24))
                                    .child(Node.text("Controls"))
                                    .child(featureToggle.view(ctx, demo.checkboxState))
                                    .child(themeRadio.view(ctx, demo.radioState))
                                    .child(Node.text("Progress"))
                                    .child(progress.view(ctx, demo.progressState))
                            )
                        )
                )
            )
            .child(Node.text("Command palette"))
            .child(
                Node.div(
                    Div()
                        .direction(Direction.Horizontal)
                        .gap(2)
                        .child(input.view(ctx, demo.inputState))
                        .child(runButton.view(ctx, demo.buttonState))
                )
            )
            .child(Node.text("Submitted: ${submittedValue}"))

        if (demo.modalState.open) {
            root.child(Node.text(""))
            root.child(modal.view(ctx, demo.modalState))
        }

        Node.div(root)
    }
}

private func heroSpans(): ArrayList<TextSpan> {
    let spans = ArrayList<TextSpan>()
    spans.add(TextSpan("cj", TextStyle().withForeground(Color.BrightCyan).withBold(true)))
    spans.add(TextSpan("rx", TextStyle().withForeground(Color.BrightMagenta).withBold(true)))
    spans.add(TextSpan("tui", TextStyle().withForeground(Color.BrightYellow).withBold(true)))
    spans.add(TextSpan(" flagship", TextStyle().withForeground(Color.White)))
    spans
}

private func flagshipTasks(): Array<String> {
    [
        "Ship demo gallery",
        "Refine layout clipping",
        "Audit focus routing",
        "Tune color palette",
        "Benchmark diff speed",
        "Document widgets",
        "Prepare release notes"
    ]
}

private func flagshipLogs(): Array<String> {
    [
        "10:00 mount root node",
        "10:01 resolve layout tree",
        "10:02 apply rich text spans",
        "10:03 clip overflow regions",
        "10:04 diff terminal cells",
        "10:05 update progress bar",
        "10:06 animate spinner",
        "10:07 submit modal event",
        "10:08 persist widget state"
    ]
}

private func focusFlagshipPane(ctx: Context, activePane: Int64): Unit {
    match (activePane) {
        case 0 => ctx.focus("flag.tabs")
        case 1 => ctx.focus("flag.list")
        case 2 => ctx.focus("flag.scroll")
        case 3 => ctx.focus("flag.checkbox")
        case 4 => ctx.focus("flag.input")
        case _ => ctx.focus("flag.button")
    }
}

private func startDeployment(demo: FlagshipDemoState): Action {
    if (demo.deploymentRunning) {
        demo.status = "Async deploy already running"
        return Action.update(demo)
    }

    let command = if (demo.submitted == "<none>") { "deploy --preview" } else { demo.submitted }
    demo.deploymentRunning = true
    demo.progressState.value = 0
    demo.status = "Starting async deploy: ${command}"
    demo.modalState.open = false
    demo.modalState.focused = false

    Action.batch([
        Action.update(demo),
        Action.effect(Effects.interval(140, 10, FlagshipPulseMessage())),
        Action.effect(Effects.delay(1500, FlagshipCompleteMessage(command)))
    ])
}

private func clampPercent(value: Int64): Int64 {
    if (value < 0) {
        return 0
    }
    if (value > 100) {
        return 100
    }
    value
}

private func paneName(activePane: Int64): String {
    match (activePane) {
        case 0 => "tabs"
        case 1 => "task list"
        case 2 => "log view"
        case 3 => "checkbox"
        case 4 => "input"
        case _ => "deploy button"
    }
}

main() {
    App.runInteractive(FlagshipDemoComponent(), FlagshipDemoState(), 86, 24)
}
