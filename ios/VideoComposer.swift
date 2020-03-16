import AVKit

@objc(VideoComposer)
class VideoComposer: NSObject {
  override init() {
  }
  
  @objc
  func compose(_ composition: NSDictionary, outPath outputPath: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {
    let videos: NSArray? = composition["videos"] as? NSArray;
    
    if (videos != nil && videos!.count > 0) {
      build(videos: videos!, outputPath: outputPath, resolver: resolve)
    } else {
      resolve(nil);
    }
  }
  
  func build(videos: NSArray, outputPath: String, resolver resolve: @escaping RCTPromiseResolveBlock) {
    let mixComposition = AVMutableComposition();
    
    let videoTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid);
    
    var lastEndTime: CMTime = .zero;
    
    for video in videos {
      let path = (video as! NSDictionary)["path"] as! String;
      let startAt = (video as! NSDictionary)["startAt"] as! NSNumber;
      
      let url = URL.init(string: path)!;
      let asset = AVAsset.init(url: url);
        
      let range: CMTimeRange = CMTimeRangeMake(start: .zero, duration: asset.duration);
      
      do {
        let assetVideoTracks: [AVAssetTrack] = asset.tracks(withMediaType: .video)
        let firstVideoTrack: AVAssetTrack = assetVideoTracks.first!;
        
        try videoTrack!.insertTimeRange(range, of: firstVideoTrack, at: lastEndTime)
      } catch { print("test"); };
            
      lastEndTime = CMTimeAdd(lastEndTime, asset.duration);
    }
  
    // 3.1 - Create AVMutableVideoCompositionInstruction
    let mainInstruction = AVMutableVideoCompositionInstruction()
    mainInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: lastEndTime);

    // 3.2 - Create an AVMutableVideoCompositionLayerInstruction for the video track and fix the orientation.
    let videolayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack!)
//    let videoAssetTrack = asset.tracks(withMediaType: .video)[0]
//    var videoAssetOrientation_: UIImage.Orientation = .up
//    var isVideoAssetPortrait_ = false
//    let videoTransform = videoAssetTrack.preferredTransform
//    if videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0 {
//        videoAssetOrientation_ = UIImage.Orientation.right
//        isVideoAssetPortrait_ = true
//    }
//    if videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0 {
//        videoAssetOrientation_ = UIImage.Orientation.left
//        isVideoAssetPortrait_ = true
//    }
//    if videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0 {
//        videoAssetOrientation_ = UIImage.Orientation.up
//    }
//    if videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0 {
//        videoAssetOrientation_ = UIImage.Orientation.down
//    }
//    videolayerInstruction.setTransform(videoAssetTrack.preferredTransform, at: .zero)
    videolayerInstruction.setOpacity(0.0, at: lastEndTime)

    // 3.3 - Add instructions
    mainInstruction.layerInstructions = [videolayerInstruction]
    


    let mainCompositionInst = AVMutableVideoComposition()

//    var naturalSize: CGSize
//    if isVideoAssetPortrait_ {
//        naturalSize = CGSize(width: videoAssetTrack.naturalSize.height, height: videoAssetTrack.naturalSize.width)
//    } else {
//        naturalSize = videoAssetTrack.naturalSize
//    }
//
//
//    var renderWidth: Float
//    var renderHeight: Float
//    renderWidth = Float(naturalSize.width)
//    renderHeight = Float(naturalSize.height)
    mainCompositionInst.renderSize = CGSize(width: CGFloat(720), height: CGFloat(1280))
    mainCompositionInst.instructions = [mainInstruction]
    mainCompositionInst.frameDuration = CMTimeMake(value: 1, timescale: 30)

    // 5 - Create exporter
    let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
    exporter?.outputURL = URL(string: outputPath)
    exporter?.outputFileType = .mp4
    exporter?.shouldOptimizeForNetworkUse = true
    exporter?.videoComposition = mainCompositionInst
    exporter?.exportAsynchronously(completionHandler: {
        DispatchQueue.main.async(execute: {
          resolve(nil);
        })
    })
  }
}
