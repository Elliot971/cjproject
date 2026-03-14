package cjrxtui.app

import std.collection.ArrayList
import cjrxtui.component.{Action, Component, Context, Effects, KeyCode, Message, MouseButton, MouseEvent, MouseEventKind, State, UiEvent}
import cjrxtui.node.{Div, Node}
import cjrxtui.style.{Dimension, Direction}
import cjrxtui.terminal.{TerminalInputMode, TerminalModeController, TerminalSize, TerminalSizeReader}

class FakeTerminalModeController <: TerminalModeController {
    var enterCount: Int64 = 0
    var restoreCount: Int64 = 0
    var mode: TerminalInputMode = TerminalInputMode.Canonical

    public init() {}

    public func enterRawMode(): Unit {
        enterCount += 1
        mode = TerminalInputMode.Raw
    }

    public func restoreMode(): Unit {
        restoreCount += 1
        mode = TerminalInputMode.Canonical
    }

    public func currentMode(): TerminalInputMode {
        mode
    }
}

class FakeTerminalSizeReader <: TerminalSizeReader {
    private let sizes: Array<?TerminalSize>
    private var index: Int64 = 0

    public init(sizes: Array<?TerminalSize>) {
        this.sizes = sizes
    }

    public func read(): ?TerminalSize {
        if (sizes.isEmpty()) {
            return None
        }
        if (index >= sizes.size) {
            return sizes[sizes.size - 1]
        }
        let size = sizes[index]
        index += 1
        size
    }
}

class DelayedStopRuntimeEventSource <: RuntimeEventSource {
    private let delayMillis: Int64
    private var stopped: Bool = false

    public init(delayMillis: Int64) {
        this.delayMillis = delayMillis
    }

    public func next(): ?RuntimeEvent {
        if (stopped) {
            return None
        }
        stopped = true
        sleep(delayMillis * Duration.millisecond)
        RuntimeEvent.Stop
    }
}

class DelayedTickRuntimeEventSource <: PollingRuntimeEventSource {
    private let delayMillis: Int64
    private var emitted: Bool = false
    private var waitedMillis: Int64 = 0

    public init(delayMillis: Int64) {
        this.delayMillis = delayMillis
    }

    public func next(): ?RuntimeEvent {
        match (poll(delayMillis)) {
            case RuntimeEventPollResult.Event(event) => event
            case RuntimeEventPollResult.Timeout => None
            case RuntimeEventPollResult.End => None
        }
    }

    public func poll(timeoutMillis: Int64): RuntimeEventPollResult {
        if (emitted) {
            return RuntimeEventPollResult.End
        }

        let waitSlice = if (timeoutMillis > 0) { timeoutMillis } else { 0 }
        if (waitSlice <= 0) {
            return RuntimeEventPollResult.Timeout
        }

        sleep(waitSlice * Duration.millisecond)
        waitedMillis += waitSlice
        if (waitedMillis < delayMillis) {
            return RuntimeEventPollResult.Timeout
        }

        emitted = true
        RuntimeEventPollResult.Event(RuntimeEvent.Tick)
    }
}

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
            return resolveEvent(event, counter)
        }
        Action.none()
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let counter = (state as CounterState).getOrThrow()
        Node.div(
            Div()
                .width(Dimension.Fixed(14))
                .child(Node.text("Count: ${counter.count}"))
        )
    }

    private func resolveEvent(event: UiEvent, counter: CounterState): Action {
        match (event) {
            case Key(keyEvent) => resolveKey(keyEvent.code, counter)
            case _ => Action.none()
        }
    }

    private func resolveKey(code: KeyCode, counter: CounterState): Action {
        match (code) {
            case KeyCode.Up =>
                counter.count += 1
                Action.update(counter)
            case KeyCode.Down =>
                counter.count -= 1
                Action.update(counter)
            case KeyCode.Esc => Action.exit()
            case _ => Action.none()
        }
    }
}

class MouseRoutingState <: State {
    let events = ArrayList<String>()

    public init() {}

    public func record(value: String): Unit {
        events.add(value)
    }
}

class EffectState <: State {
    var value: Int64
    let events = ArrayList<String>()

    public init() {
        value = 0
    }
}

class EffectMessage <: Message {
    let kind: String

    public init(kind: String) {
        this.kind = kind
    }
}

class AsyncEffectMessage <: Message {
    let value: String

