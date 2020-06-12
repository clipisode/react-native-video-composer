#import <AVKit/AVKit.h>
#import <React/RCTViewManager.h>
#import <React/RCTUIManager.h>
#import "CLPThemePainter.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "CLPThemeCompositor.h"
#import "CLPCompositionManager.h"

@interface CLPVideoUtil : RCTViewManager <RCTBridgeModule>
@end

@implementation CLPVideoUtil

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(getDuration:(NSString *)videoUri
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSURL *url = [NSURL URLWithString:videoUri];
  AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:@{AVURLAssetPreferPreciseDurationAndTimingKey:@YES}];
  
  double seconds = CMTimeGetSeconds(asset.duration);
  NSNumber *duration = [NSNumber numberWithDouble:seconds];
  
  resolve(duration);
}

RCT_EXPORT_METHOD(shareInstagramStory:(NSString *)videoFileUri
                  stickerPath:(NSString *)stickerPath
                  url:(NSString *)attributionURL
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSURL *urlScheme = [NSURL URLWithString:@"instagram-stories://share"];
  
  dispatch_async(dispatch_get_main_queue(), ^{
    if ([[UIApplication sharedApplication] canOpenURL:urlScheme]) {
      NSURL *videoUrl = [NSURL URLWithString:videoFileUri];
      NSData *backgroundVideo = [NSData dataWithContentsOfURL:videoUrl];
      NSData *stickerImage = NULL;
      
      
          // Assign background image asset and attribution link URL to pasteboard
      NSMutableDictionary *items = [NSMutableDictionary dictionaryWithDictionary:@{@"com.instagram.sharedSticker.backgroundVideo" : backgroundVideo,
                                         @"com.instagram.sharedSticker.contentURL" : attributionURL }];
      
      if (stickerPath != nil) {
        stickerImage = [NSData dataWithContentsOfURL:[NSURL URLWithString:stickerPath]];
        items[@"com.instagram.sharedSticker.stickerImage"] = stickerImage;
      }

      NSArray *pasteboardItems = @[items];

      NSDictionary *pasteboardOptions = @{UIPasteboardOptionExpirationDate : [[NSDate date] dateByAddingTimeInterval:60 * 5]};
      // This call is iOS 10+, can use 'setItems' depending on what versions you support
      [[UIPasteboard generalPasteboard] setItems:pasteboardItems options:pasteboardOptions];

      [[UIApplication sharedApplication] openURL:urlScheme options:@{} completionHandler:^(BOOL success) {
        if (success) {
          resolve(nil);
        } else {
          reject(@"Unknown Error", @"Unknown Error", nil);
        }
      }];
    } else {
        reject(@"Unknown Error", @"Unknown Error", nil);
    }
  });
}

RCT_EXPORT_METHOD(exportTeaser:(NSString *)outputPath
                  manifest:(NSDictionary *)manifest
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSNumber *duration = manifest[@"teaserDuration"];
  
  CLPCompositionManager *manager = [[CLPCompositionManager alloc] initWithManifest:manifest];
  
  AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:manager.composition presetName:AVAssetExportPreset1280x720];
  
  exportSession.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMake([duration intValue], 1000));
  exportSession.outputURL = [NSURL URLWithString:outputPath];
  exportSession.outputFileType = AVFileTypeMPEG4;
   
  exportSession.videoComposition = manager.videoComposition;
   
  if (exportSession.customVideoCompositor) {
    if ([exportSession.customVideoCompositor isKindOfClass:[CLPThemeCompositor class]]) {
      CLPThemeCompositor *themeCompositor = (id)exportSession.customVideoCompositor;
       
      [themeCompositor setIcon:[UIImage imageNamed:@"iconfortheme.png"]];
      [themeCompositor setLogo:[UIImage imageNamed:@"logofortheme.png"]];
      [themeCompositor setArrow:[UIImage imageNamed:@"swipearrow.png"]];
      [themeCompositor setComposition:manifest];
    }
  }
  
  [exportSession exportAsynchronouslyWithCompletionHandler:^{
    if (exportSession.status == AVAssetExportSessionStatusCompleted) {
      resolve(nil);
    } else if (exportSession.status == AVAssetExportSessionStatusFailed) {
      reject(@"Unknown", @"Unknown", exportSession.error);
    } else {
      reject(@"Unknown", @"Unknown", nil);
    }
  }];
}

RCT_EXPORT_METHOD(generateSticker:(NSString *)outputPath
                  composition:(NSDictionary *)composition
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  // Passing a NULL data parameter causes CGBitmapContextCreate to allocate and manage the memory automatically
  void *data = NULL;
  NSNumber *stickerWidth = (NSNumber *)composition[@"width"];
  NSNumber *stickerHeight = (NSNumber *)composition[@"height"];
  
  if (stickerWidth == nil) stickerWidth = @1000;
  if (stickerHeight == nil) stickerHeight = @500;

  size_t bitsPerComponent = 8;
  // The number of bytes of memory to use per row of the bitmap.
  // If the data parameter is NULL, passing a value of 0 causes the value to be calculated automatically.
  // https://developer.apple.com/documentation/coregraphics/1455939-cgbitmapcontextcreate
  size_t bytesPerRow = 0;
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  // From https://stackoverflow.com/a/51021149
  uint32_t bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst;;
  
  CGContextRef context = CGBitmapContextCreate(data, [stickerWidth intValue], [stickerHeight intValue], bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo);
  UIGraphicsPushContext(context);
  
  CLPThemePainter *painter = [[CLPThemePainter alloc] initWithHeight:stickerHeight];
  [painter setIcon:[UIImage imageNamed:@"iconfortheme.png"]];
  [painter setLogo:[UIImage imageNamed:@"logofortheme.png"]];
  [painter setArrow:[UIImage imageNamed:@"swipearrow.png"]];
  
  if (composition != nil) {
    NSArray *elements = composition[@"elements"];
    
    for (NSDictionary* element in elements) {
      NSString *type = (NSString *)element[@"type"];
      NSDictionary *props = (NSDictionary *)element[@"props"];
      
      [painter draw:type context:context props:props];
    }
  }
  UIGraphicsPopContext();
  
  CGImageRef bitmapImage = CGBitmapContextCreateImage(context);
  UIImage *image = [UIImage imageWithCGImage:bitmapImage];
  CGImageRelease(bitmapImage);

  NSData *imageData = UIImagePNGRepresentation(image);
  BOOL success = [imageData writeToFile:outputPath atomically:NO];
  
  CGColorSpaceRelease(colorSpace);
  CGContextRelease(context);
  
  if (success) {
    resolve(NULL);
  } else {
    reject(@"Unknown", @"Unknown", nil);
  }
}


@end
