package cjrxtui.component

public struct KeyModifiers {
    public let ctrl: Bool
    public let alt: Bool
    public let shift: Bool
    public let meta: Bool

    public init() {
        this.ctrl = false
        this.alt = false
        this.shift = false
        this.meta = false
    }

    public init(ctrl: Bool, alt: Bool, shift: Bool, meta: Bool) {
        this.ctrl = ctrl
        this.alt = alt
        this.shift = shift
        this.meta = meta
    }
}

public enum KeyCode {
    | Named(String)
    | Char(Rune)
    | Enter
    | Esc
    | Backspace
    | Tab
    | BackTab
    | Up
    | Down
    | Left
    | Right
    | Home
    | End
    | PageUp
    | PageDown
    | Insert
    | Delete
    | Function(Int64)
}

public struct KeyEvent {
    public let code: KeyCode
    public let modifiers: KeyModifiers

    public init(code: KeyCode) {
        this.code = code
        this.modifiers = KeyModifiers()
    }

    public init(code: KeyCode, modifiers: KeyModifiers) {
        this.code = code
        this.modifiers = modifiers
    }
}

public enum MouseButton {
    | Left
    | Right
    | Middle
}

public enum MouseEventKind {
    | Down(MouseButton)
    | Up(MouseButton)
    | Move
    | Drag(MouseButton)
    | ScrollUp
    | ScrollDown
}

public struct MouseEvent {
    public let x: Int64
    public let y: Int64
    public let kind: MouseEventKind
    public let modifiers: KeyModifiers

    public init(x: Int64, y: Int64, kind: MouseEventKind) {
        this.x = x
        this.y = y
        this.kind = kind
        this.modifiers = KeyModifiers()
    }

    public init(x: Int64, y: Int64, kind: MouseEventKind, modifiers: KeyModifiers) {
        this.x = x
        this.y = y
        this.kind = kind
        this.modifiers = modifiers
    }
}

public struct ResizeEvent {
    public let width: Int64
    public let height: Int64

    public init(width: Int64, height: Int64) {
        this.width = width
        this.height = height
    }
}

public enum UiEvent <: Message {
    | Tick
    | Exit
    | Key(KeyEvent)
    | Mouse(MouseEvent)
    | Click(String, MouseEvent)
    | Resize(ResizeEvent)
    | Focus(String)
    | Blur(String)
    | HoverEnter(String)
    | HoverLeave(String)
}
