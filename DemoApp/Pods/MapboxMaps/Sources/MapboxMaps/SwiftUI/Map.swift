import SwiftUI

/// A SwiftUI view that displays a Mapbox Map.
///
/// The `Map` is an entry point to display Mapbox Map in a SwiftUI Application. Typically, you create a ``Map`` in the `body` variable of your view. Then you can use
/// - ``Viewport`` and ``ViewportAnimation`` to manage map camera state and animations.
/// - `Map`'s modifier functions such as ``Map/mapStyle(_:)``,  ``Map/onTapGesture(count:perform:)``, ``Map/onLayerTapGesture(_:perform:)`` and many others to configure the map appearance and behavior.
/// - Map Content objects, such as ``Puck2D``, ``Puck3D``, ``PointAnnotation``, ``PolylineAnnotation``, ``PolygonAnnotation``, ``MapViewAnnotation`` and others, to display your content on the map.
///
/// In the example below the `ContentView` displays a map with [Mapbox Standard](https://www.mapbox.com/blog/standard-core-style) style in the dusk light preset, shows the user location indicator (Puck), displays a view annotation with a SwiftUI View inside, draws a polygon, and focuses camera on that polygon.
///
/// ```swift
/// struct ContentView: View {
///     static let polygon = Polygon(...)
///
///     // Configures the map camera to overview the given polygon.
///     @State var viewport = Viewport.overview(geometry: Self.polygon)
///
///     var body: some View {
///         Map(viewport: $viewport) {
///             // Displays the user location.
///             Puck2D(heading: bearing)
///
///             // Displays a view annotation.
///             MapViewAnnotation(CLLocationCoordinate(...))
///                 Text("🚀")
///                     .background(Circle().fill(.red))
///             }
///
///             // Displays a polygon annotation.
///             PolygonAnnotation(polygon: Self.polygon)
///                 .fillColor(StyleColor(.systemBlue))
///                 .fillOpacity(0.5)
///                 .fillOutlineColor(StyleColor(.black))
///                 .onTapGesture {
///                     print("Polygon is tapped")
///                 }
///          }
///          // Uses Mapbox Standard style in the dusk light preset.
///          .mapStyle(.standard(lightPreset: .dusk))
///     }
/// }
/// ```
///
/// Check out the <doc:SwiftUI-User-Guide> for more information about ``Map`` capabilities, and the <doc:Map-Content-Gestures-User-Guide> for more information about gesture handling.
@_documentation(visibility: public)
@_spi(Experimental)
@available(iOS 13.0, *)
public struct Map: UIViewControllerRepresentable {
    private var viewport: ConstantOrBinding<Viewport>
    var mapDependencies = MapDependencies()
    private var mapContentVisitor = DefaultMapContentVisitor()
    private let urlOpenerProvider: URLOpenerProvider

    @Environment(\.layoutDirection) var layoutDirection

    /// Creates a map that displays annotations.
    ///
    /// - Parameters:
    ///     - viewport: The camera viewport to display.
    ///     - content: A map content building closure.
    @_documentation(visibility: public)
    @available(iOSApplicationExtension, unavailable)
    public init(
        viewport: Binding<Viewport>,
        @MapContentBuilder content: @escaping () -> MapContent
    ) {
        self.init(
            _viewport: .binding(viewport),
            urlOpenerProvider: URLOpenerProvider(),
            content: content)
    }

    /// Creates a map that displays annotations.
    ///
    /// - Parameters:
    ///     - initialViewport: The camera viewport to display.
    ///     - content: A map content building closure.
    @_documentation(visibility: public)
    @available(iOSApplicationExtension, unavailable)
    public init(
        initialViewport: Viewport = .styleDefault,
        @MapContentBuilder content: @escaping () -> MapContent
    ) {
        self.init(
            _viewport: .constant(initialViewport),
            urlOpenerProvider: URLOpenerProvider(),
            content: content)
    }

    private init(
        _viewport: ConstantOrBinding<Viewport>,
        urlOpenerProvider: URLOpenerProvider,
        content: (() -> MapContent)? = nil
    ) {
        self.viewport = _viewport
        self.urlOpenerProvider = urlOpenerProvider
        content?()
            .visit(mapContentVisitor)
    }

