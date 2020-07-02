import Foundation
import CoreImage
import CoreMedia
import CoreGraphics
import AVFoundation
import UIKit

@objc
class ThemeCompositor : NSObject, AVVideoCompositing {
  @objc
  var manifest: Dictionary<String, Any>? = nil
  
  @objc
  var manager: CompositionManager? = nil
  
  func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
    if (self.manifest == nil) {
//      request.finish(with: nil)
      return
    }
    
    let manifest = self.manifest!
    
    if let destination = request.renderContext.newPixelBuffer() {
      CVPixelBufferLockBaseAddress(destination, CVPixelBufferLockFlags(rawValue: 0))
      
      let destinationWidth: Int = CVPixelBufferGetWidth(destination)
      let destinationHeight: Int = CVPixelBufferGetHeight(destination)
      let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB();
      
      let destinationBaseAddress: UnsafeMutableRawPointer? = CVPixelBufferGetBaseAddress(destination)
      let bytesPerRow: size_t = CVPixelBufferGetBytesPerRow(destination)
      let bitmapInfo: CGBitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
      
      let context: CGContext? = CGContext(
        data: destinationBaseAddress,
        width: destinationWidth,
        height: destinationHeight,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
      )
      
      if context != nil, manager != nil {
        renderIntoContext(context!, manifest: manifest, manager: manager!, request: request)
      }
      
      CVPixelBufferUnlockBaseAddress(destination, CVPixelBufferLockFlags(rawValue: 0));
      
      request.finish(withComposedVideoFrame: destination)
    } else {
//      request.finish(with: nil)
    }
  }
  
  func renderElements(_ elements: Array<[String:Any]>, at: CMTime, request: AVAsynchronousVideoCompositionRequest, painter: ElementPainter) {
    for element in elements {
      let startAtConfig = element["startAt"] as? Double ?? 0.0
      let endAtConfig = element["endAt"] as? Double

      let startAt: CMTime = CMTime(seconds: startAtConfig, preferredTimescale: 1000)
      let endAt: CMTime = endAtConfig == nil ? CMTime.positiveInfinity : CMTime(seconds: endAtConfig!, preferredTimescale: 1000)
      
      if TweenHelper.isTimeInRange(time: at, from: startAt, to: endAt) {
        if let type = element["type"] as? String, let props = element["props"] as? Props {
          let animations = element["animations"] as? Array<[String:Any]>
          let finalProps = TweenHelper.tweenAll(props: props, animations: animations, time: at)

          painter.drawElement(type: type, element: element, props: finalProps, at: at, compositionRequest: request)
        }
      }
    }
  }
  
  func renderIntoContext(_ context: CGContext, manifest: Dictionary<String, Any>, manager: CompositionManager, request: AVAsynchronousVideoCompositionRequest) {
    context.setAllowsAntialiasing(true)
    
    UIGraphicsPushContext(context)
    
    let painter = ElementPainter(context: context, height: 1280, manager: manager)
    
    painter.drawBackground()
    
    if let elements = manifest["elements"] as? Array<[String:Any]> {
      if let teaserVideoDurationConfig = manifest["teaserVideoDuration"] as? Double {
        let teaserVideoDuration = CMTimeSubtract(CMTime(seconds: teaserVideoDurationConfig, preferredTimescale: 1000), CMTime(value: 1, timescale: 30))
        
        renderElements(elements, at: CMTimeMinimum(request.compositionTime, teaserVideoDuration), request: request, painter: painter)
      } else {
        renderElements(elements, at: request.compositionTime, request: request, painter: painter)
      }
    }
    
    if let teaserElements = manifest["teaserElements"] as? Array<[String:Any]> {
      renderElements(teaserElements, at: request.compositionTime, request: request, painter: painter)
    }
    
    UIGraphicsPopContext();
  }
  
  func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
    
  }
  
  func cancelAllPendingVideoCompositionRequests() {
    
  }
  
  var requiredPixelBufferAttributesForRenderContext: [String : Any] = [
    String(kCVPixelBufferPixelFormatTypeKey): [kCVPixelFormatType_32BGRA]
  ]
  
  var sourcePixelBufferAttributes: [String : Any]? = [
    String(kCVPixelBufferPixelFormatTypeKey): [kCVPixelFormatType_32BGRA]
  ]
}
