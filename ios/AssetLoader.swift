import Foundation
import AVFoundation

@objc
class AssetLoader : NSObject {
  var assets: Dictionary<String, AVAsset> = [:];
  
  @objc
  func load(key: String, filePath: String) -> AVAsset {
    var asset: AVAsset? = assets[key];
    
    var url: URL? = nil
    
    if filePath.contains("://") {
      url = URL(string: filePath)
    } else {
      url = URL(fileURLWithPath: filePath)
    }
    
    if asset == nil, let u = url {
      asset = AVURLAsset(
        url: u,
        options: [AVURLAssetPreferPreciseDurationAndTimingKey:true]
      )
      assets[key] = asset;
    }
    
    return asset!;
  }
}