    public func makeCoordinator() -> Coordinator {
        let urlOpener = ClosureURLOpener()
        let mapView = MapView(frame: .zero, urlOpener: urlOpener)
        let vc = MapViewController(mapView: mapView)

        let basicCoordinator = MapBasicCoordinator(
            setViewport: viewport.setter,
            mapView: MapViewFacade(from: mapView))

        let viewAnnotationCoordinator = ViewAnnotationCoordinator(
            viewAnnotationsManager: mapView.viewAnnotations,
            addViewController: { childVC in
                vc.addChild(childVC)
                childVC.didMove(toParent: vc)
            },
            removeViewController: { childVC in
                childVC.willMove(toParent: nil)
                childVC.removeFromParent()
            }
        )

        let layerAnnotationCoordinator = LayerAnnotationCoordinator(annotationOrchestrator: mapView.annotations)

        return Coordinator(
            basic: basicCoordinator,
            viewAnnotation: viewAnnotationCoordinator,
            layerAnnotation: layerAnnotationCoordinator,
            viewController: vc,
            urlOpener: urlOpener,
            mapView: mapView)
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        context.coordinator.urlOpener.openURL = urlOpenerProvider.resolve(in: context.environment)
        context.environment.mapViewProvider?.mapView = context.coordinator.mapView
        return context.coordinator.viewController
    }

    public func updateUIViewController(_ mapController: UIViewController, context: Context) {
        mapController.additionalSafeAreaInsets = UIEdgeInsets(insets: mapDependencies.additionalSafeArea, layoutDirection: layoutDirection)
        context.coordinator.basic.update(
            viewport: viewport,
            deps: mapDependencies,
            layoutDirection: layoutDirection,
            animationData: context.transaction.viewportAnimationData)
        context.coordinator.layerAnnotation.update(annotations: mapContentVisitor.annotationGroups)
        context.coordinator.viewAnnotation.updateAnnotations(to: mapContentVisitor.visitedViewAnnotations)
        context.coordinator.mapView.location.options = mapContentVisitor.locationOptions
    }
}

@_documentation(visibility: public)
@available(iOS 13.0, *)
extension Map {

    /// Creates a map with a viewport binding.
    ///
    /// - Parameters:
    ///     - viewport: The camera viewport to display.
    @_documentation(visibility: public)
    @available(iOSApplicationExtension, unavailable)
    public init(
        viewport: Binding<Viewport>
    ) {
        self.init(
            _viewport: .binding(viewport),
            urlOpenerProvider: URLOpenerProvider(),
            content: nil)
    }

    /// Creates a map an initial viewport.
    ///
    /// - Parameters:
    ///     - initialViewport: Initial camera viewport.
    @_documentation(visibility: public)
    @available(iOSApplicationExtension, unavailable)
    public init(
        initialViewport: Viewport = .styleDefault
    ) {
        self.init(
            _viewport: .constant(initialViewport),
            urlOpenerProvider: URLOpenerProvider(),
            content: nil)
    }

    /// Creates a map with a viewport binding.
    ///
    /// Use this method to create a map in application extension context, or to override default url opening mechanism on iOS < 15.
    ///
    /// - Note: Starting from iOS 14  ``Map`` will use standard `OpenURLAction` taken from the `Environment`
    ///   to open attribution urls, if `urlOpener` is not set.
    ///
    /// - Parameters:
    ///     - viewport: The camera viewport to display.
    ///     - urlOpener: A closure that handles attribution url opening.
    ///     - content: A map content building closure.
    @_documentation(visibility: public)
    public init(
        viewport: Binding<Viewport>,
        urlOpener: @escaping MapURLOpener,
        @MapContentBuilder content: @escaping () -> MapContent
    ) {
        self.init(
            _viewport: .binding(viewport),
            urlOpenerProvider: URLOpenerProvider(userUrlOpener: urlOpener),
            content: content)
    }

    /// Creates a map an initial viewport.
    ///
    /// Use this method to create a map in application extension context, or to override default url opening mechanism on iOS < 15.
    ///
    /// - Note: Starting from iOS 14  ``Map`` will use standard `OpenURLAction` taken from the `Environment`
    ///   to open attribution urls, if `urlOpener` is not set.
    ///
    /// - Parameters:
    ///     - initialViewport: The camera viewport to display.
    ///     - urlOpener: A closure that handles attribution url opening.
    ///     - content: A map content building closure.
    @_documentation(visibility: public)
    public init(
        initialViewport: Viewport = .styleDefault,
        urlOpener: @escaping MapURLOpener,
        @MapContentBuilder content: @escaping () -> MapContent
    ) {
        self.init(
            _viewport: .constant(initialViewport),
            urlOpenerProvider: URLOpenerProvider(userUrlOpener: urlOpener),
            content: content)
    }
}

