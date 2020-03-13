@objc(VideoComposer)
class VideoComposer: NSObject {
  override init() {
  }
  
  @objc
  func compose(_ one: String, url two: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {
    resolve("Hello");
  }
}
