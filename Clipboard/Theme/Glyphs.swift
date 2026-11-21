import SwiftUI

/// Vector glyphs ported from the design's inline SVGs.
///
/// Each shape is authored in its SVG `viewBox` coordinates and scaled into
/// the proposed rect with `preserveAspectRatio="xMidYMid meet"` semantics, so
/// `Glyph.Pin().frame(width: 11, height: 11)` renders exactly like
/// `<svg width="11" height="11" viewBox="0 0 24 24">`.
protocol ViewBoxShape: Shape {
    static var viewBox: CGSize { get }
    func viewBoxPath() -> Path
}

extension ViewBoxShape {
    static var viewBox: CGSize { CGSize(width: 24, height: 24) }

    func path(in rect: CGRect) -> Path {
        viewBoxPath().applying(Self.transform(into: rect))
    }

    static func scale(for size: CGSize) -> CGFloat {
        min(size.width / viewBox.width, size.height / viewBox.height)
    }

    private static func transform(into rect: CGRect) -> CGAffineTransform {
        let scale = scale(for: rect.size)
        let originX = rect.minX + (rect.width - viewBox.width * scale) / 2
        let originY = rect.minY + (rect.height - viewBox.height * scale) / 2
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: originX, ty: originY)
    }
}

/// Strokes a view-box glyph with an SVG `stroke-width`, scaled with the glyph.
struct GlyphStroke<S: ViewBoxShape>: View {
    let shape: S
    let width: CGFloat
    let size: CGSize
    var lineJoin: CGLineJoin = .round

    init(_ shape: S, width: CGFloat, size: CGFloat, lineJoin: CGLineJoin = .round) {
        self.init(shape, width: width, size: CGSize(width: size, height: size), lineJoin: lineJoin)
    }

    init(_ shape: S, width: CGFloat, size: CGSize, lineJoin: CGLineJoin = .round) {
        self.shape = shape
        self.width = width
        self.size = size
        self.lineJoin = lineJoin
    }

    var body: some View {
        shape
            .stroke(style: StrokeStyle(
                lineWidth: width * S.scale(for: size),
                lineCap: .round,
                lineJoin: lineJoin
            ))
            .frame(width: size.width, height: size.height)
    }
}

enum Glyph {
    /// Search magnifier (stroked, width 2).
    struct Magnifier: ViewBoxShape {
        func viewBoxPath() -> Path {
            var path = Path()
            path.addEllipse(in: CGRect(x: 10.5 - 6.75, y: 10.5 - 6.75, width: 13.5, height: 13.5))
            path.move(to: CGPoint(x: 20, y: 20))
            path.addLine(to: CGPoint(x: 15.8, y: 15.8))
            return path
        }
    }

    /// Push-pin (filled).
    struct Pin: ViewBoxShape {
        func viewBoxPath() -> Path {
            var path = Path()
            path.addLines([
                CGPoint(x: 14, y: 2), CGPoint(x: 22, y: 10), CGPoint(x: 18.8, y: 10.8),
                CGPoint(x: 15.4, y: 14.2), CGPoint(x: 14.5, y: 20), CGPoint(x: 12, y: 22),
                CGPoint(x: 8, y: 18), CGPoint(x: 3, y: 21), CGPoint(x: 6, y: 16),
                CGPoint(x: 2, y: 12), CGPoint(x: 4, y: 10), CGPoint(x: 9.4, y: 11.1),
                CGPoint(x: 15.2, y: 5.2), CGPoint(x: 16, y: 2),
            ])
            path.closeSubpath()
            return path
        }
    }

