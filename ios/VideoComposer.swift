@objc(VideoComposer)
class VideoComposer: NSObject {
  override init() {
  }
  
  @objc
  func compose(resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {
    resolve();
  }
}