    public init(value: String) {
        this.value = value
    }
}

class EffectComponent <: Component {
    public func update(ctx: Context, msg: Message, state: State): Action {
        let _ = ctx
        let effectState = (state as EffectState).getOrThrow()
        if (let Some(effectMessage) <- (msg as EffectMessage)) {
            effectState.events.add(effectMessage.kind)
            match (effectMessage.kind) {
                case "kick" => return Action.command(EffectMessage("followup"))
                case "followup" =>
                    effectState.value += 1
                    return Action.update(effectState)
                case "batch" =>
                    effectState.value += 2
                    return Action.batch([Action.update(effectState), Action.command(EffectMessage("after-batch"))])
                case "after-batch" =>
                    effectState.events.add("tail")
                    return Action.update(effectState)
                case _ => ()
            }
        }
        Action.none()
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let effectState = (state as EffectState).getOrThrow()
        Node.text("value:${effectState.value}")
    }
}

class AsyncEffectState <: State {
    let events = ArrayList<String>()

    public init() {}
}

class AsyncEffectComponent <: Component {
    public func update(ctx: Context, msg: Message, state: State): Action {
        let _ = ctx
        let asyncState = (state as AsyncEffectState).getOrThrow()
        if (let Some(effectMessage) <- (msg as AsyncEffectMessage)) {
            asyncState.events.add(effectMessage.value)
            match (effectMessage.value) {
                case "start" => return Action.effect(Effects.delay(1, AsyncEffectMessage("done")))
                case "done" => return Action.update(asyncState)
                case _ => ()
            }
        }
        Action.none()
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let asyncState = (state as AsyncEffectState).getOrThrow()
        let summary = if (asyncState.events.isEmpty()) { "idle" } else { asyncState.events[asyncState.events.size - 1] }
        Node.text(summary)
    }
}

class MouseRoutingComponent <: Component {
    public func update(ctx: Context, msg: Message, state: State): Action {
        let _ = ctx
        let routingState = (state as MouseRoutingState).getOrThrow()
        if (let Some(event) <- (msg as UiEvent)) {
            match (event) {
                case UiEvent.Focus(nodeId) => routingState.record("focus:${nodeId}")
                case UiEvent.Blur(nodeId) => routingState.record("blur:${nodeId}")
                case UiEvent.Click(nodeId, _) => routingState.record("click:${nodeId}")
                case UiEvent.Mouse(mouseEvent) => routingState.record(describeMouse(mouseEvent))
                case _ => ()
            }
        }
        Action.update(routingState)
    }

    public func view(ctx: Context, state: State): Node {
        let _ = ctx
        let _ = state
        Node.div(
            Div()
                .direction(Direction.Vertical)
                .gap(1)
                .child(
                    Node.div(
                        Div()
                            .id("left")
                            .focusable()
                            .width(Dimension.Fixed(10))
                            .height(Dimension.Fixed(2))
                            .child(Node.text("left"))
                    )
                )
                .child(
                    Node.div(
                        Div()
                            .id("right")
                            .focusable()
                            .width(Dimension.Fixed(10))
                            .height(Dimension.Fixed(2))
                            .child(Node.text("right"))
                    )
                )
                .child(
                    Node.div(
                        Div()
                            .focusable()
                            .width(Dimension.Fixed(10))
                            .height(Dimension.Fixed(2))
                            .child(Node.text("anonymous"))
                    )
                )
        )
    }

    private func describeMouse(mouseEvent: MouseEvent): String {
        match (mouseEvent.kind) {
            case MouseEventKind.Down(MouseButton.Left) => "mouse:down:left:${mouseEvent.x}:${mouseEvent.y}"
            case MouseEventKind.ScrollUp => "mouse:scrollup:${mouseEvent.x}:${mouseEvent.y}"
            case MouseEventKind.ScrollDown => "mouse:scrolldown:${mouseEvent.x}:${mouseEvent.y}"
            case _ => "mouse:other:${mouseEvent.x}:${mouseEvent.y}"
        }
    }
}

@Test
func runtimeBootFrameRendersInitialTree() {
    let runtime = App.createRuntime(CounterComponent(), CounterState(), RuntimeConfig(20, 6, false))
    let result = runtime.bootFrame()

    @Expect(result.frame.size > 0)
    @Assert((runtime.currentState() as CounterState).getOrThrow().count, 0)
    @Assert(result.shouldExit, false)
}