@_documentation(visibility: public)
@available(iOS 13.0, *)
public extension Map {
    /// Sets camera bounds.
    @_documentation(visibility: public)
    func cameraBounds(_ cameraBounds: CameraBoundsOptions) -> Self {
        copyAssigned(self, \.mapDependencies.cameraBounds, cameraBounds)
    }

    /// Sets style to the map.
    ///
    /// - Parameters:
    ///     - mapStyle: A map style configuration.
    @_documentation(visibility: public)
    func mapStyle(_ mapStyle: MapStyle) -> Self {
        copyAssigned(self, \.mapDependencies.mapStyle, mapStyle)
    }

    /// Sets constraint mode to the map. If not set, `heightOnly` will be in use.
    @_documentation(visibility: public)
    func constrainMode(_ constrainMode: ConstrainMode) -> Self {
        copyAssigned(self, \.mapDependencies.constrainMode, constrainMode)
    }

    /// Sets viewport mode to the map.
    @_documentation(visibility: public)
    func viewportMode(_ viewportMode: ViewportMode) -> Self {
        copyAssigned(self, \.mapDependencies.viewportMode, viewportMode)
    }

    /// Sets ``NorthOrientation`` to the map. If not set, `upwards` will be in use.
    @_documentation(visibility: public)
    func northOrientation(_ northOrientation: NorthOrientation) -> Self {
        copyAssigned(self, \.mapDependencies.orientation, northOrientation)
    }

    /// Sets ``OrnamentOptions`` to the map.
    @_documentation(visibility: public)
    func ornamentOptions(_ options: OrnamentOptions) -> Self {
        copyAssigned(self, \.mapDependencies.ornamentOptions, options)
    }

    /// Sets ``MapViewDebugOptions`` to the map.
    @_documentation(visibility: public)
    func debugOptions(_ debugOptions: MapViewDebugOptions) -> Self {
        copyAssigned(self, \.mapDependencies.debugOptions, debugOptions)
    }

    /// A boolean value that determines whether the view is opaque. Default is true.
    @_documentation(visibility: public)
    func opaque(_ value: Bool) -> Self {
        copyAssigned(self, \.mapDependencies.isOpaque, value)
    }

    /// The preferred frames per second used for map rendering.
    /// The system can change the available range of frame rates because of factors in system policies and a person’s preferences.
    /// Changing this setting maybe beneficial to get smoother experience on devices which support 120 FPS.
    ///
    /// - Note: `range` values  have effect only on iOS 15.0 and newer. Value`nil` in any of the parameters is interpreted as using system default value.
    ///
    /// - Parameters:
    ///    - range: Allowed frame rate range. Negative and values less than 1 will be clamped to 1.
    ///    - preferred: Preferred frame rate.  Negative and values less than 1 will be clamped to 1, while too large values will be clamped to Int.max.
    @_documentation(visibility: public)
    func frameRate(range: ClosedRange<Float>? = nil, preferred: Float? = nil) -> Self {
        copyAssigned(
            self, \.mapDependencies.frameRate, FrameRate(range: range, preferred: preferred))
    }

    /// A Boolean value that indicates whether the underlying `CAMetalLayer` of the `MapView`
    /// presents its content using a CoreAnimation transaction
    ///
    /// See ``MapView/presentsWithTransaction``.
    @_documentation(visibility: public)
    func presentsWithTransaction(_ value: Bool) -> Self {
        copyAssigned(self, \.mapDependencies.presentsWithTransaction, value)
    }

    /// Indicates whether the ``Viewport`` should idle when map receives pan touch input.
    ///
    /// Defaults to `true`.
    @_documentation(visibility: public)
    func transitionsToIdleUponUserInteraction(_ value: Bool) -> Self {
        copyAssigned(self, \.mapDependencies.viewportOptions.transitionsToIdleUponUserInteraction, value)
    }

    /// When `true`, all viewport states increase the camera padding by the amount of the safe area insets.
    ///
    /// The following formula is used to calculate the camera padding:
    /// ```
    /// safe area insets = view safe area insets + additional safe area insets
    /// camera padding = viewport padding + safe area insets
    /// ```
    ///
    /// If your view has some UI elements on top of the map and you want them to be padded,
    /// use ``Map/additionalSafeAreaInsets(_:)`` to specify an additional amount of safe area insets.
    ///
    /// - Note: ``MapViewAnnotation`` will respect the padding area and will be placed outside of it.
    ///
    /// Defaults to `true`.
    @_documentation(visibility: public)
    func usesSafeAreaInsetsAsPadding(_ value: Bool) -> Self {
        copyAssigned(self, \.mapDependencies.viewportOptions.usesSafeAreaInsetsAsPadding, value)
    }

