//
//  QuickLook+SwiftUI.swift
//  QLThumbnail
//
//  Created by Edon Valdman on 6/22/23.
//

import SwiftUI
import QuickLook
import QuickLookThumbnailing

import SwiftUIBackports

public struct QLThumbnail: View {
    /// The URL of the file for which you want to create a thumbnail.
    public var url: URL
    
    /// The desired size of the thumbnails.
    ///
    /// This is the actual size of the thumbnail image.
    public var resolution: CGSize
    
    /// The pixel density of the display on the intended device.
    ///
    /// This property represents the scale factor, or pixel density, of the device’s display as described in [Image Size and Resolution](https://developer.apple.com/design/human-interface-guidelines/images). For example, the value for a device with a `@2x` display is `2.0`.
    ///
    /// You can pass the initializer a screen scale that isn’t the current device’s screen scale. For example, you can create thumbnails for different scales, upload them to a server, and download them later on devices with a different screen scale.
    public var scale: CGFloat
    
    /// The thumbnail sizes that you provide for a thumbnail request.
    ///
    /// The representation types provide access to icon, low-quality, and high-quality thumbnails so you can request and show a lower-quality thumbnail quickly while computing a higher-quality thumbnail in the background.
    public var representationTypes: QLThumbnailGenerator.Request.RepresentationTypes
    
    /// Whether tapping the thumbnail will show a full-screen preview of the file.
    ///
    /// This property is only relevant in iOS 14+ and macOS 11+. This is because [`quickLookPreview(_:)`](https://developer.apple.com/documentation/swiftui/view/quicklookpreview(_:)) is what's used behind the scenes.
    public var tapToPreview: Bool
    
    /// Whether the resulting thumbnail should be allowed to resize to fit its space. When this is set to `false`, it will stay at the image size set by ``resolution``.
    ///
    /// Internally, this enables the use of [.resizable(capInsets:resizingMode:)](https://developer.apple.com/documentation/swiftui/image/resizable(capinsets:resizingmode:)).
    public var resizable: Bool
    
    /// Creates a thumbnail view of the file at the provided URL.
    /// - Parameters:
    ///   - url: The URL of the file for which you want to create a thumbnail.
    ///   - resolution: The desired size of the thumbnails (the actual size of the thumbnail image).
    ///   - scale: The scale of the thumbnails. This parameter usually represents the scale of the current screen. However, you can pass a screen scale to the initializer that isn’t the current device’s screen scale. For example, you can create thumbnails for different scales and upload them to a server in order to download them later on devices with a different screen scale.
    ///   - representationTypes: The different thumbnail types. For a list of all possible thumbnail representation types, see [QLThumbnailGenerator.Request.RepresentationTypes](https://developer.apple.com/documentation/quicklookthumbnailing/qlthumbnailgenerator/request/representationtypes).
    ///   - tapToPreview: Whether tapping the thumbnail will show a full-screen preview of the file.
    ///   - resizable: Whether the resulting thumbnail should be allowed to resize to fit its space. When this is set to `false`, it will stay at the image size set by `resolution`.
    public init(url: URL, resolution: CGSize, scale: CGFloat, representationTypes: QLThumbnailGenerator.Request.RepresentationTypes, tapToPreview: Bool = false, resizable: Bool = false) {
        self.url = url
        self.resolution = resolution
        self.scale = scale
        self.representationTypes = representationTypes
        self.tapToPreview = tapToPreview
        self.resizable = resizable
    }
    
    @State private var thumbnail: QLThumbnailRepresentation? = nil
    @State private var previewItem: URL? = nil
    
    @ViewBuilder
    public var body: some View {
        Group {
            if let image {
                Group {
                    if #available(iOS 14, macOS 11, *) {
                        image
                            .if(resizable) {
                                $0.resizable()
                            }
                            .quickLookPreview($previewItem)
                    } else {
                        image
                            .if(true) {
                                $0.resizable()
                            }
                    }
                }
                .onTapGesture {
                    guard tapToPreview else { return }
                    previewItem = url
                }
            } else {
                ProgressView()
            }
        }
        .backport.task {
            do {
                for try await thumb in QLThumbnailGenerator.shared.generateRepresentations(for: request) {
                    thumbnail = thumb
                }
            } catch {
                print("Error creating thumbnails:", error as NSError)
            }
        }
    }
    
    private var image: Image? {
        #if canImport(UIKit)
        guard let uiImage = thumbnail?.uiImage else { return nil }
        return Image(uiImage: uiImage)
        #else
        guard let nsImage = thumbnail?.nsImage else { return nil }
        return Image(nsImage: nsImage)
        #endif
    }
    
    private var request: QLThumbnailGenerator.Request {
        QLThumbnailGenerator.Request(fileAt: url,
                                     size: resolution,
                                     scale: scale,
                                     representationTypes: representationTypes)
    }
}

extension QLThumbnail {
    /// Creates a thumbnail view of the file at the provided URL.
    /// - Parameters:
    ///   - url: The URL of the file for which you want to create a thumbnail.
    ///   - resolution: The desired size of the thumbnails (the actual size of the thumbnail image). This value will be used as both the `width` and `height`.
    ///   - scale: The scale of the thumbnails. This parameter usually represents the scale of the current screen. However, you can pass a screen scale to the initializer that isn’t the current device’s screen scale. For example, you can create thumbnails for different scales and upload them to a server in order to download them later on devices with a different screen scale.
    ///   - representationTypes: The different thumbnail types. For a list of all possible thumbnail representation types, see [QLThumbnailGenerator.Request.RepresentationTypes](https://developer.apple.com/documentation/quicklookthumbnailing/qlthumbnailgenerator/request/representationtypes).
    ///   - tapToPreview: Whether tapping the thumbnail will show a full-screen preview of the file.
    ///   - resizable: Whether the resulting thumbnail should be allowed to resize to fit its space. When this is set to `false`, it will stay at the image size set by `resolution`.
    public init(url: URL, resolution: CGFloat, scale: CGFloat, representationTypes: QLThumbnailGenerator.Request.RepresentationTypes, tapToPreview: Bool = false, resizable: Bool = false) {
        self.url = url
        self.resolution = .init(width: resolution, height: resolution)
        self.scale = scale
        self.representationTypes = representationTypes
        self.tapToPreview = tapToPreview
        self.resizable = resizable
    }
}

extension QLThumbnailGenerator {
    public func generateRepresentations(for request: Request) -> AsyncThrowingStream<QLThumbnailRepresentation, Error> {
        AsyncThrowingStream(QLThumbnailRepresentation.self) { continuation in
            self.generateRepresentations(for: request) { thumbnail, type, error in
                if let thumbnail {
                    continuation.yield(thumbnail)
                } else {
                    continuation.finish(throwing: error)
                }
                
                switch type {
                case .thumbnail:
                    continuation.finish()
                case .icon:
                    fallthrough
                case .lowQualityThumbnail:
                    fallthrough
                @unknown default:
                    break
                }
            }
        }
    }
}
