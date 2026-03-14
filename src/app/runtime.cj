package cjrxtui.app

import std.collection.ArrayList
import std.collection.concurrent.LinkedBlockingQueue
import cjrxtui.component.{Action, Component, ComponentId, Context, Effect, EffectDispatcher, EffectSink, Message, MouseEvent, ResizeEvent, State, UiEvent}
import cjrxtui.layout.{LayoutBox, LayoutEngine}
import cjrxtui.render.FramePipeline
import cjrxtui.terminal.TerminalRenderer

public struct RuntimeConfig {
    public let width: Int64
    public let height: Int64
    public let clearScreenOnStart: Bool
    public let mouseCapture: Bool

    public init() {
        this.width = 80
        this.height = 24
        this.clearScreenOnStart = true
        this.mouseCapture = false
    }

    public init(width: Int64, height: Int64, clearScreenOnStart: Bool) {
        this.width = width
        this.height = height
        this.clearScreenOnStart = clearScreenOnStart
        this.mouseCapture = false
    }

    public init(width: Int64, height: Int64, clearScreenOnStart: Bool, mouseCapture: Bool) {
        this.width = width
        this.height = height
        this.clearScreenOnStart = clearScreenOnStart
        this.mouseCapture = mouseCapture
    }
}

public struct RuntimeStepResult {
    public let frame: String
    public let shouldExit: Bool

    public init(frame: String, shouldExit: Bool) {
        this.frame = frame
        this.shouldExit = shouldExit
    }
}

public struct RuntimeSnapshot {
    public let width: Int64
    public let height: Int64
    public let running: Bool
    public let entered: Bool

    public init(width: Int64, height: Int64, running: Bool, entered: Bool) {
        this.width = width
        this.height = height
        this.running = running
        this.entered = entered
    }
}

public enum RuntimeEvent {
    | Tick
    | Key(String)
    | Mouse(MouseEvent)
    | Resize(Int64, Int64)
    | Stop
}

private enum AsyncEnvelope {
    | Message(Message)
    | Topic(String, Message)
}

public class AppRuntime {
    private let root: Component
    private var state: State
    private let context: Context
    private let pipeline: FramePipeline
    private let layoutEngine: LayoutEngine
    private let terminalRenderer: TerminalRenderer
    private var running: Bool = true
    private var width: Int64
    private var height: Int64
    private let clearScreenOnStart: Bool
    private let mouseCapture: Bool
    private var entered: Bool = false
    private var focusedNodeId: ?String = None
    private var latestLayout: ?LayoutBox = None
    private let asyncQueue = LinkedBlockingQueue<AsyncEnvelope>()

    public init(root: Component, initialState: State) {
        this.root = root
        this.state = initialState
        this.context = Context(ComponentId.root())
        let config = RuntimeConfig()
        this.width = config.width
        this.height = config.height
        this.clearScreenOnStart = config.clearScreenOnStart
        this.mouseCapture = config.mouseCapture
        this.pipeline = FramePipeline(width, height)
        this.layoutEngine = LayoutEngine()
        this.terminalRenderer = TerminalRenderer()
    }

    public init(root: Component, initialState: State, config: RuntimeConfig) {
        this.root = root
        this.state = initialState
        this.context = Context(ComponentId.root())
        this.width = config.width
        this.height = config.height
        this.clearScreenOnStart = config.clearScreenOnStart
        this.mouseCapture = config.mouseCapture
        this.pipeline = FramePipeline(width, height)
        this.layoutEngine = LayoutEngine()
        this.terminalRenderer = TerminalRenderer()
    }

    public func currentState(): State {
        state
    }

    public func isRunning(): Bool {
        running
    }

    public func snapshot(): RuntimeSnapshot {
        RuntimeSnapshot(width, height, running, entered)
    }

    public func send(message: Message): Unit {
        context.send(message)
    }

    public func flushAsync(): ?RuntimeStepResult {
        if (!drainAsyncMessages(20)) {
            return None
        }
        processMessages()
        let frame = renderFrame()
        Some(RuntimeStepResult(frame, !running))
    }

