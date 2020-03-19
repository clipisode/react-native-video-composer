#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

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
  resolve(nil);
}

@end

//@interface RCT_EXTERN_MODULE(VideoComposer, NSObject)
//
//+ (BOOL)requiresMainQueueSetup
//{
//  return NO;
//}
//
//RCT_EXTERN_METHOD(cancel:(NSString *)exportId)
//RCT_EXTERN_METHOD(compose:(NSDictionary *)composition id:(NSString *)exportId outPath:(NSString *)outPath resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
//
//@end
