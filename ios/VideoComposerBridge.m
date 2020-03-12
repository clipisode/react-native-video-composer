#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(VideoComposer, NSObject)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

RCT_EXTERN_METHOD(compose:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end
