package cjrxtui.app

import std.collection.ArrayList
import std.collection.concurrent.LinkedBlockingQueue
import std.env.*
import std.fs.*
import std.sync.{AtomicBool, AtomicInt64}
import cjrxtui.terminal.{NoopTerminalModeController, NoopTerminalSizeReader, SttyTerminalModeController, TerminalInputMode, TerminalModeController, TerminalSize, TerminalSizeReader}

public interface RuntimeEventSource {
    func next(): ?RuntimeEvent
}

public enum RuntimeEventPollResult {
    | Event(RuntimeEvent)
    | Timeout
    | End
}

public interface PollingRuntimeEventSource <: RuntimeEventSource {
    func poll(timeoutMillis: Int64): RuntimeEventPollResult
}

public interface FrameSink {
    func write(frame: String): Unit
}

public class AppRunner {
    private let modeController: TerminalModeController

    public init() {
        this.modeController = NoopTerminalModeController()
    }

    public init(modeController: TerminalModeController) {
        this.modeController = modeController
    }

    public func run(runtime: AppRuntime, source: RuntimeEventSource, sink: FrameSink): Unit {
        enterInputMode(source)
        let boot = runtime.enterAndBoot()
        if (boot.frame.size > 0) {
            sink.write(boot.frame)
        }

        while (runtime.isRunning()) {
            match (runtime.flushAsync()) {
                case Some(asyncResult) =>
                    if (asyncResult.frame.size > 0) {
                        sink.write(asyncResult.frame)
                    }
                    if (asyncResult.shouldExit) {
                        break
                    }
                case None => ()
            }
            match (pollNextEvent(source)) {
                case RuntimeEventPollResult.Event(event) =>
                    let result = runtime.runOnce(event)
                    if (result.frame.size > 0) {
                        sink.write(result.frame)
                    }
                case RuntimeEventPollResult.Timeout => ()
                case RuntimeEventPollResult.End => break
            }
        }

        sink.write(runtime.shutdownFrame())
        restoreInputMode()
    }

    public func inputMode(): TerminalInputMode {
        modeController.currentMode()
    }

    public func runInteractive(runtime: AppRuntime): Unit {
        run(runtime, InteractiveRuntimeEventSource(), StdoutFrameSink())
    }

    private func enterInputMode(source: RuntimeEventSource): Unit {
        if (source is RawStdinRuntimeEventSource || source is InteractiveRuntimeEventSource) {
            modeController.enterRawMode()
        }
    }

    private func restoreInputMode(): Unit {
        modeController.restoreMode()
    }

    private func pollNextEvent(source: RuntimeEventSource): RuntimeEventPollResult {
        if (let Some(pollingSource) <- (source as PollingRuntimeEventSource)) {
            return pollingSource.poll(asyncPollIntervalMillis())
        }
        match (source.next()) {
            case Some(event) => RuntimeEventPollResult.Event(event)
            case None => RuntimeEventPollResult.End
        }
    }

    private func asyncPollIntervalMillis(): Int64 {
        20
    }
}

public class InteractiveRunnerFactory {
    public init() {}

    public func create(): AppRunner {
        AppRunner(SttyTerminalModeController())
    }
}

public class ArrayRuntimeEventSource <: RuntimeEventSource {
    private let events: Array<RuntimeEvent>
    private var index: Int64 = 0

    public init(events: Array<RuntimeEvent>) {
        this.events = events
    }

    public func next(): ?RuntimeEvent {
        if (index >= events.size) {
            return None
        }
        let event = events[index]
        index += 1
        event
    }
}

public class StdinRuntimeEventSource <: RuntimeEventSource {
    public init() {}

    public func next(): ?RuntimeEvent {
        match (getStdIn().readln()) {
            case Some(line) =>
                let parsed = parseInputLine(line)
                if (!parsed.shouldContinue) {
                    return RuntimeEvent.Stop
                }
                parsed.event
            case None => RuntimeEvent.Stop
        }
    }
}

public class RawRuntimeEventParser {
    public init() {}

    public func nextFromBuffer(buffer: String): ParsedRawInput {
        parseRawInput(buffer)
    }
}

