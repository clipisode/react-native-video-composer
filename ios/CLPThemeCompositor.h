#import <AVKit/AVKit.h>

@interface CLPThemeCompositor : NSObject<AVVideoCompositing>
- (void)setCALayer:(CALayer *)layer;
@end
