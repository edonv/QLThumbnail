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
    var url: URL
    var size: CGSize
    var scale: CGFloat
    var representationTypes: QLThumbnailGenerator.Request.RepresentationTypes
    /// This property is only relevant in iOS 14+ and macOS 11+.
    ///
    /// This is because [`quickLookPreview(_:)`](https://developer.apple.com/documentation/swiftui/view/quicklookpreview(_:)) is what's used behind the scenes.
    var tapToPreview: Bool = false
    
    @State private var thumbnail: QLThumbnailRepresentation? = nil
    @State private var previewItem: URL? = nil
    
    @ViewBuilder
    public var body: some View {
        Group {
            if let image {
                Group {
                    if #available(iOS 14, macOS 11, *) {
                        image
                            .quickLookPreview($previewItem)
                    } else {
                        image
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
    
    var image: Image? {
        #if canImport(UIKit)
        guard let uiImage = thumbnail?.uiImage else { return nil }
        return Image(uiImage: uiImage)
        #else
        guard let nsImage = thumbnail?.nsImage else { return nil }
        return Image(nsImage: nsImage)
        #endif
    }
    
    var request: QLThumbnailGenerator.Request {
        QLThumbnailGenerator.Request(fileAt: url,
                                     size: size,
                                     scale: scale,
                                     representationTypes: representationTypes)
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
                @unknown default:
                    break
//                default:
//                    break
                }
            }
        }
    }
}
