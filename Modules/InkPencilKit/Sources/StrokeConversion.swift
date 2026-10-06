import Foundation
import InkCore
import PencilKit
import UIKit

/// Converts between InkCore strokes and PencilKit strokes. Used for export and for Feel Lab
/// Replay mode (custom-engine input rendered through PencilKit).
public enum StrokeConversion {
    public static func pkStroke(from stroke: Stroke) -> PKStroke? {
        guard let start = stroke.samples.first?.timestamp else { return nil }
        let size = CGSize(width: stroke.tool.width, height: stroke.tool.width)
        let points = stroke.samples.map { sample in
            PKStrokePoint(
                location: CGPoint(x: sample.x, y: sample.y),
                timeOffset: sample.timestamp - start,
                size: size,
                opacity: 1,
                force: sample.force,
                azimuth: sample.azimuth,
                altitude: sample.altitude)
        }
        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return PKStroke(ink: ink(for: stroke.tool), path: path)
    }

    public static func stroke(from pkStroke: PKStroke, id: UUID = UUID()) -> Stroke {
        let samples = pkStroke.path.map { point in
            let location = point.location.applying(pkStroke.transform)
            return StrokeSample(
                x: location.x, y: location.y, force: point.force,
                altitude: point.altitude, azimuth: point.azimuth, timestamp: point.timeOffset)
        }
        let width = pkStroke.path.first.map { Double($0.size.width) } ?? InkTool.defaultPen.width
        let kind: InkTool.Kind = pkStroke.ink.inkType == .marker ? .highlighter : .pen
        return Stroke(
            id: id, tool: InkTool(kind: kind, color: InkColor(pkStroke.ink.color), width: width), samples: samples)
    }

    static func ink(for tool: InkTool) -> PKInk {
        PKInk(tool.kind == .highlighter ? .marker : .pen, color: UIColor(tool.color))
    }
}

extension UIColor {
    convenience init(_ color: InkColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }
}

extension InkColor {
    init(_ color: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