@Test
func runtimeStepUpdatesStateAndRendersNextFrame() {
    let runtime = App.createRuntime(CounterComponent(), CounterState(), RuntimeConfig(20, 6, false))
    let _ = runtime.bootFrame()
    let result = runtime.stepKey("up")

    @Expect(result.frame.size > 0)
    @Assert((runtime.currentState() as CounterState).getOrThrow().count, 1)
    @Assert(result.shouldExit, false)
}

@Test
func runtimeExitActionStopsLoop() {
    let runtime = App.createRuntime(CounterComponent(), CounterState(), RuntimeConfig(20, 6, false))
    let _ = runtime.bootFrame()
    let result = runtime.stepKey("esc")

    @Assert(result.shouldExit, true)
    @Assert(runtime.isRunning(), false)
}

@Test
func runtimeResizeUpdatesSnapshotAndRerenders() {
    let runtime = App.createRuntime(CounterComponent(), CounterState(), RuntimeConfig(20, 6, false))
    let _ = runtime.bootFrame()
    let result = runtime.resize(32, 10)
    let snapshot = runtime.snapshot()

    @Expect(result.frame.size > 0)
    @Assert(snapshot.width, 32)
    @Assert(snapshot.height, 10)
    @Assert(snapshot.running, true)
}

@Test
func runtimeDispatchRoutesTickKeyAndResizeEvents() {
    let runtime = App.createRuntime(CounterComponent(), CounterState(), RuntimeConfig(20, 6, false))
    let _ = runtime.bootFrame()
    let tickResult = runtime.dispatch(RuntimeEvent.Tick)
    let keyResult = runtime.dispatch(RuntimeEvent.Key("up"))
    let resizeResult = runtime.dispatch(RuntimeEvent.Resize(28, 8))
    let snapshot = runtime.snapshot()

    @Assert(tickResult.shouldExit, false)
    @Expect(keyResult.frame.size > 0)
    @Expect(resizeResult.frame.size > 0)
    @Assert((runtime.currentState() as CounterState).getOrThrow().count, 1)
    @Assert(snapshot.width, 28)
    @Assert(snapshot.height, 8)
}

@Test
func runtimeRunLoopStopsAfterExitEvent() {
    let runtime = App.createRuntime(CounterComponent(), CounterState(), RuntimeConfig(20, 6, false))
    let _ = runtime.bootFrame()
    let results = runtime.runLoop([RuntimeEvent.Key("up"), RuntimeEvent.Key("esc"), RuntimeEvent.Key("down")])

    @Assert(results.size, 2)
    @Assert((runtime.currentState() as CounterState).getOrThrow().count, 1)
    @Assert(results[1].shouldExit, true)
    @Assert(runtime.isRunning(), false)
}

@Test
func runtimeEnterAndShutdownProduceTerminalLifecycleSequences() {
    let runtime = App.createRuntime(CounterComponent(), CounterState(), RuntimeConfig(20, 6, false))
    let boot = runtime.enterAndBoot()
    let snapshotAfterEnter = runtime.snapshot()
    let shutdown = runtime.shutdownFrame()
    let snapshotAfterShutdown = runtime.snapshot()

    @Expect(boot.frame.contains("\u{1b}[?1049h"))
    @Expect(boot.frame.contains("\u{1b}[?25l"))
    @Expect(boot.frame.size > 0)
    @Assert(snapshotAfterEnter.entered, true)
    @Expect(shutdown.contains("\u{1b}[0m"))
    @Expect(shutdown.contains("\u{1b}[?25h"))
    @Expect(shutdown.contains("\u{1b}[?1049l"))
    @Assert(snapshotAfterShutdown.entered, false)
}

@Test
func runtimeMouseCaptureLifecycleSequencesAreOptional() {
    let runtime = App.createRuntime(CounterComponent(), CounterState(), RuntimeConfig(20, 6, false, true))
    let boot = runtime.enterAndBoot()
    let shutdown = runtime.shutdownFrame()

    @Expect(boot.frame.contains("\u{1b}[?1003h"))
    @Expect(boot.frame.contains("\u{1b}[?1006h"))
    @Expect(shutdown.contains("\u{1b}[?1006l"))
    @Expect(shutdown.contains("\u{1b}[?1003l"))
}

