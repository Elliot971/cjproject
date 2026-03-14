package cjrxtui.render

import cjrxtui.node.{Div, Node}
import cjrxtui.style.Dimension

@Test
func framePipelineProducesInitialUpdates() {
    let pipeline = FramePipeline(12, 4)
    let node = Node.div(
        Div()
            .width(Dimension.Fixed(8))
            .child(Node.text("Hello"))
    )

    let result = pipeline.renderFrame(node)
    @Expect(result.updates.size > 0)
    @Expect(result.frame.contains("Hello"))
}

@Test
func framePipelineSkipsUnchangedFrame() {
    let pipeline = FramePipeline(12, 4)
    let node = Node.div(
        Div()
            .width(Dimension.Fixed(8))
            .child(Node.text("Hello"))
    )

    let first = pipeline.renderFrame(node)
    let second = pipeline.renderFrame(node)

    @Expect(first.updates.size > 0)
    @Assert(second.updates.size, 0)
}
