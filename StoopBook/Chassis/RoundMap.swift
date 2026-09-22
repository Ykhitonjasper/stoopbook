import MapKit
import SwiftUI

/// The round on a real basemap: Apple's tiles underneath, this app's marks on top.
///
/// The house style still holds on a live map. The walk is a brass thread over a
/// paper casing so it stays legible over any basemap, and every household is one of
/// this app's drawn marks with its visit number, tinted by cadence state — no stock
/// pin glyphs. Taps resolve to the nearest pin, exactly as on the drawn sheet, so
/// two households in one building still open the door you meant.
struct RoundMap: UIViewRepresentable {
    let stops: [VisitStop]
    let route: [VisitStop]
    let focusedStopID: String?
    let state: (VisitStop) -> CadenceState
    var onSelect: (VisitStop) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, state: state)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = TappableMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        // The sheet lives inside the page's scroll, and a pannable map view fights
        // the page for one vertical gesture — the oldest MapKit-in-a-scroll bug.
        // The map is a figure on the page, so the page wins: pan is off, the pins
        // refit on every change anyway, and pinch and tap still work on the figure.
        mapView.isScrollEnabled = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = Self.quietConfiguration()
        mapView.layer.cornerCurve = .continuous
        mapView.onTap = { [weak mapView, coordinator = context.coordinator] point in
            guard let mapView else { return }
            coordinator.focusNearest(to: point, in: mapView)
        }
        // The first fit asks before the map has bounds; this is the second ask, once
        // it does. Without it every pin sits on the default region, stacked.
        mapView.onLayout = { [weak mapView, weak coordinator = context.coordinator] in
            guard let mapView, let coordinator else { return }
            coordinator.fitIfNeeded(mapView)
        }
        context.coordinator.apply(to: mapView, stops: stops, route: route, focused: focusedStopID, force: true)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onSelect = onSelect
        context.coordinator.state = state
        context.coordinator.apply(to: mapView, stops: stops, route: route, focused: focusedStopID, force: false)
    }

    /// Standard tiles in the flat, quiet treatment: the map is ground, the marks are
    /// the content. Excluding points of interest keeps shop logos out of a round book.
    private static func quietConfiguration() -> MKStandardMapConfiguration {
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat)
        configuration.emphasisStyle = .muted
        return configuration
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onSelect: (VisitStop) -> Void
        var state: (VisitStop) -> CadenceState
        private var drawnStopIDs: [String] = []
        private var drawnRouteIDs: [String] = []
        private var fittedSignature = ""
        private var stopped: [VisitStop] = []
        private var route: [VisitStop] = []
        private var focusedStopID: String?

        init(onSelect: @escaping (VisitStop) -> Void, state: @escaping (VisitStop) -> CadenceState) {
            self.onSelect = onSelect
            self.state = state
        }

        // MARK: - Content

        func apply(to mapView: MKMapView, stops: [VisitStop], route: [VisitStop], focused: String?, force: Bool) {
            self.stopped = stops
            self.route = route
            focusedStopID = focused

            if force || drawnStopIDs != stops.map(\.id) {
                mapView.removeAnnotations(mapView.annotations)
                let annotations = stops.map { StoopAnnotation(stop: $0) }
                mapView.addAnnotations(annotations)
                drawnStopIDs = stops.map(\.id)
            }

            let routeIDs = route.map(\.id)
            if force || drawnRouteIDs != routeIDs {
                mapView.removeOverlays(mapView.overlays)
                let coordinates = route.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                if coordinates.count >= 2 {
                    // Two lines: a paper casing under the brass thread, so the walk
                    // stays readable over dark tiles as well as pale ones.
                    let casing = MKPolyline(coordinates: coordinates, count: coordinates.count)
                    casing.title = "casing"
                    let thread = MKPolyline(coordinates: coordinates, count: coordinates.count)
                    thread.title = "thread"
                    mapView.addOverlays([casing, thread])
                }
                drawnRouteIDs = routeIDs
            }

            // Views are created lazily by the map, so this pass restyles the ones
            // already on screen and viewFor styles the rest as they arrive.
            for annotation in mapView.annotations {
                guard let stoop = annotation as? StoopAnnotation,
                      let view = mapView.view(for: stoop) else { continue }
                style(view, annotation: stoop)
            }

            fitIfNeeded(mapView)
        }

        func fitIfNeeded(_ mapView: MKMapView) {
            guard mapView.bounds.width > 8, mapView.bounds.height > 8 else { return }
            let signature = stopped.map(\.id).joined(separator: ",")
            guard signature != fittedSignature else { return }
            // The first fit lands instantly, the way the page arrived. Every fit after
            // it glides, so changing the block glides the map to the new households
            // instead of cutting.
            let opening = fittedSignature.isEmpty
            fittedSignature = signature
            guard !stopped.isEmpty else { return }

            var rect = MKMapRect.null
            for stop in stopped {
                let point = MKMapPoint(CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon))
                rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
            }
            mapView.setVisibleMapRect(
                rect,
                edgePadding: UIEdgeInsets(top: 48, left: 44, bottom: 56, right: 44),
                animated: !opening
            )
        }

        // MARK: - Marks

        private func style(_ view: MKAnnotationView, annotation: StoopAnnotation) {
            let isFocused = annotation.stopID == focusedStopID
            let number = route.firstIndex { $0.id == annotation.stopID }.map { $0 + 1 }
            view.image = StoopMarkRenderer.image(
                number: number,
                tone: state(annotation.stop).tone,
                focused: isFocused
            )
            // The mark sits above the bottom of its image, so the dot — not the
            // image box — lands on the coordinate.
            view.centerOffset = StoopMarkRenderer.centerOffset
            view.canShowCallout = false
            view.displayPriority = .required
            view.collisionMode = .none
            view.isAccessibilityElement = true
            view.accessibilityLabel = annotation.accessibilityLabel(
                state: state(annotation.stop),
                number: number
            )
            view.accessibilityTraits = isFocused ? [.button, .selected] : [.button]
        }

        // MARK: - Interaction

        /// Nearest pin wins, mirroring the drawn sheet: overlapping 44pt targets in
        /// one building must not open whichever view happens to sit on top.
        func focusNearest(to point: CGPoint, in mapView: MKMapView, within limit: CGFloat = 44) {
            var best: (stop: VisitStop, distance: CGFloat)?
            for annotation in mapView.annotations {
                guard let stoop = annotation as? StoopAnnotation else { continue }
                let pin = mapView.convert(stoop.coordinate, toPointTo: mapView)
                let distance = hypot(pin.x - point.x, pin.y - point.y)
                if best == nil || distance < best!.distance {
                    best = (stoop.stop, distance)
                }
            }
            guard let best, best.distance <= limit else { return }
            onSelect(best.stop)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let stoop = annotation as? StoopAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: StoopAnnotation.reuseIdentifier)
                as? StoopAnnotationView
                ?? StoopAnnotationView(annotation: stoop, reuseIdentifier: StoopAnnotation.reuseIdentifier)
            view.annotation = stoop
            view.onActivate = { [weak self] in self?.onSelect(stoop.stop) }
            style(view, annotation: stoop)
            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            let isCasing = polyline.title == "casing"
            renderer.strokeColor = isCasing ? UIColor(AppTheme.paper).withAlphaComponent(0.92) : UIColor(AppTheme.brass)
            renderer.lineWidth = isCasing ? 5.5 : 2
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }

        /// The map's own selection is deliberately not a focus action: it picks the
        /// annotation view on top, and with two households 8pt apart that is not the
        /// one the tap meant. Focus comes from the nearest-pin rule and nowhere else.
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            mapView.deselectAnnotation(view.annotation, animated: false)
        }
    }
}

