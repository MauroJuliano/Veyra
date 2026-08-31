import Testing
@testable import Veyra

struct DesignTokenTests {
    @Test
    func spacingScaleIsStrictlyIncreasing() {
        let scale = [
            VeyraSpacing.xxs,
            VeyraSpacing.xs,
            VeyraSpacing.sm,
            VeyraSpacing.md,
            VeyraSpacing.lg,
            VeyraSpacing.xl,
            VeyraSpacing.xxl
        ]

        #expect(zip(scale, scale.dropFirst()).allSatisfy(<))
    }

    @Test
    func avatarSizesAreStrictlyIncreasing() {
        let sizes = [
            VeyraAvatarSize.small.dimension,
            VeyraAvatarSize.medium.dimension,
            VeyraAvatarSize.large.dimension
        ]

        #expect(zip(sizes, sizes.dropFirst()).allSatisfy(<))
    }
}