@Test
func runtimeCanRenderWithoutClearingScreenForInlineMode() {
    let runtime = App.createRuntime(CounterComponent(), CounterState(), RuntimeConfig(20, 6, false, true))
    let boot = runtime.enterAndBoot()

    @Expect(!boot.frame.contains("\u{1b}[2J"))
    @Expect(boot.frame.contains("\u{1b}[?1049h"))
}

@Test
func runtimeRunOnceProcessesSingleEvent() {
    let runtime = App.createRuntime(CounterComponent(), CounterState(), RuntimeConfig(20, 6, false))
    let _ = runtime.bootFrame()
    let result = runtime.runOnce(RuntimeEvent.Key("up"))

    @Expect(result.frame.size > 0)
    @Assert(result.shouldExit, false)
    @Assert((runtime.currentState() as CounterState).getOrThrow().count, 1)
}

@Test
func runtimeProcessesCommandEffectsRecursively() {
    let runtime = App.createRuntime(EffectComponent(), EffectState(), RuntimeConfig(20, 4, false))
    let _ = runtime.bootFrame()

    runtime.send(EffectMessage("kick"))
    let result = runtime.step(UiEvent.Tick)
    let effectState = (runtime.currentState() as EffectState).getOrThrow()

    @Expect(result.frame.size >= 0)
    @Assert(effectState.value, 1)
    @Assert(effectState.events.size, 2)
    @Assert(effectState.events[0], "kick")
    @Assert(effectState.events[1], "followup")
}

@Test
func runtimeProcessesBatchEffectsAndQueuedCommands() {
    let runtime = App.createRuntime(EffectComponent(), EffectState(), RuntimeConfig(20, 4, false))
    let _ = runtime.bootFrame()

    runtime.send(EffectMessage("batch"))
    let _ = runtime.step(UiEvent.Tick)
    let effectState = (runtime.currentState() as EffectState).getOrThrow()

    @Assert(effectState.value, 2)
    @Assert(effectState.events.size, 3)
    @Assert(effectState.events[0], "batch")
    @Assert(effectState.events[1], "after-batch")
    @Assert(effectState.events[2], "tail")
}

@Test
func runtimeFlushesDelayedEffectsIntoFrames() {
    let runtime = App.createRuntime(AsyncEffectComponent(), AsyncEffectState(), RuntimeConfig(20, 4, false))
    let _ = runtime.bootFrame()

    runtime.send(AsyncEffectMessage("start"))
    let _ = runtime.step(UiEvent.Tick)
    sleep(5 * Duration.millisecond)
    match (runtime.flushAsync()) {
        case Some(result) =>
            let asyncState = (runtime.currentState() as AsyncEffectState).getOrThrow()
            @Expect(result.frame.size >= 0)
            @Assert(asyncState.events.size, 2)
            @Assert(asyncState.events[0], "start")
            @Assert(asyncState.events[1], "done")
        case None => @Fail("expected delayed effect flush")
    }
}

@Test
func runtimeMouseDownDispatchesFocusClickAndMouseInOrder() {
    let runtime = App.createRuntime(MouseRoutingComponent(), MouseRoutingState(), RuntimeConfig(20, 10, false))
    let _ = runtime.bootFrame()
    let result = runtime.dispatch(RuntimeEvent.Mouse(MouseEvent(1, 0, MouseEventKind.Down(MouseButton.Left))))
    let state = (runtime.currentState() as MouseRoutingState).getOrThrow()

    @Assert(result.shouldExit, false)
    @Assert(state.events.size, 3)
    @Assert(state.events[0], "focus:left")
    @Assert(state.events[1], "click:left")
    @Assert(state.events[2], "mouse:down:left:1:0")
}

@Test
func runtimeMouseDownOnDifferentNodeBlursPreviousFocus() {
    let runtime = App.createRuntime(MouseRoutingComponent(), MouseRoutingState(), RuntimeConfig(20, 10, false))
    let _ = runtime.bootFrame()
    let _ = runtime.dispatch(RuntimeEvent.Mouse(MouseEvent(1, 0, MouseEventKind.Down(MouseButton.Left))))
    let result = runtime.dispatch(RuntimeEvent.Mouse(MouseEvent(1, 3, MouseEventKind.Down(MouseButton.Left))))
    let state = (runtime.currentState() as MouseRoutingState).getOrThrow()

    @Assert(result.shouldExit, false)
    @Assert(state.events.size, 7)
    @Assert(state.events[3], "blur:left")
    @Assert(state.events[4], "focus:right")
    @Assert(state.events[5], "click:right")
    @Assert(state.events[6], "mouse:down:left:1:3")
}

