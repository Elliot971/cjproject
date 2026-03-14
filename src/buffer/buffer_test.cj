package cjrxtui.buffer

@Test
func setAndGetCellWorks() {
    let buffer = ScreenBuffer(4, 2)
    buffer.setCell(1, 0, Cell(r'X'))

    match (buffer.getCell(1, 0)) {
        case Some(cell) => @Assert(cell.rune, r'X')
        case None => @Fail("expected cell at 1,0")
    }
}

@Test
func fillRectFillsExpectedArea() {
    let buffer = ScreenBuffer(5, 3)
    buffer.fillRect(1, 1, 2, 1, Cell(r'#'))

    match (buffer.getCell(1, 1)) {
        case Some(cell) => @Assert(cell.rune, r'#')
        case None => @Fail("expected filled cell at 1,1")
    }

    match (buffer.getCell(2, 1)) {
        case Some(cell) => @Assert(cell.rune, r'#')
        case None => @Fail("expected filled cell at 2,1")
    }

    match (buffer.getCell(0, 1)) {
        case Some(cell) => @Assert(cell.rune, r' ')
        case None => @Fail("expected cell at 0,1")
    }
}

@Test
func writeTextWritesAcrossRows() {
    let buffer = ScreenBuffer(5, 3)
    buffer.writeText(1, 0, "AB\nCD")

    @Assert(buffer.toString(), " AB\n CD\n")
}

@Test
func doubleBufferDiffTracksChanges() {
    let buffers = DoubleBuffer(4, 2)
    let firstDiff = buffers.diff()
    @Assert(firstDiff.size, 0)

    buffers.backBuffer().setCell(1, 0, Cell(r'A'))
    let secondDiff = buffers.diff()
    @Assert(secondDiff.size, 1)

    buffers.swap()
    buffers.clearBack()
    buffers.backBuffer().setCell(1, 0, Cell(r'A'))
    let thirdDiff = buffers.diff()
    @Assert(thirdDiff.size, 0)
}
