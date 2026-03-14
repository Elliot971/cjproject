package cjrxtui.component

import std.collection.ArrayList

public class Context {
    private let _componentId: ComponentId
    private var _firstRender: Bool = true
    private var _focusRequest: ?String = None
    private var _messages = ArrayList<Message>()
    private var _topicMessages = ArrayList<TopicEnvelope>()

    public init(componentId: ComponentId) {
        _componentId = componentId
    }

    public prop componentId: ComponentId {
        get() {
            _componentId
        }
    }

    public func isFirstRender(): Bool {
        _firstRender
    }

    public func markRendered(): Unit {
        _firstRender = false
    }

    public func send(message: Message): Unit {
        _messages.add(message)
    }

    public func sendToTopic(topic: String, message: Message): Unit {
        _topicMessages.add(TopicEnvelope(topic, message))
    }

    public func drainMessages(): ArrayList<Message> {
        let drained = _messages
        _messages = ArrayList<Message>()
        drained
    }

    public func drainTopicMessages(): ArrayList<TopicEnvelope> {
        let drained = _topicMessages
        _topicMessages = ArrayList<TopicEnvelope>()
        drained
    }

    public func focus(nodeId: String): Unit {
        _focusRequest = nodeId
    }

    public func takeFocusRequest(): ?String {
        let request = _focusRequest
        _focusRequest = None
        request
    }
}
