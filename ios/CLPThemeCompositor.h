#import <AVKit/AVKit.h>

@interface CLPThemeCompositor : NSObject<AVVideoCompositing>

@property (nonatomic, retain) NSString *theme;
@property (nonatomic, retain) UIImage *icon;
@property (nonatomic, retain) UIImage *logo;
@property (nonatomic, retain) UIImage *arrow;
@property (nonatomic, retain) NSDictionary *composition;

@end
