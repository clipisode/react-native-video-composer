#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <AVKit/AVKit.h>

@interface VideoComposer : RCTEventEmitter <RCTBridgeModule>
{
  
}
@end

@implementation VideoComposer

RCT_EXPORT_MODULE();

static RCTEventEmitter* staticEventEmitter = nil;

+ (BOOL)requiresMainQueueSetup {
    return NO;
}

- (id) init {
  self = [super init];
  if (self) {
    staticEventEmitter = self;
//    _responsesData = [NSMutableDictionary dictionary];
  }
  return self;
}


- (void)_sendEventWithName:(NSString *)eventName body:(id)body {
  if (staticEventEmitter == nil)
    return;

  [staticEventEmitter sendEventWithName:eventName body:body];
}

- (NSArray<NSString *> *)supportedEvents {
    return @[
        @"@clipisode/react-native-video-composer:progress",
        @"@clipisode/react-native-video-composer:error"
    ];
}

// --------------------
// -- IMPLEMENTATION --
// --------------------

RCT_EXPORT_METHOD(compose:(NSDictionary *)composition id:(NSString *)exportId outPath:(NSString *)outPath resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
  AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
  
  CMTime lastEndTime = kCMTimeZero;
  
  NSArray *videos = composition[@"videos"];
  
  for (NSDictionary* video in videos) {
    NSString *path = video[@"path"];
    // NSNumber* startAt = video[@"startAt"];
    
    NSURL *url = [NSURL URLWithString:path];
    AVAsset *asset = [AVAsset assetWithURL:url];
    
    CMTimeRange range = CMTimeRangeMake(kCMTimeZero, asset.duration);
    NSArray* assetVideoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack* firstVideoTrack = assetVideoTracks[0];
    [videoTrack insertTimeRange:range ofTrack:firstVideoTrack atTime:lastEndTime error:nil];
          
    lastEndTime = CMTimeAdd(lastEndTime, asset.duration);
  }
  
  AVMutableVideoCompositionInstruction *mainInstruction = [[AVMutableVideoCompositionInstruction alloc] init];
  mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, lastEndTime);
  
  AVMutableVideoCompositionLayerInstruction *videolayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
  [videolayerInstruction setOpacity:0.0 atTime:lastEndTime];
  
  mainInstruction.layerInstructions = [NSArray arrayWithObjects:videolayerInstruction, nil];

  AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
  
  mainCompositionInst.renderSize = CGSizeMake(720.0, 1280.0);
  
  mainCompositionInst.instructions = [NSArray arrayWithObject:mainInstruction];
  mainCompositionInst.frameDuration = CMTimeMake(1, 30);
  
  
  // -- EXPORT
  
  AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];

  exporter.outputURL = [NSURL URLWithString:outPath];
  exporter.outputFileType = AVFileTypeMPEG4;
  exporter.shouldOptimizeForNetworkUse = YES;
  exporter.videoComposition = mainCompositionInst;
  [exporter exportAsynchronouslyWithCompletionHandler:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      resolve(nil);
    });
  }];
  
  dispatch_async(dispatch_get_main_queue(), ^{
  NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (exporter.status == AVAssetExportSessionStatusExporting) {
        printf("%f\n", exporter.progress);
        
        NSMutableDictionary *body = [NSMutableDictionary dictionary];
        [body setObject:[NSNumber numberWithFloat:exporter.progress] forKey:@"progress"];
        
        [self sendEventWithName:@"@clipisode/react-native-video-composer:progress" body:body];
      } else {
        [timer invalidate];
      }
    });
  }];});
  
//
//      let _ = Timer(timeInterval: 0.1, repeats: true) { timer in
//        if (exporter!.status == .exporting) {
//          print("status")
//          print(exporter!.status)
//  //        sendEvent(withName: "onProgress", body: ["progress": exporter!.progress])
//        } else {
//          timer.invalidate()
//        }
//      }
//
//      exporters[id] = exporter;
}

RCT_EXPORT_METHOD(cancel:(NSString *)exportId)
{
  // TODO: Implement
}

@end