    /// Amount of additional safe area insets.
    ///
    /// If called multiple times, the last call wins. This property behaves identically to the
    /// `UIViewController.additionalSafeAreaInsets`.
    ///
    /// - Note: This property cannot be animated.
    @_documentation(visibility: public)
    func additionalSafeAreaInsets(_ insets: SwiftUI.EdgeInsets) -> Self {
        copyAssigned(self, \.mapDependencies.additionalSafeArea, insets)
    }

    /// Collects CPU, GPU resource usage and timings of layers and rendering groups over a user-configurable sampling duration.
    /// Use the collected information to find which layers or rendering groups might be performing poorly.
    ///
    /// Use ``PerformanceStatisticsOptions`` to configure the following collection behaviours:
    ///     - Which types of sampling to perform, whether cumulative, per-frame, or both.
    ///     - Duration of sampling in milliseconds. Value 0 forces the collection of performance statistics every frame.
    ///
    /// Utilize ``PerformanceStatisticsCallback`` to observe the collected performance statistics. The callback function is invoked
    /// after the configured sampling duration has elapsed. The callback is invoked on the main thread. The collection process is
    /// continuous; without user-input, it restarts after each callback invocation.
    /// - Note: Specifying a negative sampling duration or omitting the callback function will result in no operation, which will be logged for visibility.
    /// - Note: The statistics collection can be canceled by setting `nil` to the options parameter.
    /// The callback function will be called every time the configured sampling duration ``PerformanceStatisticsOptions/sasamplingDurationMillis has elapsed.
    ///
    /// - Parameters:
    ///   - options The statistics collection options to collect.
    ///   - callback The callback to be invoked when performance statistics are available.
    /// - Returns:  An ``AnyCancelable`` object that can be used to cancel performance statistics collection.
    @_documentation(visibility: public)
    func collectPerformanceStatistics(_ options: PerformanceStatisticsOptions?, callback: @escaping (PerformanceStatistics) -> Void) -> Self {
        copyAssigned(self, \.mapDependencies.performanceStatisticsParameters, options.map { PerformanceStatisticsParameters(options: $0, callback: callback) })
    }

    /// Sets the amount of additional safe area insets for the given edges.
    ///
    /// If called multiple times, the last call wins. This property behaves identically to the
    /// `UIViewController.additionalSafeAreaInsets`.
    ///
    /// - Note: This property cannot be animated.
    @_documentation(visibility: public)
    func additionalSafeAreaInsets(_ edges: Edge.Set = .all, _ length: CGFloat) -> Self {
        var copy = self
        copy.mapDependencies.additionalSafeArea.updateEdges(edges, length)
        return copy
    }
}

@available(iOS 13.0, *)
extension Map {

    /// Map Coordinator.
    public final class Coordinator {
        let basic: MapBasicCoordinator
        let viewAnnotation: ViewAnnotationCoordinator
        let layerAnnotation: LayerAnnotationCoordinator
        let viewController: UIViewController
        let urlOpener: ClosureURLOpener
        let mapView: MapView

        init(
            basic: MapBasicCoordinator,
            viewAnnotation: ViewAnnotationCoordinator,
            layerAnnotation: LayerAnnotationCoordinator,
            viewController: UIViewController,
            urlOpener: ClosureURLOpener,
            mapView: MapView
        ) {
            self.basic = basic
            self.viewAnnotation = viewAnnotation
            self.layerAnnotation = layerAnnotation
            self.viewController = viewController
            self.urlOpener = urlOpener
            self.mapView = mapView
        }
    }

    private final class MapViewController: UIViewController {
        private let mapView: MapView

        init(mapView: MapView) {
            self.mapView = mapView
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.addConstrained(child: mapView)
            mapView.mapboxMap.size = view.bounds.size
        }
    }
}

@available(iOS 13.0, *)
private extension Binding {
    var setter: (Value) -> Void {
        { self.wrappedValue = $0 }
    }
}

@available(iOS 13.0, *)
private extension ConstantOrBinding {
    var setter: ((T) -> Void)? {
        switch self {
        case .constant:
            return nil
        case .binding(let binding):
            return binding.setter
        }
    }
}
