import SwiftUI
import XCTest
@testable import ToastKit

final class ToastMetricsTests: XCTestCase {

    private let available: CGFloat = 400

    // MARK: - Regular

    func testRegularIsTodaysHardCodedSizing() {
        let regular = ToastMetrics.regular
        XCTAssertNil(regular.width)
        XCTAssertEqual(regular.contentPadding, EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        XCTAssertEqual(regular.titleFont, .callout.weight(.medium))
        XCTAssertEqual(regular.messageFont, .footnote)
        XCTAssertEqual(regular.glyphSide, 30)
        XCTAssertEqual(regular.glyphSpacing, 12)
        XCTAssertEqual(regular.textSpacing, 3)
        XCTAssertEqual(regular.cornerRadius, 22)
        XCTAssertEqual(regular.titleLineLimit, 2)
        XCTAssertEqual(regular.messageLineLimit, 2)
        XCTAssertEqual(regular.actionTrackScale, 1)
    }

    func testTheDefaultInitializerIsStillRegular() {
        XCTAssertEqual(ToastMetrics(), .regular)
    }

    func testRegularProgressSizesFollowThePlatform() {
        let expected: [(ToastPlatform, CGFloat, CGFloat)] = [
            (.iOS, 4, 28),
            (.macOS, 4, 22),
            (.watchOS, 4, 32),
            (.visionOS, 5, 32)
        ]
        for (platform, bar, side) in expected {
            XCTAssertEqual(platform.regularProgressBarHeight, bar, "\(platform) bar")
            XCTAssertEqual(platform.regularProgressButtonSide, side, "\(platform) button")
        }
        let regular = ToastMetrics.regular
        XCTAssertEqual(regular.progressBarHeight, ToastPlatform.current.regularProgressBarHeight)
        XCTAssertEqual(regular.progressButtonSide, ToastPlatform.current.regularProgressButtonSide)
        XCTAssertEqual(regular.progressSpacing, 8)
        XCTAssertEqual(regular.progressTitleLineLimit, 1)
        XCTAssertEqual(regular.progressDetailLineLimit, 1)
    }

    func testRegularIsTheEnvironmentDefault() {
        XCTAssertEqual(EnvironmentValues().toastMetrics, .regular)
    }

    func testRegularIsSixtyPercentEverywhereButTheWatch() {
        for platform in ToastPlatform.allCases where platform != .watchOS {
            XCTAssertEqual(ToastMetrics.regular.resolvedWidth(explicit: nil, on: platform), .fraction(0.6), "\(platform)")
        }
        XCTAssertEqual(ToastMetrics.regular.resolvedWidth(explicit: nil, on: .watchOS), .fraction(1))
    }

    // MARK: - Presets

    func testPresetWidthsFollowTheProposal() {
        let expected: [(ToastPlatform, ToastWidth, ToastWidth)] = [
            (.iOS, .fraction(0.5), .fraction(0.8)),
            (.macOS, .points(280), .points(480)),
            (.watchOS, .fraction(1), .fraction(1)),
            (.visionOS, .fraction(0.5), .fraction(0.7))
        ]
        for (platform, compact, large) in expected {
            XCTAssertEqual(ToastMetrics.compactTable(on: platform).width, compact, "\(platform) compact")
            XCTAssertEqual(ToastMetrics.largeTable(on: platform).width, large, "\(platform) large")
        }
    }

    func testPresetProgressSizesFollowTheProposal() {
        // bar height, title lines, detail lines
        let compact: [(ToastPlatform, CGFloat, Int, Int)] = [
            (.iOS, 3, 1, 1),
            (.macOS, 3, 1, 1),
            (.watchOS, 3, 1, 0),
            (.visionOS, 4, 1, 1)
        ]
        let large: [(ToastPlatform, CGFloat, Int, Int)] = [
            (.iOS, 6, 2, 1),
            (.macOS, 5, 2, 1),
            (.watchOS, 5, 2, 1),
            (.visionOS, 7, 2, 1)
        ]
        for (platform, bar, title, detail) in compact {
            let metrics = ToastMetrics.compactTable(on: platform)
            XCTAssertEqual(metrics.progressBarHeight, bar, "\(platform) compact bar")
            XCTAssertEqual(metrics.progressTitleLineLimit, title, "\(platform) compact title")
            XCTAssertEqual(metrics.progressDetailLineLimit, detail, "\(platform) compact detail")
        }
        for (platform, bar, title, detail) in large {
            let metrics = ToastMetrics.largeTable(on: platform)
            XCTAssertEqual(metrics.progressBarHeight, bar, "\(platform) large bar")
            XCTAssertEqual(metrics.progressTitleLineLimit, title, "\(platform) large title")
            XCTAssertEqual(metrics.progressDetailLineLimit, detail, "\(platform) large detail")
        }
    }

    func testPresetButtonsAndSpacingStayUniform() {
        for platform in ToastPlatform.allCases {
            for metrics in [ToastMetrics.compactTable(on: platform), ToastMetrics.largeTable(on: platform)] {
                XCTAssertEqual(metrics.progressButtonSide, platform.regularProgressButtonSide, "\(platform)")
                XCTAssertEqual(metrics.progressSpacing, 8, "\(platform)")
            }
        }
    }

    func testTheCompactWatchHidesTheDetailLine() {
        XCTAssertEqual(ToastMetrics.compactTable(on: .watchOS).progressDetailLineLimit, 0)
        XCTAssertEqual(ToastMetrics.largeTable(on: .watchOS).progressTitleLineLimit, 2)
    }

    func testPresetPaddingGlyphAndRadiusFollowTheProposal() {
        let compactIOS = ToastMetrics.compactTable(on: .iOS)
        XCTAssertEqual(compactIOS.contentPadding, EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        XCTAssertEqual(compactIOS.glyphSide, 24)
        XCTAssertEqual(compactIOS.glyphSpacing, 8)
        XCTAssertEqual(compactIOS.textSpacing, 2)
        XCTAssertEqual(compactIOS.cornerRadius, 16)

        let largeVision = ToastMetrics.largeTable(on: .visionOS)
        XCTAssertEqual(largeVision.contentPadding, EdgeInsets(top: 20, leading: 24, bottom: 20, trailing: 24))
        XCTAssertEqual(largeVision.glyphSide, 44)
        XCTAssertEqual(largeVision.glyphSpacing, 16)
        XCTAssertEqual(largeVision.cornerRadius, 32)

        let largeWatch = ToastMetrics.largeTable(on: .watchOS)
        XCTAssertEqual(largeWatch.titleFont, .headline)
        XCTAssertEqual(largeWatch.messageFont, .footnote)
        XCTAssertEqual(largeWatch.cornerRadius, 24)
    }

    func testPresetsStepUpInSizeOnEveryPlatform() {
        for platform in ToastPlatform.allCases {
            let compact = ToastMetrics.compactTable(on: platform)
            let large = ToastMetrics.largeTable(on: platform)
            XCTAssertLessThan(compact.glyphSide, ToastMetrics.regular.glyphSide, "\(platform)")
            XCTAssertGreaterThan(large.glyphSide, ToastMetrics.regular.glyphSide, "\(platform)")
            XCTAssertLessThan(compact.cornerRadius, ToastMetrics.regular.cornerRadius, "\(platform)")
            // macOS keeps today's 22 for large: its card is already rounded for its size.
            XCTAssertGreaterThanOrEqual(large.cornerRadius, ToastMetrics.regular.cornerRadius, "\(platform)")
            XCTAssertLessThan(compact.stackPeek, large.stackPeek, "\(platform)")
        }
    }

    func testTheTrackScalesWithThePreset() {
        for platform in ToastPlatform.allCases {
            XCTAssertLessThan(ToastMetrics.compactTable(on: platform).actionTrackScale, 1)
            XCTAssertGreaterThan(ToastMetrics.largeTable(on: platform).actionTrackScale, 1)
        }
    }

    func testEveryPresetClampsDynamicTypeAtAccessibility1() {
        XCTAssertEqual(ToastMetrics.regular.maximumDynamicTypeSize, .accessibility1)
        for platform in ToastPlatform.allCases {
            XCTAssertEqual(ToastMetrics.compactTable(on: platform).maximumDynamicTypeSize, .accessibility1)
            XCTAssertEqual(ToastMetrics.largeTable(on: platform).maximumDynamicTypeSize, .accessibility1)
        }
    }

    func testLargeAllowsMoreTextThanCompact() {
        let compact = ToastMetrics.compactTable(on: .iOS)
        let large = ToastMetrics.largeTable(on: .iOS)
        XCTAssertEqual(compact.titleLineLimit, 2)
        XCTAssertEqual(compact.messageLineLimit, 2)
        XCTAssertEqual(large.titleLineLimit, 3)
        XCTAssertEqual(large.messageLineLimit, 4)
    }

    // MARK: - Custom metrics

    func testCustomInitializerDefaultsToRegular() {
        XCTAssertEqual(ToastMetrics(), .regular)
        let custom = ToastMetrics(width: .fraction(0.8), cornerRadius: 12, messageLineLimit: nil)
        XCTAssertEqual(custom.width, .fraction(0.8))
        XCTAssertEqual(custom.cornerRadius, 12)
        XCTAssertNil(custom.messageLineLimit)
        XCTAssertEqual(custom.glyphSide, ToastMetrics.regular.glyphSide)
    }

    // MARK: - Width precedence

    func testExplicitWidthBeatsThePresetWidth() {
        for platform in ToastPlatform.allCases {
            let metrics = ToastMetrics.largeTable(on: platform)
            XCTAssertEqual(metrics.resolvedWidth(explicit: .points(320), on: platform), .points(320), "\(platform)")
        }
    }

    func testExplicitDefaultWidthStillBeatsThePresetWidth() {
        let metrics = ToastMetrics.largeTable(on: .watchOS)
        XCTAssertEqual(metrics.resolvedWidth(explicit: .default, on: .watchOS), .fraction(0.6))
    }

    func testPresetWidthBeatsThePlatformDefault() {
        let metrics = ToastMetrics.compactTable(on: .iOS)
        XCTAssertEqual(metrics.resolvedWidth(explicit: nil, on: .iOS), .fraction(0.5))
    }

    func testWidthFallsBackToTheMetricsThenThePlatform() {
        XCTAssertEqual(ToastMetrics(width: .points(300)).resolvedWidth(explicit: nil, on: .iOS), .points(300))
        XCTAssertEqual(ToastMetrics(width: nil).resolvedWidth(explicit: nil, on: .iOS), .default)
        XCTAssertEqual(ToastMetrics(width: nil).resolvedWidth(explicit: nil, on: .watchOS), .fraction(1))
    }

    func testResolvedWidthsMeasureAgainstTheSafeArea() {
        let compact = ToastMetrics.compactTable(on: .macOS).resolvedWidth(explicit: nil, on: .macOS)
        XCTAssertEqual(compact.resolved(in: available), 280)
        XCTAssertEqual(compact.resolved(in: 200), 200, "fixed widths clamp to the room there is")
    }

    // MARK: - Stack offset

    func testRegularPeeksFourteenPoints() {
        XCTAssertEqual(ToastMetrics.regular.stackPeek, 14)
    }

    func testPeekIsTheAverageOfTopAndBottomPadding() {
        let metrics = ToastMetrics(contentPadding: EdgeInsets(top: 10, leading: 40, bottom: 20, trailing: 40))
        XCTAssertEqual(metrics.stackPeek, 15)
    }

    func testPeekFollowsEachPresetsPadding() {
        XCTAssertEqual(ToastMetrics.compactTable(on: .iOS).stackPeek, 10)
        XCTAssertEqual(ToastMetrics.largeTable(on: .iOS).stackPeek, 18)
        XCTAssertEqual(ToastMetrics.compactTable(on: .watchOS).stackPeek, 8)
    }

    // MARK: - Theme overrides

    func testAThemeThatSetsNothingLeavesTheMetricsAlone() {
        let metrics = ToastMetrics.largeTable(on: .iOS)
        XCTAssertEqual(metrics.resolved(in: ToastTheme()), metrics)
    }

    func testValuesSetOnAThemeBeatThePreset() {
        let theme = ToastTheme(
            titleFont: .headline,
            cornerRadius: 14,
            contentPadding: EdgeInsets(top: 6, leading: 6, bottom: 8, trailing: 6)
        )
        let resolved = ToastMetrics.largeTable(on: .iOS).resolved(in: theme)
        XCTAssertEqual(resolved.titleFont, .headline)
        XCTAssertEqual(resolved.cornerRadius, 14)
        XCTAssertEqual(resolved.contentPadding.top, 6)
        XCTAssertEqual(ToastMetrics.largeTable(on: .iOS).stackPeek, 18, "the stack offset is the preset's, not the theme's")
        XCTAssertEqual(resolved.messageFont, ToastMetrics.largeTable(on: .iOS).messageFont, "unset tokens defer")
    }

    func testThemeTokensStillReadTheirOldDefaults() {
        let theme = ToastTheme()
        XCTAssertEqual(theme.titleFont, .callout.weight(.medium))
        XCTAssertEqual(theme.messageFont, .footnote)
        XCTAssertEqual(theme.cornerRadius, 22)
        XCTAssertEqual(theme.contentPadding, EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
    }
}
