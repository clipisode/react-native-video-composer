#import <AVKit/AVKit.h>
#import <React/RCTViewManager.h>
#import "CLPVideo.m"

@interface CLPCompositionPlayerManager : RCTViewManager
@end

@implementation CLPCompositionPlayerManager

RCT_EXPORT_MODULE(CLPCompositionPlayer)

- (UIView *)view
{
  CLPVideo *video = [[CLPVideo alloc] init];
  
  return video;
}

RCT_EXPORT_VIEW_PROPERTY(composition, NSDictionary)

@end