/// A map view that reports taps in its own coordinates, so focus can be resolved by
/// distance rather than by which annotation view is on top.
final class TappableMapView: MKMapView {
    var onTap: ((CGPoint) -> Void)?
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        installTapRecognizer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installTapRecognizer()
    }

    private func installTapRecognizer() {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        addGestureRecognizer(recognizer)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        onTap?(recognizer.location(in: self))
    }
}

/// An annotation view that answers VoiceOver activation, so a screen reader user
/// focuses the household instead of selecting a marker the map then ignores.
final class StoopAnnotationView: MKAnnotationView {
    var onActivate: (() -> Void)?

    override func accessibilityActivate() -> Bool {
        guard let onActivate else { return super.accessibilityActivate() }
        onActivate()
        return true
    }
}

/// The map has its own recognizers for panning and for selecting annotations. Ours
/// has to run beside them, or a tap on a pin is swallowed and the nearest-pin rule
/// never gets a chance.
extension TappableMapView: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

private final class StoopAnnotation: NSObject, MKAnnotation {
    static let reuseIdentifier = "stoop.mark"

    let stopID: String
    let nickname: String
    let stop: VisitStop

    init(stop: VisitStop) {
        self.stop = stop
        stopID = stop.id
        nickname = stop.nickname
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon)
    }

    var title: String? { nickname }

    func accessibilityLabel(state: CadenceState, number: Int?) -> String {
        let prefix = number.map { "Stop \($0)," } ?? "Pin,"
        return "\(prefix) \(nickname). \(state.title), visited \(stop.lastVisitDayOffset) days ago on a \(stop.cadenceDays) day cadence. Window \(stop.windowStartHour) to \(stop.windowEndHour)."
    }
}