@Test
func runtimeMouseDownOutsideFocusableAreaClearsFocusButStillDeliversMouse() {
    let runtime = App.createRuntime(MouseRoutingComponent(), MouseRoutingState(), RuntimeConfig(20, 10, false))
    let _ = runtime.bootFrame()
    let _ = runtime.dispatch(RuntimeEvent.Mouse(MouseEvent(1, 0, MouseEventKind.Down(MouseButton.Left))))
    let result = runtime.dispatch(RuntimeEvent.Mouse(MouseEvent(18, 9, MouseEventKind.Down(MouseButton.Left))))
    let state = (runtime.currentState() as MouseRoutingState).getOrThrow()

    @Assert(result.shouldExit, false)
    @Assert(state.events.size, 5)
    @Assert(state.events[3], "blur:left")
    @Assert(state.events[4], "mouse:down:left:18:9")
}

@Test
func runtimeMouseDownOnAnonymousFocusableNodeDoesNotStealFocus() {
    let runtime = App.createRuntime(MouseRoutingComponent(), MouseRoutingState(), RuntimeConfig(20, 10, false))
    let _ = runtime.bootFrame()
    let result = runtime.dispatch(RuntimeEvent.Mouse(MouseEvent(1, 6, MouseEventKind.Down(MouseButton.Left))))
    let state = (runtime.currentState() as MouseRoutingState).getOrThrow()

    @Assert(result.shouldExit, false)
    @Assert(state.events.size, 1)
    @Assert(state.events[0], "mouse:down:left:1:6")
}

@Test
func runtimeScrollFocusesNodeUnderPointerBeforeMouseDispatch() {
    let runtime = App.createRuntime(MouseRoutingComponent(), MouseRoutingState(), RuntimeConfig(20, 10, false))
    let _ = runtime.bootFrame()
    let result = runtime.dispatch(RuntimeEvent.Mouse(MouseEvent(1, 3, MouseEventKind.ScrollUp)))
    let state = (runtime.currentState() as MouseRoutingState).getOrThrow()

    @Assert(result.shouldExit, false)
    @Assert(state.events.size, 2)
    @Assert(state.events[0], "focus:right")
    @Assert(state.events[1], "mouse:scrollup:1:3")
}

@Test
func normalizeKeyNameBuildsStructuredKeyCodes() {
    let up = normalizeKeyName("up")
    let charA = normalizeKeyName("a")
    let named = normalizeKeyName("space")

    match (up.code) {
        case KeyCode.Up => @Assert(true)
        case _ => @Fail("expected Up key code")
    }
    match (charA.code) {
        case KeyCode.Char(ch) => @Assert(ch, r'a')
        case _ => @Fail("expected Char key code")
    }
    match (named.code) {
        case KeyCode.Named(value) => @Assert(value, "space")
        case _ => @Fail("expected Named key code")
    }
}

@Test
func normalizeRuntimeEventConvertsResizeToUiEvent() {
    let event = normalizeRuntimeEvent(RuntimeEvent.Resize(42, 9))

    match (event) {
        case Some(UiEvent.Resize(resizeEvent)) =>
            @Assert(resizeEvent.width, 42)
            @Assert(resizeEvent.height, 9)
        case _ => @Fail("expected resize ui event")
    }
}

@Test
func appRunnerStreamsFramesThroughSourceAndSink() {
    let runtime = App.createRuntime(CounterComponent(), CounterState(), RuntimeConfig(20, 6, false))
    let source = ArrayRuntimeEventSource([RuntimeEvent.Key("up"), RuntimeEvent.Key("esc")])
    let sink = MemoryFrameSink()
    let runner = App.createRunner()

    runner.run(runtime, source, sink)

    let frames = sink.allFrames()
    @Assert(frames.size, 3)
    @Expect(frames[0].contains("\u{1b}[?1049h"))
    @Expect(frames[1].size > 0)
    @Assert(runtime.isRunning(), false)
    @Expect(frames[2].contains("\u{1b}[?1049l"))
}

