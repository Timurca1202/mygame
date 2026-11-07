// Run after tests/stream/render_catalog_preview.gd; macOS frameworks only.
import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("source_art/prototypes/stream/catalog_airflow_v07.gif")
let frames = URL(fileURLWithPath: "/tmp/hypster_fan_frames")
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, 12, nil)!
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for index in 0..<12 {
    let path = frames.appendingPathComponent(String(format: "frame_%02d.png", index))
    let source = CGImageSourceCreateWithURL(path as CFURL, nil)!
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 6.0]] as CFDictionary)
}
precondition(CGImageDestinationFinalize(destination))
let verify = CGImageSourceCreateWithURL(output as CFURL, nil)!
precondition(CGImageSourceGetCount(verify) == 12)
print("12 animated frames: \(output.path)")
