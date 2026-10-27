import CoreGraphics
import Foundation
import NotebookCore
import PencilKit
import Testing
import UIKit

@testable import Ductus

struct ThumbnailerTests {
    /// An A5 page in canvas units.
    let page = PageLayout(size: .a5, pageCount: 1).pageSize
    let start = Date(timeIntervalSinceReferenceDate: 0)

    func ink(_ rect: CGRect, at seconds: Double) -> Thumbnailer.Ink {
        Thumbnailer.Ink(bounds: rect, created: start.addingTimeInterval(seconds))
    }

    @Test func cropHasTheCardShapeAndAReadableSize() {
        let crop = Thumbnailer.crop(for: [], pageSize: page)
        #expect(abs(crop.width / crop.height - Thumbnailer.aspect) < 0.001)
        #expect(abs(crop.width - Thumbnailer.cropWidth * PageLayout.unitsPerPoint) < 0.001)
    }

    @Test func aBlankPageShowsItsTopLeft() {
        let crop = Thumbnailer.crop(for: [], pageSize: page)
        #expect(crop.origin == .zero)
    }

    @Test func cropFollowsTheLatestWriting() {
        let early = ink(CGRect(x: 60, y: 80, width: 300, height: 30), at: 0)
        let latest = ink(CGRect(x: 100, y: 1000, width: 200, height: 30), at: 60)
        let crop = Thumbnailer.crop(for: [latest, early], pageSize: page)
        #expect(crop.contains(latest.bounds))
        #expect(!crop.intersects(early.bounds))
    }

    @Test func cropTakesInAsMuchRecentWritingAsFits() {
        let lines = (0..<6).map { i in
            ink(CGRect(x: 80, y: 600 + Double(i) * 50, width: 400, height: 30), at: Double(i))
        }
        let crop = Thumbnailer.crop(for: lines.shuffled(), pageSize: page)
        #expect(crop.contains(lines[5].bounds) && crop.contains(lines[4].bounds) && crop.contains(lines[3].bounds))
    }

    @Test func cropStaysOnThePage() {
        let corner = ink(CGRect(x: page.width - 20, y: page.height - 20, width: 15, height: 15), at: 0)
        let crop = Thumbnailer.crop(for: [corner], pageSize: page)
        #expect(crop.maxX <= page.width + 0.001 && crop.maxY <= page.height + 0.001)
        #expect(crop.minX >= 0 && crop.minY >= 0)
        #expect(crop.contains(corner.bounds))
    }

    @Test func pngHasTheCardShape() throws {
        let data = try #require(
            Thumbnailer.png(
                drawingData: PKDrawing().dataRepresentation(), paper: Paper(type: .fineLined, color: .ivory), size: .a5)
        )
        let image = try #require(UIImage(data: data))
        #expect(abs(image.size.width / image.size.height - Thumbnailer.aspect) < 0.01)
    }

    @Test func inkStaysDarkInDarkMode() throws {
        let previous = UITraitCollection.current
        UITraitCollection.current = UITraitCollection(userInterfaceStyle: .dark)
        defer { UITraitCollection.current = previous }
        let points = (0..<20).map { i in
            PKStrokePoint(
                location: CGPoint(x: 200 + Double(i) * 20, y: 400), timeOffset: Double(i) * 0.01,
                size: CGSize(width: 12, height: 12), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let stroke = PKStroke(
            ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: start))
        let data = try #require(
            Thumbnailer.png(
                drawingData: PKDrawing(strokes: [stroke]).dataRepresentation(),
                paper: Paper(type: .blank, color: .white), size: .a5))
        let image = try #require(UIImage(data: data)?.cgImage)
        // The crop is centred on the stroke, so the middle of the thumbnail is ink.
        let middle = try #require(luminance(of: image, x: image.width / 2, y: image.height / 2))
        #expect(middle < 0.3)
    }

    func luminance(of image: CGImage, x: Int, y: Int) -> Double? {
        var pixel = [UInt8](repeating: 0, count: 4)
        guard
            let context = CGContext(
                data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        return (Double(pixel[0]) + Double(pixel[1]) + Double(pixel[2])) / (3 * 255)
    }
}
