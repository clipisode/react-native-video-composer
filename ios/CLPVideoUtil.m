#import <AVKit/AVKit.h>
#import <React/RCTViewManager.h>
#import <React/RCTUIManager.h>
#import "CLPThemePainter.h"

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

RCT_EXPORT_METHOD(generateSticker:(NSString *)outputPath
                  composition:(NSDictionary *)composition
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  // Passing a NULL data parameter causes CGBitmapContextCreate to allocate and manage the memory automatically
  void *data = NULL;
  size_t stickerWidth = 1000;
  size_t stickerHeight = 500;
  size_t bitsPerComponent = 8;
  // The number of bytes of memory to use per row of the bitmap.
  // If the data parameter is NULL, passing a value of 0 causes the value to be calculated automatically.
  // https://developer.apple.com/documentation/coregraphics/1455939-cgbitmapcontextcreate
  size_t bytesPerRow = 0;
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  // From https://stackoverflow.com/a/51021149
  uint32_t bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst;;
  
  CGContextRef context = CGBitmapContextCreate(data, stickerWidth, stickerHeight, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo);
  UIGraphicsPushContext(context);
  
  CLPThemePainter *painter = [[CLPThemePainter alloc] initWithHeight:@500.0];
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
