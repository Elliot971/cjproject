package cjrxtui.terminal

import cjrxtui.buffer.{Cell, CellUpdate}
import cjrxtui.style.Color

@Test
func rendererBuildsCursorAndPrintCommands() {
    let renderer = TerminalRenderer()
    let updates = [CellUpdate.Single(2, 1, Cell(r'A'))]

    let commands = renderer.buildCommands(updates)
    @Assert(commands.size, 2)

    match (commands[0]) {
        case TerminalCommand.MoveTo(x, y) => @Assert(x == 2 && y == 1)
        case _ => @Fail("expected move command")
    }

    match (commands[1]) {
        case TerminalCommand.Print(text) => @Assert(text, "A")
        case _ => @Fail("expected print command")
    }
}

@Test
func rendererOutputsAnsiForStyledCell() {
    let renderer = TerminalRenderer()
    let styled = Cell(r'Z').withForeground(Color.Red).withBackground(Color.Black)
    let ansi = renderer.renderToAnsi([CellUpdate.Single(0, 0, styled)])

    @Expect(ansi.contains("\u{1b}[1;1H"))
    @Expect(ansi.contains("\u{1b}[31m"))
    @Expect(ansi.contains("\u{1b}[40m"))
    @Expect(ansi.contains("Z"))
}

@Test
func rendererAvoidsRepeatedMoveWhenCellsAreAdjacent() {
    let renderer = TerminalRenderer()
    let updates = [CellUpdate.Single(0, 0, Cell(r'A')), CellUpdate.Single(1, 0, Cell(r'B'))]
    let commands = renderer.buildCommands(updates)

    var moveCount = 0
    for (command in commands) {
        match (command) {
            case TerminalCommand.MoveTo(_, _) => moveCount += 1
            case _ => ()
        }
    }

    @Assert(moveCount, 1)
}

@Test
func noopTerminalModeControllerLeavesModeCanonical() {
    let controller = NoopTerminalModeController()

    controller.enterRawMode()
    match (controller.currentMode()) {
        case TerminalInputMode.Canonical => @Assert(true)
        case _ => @Fail("expected noop controller to stay canonical")
    }

    controller.restoreMode()
    match (controller.currentMode()) {
        case TerminalInputMode.Canonical => @Assert(true)
        case _ => @Fail("expected noop controller to stay canonical")
    }
}

@Test
func rendererProvidesMouseCaptureAnsiSequences() {
    let renderer = TerminalRenderer()

    @Assert(renderer.enableMouseCaptureAnsi(), "\u{1b}[?1003h\u{1b}[?1006h")
    @Assert(renderer.disableMouseCaptureAnsi(), "\u{1b}[?1006l\u{1b}[?1003l")
}

@Test
func noopTerminalSizeReaderReturnsNone() {
    let reader = NoopTerminalSizeReader()

    match (reader.read()) {
        case None => @Assert(true)
        case _ => @Fail("expected noop size reader to return none")
    }
}
