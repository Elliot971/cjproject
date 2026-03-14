package cjrxtui.layout

import cjrxtui.node.{Div, Node}
import cjrxtui.style.{Alignment, Dimension, Direction, JustifyContent, Spacing}

@Test
func textNodeHasContentSize() {
    let engine = LayoutEngine()
    let layout = engine.layout(Node.text("hello"))

    @Assert(layout.frame.width, 5)
    @Assert(layout.frame.height, 1)
}

@Test
func verticalDivRespectsPaddingAndGap() {
    let engine = LayoutEngine()
    let root = Div()
        .padding(Spacing.all(1))
        .gap(1)
        .child(Node.text("ab"))
        .child(Node.text("c"))

    let layout = engine.layout(Node.div(root))
    @Assert(layout.frame.width, 4)
    @Assert(layout.frame.height, 5)
    @Assert(layout.childrenView[0].frame.x, 1)
    @Assert(layout.childrenView[0].frame.y, 1)
    @Assert(layout.childrenView[1].frame.x, 1)
    @Assert(layout.childrenView[1].frame.y, 3)
}

@Test
func horizontalDivStacksChildrenAcrossMainAxis() {
    let engine = LayoutEngine()
    let root = Div()
        .direction(Direction.Horizontal)
        .padding(Spacing.all(1))
        .gap(2)
        .child(Node.text("aa"))
        .child(Node.text("bbb"))

    let layout = engine.layout(Node.div(root))
    @Assert(layout.frame.width, 9)
    @Assert(layout.frame.height, 3)
    @Assert(layout.childrenView[0].frame.x, 1)
    @Assert(layout.childrenView[1].frame.x, 5)
}

@Test
func fixedDimensionsOverrideContentSize() {
    let engine = LayoutEngine()
    let root = Div()
        .width(Dimension.Fixed(20))
        .height(Dimension.Fixed(4))
        .child(Node.text("small"))

    let layout = engine.layout(Node.div(root))
    @Assert(layout.frame.width, 20)
    @Assert(layout.frame.height, 4)
}

@Test
func deepestFocusableAtPrefersDeepestNodeWithId() {
    let engine = LayoutEngine()
    let root = Div()
        .width(Dimension.Fixed(12))
        .height(Dimension.Fixed(6))
        .id("outer")
        .focusable()
        .child(
            Node.div(
                Div()
                    .width(Dimension.Fixed(6))
                    .height(Dimension.Fixed(2))
                    .id("inner")
                    .focusable()
                    .child(Node.text("hit"))
            )
        )

    let layout = engine.layout(Node.div(root))
    match (layout.deepestFocusableAt(1, 0)) {
        case Some(target) => match (target.nodeId) {
            case Some(nodeId) => @Assert(nodeId, "inner")
            case None => @Fail("expected node id")
        }
        case None => @Fail("expected focusable target")
    }
}

@Test
func deepestFocusableAtFallsBackToAncestorWhenChildHasNoId() {
    let engine = LayoutEngine()
    let root = Div()
        .width(Dimension.Fixed(12))
        .height(Dimension.Fixed(6))
        .id("outer")
        .focusable()
        .child(
            Node.div(
                Div()
                    .width(Dimension.Fixed(6))
                    .height(Dimension.Fixed(2))
                    .focusable()
                    .child(Node.text("hit"))
            )
        )

    let layout = engine.layout(Node.div(root))
    match (layout.deepestFocusableAt(1, 0)) {
        case Some(target) => match (target.nodeId) {
            case Some(nodeId) => @Assert(nodeId, "outer")
            case None => @Fail("expected ancestor node id")
        }
        case None => @Fail("expected ancestor focus target")
    }
}

@Test
func marginAddsSpaceAroundChild() {
    let engine = LayoutEngine()
    let root = Div()
        .child(
            Node.div(
                Div()
                    .margin(Spacing(1, 2, 1, 2))
                    .child(Node.text("hi"))
            )
        )

    let layout = engine.layout(Node.div(root))
    // "hi" is 2 wide, 1 tall; margin adds 2+2=4 horizontal, 1+1=2 vertical
    @Assert(layout.frame.width, 6)
    @Assert(layout.frame.height, 3)
    // child border box at (2, 1)
    let child = layout.childrenView[0]
    @Assert(child.frame.x, 2)
    @Assert(child.frame.y, 1)
    @Assert(child.frame.width, 2)
    @Assert(child.frame.height, 1)
}

@Test
func alignItemsCenterPositionsChildInCrossAxis() {
    let engine = LayoutEngine()
    let root = Div()
        .width(Dimension.Fixed(20))
        .height(Dimension.Fixed(5))
        .alignItems(Alignment.Center)
        .child(Node.text("hi"))

    let layout = engine.layout(Node.div(root))
    // Vertical direction: cross axis is horizontal. "hi" is 2 wide, container is 20.
    // Center offset = (20 - 2) / 2 = 9; padding.left = 0 so x = 0 + 9 = 9
    let child = layout.childrenView[0]
    @Assert(child.frame.x, 9)
    @Assert(child.frame.y, 0)
}

@Test
func alignItemsEndPositionsChildAtCrossEnd() {
    let engine = LayoutEngine()
    let root = Div()
        .width(Dimension.Fixed(20))
        .height(Dimension.Fixed(5))
        .alignItems(Alignment.End)
        .child(Node.text("hi"))

    let layout = engine.layout(Node.div(root))
    let child = layout.childrenView[0]
    // End offset = 20 - 2 = 18
    @Assert(child.frame.x, 18)
}

@Test
func justifyContentCenterPositionsChildrenInMainAxis() {
    let engine = LayoutEngine()
    let root = Div()
        .width(Dimension.Fixed(10))
        .height(Dimension.Fixed(10))
        .justifyContent(JustifyContent.Center)
        .child(Node.text("a"))
        .child(Node.text("b"))

    let layout = engine.layout(Node.div(root))
    // Vertical direction: 2 children each 1 tall = 2; free = 10 - 2 = 8; offset = 4
    let first = layout.childrenView[0]
    let second = layout.childrenView[1]
    @Assert(first.frame.y, 4)
    @Assert(second.frame.y, 5)
}

@Test
func justifyContentSpaceBetweenDistributesEvenly() {
    let engine = LayoutEngine()
    let root = Div()
        .width(Dimension.Fixed(5))
        .height(Dimension.Fixed(10))
        .justifyContent(JustifyContent.SpaceBetween)
        .child(Node.text("a"))
        .child(Node.text("b"))

    let layout = engine.layout(Node.div(root))
    // 2 children each 1 tall, free = 10 - 2 = 8, extraGap = 8 / 1 = 8
    let first = layout.childrenView[0]
    let second = layout.childrenView[1]
    @Assert(first.frame.y, 0)
    @Assert(second.frame.y, 9)  // 0 + 1 + 0(gap) + 8(extra) = 9
}

@Test
func horizontalAlignItemsCenterPositionsVertically() {
    let engine = LayoutEngine()
    let root = Div()
        .direction(Direction.Horizontal)
        .width(Dimension.Fixed(20))
        .height(Dimension.Fixed(6))
        .alignItems(Alignment.Center)
        .child(Node.text("x"))

    let layout = engine.layout(Node.div(root))
    // Horizontal direction: cross axis is vertical. "x" is 1 tall, container is 6.
    // Center offset = (6 - 1) / 2 = 2
    let child = layout.childrenView[0]
    @Assert(child.frame.y, 2)
    @Assert(child.frame.x, 0)
}
