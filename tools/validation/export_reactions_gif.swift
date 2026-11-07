// Run after tests/stream/render_reactions_preview.gd. Uses macOS frameworks only.
import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

let project = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let frames = URL(fileURLWithPath: "/tmp/hypster_reactions_frames")
let output = project.appendingPathComponent("source_art/prototypes/stream")
for (prefix, name) in [("frame", "stream_reactions_v05.gif"), ("detail", "hero_reactions_v05.gif")] {
    let url = output.appendingPathComponent(name)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 180, nil) else {
        fatalError("Cannot create GIF")
    }
    CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for index in 0..<180 {
        let frame = frames.appendingPathComponent(String(format: "%@_%03d.png", prefix, index))
        guard let source = CGImageSourceCreateWithURL(frame as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            fatalError("Missing frame: \(frame.path)")
        }
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 12.0]] as CFDictionary)
    }
    guard CGImageDestinationFinalize(destination) else { fatalError("GIF export failed") }
    let verify = CGImageSourceCreateWithURL(url as CFURL, nil)!
    precondition(CGImageSourceGetCount(verify) == 180)
    print("180 frames: \(url.path)")
}
