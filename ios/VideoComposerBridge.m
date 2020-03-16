#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(VideoComposer, NSObject)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

RCT_EXTERN_METHOD(compose:(NSDictionary *)composition outPath:(NSString *)outPath resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end