    public func bootFrame(): RuntimeStepResult {
        let frame = renderFrame()
        if (clearScreenOnStart) {
            return RuntimeStepResult("\u{1b}[2J\u{1b}[H" + frame, !running)
        }
        RuntimeStepResult(frame, !running)
    }

    public func enter(): String {
        entered = true
        let mouseCaptureAnsi = if (mouseCapture) { terminalRenderer.enableMouseCaptureAnsi() } else { "" }
        terminalRenderer.enterAlternateScreenAnsi() + terminalRenderer.hideCursorAnsi() + mouseCaptureAnsi
    }

    public func enterAndBoot(): RuntimeStepResult {
        let prefix = enter()
        let result = bootFrame()
        RuntimeStepResult(prefix + result.frame, result.shouldExit)
    }

    public func shutdownFrame(): String {
        entered = false
        terminalRenderer.resetState()
        let mouseCaptureAnsi = if (mouseCapture) { terminalRenderer.disableMouseCaptureAnsi() } else { "" }
        terminalRenderer.resetAnsi() + mouseCaptureAnsi + terminalRenderer.showCursorAnsi() + terminalRenderer.leaveAlternateScreenAnsi()
    }

    public func step(message: Message): RuntimeStepResult {
        if (!running) {
            return RuntimeStepResult("", true)
        }

        context.send(message)
        processMessages()
        let frame = renderFrame()
        RuntimeStepResult(frame, !running)
    }

    public func stepKey(name: String): RuntimeStepResult {
        step(UiEvent.Key(normalizeKeyName(name)))
    }

    public func tick(): RuntimeStepResult {
        step(UiEvent.Tick)
    }

    public func dispatch(event: RuntimeEvent): RuntimeStepResult {
        match (normalizeRuntimeEvent(event)) {
            case Some(uiEvent) => dispatchUiEvent(uiEvent)
            case None =>
                stop()
                RuntimeStepResult("", true)
        }
    }

    public func runLoop(events: Array<RuntimeEvent>): Array<RuntimeStepResult> {
        let results = ArrayList<RuntimeStepResult>()
        for (event in events) {
            if (!running) {
                break
            }
            results.add(dispatch(event))
        }
        Array<RuntimeStepResult>(results.size, { index => results[index] })
    }

    public func runOnce(event: RuntimeEvent): RuntimeStepResult {
        dispatch(event)
    }

    public func stop(): Unit {
        running = false
    }

    public func resize(width: Int64, height: Int64): RuntimeStepResult {
        this.width = width
        this.height = height
        pipeline.resize(width, height)
        processMessage(UiEvent.Resize(ResizeEvent(width, height)))
        let frame = renderFrame()
        RuntimeStepResult(frame, !running)
    }

    public func dispatchUiEvent(event: UiEvent): RuntimeStepResult {
        match (event) {
            case UiEvent.Resize(resizeEvent) => resize(resizeEvent.width, resizeEvent.height)
            case UiEvent.Mouse(mouseEvent) => dispatchMouseEvent(mouseEvent)
            case _ => step(event)
        }
    }

    private func renderFrame(): String {
        let tree = root.view(context, state)
        latestLayout = layoutEngine.layout(tree)
        context.markRendered()
        let result = pipeline.renderFrame(tree)
        result.frame
    }

    private func processMessages(): Unit {
        while (true) {
            let messages = context.drainMessages()
            let topicMessages = context.drainTopicMessages()
            if (messages.isEmpty() && topicMessages.isEmpty()) {
                break
            }

            for (message in messages) {
                processMessage(message)
                processFocusRequest()
            }

            for (envelope in topicMessages) {
                let _ = envelope.topic
                processMessage(envelope.message)
                processFocusRequest()
            }
        }
    }

    private func processMessage(message: Message): Unit {
        applyAction(root.update(context, message, state))
    }

    private func dispatchMouseEvent(mouseEvent: MouseEvent): RuntimeStepResult {
        if (!running) {
            return RuntimeStepResult("", true)
        }

        routeMouseInteraction(mouseEvent)
        context.send(UiEvent.Mouse(mouseEvent))
        processMessages()
        let frame = renderFrame()
        RuntimeStepResult(frame, !running)
    }

