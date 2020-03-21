#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

@interface CLPVideo : UIView <AVPlayerViewControllerDelegate>
@end

@implementation CLPVideo
{
  AVMutableComposition *_mixComposition;
  AVPlayerLayer *_playerLayer;
  AVPlayer *_player;
  AVPlayerItem *_playerItem;
  NSDictionary *_composition;
  
  BOOL _paused;
  float _rate;
}

- (instancetype)init
{
  if (self = [super init]) {
    _rate = 1.0;
  }
  
  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  
  _playerLayer.frame = self.bounds;
}

- (void)removeFromSuperview
{
  if (_playerLayer.player != nil) {
    [_playerLayer.player pause];
    _playerLayer.player = nil;
  }
  
  [_playerLayer removeFromSuperlayer];
  _playerLayer = nil;
  
  [super removeFromSuperview];
}

- (void)setComposition:(NSDictionary *)composition
{
  _composition = composition;
  
  if (_mixComposition == nil) {
    _mixComposition = [[AVMutableComposition alloc] init];
    _playerItem = [AVPlayerItem playerItemWithAsset:_mixComposition];
    _player = [AVPlayer playerWithPlayerItem:_playerItem];
    _player.rate = 0.5;
    _player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    _playerLayer.needsDisplayOnBoundsChange = YES;
//    _playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.layer addSublayer:_playerLayer];
  }
  
  [self load];
}

- (void)setPaused:(BOOL)paused {
  _paused = paused;
  
  if (paused) {
    [_player pause];
  } else {
    [_player play];
  }
}

- (void)setSeek:(NSDictionary *)info
{
  NSNumber *seekTime = info[@"time"];
  
  int timeScale = 1000;
  
  if (_playerItem && _playerItem.status == AVPlayerItemStatusReadyToPlay) {
    CMTime to = CMTimeMakeWithSeconds([seekTime floatValue], timeScale);
    
    [_player seekToTime:to toleranceBefore:CMTimeMakeWithSeconds(0.1, timeScale) toleranceAfter:CMTimeMakeWithSeconds(0.1, timeScale)];
  }
}

- (void)setRate:(float)rate
{
  _rate = rate;
  
  _player.rate = rate;
}

- (void)load
{
  NSDictionary *composition = _composition;
  // BEGIN COMPOSITION SETUP
  
  AVMutableCompositionTrack *videoTrack = [_mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
  
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
}

@end
