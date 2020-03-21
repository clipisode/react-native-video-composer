#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

@interface CLPVideo : UIView <AVPlayerViewControllerDelegate>
@end

@implementation CLPVideo
{
  AVPlayerViewController *_playerViewController;
  AVPlayer *_player;
  AVPlayerItem *_playerItem;
  NSDictionary *_composition;
}

- (instancetype)init
{
  if (self = [super init]) {
    _playerViewController = [[AVPlayerViewController alloc] init];
    
    [self addSubview:_playerViewController.view];
    _playerViewController.showsPlaybackControls = YES;
    _playerViewController.view.frame = self.bounds;
  }
  
  return self;
}

- (void)removeFromSuperview
{
  if (_playerViewController.player != nil) {
    [_playerViewController.player pause];
    _playerViewController.player = nil;
  }
  
  [_playerViewController.view removeFromSuperview];
  _playerViewController = nil;
  
  [super removeFromSuperview];
}

- (void)setComposition:(NSDictionary *)composition
{
  _composition = composition;
  
  [self load];
}

- (void)load
{
  NSDictionary *composition = _composition;
  // BEGIN COMPOSITION SETUP
  
  AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
  AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
  
  CMTime lastEndTime = kCMTimeZero;
  
  NSArray *videos = composition[@"videos"];
  
  for (NSDictionary* video in videos) {
    NSString *path = video[@"path"];
    // NSNumber* startAt = video[@"startAt"];
    
    NSURL *url = [NSURL URLWithString:path];
    AVAsset *asset = [AVAsset assetWithURL:url];
    
    CMTimeRange range = CMTimeRangeMake(kCMTimeZero, asset.duration);
    NSArray* assetVideoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack* firstVideoTrack = assetVideoTracks[0];
    [videoTrack insertTimeRange:range ofTrack:firstVideoTrack atTime:lastEndTime error:nil];
          
    lastEndTime = CMTimeAdd(lastEndTime, asset.duration);
  }
  
  AVMutableVideoCompositionInstruction *mainInstruction = [[AVMutableVideoCompositionInstruction alloc] init];
  mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, lastEndTime);
  
  AVMutableVideoCompositionLayerInstruction *videolayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
  [videolayerInstruction setOpacity:0.0 atTime:lastEndTime];
  
  mainInstruction.layerInstructions = [NSArray arrayWithObjects:videolayerInstruction, nil];

  AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
  
  mainCompositionInst.renderSize = CGSizeMake(720.0, 1280.0);
  
  mainCompositionInst.instructions = [NSArray arrayWithObject:mainInstruction];
  mainCompositionInst.frameDuration = CMTimeMake(1, 30);
  
  
  _playerItem = [AVPlayerItem playerItemWithAsset:mixComposition];
  _player = [AVPlayer playerWithPlayerItem:_playerItem];
  _player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
  _playerViewController.player = _player;
}

@end