@Test
func parseInputLineBuildsRuntimeEventsFromTextCommands() {
    let key = parseInputLine("key up")
    let resize = parseInputLine("resize 40 12")
    let tick = parseInputLine("tick")
    let quit = parseInputLine("quit")

    match (key.event) {
        case Some(RuntimeEvent.Key(name)) => @Assert(name, "up")
        case _ => @Fail("expected key runtime event")
    }
    match (resize.event) {
        case Some(RuntimeEvent.Resize(width, height)) =>
            @Assert(width, 40)
            @Assert(height, 12)
        case _ => @Fail("expected resize runtime event")
    }
    match (tick.event) {
        case Some(RuntimeEvent.Tick) => @Assert(true)
        case _ => @Fail("expected tick runtime event")
    }
    @Assert(quit.shouldContinue, false)
}

@Test
func arrayRuntimeEventSourceReturnsStopWhenConsumedByRunnerSequence() {
    let source = ArrayRuntimeEventSource([RuntimeEvent.Key("up")])

    match (source.next()) {
        case Some(RuntimeEvent.Key(name)) => @Assert(name, "up")
        case _ => @Fail("expected first event")
    }
    match (source.next()) {
        case None => @Assert(true)
        case _ => @Fail("expected source exhaustion")
    }
}

@Test
func parseRawInputRecognizesArrowAndFunctionKeys() {
    let up = parseRawInput("\u{1b}[A")
    let f1 = parseRawInput("\u{1b}OP")
    let pageDown = parseRawInput("\u{1b}[6~")

    match (up.event) {
        case Some(RuntimeEvent.Key(name)) => @Assert(name, "up")
        case _ => @Fail("expected raw up key")
    }
    @Assert(up.consumed, 3)
    match (f1.event) {
        case Some(RuntimeEvent.Key(name)) => @Assert(name, "f1")
        case _ => @Fail("expected raw f1 key")
    }
    @Assert(f1.consumed, 3)
    match (pageDown.event) {
        case Some(RuntimeEvent.Key(name)) => @Assert(name, "pagedown")
        case _ => @Fail("expected raw page down key")
    }
    @Assert(pageDown.consumed, 4)
}

@Test
func parseRawInputRecognizesControlCharacters() {
    let enter = parseRawInput("\n")
    let stop = parseRawInput("\u{04}")
    let charA = parseRawInput("a")

    match (enter.event) {
        case Some(RuntimeEvent.Key(name)) => @Assert(name, "enter")
        case _ => @Fail("expected enter key")
    }
    match (stop.event) {
        case Some(RuntimeEvent.Stop) => @Assert(true)
        case _ => @Fail("expected stop event")
    }
    match (charA.event) {
        case Some(RuntimeEvent.Key(name)) => @Assert(name, "a")
        case _ => @Fail("expected character key")
    }
}

@Test
func parseRawInputRecognizesMousePressAndRelease() {
    let press = parseRawInput("\u{1b}[<0;12;7M")
    let release = parseRawInput("\u{1b}[<0;12;7m")

    match (press.event) {
        case Some(RuntimeEvent.Mouse(mouseEvent)) =>
            @Assert(mouseEvent.x, 11)
            @Assert(mouseEvent.y, 6)
            match (mouseEvent.kind) {
                case MouseEventKind.Down(MouseButton.Left) => @Assert(true)
                case _ => @Fail("expected left mouse down")
            }
        case _ => @Fail("expected mouse press event")
    }
    @Assert(press.consumed, 10)

    match (release.event) {
        case Some(RuntimeEvent.Mouse(mouseEvent)) =>
            @Assert(mouseEvent.x, 11)
            @Assert(mouseEvent.y, 6)
            match (mouseEvent.kind) {
                case MouseEventKind.Up(MouseButton.Left) => @Assert(true)
                case _ => @Fail("expected left mouse up")
            }
        case _ => @Fail("expected mouse release event")
    }
    @Assert(release.consumed, 10)
}

