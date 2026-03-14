package cjrxtui.component

import cjrxtui.node.Node

public interface Message {}

public interface State {}

public struct ComponentId <: ToString {
    public let path: String

    public init(path: String) {
        this.path = path
    }

    public static func root(): ComponentId {
        ComponentId("0")
    }

    public func child(index: Int64): ComponentId {
        ComponentId(path + "." + index.toString())
    }

    public func toString(): String {
        path
    }
}

public struct TopicEnvelope {
    public let topic: String
    public let message: Message

    public init(topic: String, message: Message) {
        this.topic = topic
        this.message = message
    }
}

public interface EffectSink {
    func send(message: Message): Unit
    func sendToTopic(topic: String, message: Message): Unit
}

public class EffectDispatcher {
    private let sink: EffectSink

    public init(sink: EffectSink) {
        this.sink = sink
    }

    public func send(message: Message): Unit {
        sink.send(message)
    }

    public func sendToTopic(topic: String, message: Message): Unit {
        sink.sendToTopic(topic, message)
    }
}

public interface Effect {
    func run(dispatcher: EffectDispatcher): Unit
}

private class ImmediateEffect <: Effect {
    private let message: Message

    public init(message: Message) {
        this.message = message
    }

    public func run(dispatcher: EffectDispatcher): Unit {
        dispatcher.send(message)
    }
}

private class TopicImmediateEffect <: Effect {
    private let topic: String
    private let message: Message

    public init(topic: String, message: Message) {
        this.topic = topic
        this.message = message
    }

    public func run(dispatcher: EffectDispatcher): Unit {
        dispatcher.sendToTopic(topic, message)
    }
}

private class DelayedEffect <: Effect {
    private let delayMillis: Int64
    private let message: Message

    public init(delayMillis: Int64, message: Message) {
        this.delayMillis = delayMillis
        this.message = message
    }

    public func run(dispatcher: EffectDispatcher): Unit {
        sleep(delayMillis * Duration.millisecond)
        dispatcher.send(message)
    }
}

private class TopicDelayedEffect <: Effect {
    private let delayMillis: Int64
    private let topic: String
    private let message: Message

    public init(delayMillis: Int64, topic: String, message: Message) {
        this.delayMillis = delayMillis
        this.topic = topic
        this.message = message
    }

    public func run(dispatcher: EffectDispatcher): Unit {
        sleep(delayMillis * Duration.millisecond)
        dispatcher.sendToTopic(topic, message)
    }
}

private class IntervalEffect <: Effect {
    private let intervalMillis: Int64
    private let repeatCount: Int64
    private let message: Message

    public init(intervalMillis: Int64, repeatCount: Int64, message: Message) {
        this.intervalMillis = intervalMillis
        this.repeatCount = repeatCount
        this.message = message
    }

    public func run(dispatcher: EffectDispatcher): Unit {
        var emitted = Int64(0)
        while (repeatCount < 0 || emitted < repeatCount) {
            sleep(intervalMillis * Duration.millisecond)
            dispatcher.send(message)
            emitted += 1
        }
    }
}

private class BatchedEffect <: Effect {
    private let effects: Array<Effect>

    public init(effects: Array<Effect>) {
        this.effects = effects
    }

    public func run(dispatcher: EffectDispatcher): Unit {
        for (effect in effects) {
            effect.run(dispatcher)
        }
    }
}

public class Effects {
    public static func send(message: Message): Effect {
        ImmediateEffect(message)
    }

    public static func sendToTopic(topic: String, message: Message): Effect {
        TopicImmediateEffect(topic, message)
    }

    public static func delay(delayMillis: Int64, message: Message): Effect {
        DelayedEffect(delayMillis, message)
    }

    public static func delayToTopic(delayMillis: Int64, topic: String, message: Message): Effect {
        TopicDelayedEffect(delayMillis, topic, message)
    }

    public static func interval(intervalMillis: Int64, repeatCount: Int64, message: Message): Effect {
        IntervalEffect(intervalMillis, repeatCount, message)
    }

    public static func batch(effects: Array<Effect>): Effect {
        BatchedEffect(effects)
    }
}

public enum Action {
    | Update(State)
    | UpdateTopic(String, State)
    | Command(Message)
    | CommandTopic(String, Message)
    | RunEffect(Effect)
    | Batch(Array<Action>)
    | DoNothing
    | Exit

    public static func update(state: State): Action {
        Action.Update(state)
    }

    public static func updateTopic(topic: String, state: State): Action {
        Action.UpdateTopic(topic, state)
    }

    public static func none(): Action {
        Action.DoNothing
    }

    public static func command(message: Message): Action {
        Action.Command(message)
    }

    public static func commandTopic(topic: String, message: Message): Action {
        Action.CommandTopic(topic, message)
    }

    public static func effect(effect: Effect): Action {
        Action.RunEffect(effect)
    }

    public static func batch(actions: Array<Action>): Action {
        Action.Batch(actions)
    }

    public static func exit(): Action {
        Action.Exit
    }
}

public interface Component {
    func update(ctx: Context, msg: Message, state: State): Action {
        let _ = ctx
        let _ = msg
        let _ = state
        Action.none()
    }

    func view(ctx: Context, state: State): Node
}
