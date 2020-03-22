#import <AVKit/AVKit.h>
#import <React/RCTViewManager.h>
#import <React/RCTUIManager.h>
#import "CLPVideo.m"

@interface CLPCompositionPlayerManager : RCTViewManager <RCTBridgeModule>
@end

@implementation CLPCompositionPlayerManager

RCT_EXPORT_MODULE()

- (UIView *)view
{
  CLPVideo *video = [[CLPVideo alloc] init];
  
  return video;
}

RCT_EXPORT_VIEW_PROPERTY(composition, NSDictionary);
RCT_EXPORT_VIEW_PROPERTY(paused, BOOL);
RCT_EXPORT_VIEW_PROPERTY(rate, float);
RCT_EXPORT_VIEW_PROPERTY(seek, NSDictionary);
RCT_EXPORT_VIEW_PROPERTY(onVideoProgress, RCTDirectEventBlock);

RCT_EXPORT_METHOD(save:(NSString *)outPath
        reactTag:(nonnull NSNumber *)reactTag
        resolver:(RCTPromiseResolveBlock)resolve
        rejecter:(RCTPromiseRejectBlock)reject)
{
    [self.bridge.uiManager prependUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, CLPVideo *> *viewRegistry) {
        CLPVideo *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[CLPVideo class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting CLPVideo, got: %@", view);
        } else {
          [view save:outPath resolve:resolve reject:reject];
        }
    }];
}

@end
