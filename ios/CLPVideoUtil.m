#import <AVKit/AVKit.h>
#import <React/RCTViewManager.h>
#import <React/RCTUIManager.h>

@interface CLPVideoUtil : RCTViewManager <RCTBridgeModule>
@end

@implementation CLPVideoUtil

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(getDuration:(NSString *)videoPath
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSURL *url = [NSURL URLWithString:videoPath];
  AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:@{AVURLAssetPreferPreciseDurationAndTimingKey:@YES}];
  
  double seconds = CMTimeGetSeconds(asset.duration);
  NSNumber *duration = [NSNumber numberWithDouble:seconds];
  
  resolve(duration);
}

@end