@Test
func parseRawInputRecognizesMouseMoveDragAndScroll() {
    let drag = parseRawInput("\u{1b}[<32;5;3M")
    let move = parseRawInput("\u{1b}[<35;5;3M")
    let scroll = parseRawInput("\u{1b}[<64;9;4M")

    match (drag.event) {
        case Some(RuntimeEvent.Mouse(mouseEvent)) =>
            match (mouseEvent.kind) {
                case MouseEventKind.Drag(MouseButton.Left) => @Assert(true)
                case _ => @Fail("expected left drag")
            }
        case _ => @Fail("expected drag mouse event")
    }

    match (move.event) {
        case Some(RuntimeEvent.Mouse(mouseEvent)) =>
            match (mouseEvent.kind) {
                case MouseEventKind.Move => @Assert(true)
                case _ => @Fail("expected move mouse event")
            }
        case _ => @Fail("expected move mouse event")
    }

    match (scroll.event) {
        case Some(RuntimeEvent.Mouse(mouseEvent)) =>
            @Assert(mouseEvent.x, 8)
            @Assert(mouseEvent.y, 3)
            match (mouseEvent.kind) {
                case MouseEventKind.ScrollUp => @Assert(true)
                case _ => @Fail("expected scroll up mouse event")
            }
        case _ => @Fail("expected scroll mouse event")
    }
}

@Test
func parseRawInputWaitsForCompleteMouseSequence() {
    let partial = parseRawInput("\u{1b}[<0;12")

    match (partial.event) {
        case None => @Assert(true)
        case _ => @Fail("expected incomplete mouse sequence to wait")
    }
    @Assert(partial.consumed, 0)
}

@Test
func rawStringRuntimeEventSourceConsumesAnsiSequences() {
    let source = RawStringRuntimeEventSource("\u{1b}[Aa\u{1b}OP")

    match (source.next()) {
        case Some(RuntimeEvent.Key(name)) => @Assert(name, "up")
        case _ => @Fail("expected first raw event")
    }
    match (source.next()) {
        case Some(RuntimeEvent.Key(name)) => @Assert(name, "a")
        case _ => @Fail("expected second raw event")
    }
    match (source.next()) {
        case Some(RuntimeEvent.Key(name)) => @Assert(name, "f1")
        case _ => @Fail("expected third raw event")
    }
    match (source.next()) {
        case None => @Assert(true)
        case _ => @Fail("expected raw source exhaustion")
    }
}

@Test
func appRunnerKeepsCanonicalModeForBufferedSources() {
    let runtime = App.createRuntime(CounterComponent(), CounterState(), RuntimeConfig(20, 6, false))
    let controller = FakeTerminalModeController()
    let runner = App.createRunner(controller)
    let sink = MemoryFrameSink()

    runner.run(runtime, ArrayRuntimeEventSource([RuntimeEvent.Stop]), sink)

    @Assert(controller.enterCount, 0)
    @Assert(controller.restoreCount, 1)
    match (runner.inputMode()) {
        case TerminalInputMode.Canonical => @Assert(true)
        case _ => @Fail("expected canonical input mode")
    }
}

@Test
func appCreatesInteractiveRunnerWithSttyModeController() {
    let runner = App.createInteractiveRunner()

    match (runner.inputMode()) {
        case TerminalInputMode.Canonical => @Assert(true)
        case _ => @Fail("expected canonical input mode")
    }
}

@Test
func appCreatesInteractiveRuntimeWithMouseCaptureEnabled() {
    let runtime = App.createInteractiveRuntime(CounterComponent(), CounterState(), 40, 8)
    let boot = runtime.enterAndBoot()
    let shutdown = runtime.shutdownFrame()

    @Expect(boot.frame.contains("\u{1b}[?1003h"))
    @Expect(boot.frame.contains("\u{1b}[?1006h"))
    @Expect(shutdown.contains("\u{1b}[?1006l"))
    @Expect(shutdown.contains("\u{1b}[?1003l"))
}

@Test
func interactiveRunnerFactoryCreatesCanonicalRunner() {
    let factory = InteractiveRunnerFactory()
    let runner = factory.create()

    match (runner.inputMode()) {
        case TerminalInputMode.Canonical => @Assert(true)
        case _ => @Fail("expected canonical input mode")
    }
}

@Test
func interactiveRuntimeEventSourceEmitsResizeWhenTerminalSizeChanges() {
    let source = InteractiveRuntimeEventSource(
        ArrayRuntimeEventSource([RuntimeEvent.Stop]),
        FakeTerminalSizeReader([TerminalSize(80, 24), TerminalSize(100, 30)]),
        1
    )

    match (source.next()) {
        case Some(RuntimeEvent.Resize(width, height)) =>
            @Assert(width, 100)
            @Assert(height, 30)
        case _ => @Fail("expected resize runtime event")
    }
}

