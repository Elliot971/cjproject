package cjrxtui.app

import cjrxtui.component.{Component, Message, State}
import cjrxtui.terminal.{SttyTerminalModeController, SttyTerminalSizeReader, TerminalModeController, TerminalSizeReader}

public class AppSession {
    private let runtime: AppRuntime

    public init(root: Component, initialState: State) {
        runtime = AppRuntime(root, initialState)
    }

    public func send(message: Message): Unit {
        runtime.send(message)
    }

    public func currentState(): State {
        runtime.currentState()
    }

    public func render(): String {
        runtime.bootFrame().frame
    }
}

public class App {
    public static func createSession(root: Component, initialState: State): AppSession {
        AppSession(root, initialState)
    }

    public static func createRuntime(root: Component, initialState: State): AppRuntime {
        AppRuntime(root, initialState)
    }

    public static func createRuntime(root: Component, initialState: State, config: RuntimeConfig): AppRuntime {
        AppRuntime(root, initialState, config)
    }

    public static func createInteractiveRuntime(root: Component, initialState: State): AppRuntime {
        createInteractiveRuntime(root, initialState, 80, 24, SttyTerminalSizeReader())
    }

    public static func createInteractiveRuntime(root: Component, initialState: State, width: Int64, height: Int64): AppRuntime {
        createInteractiveRuntime(root, initialState, width, height, SttyTerminalSizeReader())
    }

    public static func createRunner(): AppRunner {
        AppRunner()
    }

    public static func createRunner(modeController: TerminalModeController): AppRunner {
        AppRunner(modeController)
    }

    public static func createInteractiveRunner(): AppRunner {
        AppRunner(SttyTerminalModeController())
    }

    public static func runInteractive(root: Component, initialState: State): Unit {
        let runtime = createInteractiveRuntime(root, initialState)
        let runner = createInteractiveRunner()
        runner.run(runtime, InteractiveRuntimeEventSource(RawStdinRuntimeEventSource(), SttyTerminalSizeReader(), 1000), StdoutFrameSink())
    }

    public static func runInteractive(root: Component, initialState: State, width: Int64, height: Int64): Unit {
        let runtime = createInteractiveRuntime(root, initialState, width, height)
        let runner = createInteractiveRunner()
        runner.run(runtime, InteractiveRuntimeEventSource(RawStdinRuntimeEventSource(), SttyTerminalSizeReader(), 1000), StdoutFrameSink())
    }

    public static func runInline(root: Component, initialState: State, width: Int64, height: Int64): Unit {
        let runtime = AppRuntime(root, initialState, RuntimeConfig.inline(width, height))
        let runner = createInteractiveRunner()
        runner.run(runtime, InteractiveRuntimeEventSource(RawStdinRuntimeEventSource(), SttyTerminalSizeReader(), 1000), StdoutFrameSink())
    }

    static func createInteractiveRuntime(
        root: Component,
        initialState: State,
        fallbackWidth: Int64,
        fallbackHeight: Int64,
        sizeReader: TerminalSizeReader
    ): AppRuntime {
        AppRuntime(root, initialState, interactiveRuntimeConfig(fallbackWidth, fallbackHeight, sizeReader))
    }
}

func interactiveRuntimeConfig(fallbackWidth: Int64, fallbackHeight: Int64, sizeReader: TerminalSizeReader): RuntimeConfig {
    match (sizeReader.read()) {
        case Some(size) => RuntimeConfig(size.width, size.height, true, true)
        case None => RuntimeConfig(fallbackWidth, fallbackHeight, true, true)
    }
}