private enum QueuedRuntimeEvent {
    | Event(RuntimeEvent)
    | Stop
    | End
}

public class RawStringRuntimeEventSource <: RuntimeEventSource {
    private let parser: RawRuntimeEventParser
    private var buffer: String

    public init(buffer: String) {
        this.parser = RawRuntimeEventParser()
        this.buffer = buffer
    }

    public func next(): ?RuntimeEvent {
        while (!buffer.isEmpty()) {
            let parsed = parser.nextFromBuffer(buffer)
            if (parsed.consumed <= 0) {
                return None
            }
            buffer = buffer[parsed.consumed..buffer.size]
            match (parsed.event) {
                case Some(event) => return event
                case None => ()
            }
        }
        None
    }
}

public class RawStdinRuntimeEventSource <: PollingRuntimeEventSource {
    private let queue = LinkedBlockingQueue<QueuedRuntimeEvent>()
    private var started: Bool = false
    // Shared flag: reader thread sets to 1 when a new byte arrives
    private let byteReady = AtomicInt64(0)

    public init() {
        this.started = false
    }

    public func next(): ?RuntimeEvent {
        ensureStarted()
        match (queue.remove()) {
            case QueuedRuntimeEvent.Event(event) => event
            case QueuedRuntimeEvent.Stop => RuntimeEvent.Stop
            case QueuedRuntimeEvent.End => None
        }
    }

    public func poll(timeoutMillis: Int64): RuntimeEventPollResult {
        ensureStarted()
        let timeout = if (timeoutMillis > 0) { timeoutMillis * Duration.millisecond } else { Duration.Zero }
        match (queue.remove(timeout)) {
            case Some(QueuedRuntimeEvent.Event(event)) => RuntimeEventPollResult.Event(event)
            case Some(QueuedRuntimeEvent.Stop) => RuntimeEventPollResult.Event(RuntimeEvent.Stop)
            case Some(QueuedRuntimeEvent.End) => RuntimeEventPollResult.End
            case None => RuntimeEventPollResult.Timeout
        }
    }

    private func ensureStarted(): Unit {
        if (started) {
            return
        }
        started = true

        let charQueue = LinkedBlockingQueue<?Rune>()

        // Reader thread: reads raw bytes from /dev/tty into charQueue.
        // We bypass ConsoleReader (getStdIn().read()) because its internal
        // line-buffering blocks indefinitely in terminal raw mode.
        spawn {
            try {
                let tty = File("/dev/tty", OpenMode.Read)
                let buf = Array<Byte>(1, repeat: 0)
                while (true) {
                    let n = tty.read(buf)
                    if (n <= 0) {
                        charQueue.add(None)
                        return
                    }
                    let ch = Rune(UInt32(buf[0]))
                    charQueue.add(ch)
                }
            } catch (_: Exception) {
                charQueue.add(None)
            }
        }

        // Parser thread: reads from charQueue, assembles buffer, parses events
        let sourceQueue = queue
        spawn {
            let parser = RawRuntimeEventParser()
            var buffer = ""
            while (true) {
                // Try to parse what we have in the buffer first
                let parsed = parser.nextFromBuffer(buffer)
                if (parsed.consumed > 0) {
                    buffer = dropConsumedPrefix(buffer, parsed.consumed)
                }
                match (parsed.event) {
                    case Some(RuntimeEvent.Stop) =>
                        sourceQueue.add(QueuedRuntimeEvent.Stop)
                        sourceQueue.add(QueuedRuntimeEvent.End)
                        return
                    case Some(event) =>
                        sourceQueue.add(QueuedRuntimeEvent.Event(event))
                        continue
                    case None => ()
                }

                // parsed.consumed == 0 and event == None → need more data
                if (buffer.isEmpty()) {
                    // Buffer empty: block waiting for next char
                    // charQueue.remove() returns ?Rune (the T of LinkedBlockingQueue<?Rune>)
                    let optCh = charQueue.remove()
                    match (optCh) {
                        case Some(ch) => buffer += ch.toString()
                        case None =>
                            sourceQueue.add(QueuedRuntimeEvent.Stop)
                            sourceQueue.add(QueuedRuntimeEvent.End)
                            return
                    }
                } else {
                    // Buffer has incomplete sequence (e.g. lone ESC).
                    // Wait briefly for more chars, then flush as standalone keys.
                    let escTimeoutMs: Int64 = 50
                    // charQueue.remove(timeout) returns ??Rune
                    let result = charQueue.remove(escTimeoutMs * Duration.millisecond)
                    match (result) {
                        case Some(optCh) =>
                            match (optCh) {
                                case Some(ch) => buffer += ch.toString()
                                case None =>
                                    // EOF: flush remaining buffer
                                    flushRemainingBuffer(parser, buffer, sourceQueue)
                                    sourceQueue.add(QueuedRuntimeEvent.End)
                                    return
                            }
                        case None =>
                            // Timeout: no more chars coming, flush ESC as standalone key
                            let flushed = forceFlushEsc(buffer)
                            if (flushed.consumed > 0) {
                                buffer = dropConsumedPrefix(buffer, flushed.consumed)
                                match (flushed.event) {
                                    case Some(RuntimeEvent.Stop) =>
                                        sourceQueue.add(QueuedRuntimeEvent.Stop)
                                        sourceQueue.add(QueuedRuntimeEvent.End)
                                        return
                                    case Some(event) =>
                                        sourceQueue.add(QueuedRuntimeEvent.Event(event))
                                    case None => ()
                                }
                            }
                    }
                }
            }
        }
    }
}