@Test
func interactiveRuntimeEventSourceDeliversStopAfterResizeDrain() {
    let source = InteractiveRuntimeEventSource(
        ArrayRuntimeEventSource([RuntimeEvent.Stop]),
        FakeTerminalSizeReader([TerminalSize(80, 24), TerminalSize(100, 30)]),
        1
    )

    match (source.next()) {
        case Some(RuntimeEvent.Resize(width, height)) =>
            @Assert(width, 100)
            @Assert(height, 30)
        case _ => @Fail("expected resize before stop")
    }

    match (source.next()) {
        case Some(RuntimeEvent.Stop) => @Assert(true)
        case _ => @Fail("expected stop after drained resize event")
    }
}

@Test
func interactiveRuntimeEventSourceSkipsDuplicateTerminalSizes() {
    let source = InteractiveRuntimeEventSource(
        ArrayRuntimeEventSource([RuntimeEvent.Stop]),
        FakeTerminalSizeReader([TerminalSize(80, 24), TerminalSize(80, 24)]),
        1
    )

    match (source.next()) {
        case Some(RuntimeEvent.Stop) => @Assert(true)
        case _ => @Fail("expected stop without duplicate resize event")
    }
}

@Test
func appRunnerRerendersAfterInteractiveResizeBeforeStop() {
    let runtime = App.createRuntime(CounterComponent(), CounterState(), RuntimeConfig(40, 8, false, true))
    let sink = MemoryFrameSink()
    let source = InteractiveRuntimeEventSource(
        DelayedStopRuntimeEventSource(25),
        FakeTerminalSizeReader([TerminalSize(40, 8), TerminalSize(60, 12)]),
        1
    )
    let runner = App.createRunner(FakeTerminalModeController())

    runner.run(runtime, source, sink)

    let frames = sink.allFrames()
    @Assert(frames.size, 3)
    @Expect(frames[0].contains("\u{1b}[?1049h"))
    @Expect(frames[1].size > 0)
    @Expect(frames[2].contains("\u{1b}[?1049l"))
    @Assert(runtime.snapshot().width, 60)
    @Assert(runtime.snapshot().height, 12)
}

@Test
func appRunnerFlushesAsyncEffectsWhileWaitingForInput() {
    let runtime = App.createRuntime(AsyncEffectComponent(), AsyncEffectState(), RuntimeConfig(20, 4, false))
    let sink = MemoryFrameSink()
    let source = DelayedTickRuntimeEventSource(60)
    let runner = App.createRunner(FakeTerminalModeController())

    runtime.send(AsyncEffectMessage("start"))
    runner.run(runtime, source, sink)

    let asyncState = (runtime.currentState() as AsyncEffectState).getOrThrow()
    let frames = sink.allFrames()
    @Assert(asyncState.events.size, 2)
    @Assert(asyncState.events[0], "start")
    @Assert(asyncState.events[1], "done")
    @Expect(frames.size >= 3)
}

@Test
func createInteractiveRuntimeUsesDetectedTerminalSizeWhenAvailable() {
    let runtime = App.createInteractiveRuntime(
        CounterComponent(),
        CounterState(),
        40,
        8,
        FakeTerminalSizeReader([TerminalSize(72, 19)])
    )
    let snapshot = runtime.snapshot()

    @Assert(snapshot.width, 72)
    @Assert(snapshot.height, 19)
}

@Test
func createInteractiveRuntimeFallsBackWhenTerminalSizeUnavailable() {
    let runtime = App.createInteractiveRuntime(
        CounterComponent(),
        CounterState(),
        40,
        8,
        FakeTerminalSizeReader([None])
    )
    let snapshot = runtime.snapshot()

    @Assert(snapshot.width, 40)
    @Assert(snapshot.height, 8)
}

@Test
func appRunnerEntersRawModeForInteractiveSource() {
    let runtime = App.createRuntime(CounterComponent(), CounterState(), RuntimeConfig(20, 6, false))
    let controller = FakeTerminalModeController()
    let runner = App.createRunner(controller)
    let sink = MemoryFrameSink()
    let source = InteractiveRuntimeEventSource(
        ArrayRuntimeEventSource([RuntimeEvent.Stop]),
        FakeTerminalSizeReader([None]),
        1
    )

    runner.run(runtime, source, sink)

    @Assert(controller.enterCount, 1)
    @Assert(controller.restoreCount, 1)
}
