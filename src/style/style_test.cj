package cjrxtui.style

@Test
func spacingFactoriesWork() {
    let all = Spacing.all(2)
    @Assert(all.top, 2)
    @Assert(all.right, 2)
    @Assert(all.bottom, 2)
    @Assert(all.left, 2)

    let symmetric = Spacing.symmetric(3, 1)
    @Assert(symmetric.top, 1)
    @Assert(symmetric.right, 3)
    @Assert(symmetric.bottom, 1)
    @Assert(symmetric.left, 3)
}