private func flushRemainingBuffer(
    parser: RawRuntimeEventParser,
    buffer: String,
    sourceQueue: LinkedBlockingQueue<QueuedRuntimeEvent>
): Unit {
    var remaining = buffer
    while (!remaining.isEmpty()) {
        let parsed = parser.nextFromBuffer(remaining + "\u{04}")
        if (parsed.consumed <= 0) {
            break
        }
        remaining = dropConsumedPrefix(remaining, parsed.consumed)
        match (parsed.event) {
            case Some(RuntimeEvent.Stop) => sourceQueue.add(QueuedRuntimeEvent.Stop)
            case Some(event) => sourceQueue.add(QueuedRuntimeEvent.Event(event))
            case None => ()
        }
    }
}

public class InteractiveRuntimeEventSource <: PollingRuntimeEventSource {
    private let rawSource: RuntimeEventSource
    private let sizeReader: TerminalSizeReader
    private let pollIntervalMillis: Int64
    private let queue = LinkedBlockingQueue<QueuedRuntimeEvent>()
    private let stopped = AtomicBool(false)
    private var started: Bool = false
    private var pendingEvent: ?QueuedRuntimeEvent = None

    public init() {
        this.rawSource = RawStdinRuntimeEventSource()
        this.sizeReader = NoopTerminalSizeReader()
        this.pollIntervalMillis = 0
    }

    public init(rawSource: RuntimeEventSource, sizeReader: TerminalSizeReader, pollIntervalMillis: Int64) {
        this.rawSource = rawSource
        this.sizeReader = sizeReader
        this.pollIntervalMillis = normalizePollInterval(pollIntervalMillis)
    }

    public func next(): ?RuntimeEvent {
        ensureStarted()
        match (takeQueuedEventBlocking()) {
            case QueuedRuntimeEvent.Event(event) => event
            case QueuedRuntimeEvent.Stop => resolveStopEvent()
            case QueuedRuntimeEvent.End =>
                stopped.store(true)
                None
        }
    }

    public func poll(timeoutMillis: Int64): RuntimeEventPollResult {
        ensureStarted()
        match (takeQueuedEvent(timeoutMillis)) {
            case Some(QueuedRuntimeEvent.Event(event)) => RuntimeEventPollResult.Event(event)
            case Some(QueuedRuntimeEvent.Stop) =>
                match (resolveStopEvent()) {
                    case Some(event) => RuntimeEventPollResult.Event(event)
                    case None => RuntimeEventPollResult.End
                }
            case Some(QueuedRuntimeEvent.End) =>
                stopped.store(true)
                RuntimeEventPollResult.End
            case None => RuntimeEventPollResult.Timeout
        }
    }

