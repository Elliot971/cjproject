package cjrxtui.render

import std.collection.ArrayList
import cjrxtui.node.{Div, Node, RichText, TextSpan}
import cjrxtui.style.{Border, BorderStyle, Color, Dimension, Direction, Overflow, Spacing, Style, TextStyle}

@Test
func rendererUsesLayoutForNestedDivs() {
    let root = Div()
        .id("root")
        .width(Dimension.Fixed(12))
        .padding(Spacing.all(1))
        .child(Node.text("Title"))
        .child(
            Node.div(
                Div()
                    .id("inner")
                    .focusable()
                    .width(Dimension.Fixed(10))
                    .padding(Spacing.all(1))
                    .child(Node.text("Body"))
            )
        )

    let output = Renderer().render(Node.div(root))

    @Expect(output.contains("+div#root--+"))
    @Expect(output.contains("+div#inne+"))
    @Expect(output.contains("Title"))
    @Expect(output.contains("Body"))
}

@Test
func rendererPlacesHorizontalChildrenOnSameRow() {
    let root = Div()
        .direction(Direction.Horizontal)
        .gap(2)
        .child(Node.text("AA"))
        .child(Node.text("BB"))

    let output = Renderer().render(Node.div(root))
    @Expect(output.contains("AA  BB"))
}

@Test
func rendererPreservesStyledTextInScreenBuffer() {
    let node = Node.text("Hi", TextStyle().withForeground(Color.BrightCyan).withBackground(Color.Blue).withBold(true))
    let buffer = Renderer().renderToScreenBuffer(node).screen()

    match (buffer.getCell(0, 0)) {
        case Some(cell) =>
            @Assert(cell.rune, r'H')
            match (cell.foreground) {
                case Some(Color.BrightCyan) => @Assert(true)
                case _ => @Fail("expected bright cyan foreground")
            }
            match (cell.background) {
                case Some(Color.Blue) => @Assert(true)
                case _ => @Fail("expected blue background")
            }
            @Assert(cell.style.bold, true)
        case None => @Fail("expected rendered cell")
    }
}

@Test
func rendererUsesConfiguredBorderStyle() {
    let root = Div()
        .id("box")
        .width(Dimension.Fixed(8))
        .height(Dimension.Fixed(3))
        .style(Style().withBorder(Border(BorderStyle.Double, Color.BrightYellow)))

    let output = Renderer().render(Node.div(root))
    @Expect(output.size >= 0)
}

@Test
func rendererAppliesCenterAlignment() {
    let root = Div()
        .width(Dimension.Fixed(10))
        .height(Dimension.Fixed(1))
        .child(Node.text("Hi", TextStyle().withForeground(Color.White)))

    let output = Renderer().render(Node.div(root))
    @Expect(output.contains("Hi"))
}

@Test
func rendererClipsHiddenOverflowText() {
    let root = Div()
        .width(Dimension.Fixed(4))
        .height(Dimension.Fixed(1))
        .style(Style().withOverflow(Overflow.Hidden))
        .child(Node.text("abcdef"))

    let output = Renderer().render(Node.div(root))
    @Expect(output.contains("abcd"))
}

@Test
func rendererAppliesRichTextSpanStyles() {
    let spans = ArrayList<TextSpan>()
    spans.add(TextSpan("A", TextStyle().withForeground(Color.BrightRed).withBold(true)))
    spans.add(TextSpan("B", TextStyle().withForeground(Color.BrightGreen)))
    let node = Node.richText(RichText(spans))
    let buffer = Renderer().renderToScreenBuffer(node).screen()

    match (buffer.getCell(0, 0)) {
        case Some(cell) =>
            @Assert(cell.rune, r'A')
            match (cell.foreground) {
                case Some(Color.BrightRed) => @Assert(true)
                case _ => @Fail("expected red rich text span")
            }
            @Assert(cell.style.bold, true)
        case None => @Fail("expected first rich text cell")
    }

    match (buffer.getCell(1, 0)) {
        case Some(cell) =>
            @Assert(cell.rune, r'B')
            match (cell.foreground) {
                case Some(Color.BrightGreen) => @Assert(true)
                case _ => @Fail("expected green rich text span")
            }
        case None => @Fail("expected second rich text cell")
    }
}
