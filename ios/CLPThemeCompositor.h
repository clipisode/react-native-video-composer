#import <AVKit/AVKit.h>

@interface CLPThemeCompositor : NSObject<AVVideoCompositing>

@property (nonatomic, retain) NSString *theme;
@property (nonatomic, retain) UIImage *logo;

@end