    private func ensureStarted(): Unit {
        if (started) {
            return
        }
        started = true

        let sourceQueue = queue
        let source = rawSource
        let stopSignal = stopped
        spawn {
            while (true) {
                match (source.next()) {
                    case Some(event) =>
                        match (event) {
                            case RuntimeEvent.Stop =>
                                sourceQueue.add(QueuedRuntimeEvent.Stop)
                                return
                            case _ => sourceQueue.add(QueuedRuntimeEvent.Event(event))
                        }
                    case None =>
                        stopSignal.store(true)
                        sourceQueue.add(QueuedRuntimeEvent.End)
                        return
                }
            }
        }

        if (pollIntervalMillis > 0) {
            let resizeQueue = queue
            let reader = sizeReader
            let intervalMillis = pollIntervalMillis
            let resizeStopSignal = stopped
            spawn {
                var lastSize = reader.read()
                var currentInterval = intervalMillis
                while (!resizeStopSignal.load()) {
                    sleep(currentInterval * Duration.millisecond)
                    if (resizeStopSignal.load()) {
                        return
                    }

                    let currentSize = reader.read()
                    match (currentSize) {
                        case Some(_) => currentInterval = intervalMillis
                        case None =>
                            // Backoff on failure to avoid rapid subprocess spawning
                            currentInterval = if (currentInterval < 5000) { currentInterval * 2 } else { 5000 }
                            continue
                    }
                    if (hasTerminalSizeChanged(lastSize, currentSize)) {
                        lastSize = currentSize
                        match (currentSize) {
                            case Some(size) => resizeQueue.add(QueuedRuntimeEvent.Event(RuntimeEvent.Resize(size.width, size.height)))
                            case None => ()
                        }
                    }
                }
            }
        }
    }

    private func takeQueuedEventBlocking(): QueuedRuntimeEvent {
        match (pendingEvent) {
            case Some(event) =>
                pendingEvent = None
                event
            case None => queue.remove()
        }
    }

    private func takeQueuedEvent(timeoutMillis: Int64): ?QueuedRuntimeEvent {
        match (pendingEvent) {
            case Some(event) =>
                pendingEvent = None
                Some(event)
            case None =>
                let timeout = if (timeoutMillis > 0) { timeoutMillis * Duration.millisecond } else { Duration.Zero }
                queue.remove(timeout)
        }
    }

    private func resolveStopEvent(): ?RuntimeEvent {
        match (queue.remove(stopDrainDurationMillis() * Duration.millisecond)) {
            case Some(QueuedRuntimeEvent.Event(event)) =>
                stopped.store(true)
                pendingEvent = QueuedRuntimeEvent.Event(RuntimeEvent.Stop)
                event
            case Some(QueuedRuntimeEvent.End) =>
                stopped.store(true)
                RuntimeEvent.Stop
            case Some(QueuedRuntimeEvent.Stop) =>
                stopped.store(true)
                RuntimeEvent.Stop
            case None =>
                stopped.store(true)
                RuntimeEvent.Stop
        }
    }

    private func stopDrainDurationMillis(): Int64 {
        let scaled = pollIntervalMillis * 5
        if (scaled >= 50) {
            return scaled
        }
        50
    }
}

private func normalizePollInterval(value: Int64): Int64 {
    if (value < 0) {
        return 100
    }
    value
}

private func hasTerminalSizeChanged(previous: ?TerminalSize, current: ?TerminalSize): Bool {
    match (previous) {
        case Some(left) => match (current) {
            case Some(right) => left.width != right.width || left.height != right.height
            case None => false
        }
        case None => match (current) {
            case Some(_) => true
            case None => false
        }
    }
}

public class MemoryFrameSink <: FrameSink {
    private var frames = ArrayList<String>()

    public init() {}

    public func write(frame: String): Unit {
        frames.add(frame)
    }

    public func allFrames(): Array<String> {
        Array<String>(frames.size, { index => frames[index] })
    }
}

public class StdoutFrameSink <: FrameSink {
    public init() {}

    public func write(frame: String): Unit {
        getStdOut().write(frame)
        getStdOut().flush()
    }
}

private func dropConsumedPrefix(text: String, consumed: Int64): String {
    if (consumed >= text.size) {
        return ""
    }
    text[consumed..text.size]
}
