import CoreGraphics
import NotebookCore
import Testing

@testable import Paper

struct PaperLayoutTests {
    func mm(_ millimetres: Double) -> Double { PageSize.points(millimetres: millimetres) }

    func layout(_ type: PaperType, color: PaperColor = .ivory, size: PageSize = .a5) -> PaperLayout {
        PaperLayout(paper: Paper(type: type, color: color), size: size)
    }

    @Test func backgroundIsThePaperColour() {
        #expect(layout(.blank, color: .canary).background == PaperColor.canary.hex)
    }

    @Test func blankHasNoMarks() {
        let blank = layout(.blank)
        #expect(blank.lines.isEmpty && blank.dots.isEmpty)
    }

    @Test func fineLinedRulesAre6mmApartAndInset() throws {
        let rules = layout(.fineLined).lines
        #expect(!rules.isEmpty)
        #expect(rules.allSatisfy { $0.start.y == $0.end.y })
        let first = try #require(rules.first)
        #expect(abs(first.start.y - mm(18)) < 0.001)
        #expect(abs(first.start.x - mm(10)) < 0.001)
        #expect(abs(rules[1].start.y - rules[0].start.y - mm(6)) < 0.001)
        #expect(rules.allSatisfy { $0.start.y < PageSize.a5.height })
    }

    @Test func classicLinedHasARedMarginAt32mm() {
        let verticals = layout(.classicLined).lines.filter { $0.start.x == $0.end.x }
        #expect(verticals.count == 1)
        #expect(abs((verticals.first?.start.x ?? 0) - mm(32)) < 0.001)
        #expect(verticals.first?.color == PaperLayout.marginRed)
    }

    @Test func legalPadHasADoubleMargin() {
        let verticals = layout(.legal, color: .canary).lines.filter { $0.start.x == $0.end.x }
        #expect(verticals.count == 2)
    }

    @Test func dotGridDotsAre5mmApartAcrossThePage() {
        let dots = layout(.dotGrid).dots
        let columns = Int(PageSize.a5.width / mm(5))
        let rows = Int(PageSize.a5.height / mm(5))
        #expect(abs(dots.count - columns * rows) <= columns + rows)
        let firstRow = dots.filter { abs($0.center.y - dots[0].center.y) < 0.001 }
        #expect(abs(firstRow[1].center.x - firstRow[0].center.x - mm(5)) < 0.001)
    }

    @Test func engineeringBoldsEveryFifthLine() {
        let lines = layout(.engineering).lines
        let weights = Set(lines.map(\.weight))
        #expect(weights.count == 2)
        let bold = lines.filter { $0.weight == weights.max() }
        #expect(bold.count * 5 >= lines.count - 2 && bold.count * 5 <= lines.count + 10)
    }

    @Test func musicStavesHaveFiveLines() {
        let lines = layout(.music).lines
        #expect(!lines.isEmpty)
        #expect(lines.count.isMultiple(of: 5))
    }

    @Test(arguments: PaperType.allCases)
    func marksStayOnThePage(type: PaperType) {
        let page = layout(type, size: .a4)
        let bounds = CGRect(x: 0, y: 0, width: PageSize.a4.width, height: PageSize.a4.height).insetBy(
            dx: -0.01, dy: -0.01)
        for line in page.lines {
            #expect(bounds.contains(line.start) && bounds.contains(line.end))
        }
        for dot in page.dots { #expect(bounds.contains(dot.center)) }
    }

    @Test func darkPaperUsesLightRules() {
        let rules = layout(.fineLined, color: .charcoal).lines
        #expect(rules.allSatisfy { $0.color.hex == 0xFFFFFF })
    }

    @Test func rendererDrawsRulesDarkerThanPaper() throws {
        let paper = Paper(type: .fineLined, color: .white)
        let scale = 2.0
        let image = try #require(PaperRenderer.image(paper: paper, size: .a5, scale: scale))
        let ruleY = Int((mm(18) * scale).rounded())
        let gapY = Int(((mm(18) + mm(3)) * scale).rounded())
        let x = Int(PageSize.a5.width)
        let rule = try #require(PaperRendererTestSupport.luminance(of: image, x: x, y: ruleY))
        let gap = try #require(PaperRendererTestSupport.luminance(of: image, x: x, y: gapY))
        #expect(rule < gap - 0.05)
    }
}

enum PaperRendererTestSupport {
    static func luminance(of image: CGImage, x: Int, y: Int) -> Double? {
        var pixel = [UInt8](repeating: 0, count: 4)
        guard
            let context = CGContext(
                data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        // Core Graphics has a bottom-left origin; image rows count from the top.
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        return (Double(pixel[0]) + Double(pixel[1]) + Double(pixel[2])) / (3 * 255)
    }
}