    /// Delete cross (stroked, width 2.2).
    struct Close: ViewBoxShape {
        func viewBoxPath() -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 6, y: 6))
            path.addLine(to: CGPoint(x: 18, y: 18))
            path.move(to: CGPoint(x: 18, y: 6))
            path.addLine(to: CGPoint(x: 6, y: 18))
            return path
        }
    }

    /// Toast check mark (stroked, width 3).
    struct Check: ViewBoxShape {
        func viewBoxPath() -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 5, y: 13))
            path.addLine(to: CGPoint(x: 9, y: 17))
            path.addLine(to: CGPoint(x: 19, y: 7))
            return path
        }
    }

    /// Back panel of the folder (with the tab). Filled.
    struct FolderBack: ViewBoxShape {
        func viewBoxPath() -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 3, y: 7.5))
            path.addArc(tangent1End: CGPoint(x: 3, y: 5.5), tangent2End: CGPoint(x: 5, y: 5.5), radius: 2)
            path.addLine(to: CGPoint(x: 9.2, y: 5.5))
            path.addLine(to: CGPoint(x: 10.8, y: 7.3))
            path.addLine(to: CGPoint(x: 19, y: 7.3))
            path.addArc(tangent1End: CGPoint(x: 21, y: 7.3), tangent2End: CGPoint(x: 21, y: 9.3), radius: 2)
            path.addLine(to: CGPoint(x: 21, y: 17))
            path.addArc(tangent1End: CGPoint(x: 21, y: 19), tangent2End: CGPoint(x: 19, y: 19), radius: 2)
            path.addLine(to: CGPoint(x: 5, y: 19))
            path.addArc(tangent1End: CGPoint(x: 3, y: 19), tangent2End: CGPoint(x: 3, y: 17), radius: 2)
            path.closeSubpath()
            return path
        }
    }

    /// Front flap of the folder, layered over `FolderBack` on cards.
    struct FolderFront: ViewBoxShape {
        func viewBoxPath() -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 3, y: 9.3))
            path.addLine(to: CGPoint(x: 21, y: 9.3))
            path.addLine(to: CGPoint(x: 21, y: 17))
            path.addArc(tangent1End: CGPoint(x: 21, y: 19), tangent2End: CGPoint(x: 19, y: 19), radius: 2)
            path.addLine(to: CGPoint(x: 5, y: 19))
            path.addArc(tangent1End: CGPoint(x: 3, y: 19), tangent2End: CGPoint(x: 3, y: 17), radius: 2)
            path.closeSubpath()
            return path
        }
    }

    /// Large document page body (40×48 view box). Filled at 16% opacity.
    struct DocumentPage: ViewBoxShape {
        static let viewBox = CGSize(width: 40, height: 48)

        func viewBoxPath() -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 4, y: 4))
            path.addArc(tangent1End: CGPoint(x: 4, y: 1), tangent2End: CGPoint(x: 7, y: 1), radius: 3)
            path.addLine(to: CGPoint(x: 27, y: 1))
            path.addLine(to: CGPoint(x: 36, y: 10))
            path.addLine(to: CGPoint(x: 36, y: 44))
            path.addArc(tangent1End: CGPoint(x: 36, y: 47), tangent2End: CGPoint(x: 33, y: 47), radius: 3)
            path.addLine(to: CGPoint(x: 7, y: 47))
            path.addArc(tangent1End: CGPoint(x: 4, y: 47), tangent2End: CGPoint(x: 4, y: 44), radius: 3)
            path.closeSubpath()
            return path
        }
    }

    /// Dog-ear fold of the large document page (stroked, width 2).
    struct DocumentFold: ViewBoxShape {
        static let viewBox = CGSize(width: 40, height: 48)

        func viewBoxPath() -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 27, y: 1))
            path.addLine(to: CGPoint(x: 27, y: 7))
            path.addArc(tangent1End: CGPoint(x: 27, y: 10), tangent2End: CGPoint(x: 30, y: 10), radius: 3)
            path.addLine(to: CGPoint(x: 36, y: 10))
            return path
        }
    }

    /// Three text lines on the large document page (filled).
    struct DocumentLines: ViewBoxShape {
        static let viewBox = CGSize(width: 40, height: 48)

        func viewBoxPath() -> Path {
            var path = Path()
            for (y, width) in [(20.0, 18.0), (26.0, 18.0), (32.0, 11.0)] {
                path.addRoundedRect(
                    in: CGRect(x: 11, y: y, width: width, height: 2.4),
                    cornerSize: CGSize(width: 1.2, height: 1.2)
                )
            }
            return path
        }
    }

    /// Compact document glyph used in list rows and Quick Look (filled).
    struct DocumentSmall: ViewBoxShape {
        func viewBoxPath() -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 6, y: 3))
            path.addArc(tangent1End: CGPoint(x: 6, y: 1), tangent2End: CGPoint(x: 8, y: 1), radius: 2)
            path.addLine(to: CGPoint(x: 15, y: 1))
            path.addLine(to: CGPoint(x: 20, y: 6))
            path.addLine(to: CGPoint(x: 20, y: 19))
            path.addArc(tangent1End: CGPoint(x: 20, y: 21), tangent2End: CGPoint(x: 18, y: 21), radius: 2)
            path.addLine(to: CGPoint(x: 8, y: 21))
            path.addArc(tangent1End: CGPoint(x: 6, y: 21), tangent2End: CGPoint(x: 6, y: 19), radius: 2)
            path.closeSubpath()
            return path
        }
    }

    /// Text-lines icon for text rows in the list (stroked, width 2).
    struct TextLines: ViewBoxShape {
        func viewBoxPath() -> Path {
            var path = Path()
            for (y, endX) in [(7.0, 19.0), (12.0, 19.0), (17.0, 14.0)] {
                path.move(to: CGPoint(x: 5, y: y))
                path.addLine(to: CGPoint(x: endX, y: y))
            }
            return path
        }
    }

    /// Two-column icon shown while in the row layout (filled).
    struct LayoutColumns: ViewBoxShape {
        func viewBoxPath() -> Path {
            var path = Path()
            for x in [3.0, 14.0] {
                path.addRoundedRect(
                    in: CGRect(x: x, y: 5, width: 7, height: 14),
                    cornerSize: CGSize(width: 1.6, height: 1.6)
                )
            }
            return path
        }
    }

    /// Three-bar icon shown while in the list layout (filled).
    struct LayoutRows: ViewBoxShape {
        func viewBoxPath() -> Path {
            var path = Path()
            for y in [4.0, 9.8, 15.6] {
                path.addRoundedRect(
                    in: CGRect(x: 3, y: y, width: 18, height: 4.4),
                    cornerSize: CGSize(width: 1.4, height: 1.4)
                )
            }
            return path
        }
    }

    /// Crescent moon (filled). The SVG's two arcs describe the body circle
    /// minus an offset "bite" circle, both of radius 8.
    struct Moon: ViewBoxShape {
        func viewBoxPath() -> Path {
            let radius = 8.0
            let body = Path(ellipseIn: CGRect(x: 12.643 - radius, y: 11.357 - radius, width: radius * 2, height: radius * 2))
            let bite = Path(ellipseIn: CGRect(x: 16.857 - radius, y: 7.143 - radius, width: radius * 2, height: radius * 2))
            return body.subtracting(bite)
        }
    }

    /// Sun with eight rays (stroked, width 2).
    struct Sun: ViewBoxShape {
        func viewBoxPath() -> Path {
            var path = Path()
            path.addEllipse(in: CGRect(x: 12 - 4.2, y: 12 - 4.2, width: 8.4, height: 8.4))
            let rays: [(CGPoint, CGPoint)] = [
                (CGPoint(x: 12, y: 2.5), CGPoint(x: 12, y: 4.5)),
                (CGPoint(x: 12, y: 19.5), CGPoint(x: 12, y: 21.5)),
                (CGPoint(x: 2.5, y: 12), CGPoint(x: 4.5, y: 12)),
                (CGPoint(x: 19.5, y: 12), CGPoint(x: 21.5, y: 12)),
                (CGPoint(x: 5.2, y: 5.2), CGPoint(x: 6.6, y: 6.6)),
                (CGPoint(x: 17.4, y: 17.4), CGPoint(x: 18.8, y: 18.8)),
                (CGPoint(x: 18.8, y: 5.2), CGPoint(x: 17.4, y: 6.6)),
                (CGPoint(x: 6.6, y: 17.4), CGPoint(x: 5.2, y: 18.8)),
            ]
            for (start, end) in rays {
                path.move(to: start)
                path.addLine(to: end)
            }
            return path
        }
    }

    /// Clipboard board outline for the empty state (stroked, width 1.5).
    struct ClipboardBoard: ViewBoxShape {
        func viewBoxPath() -> Path {
            Path(roundedRect: CGRect(x: 5, y: 3, width: 14, height: 18), cornerSize: CGSize(width: 2.5, height: 2.5))
        }
    }

    /// Clipboard clip for the empty state (filled).
    struct ClipboardClip: ViewBoxShape {
        func viewBoxPath() -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 9, y: 3.5))
            path.addLine(to: CGPoint(x: 15, y: 3.5))
            path.addArc(tangent1End: CGPoint(x: 16, y: 3.5), tangent2End: CGPoint(x: 16, y: 4.5), radius: 1)
            path.addLine(to: CGPoint(x: 16, y: 6))
            path.addLine(to: CGPoint(x: 8, y: 6))
            path.addLine(to: CGPoint(x: 8, y: 4.5))
            path.addArc(tangent1End: CGPoint(x: 8, y: 3.5), tangent2End: CGPoint(x: 9, y: 3.5), radius: 1)
            path.closeSubpath()
            return path
        }
    }
}

// MARK: - Composite glyphs

/// The two-tone folder drawn on cards: the back at 90% opacity under the front.
struct FolderGlyph: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Glyph.FolderBack().fill(color).opacity(0.9)
            Glyph.FolderFront().fill(color)
        }
        .frame(width: size, height: size)
    }
}

/// The document page drawn on cards: 16% fill, stroked fold and three lines.
struct DocumentGlyph: View {
    let color: Color
    var size = CGSize(width: 46, height: 52)

    var body: some View {
        ZStack {
            Glyph.DocumentPage().fill(color).opacity(0.16)
            GlyphStroke(Glyph.DocumentFold(), width: 2, size: size, lineJoin: .miter)
            Glyph.DocumentLines().fill(color)
        }
        .foregroundStyle(color)
        .frame(width: size.width, height: size.height)
    }
}

/// Empty-state clipboard outline.
struct ClipboardGlyph: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            GlyphStroke(Glyph.ClipboardBoard(), width: 1.5, size: size)
            Glyph.ClipboardClip().fill(color)
        }
        .foregroundStyle(color)
        .frame(width: size, height: size)
    }
}