/// Draws one household mark: a cadence-toned dot with a paper ring and, where the
/// sheet can carry digits, the visit number. Never a stock pin glyph.
enum StoopMarkRenderer {
    /// The dot sits at the centre of the image, with the visit number above it. That
    /// keeps the marker's frame centred on the coordinate, so the point a person sees
    /// and the point a tap resolves against are the same point.
    static let size = CGSize(width: 44, height: 66)
    static let dotCentre = CGPoint(x: size.width / 2, y: size.height / 2)
    static var centerOffset: CGPoint { .zero }

    static func image(number: Int?, tone: Color, focused: Bool) -> UIImage {
        let size = self.size
        let renderer = UIGraphicsImageRenderer(size: size)
        let ink = UIColor(AppTheme.ink)
        let paper = UIColor(AppTheme.surface)
        let fill = UIColor(tone)
        return renderer.image { context in
            let centre = dotCentre
            let dotRadius: CGFloat = focused ? 6.5 : 5.5

            // A paper ring keeps the dot separate from busy tiles.
            context.cgContext.setFillColor(paper.cgColor)
            context.cgContext.fillEllipse(in: CGRect(x: centre.x - dotRadius - 2.5, y: centre.y - dotRadius - 2.5, width: (dotRadius + 2.5) * 2, height: (dotRadius + 2.5) * 2))

            if focused {
                context.cgContext.setStrokeColor(ink.cgColor)
                context.cgContext.setLineWidth(2)
                context.cgContext.strokeEllipse(in: CGRect(x: centre.x - 11, y: centre.y - 11, width: 22, height: 22))
            }

            context.cgContext.setFillColor(fill.cgColor)
            context.cgContext.fillEllipse(in: CGRect(x: centre.x - dotRadius, y: centre.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))

            guard let number else { return }
            let text = "\(number)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: focused ? 12 : 11, weight: .semibold),
                .foregroundColor: focused ? ink : UIColor(AppTheme.data)
            ]
            let measured = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: centre.x - measured.width / 2, y: max(0, centre.y - dotRadius - measured.height - 2)),
                withAttributes: attributes
            )
        }
        .withRenderingMode(.alwaysOriginal)
    }
}
