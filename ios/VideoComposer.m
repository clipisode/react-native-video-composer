#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <AVKit/AVKit.h>

@interface VideoComposer : RCTEventEmitter <RCTBridgeModule>
{
  NSMutableDictionary *_compositionsData;
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
    
    _compositionsData = [NSMutableDictionary dictionary];
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
  // SETUP DATA OBJECT AND CHECK FOR EXISTING EXPORT
  
  NSMutableDictionary *compositionData = _compositionsData[exportId];
  
  if (compositionData) {
    reject(@"Duplicate", @"A composition with this exportId is already in progress.", nil);
    return;
  }
  
  compositionData = [NSMutableDictionary dictionary];
  [_compositionsData setObject:compositionData forKey:exportId];
  
  // BEGIN COMPOSITION SETUP
  
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
  
  AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
  [compositionData setObject:exporter forKey:@"exportSession"];
  
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
      if (exporter.status == AVAssetExportSessionStatusExporting) {
        NSMutableDictionary *body = [NSMutableDictionary dictionary];
        [body setObject:exportId forKey:@"id"];
        [body setObject:[NSNumber numberWithFloat:exporter.progress] forKey:@"progress"];
          
        [self sendEventWithName:@"@clipisode/react-native-video-composer:progress" body:body];
      } else if (exporter.status == AVAssetExportSessionStatusCompleted) {
        [timer invalidate];
        [self->_compositionsData removeObjectForKey:exportId];
      }
    }];
    [compositionData setObject:timer forKey:@"timer"];
  });
}

RCT_EXPORT_METHOD(cancel:(NSString *)exportId)
{
  NSMutableDictionary *compositionData = _compositionsData[exportId];
  
  if (!compositionData) {
    NSLog(@"Composition data not found for given exportId.");
  } else {
    AVAssetExportSession *exportSession = compositionData[@"exportSession"];
    NSTimer *timer = compositionData[@"timer"];
    
    if (timer) {
      [timer invalidate];
    }
    
    if (exportSession) {
      [exportSession cancelExport];
    }
    
    [_compositionsData removeObjectForKey:exportId];
  }
}

@end
