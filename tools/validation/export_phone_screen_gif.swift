// Run after tests/stream/render_phone_screen.gd. Uses macOS frameworks only.
import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

let frames = URL(fileURLWithPath: "/tmp/hypster_phone_screen_frames")
let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("source_art/prototypes/stream/phone_screen_v18/phone_screen.gif")
let frameCount = 48
guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, frameCount, nil) else {
    fatalError("Cannot create phone-screen preview")
}
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for index in 0..<frameCount {
    let url = frames.appendingPathComponent(String(format: "detail_%03d.png", index))
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fatalError("Missing animation frame: \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 2.0 * Double.pi / Double(frameCount)]] as CFDictionary)
}
guard CGImageDestinationFinalize(destination),
      let verify = CGImageSourceCreateWithURL(output as CFURL, nil),
      CGImageSourceGetCount(verify) == frameCount else {
    fatalError("GIF verification failed")
}
print("48 rendered frames: \(output.path)")