    private func routeMouseInteraction(mouseEvent: MouseEvent): Unit {
        match (mouseEvent.kind) {
            case Down(_) => routePointerDown(mouseEvent)
            case ScrollUp => routePointerFocus(mouseEvent)
            case ScrollDown => routePointerFocus(mouseEvent)
            case _ => ()
        }
    }

    private func routePointerDown(mouseEvent: MouseEvent): Unit {
        match (findFocusableNodeIdAt(mouseEvent.x, mouseEvent.y)) {
            case Some(nodeId) =>
                updateFocus(nodeId)
                context.send(UiEvent.Click(nodeId, mouseEvent))
            case None => clearFocus()
        }
    }

    private func routePointerFocus(mouseEvent: MouseEvent): Unit {
        match (findFocusableNodeIdAt(mouseEvent.x, mouseEvent.y)) {
            case Some(nodeId) => updateFocus(nodeId)
            case None => clearFocus()
        }
    }

    private func processFocusRequest(): Unit {
        match (context.takeFocusRequest()) {
            case Some(nodeId) => updateFocus(nodeId)
            case None => ()
        }
    }

    private func updateFocus(nodeId: String): Unit {
        match (focusedNodeId) {
            case Some(current) =>
                if (current == nodeId) {
                    return
                }
                processMessage(UiEvent.Blur(current))
            case None => ()
        }

        focusedNodeId = nodeId
        processMessage(UiEvent.Focus(nodeId))
    }

    private func clearFocus(): Unit {
        match (focusedNodeId) {
            case Some(current) =>
                focusedNodeId = None
                processMessage(UiEvent.Blur(current))
            case None => ()
        }
    }

    private func findFocusableNodeIdAt(x: Int64, y: Int64): ?String {
        match (latestLayout) {
            case Some(layout) =>
                match (layout.deepestFocusableAt(x, y)) {
                    case Some(target) => target.nodeId
                    case None => None
                }
            case None => None
        }
    }

    private func applyAction(action: Action): Unit {
        match (action) {
            case Update(nextState) => state = nextState
            case UpdateTopic(_, nextState) => state = nextState
            case Command(message) => context.send(message)
            case CommandTopic(topic, message) => context.sendToTopic(topic, message)
            case RunEffect(effect) => launchEffect(effect)
            case Batch(actions) =>
                for (nextAction in actions) {
                    applyAction(nextAction)
                }
            case DoNothing => ()
            case Exit => running = false
        }
    }

    private func drainAsyncMessages(waitMillis: Int64): Bool {
        var drainedAny = false
        let timeout = if (waitMillis > 0) { waitMillis * Duration.millisecond } else { Duration.Zero }
        match (asyncQueue.remove(timeout)) {
            case Some(AsyncEnvelope.Message(message)) =>
                context.send(message)
                drainedAny = true
            case Some(AsyncEnvelope.Topic(topic, message)) =>
                context.sendToTopic(topic, message)
                drainedAny = true
            case None => return false
        }

        while (true) {
            match (asyncQueue.remove(Duration.Zero)) {
                case Some(AsyncEnvelope.Message(message)) =>
                    context.send(message)
                    drainedAny = true
                case Some(AsyncEnvelope.Topic(topic, message)) =>
                    context.sendToTopic(topic, message)
                    drainedAny = true
                case None => return drainedAny
            }
        }
        drainedAny
    }

    private func launchEffect(effect: Effect): Unit {
        let queue = asyncQueue
        spawn {
            effect.run(EffectDispatcher(RuntimeEffectSink(queue)))
        }
    }
}

private class RuntimeEffectSink <: EffectSink {
    private let queue: LinkedBlockingQueue<AsyncEnvelope>

    public init(queue: LinkedBlockingQueue<AsyncEnvelope>) {
        this.queue = queue
    }

    public func send(message: Message): Unit {
        queue.add(AsyncEnvelope.Message(message))
    }

    public func sendToTopic(topic: String, message: Message): Unit {
        queue.add(AsyncEnvelope.Topic(topic, message))
    }
}
