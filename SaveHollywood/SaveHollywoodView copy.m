#import "SaveHollywoodView.h"
#import "SHConfigurationWindowController.h"

#import "SHUserDefaults+Constants.h"

#import "NSColor+String.h"
#import "NSArray+Shuffle.h"

#define BORDER_SIZE		50.0

#define LRAND()                    ((long) (random() & 0x7fffffff))
#define MAXRAND                    (2147483648.0) /* unsigned 1<<31 as a float */

NSUInteger random_no(NSUInteger);

NSUInteger random_no(NSUInteger n)
{
	return ((NSUInteger) ((n + 1) * (double) LRAND() / MAXRAND));
}

@interface SaveHollywoodView ()
{
    // Data
    
    NSFileManager * _fileManager;
    BOOL _preview;
    BOOL _mainScreen;
    
    NSInteger _scaling;
    BOOL _randomPosition;
    
    BOOL _drawBorder;
    BOOL _showMetadata;
    NSInteger _metadadataMode;
    
    
    NSInteger _volumeMode;
    float _volumeLevel;
    
    // Layers
    
    CALayer * _backgroundLayer;
    AVPlayerLayer * _AVPlayerLayer;
    
    // Assets iteration
    
    BOOL _randomOrder;
    
    NSUInteger __arrayIndex;
    NSMutableArray * __assetsArray;
    
    // Current Asset
    
    NSString *_currentAssetMetadataTitle;
    NSString *_currentAssetMetadataCopyrights;
    
    // Preferences
    
    SHConfigurationWindowController *_configurationWindowController;
}

- (BOOL) playNextAsset;

@end

@implementation SaveHollywoodView

#pragma mark -

#ifdef __TEST_SCREENSAVER__

- (id)initWithFrame:(NSRect)frameRect
{
    self=[super initWithFrame:frameRect];
    
    if (self!=nil)
    {
        _fileManager=[NSFileManager defaultManager];
		
		_preview=NO;
        
        if (_preview==YES)
        {
            _mainScreen=YES;
        }
        else
        {
            _mainScreen= (NSMinX(frameRect)==0 && NSMinY(frameRect)==0);
        }
        
        [self setWantsLayer:YES];
    }
    
    return self;
}

#else

- (id)initWithFrame:(NSRect)frameRect isPreview:(BOOL)isPreview
{
    self=[super initWithFrame:frameRect isPreview:isPreview];
    
    if (self!=nil)
    {
        [self setAnimationTimeInterval:1.0];
        
        _fileManager=[NSFileManager defaultManager];
		
		_preview=isPreview;
        
        if (_preview==YES)
        {
            _mainScreen=YES;
        }
        else
        {
            _mainScreen= (NSMinX(frameRect)==0 && NSMinY(frameRect)==0);
        }
        
        [self setWantsLayer:YES];
    }
    
    return self;
}

#endif

#pragma mark -

- (void)startAnimation
{
    BOOL tBool;
#ifdef __TEST_SCREENSAVER__
    NSUserDefaults *tDefaults = [NSUserDefaults standardUserDefaults];
#else
    NSString *tIdentifier = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
    ScreenSaverDefaults *tDefaults = [ScreenSaverDefaults defaultsForModuleWithName:tIdentifier];

    [super startAnimation];
#endif
    
    tBool=[tDefaults boolForKey:SHUserDefaultsMainScreenOnly];
    
    if (tBool==NO || _mainScreen==YES)
    {
        if (_backgroundLayer==nil)
        {
            _backgroundLayer=[[CALayer alloc] init];
        
            _backgroundLayer.frame=self.layer.bounds;
        
            [self.layer addSublayer:_backgroundLayer];
        
            [_backgroundLayer release];
        }
        
        if (_backgroundLayer!=nil)
        {
            NSString * tString;
            NSColor * tColor=nil;
            CGFloat tColorComponents[4];
            CGColorRef tCGColorRef;
            id tObject;
            NSArray * tAssets;
            
            // Frame
            
                // Scaling
            
            _scaling=[tDefaults integerForKey:SHUserDefaultsFrameScaling];
            
                // Draw Border
            
            _drawBorder=[tDefaults boolForKey:SHUserDefaultsFrameDrawBorder];
            
                // Random Position
            
            _randomPosition=[tDefaults boolForKey:SHUserDefaultsFrameRandomPosition];
            
                // Background Color
            
            tString=[tDefaults stringForKey:SHUserDefaultsBackgroundColor];
            
            if (tString!=nil)
                tColor=[NSColor colorFromString:tString];
            
            if (tColor==nil)
                tColor=[NSColor redColor];
                
            [tColor getComponents:tColorComponents];
            
            tCGColorRef=CGColorCreateGenericRGB(tColorComponents[0],tColorComponents[1],tColorComponents[2], tColorComponents[3]);
            
            if (tCGColorRef!=NULL)
            {
                _backgroundLayer.backgroundColor=tCGColorRef;
            
                CFRelease(tCGColorRef);
            }
            
            // Volume
            
                // Mode
            
            _volumeMode=[tDefaults integerForKey:SHUserDefaultsMovieVolumeMode];
            
                // Custom Value
            
            tObject=[tDefaults objectForKey:SHUserDefaultsMovieVolumeCustomValue];
            
            if (tObject==nil)
                _volumeLevel=1.0f;
            else
            {
                _volumeLevel=[tDefaults floatForKey:SHUserDefaultsMovieVolumeCustomValue];
            
                if (_volumeLevel<0.0f)
                {
                    _volumeLevel=0.0f;
                }
                else if (_volumeLevel>1.0f)
                {
                    _volumeLevel=1.0f;
                }
            }
            
            // Assets
            
                // Random Order
            
            _randomOrder=[tDefaults boolForKey:SHUserDefaultsAssetsRandomOrder];
            
                // List
            
            __arrayIndex=0;
            
            /*tAssets=[NSArray arrayWithObjects:[NSURL fileURLWithPath:@"/Users/stephane/Movies/Tyler Perry's Temptation_480.mov"],
                                              [NSURL fileURLWithPath:@"/Users/stephane/Movies/Iron Man 3_1080.mov"],
                                               nil];*/
            
            tAssets=[NSArray arrayWithObjects:[NSURL fileURLWithPath:@"/Users/stephane/Pictures/IMG_0042.MOV"],
                                              [NSURL fileURLWithPath:@"/Users/stephane/Pictures/IMG_0043.MOV"],
                                              [NSURL fileURLWithPath:@"/Users/stephane/Pictures/IMG_0044.MOV"],
                                              [NSURL fileURLWithPath:@"/Users/stephane/Pictures/IMG_0045.MOV"],
                                              [NSURL fileURLWithPath:@"/Users/stephane/Pictures/IMG_0046.MOV"],
                                              [NSURL fileURLWithPath:@"/Users/stephane/Pictures/IMG_0047.MOV"],
                                              nil];
            
            // A COMPLETER
            
            if ([tAssets count]>0)
            {
                __assetsArray=[[NSMutableArray alloc] initWithCapacity:[tAssets count]];
                
                if (__assetsArray!=nil)
                {
                    // Flatten the list of potential assets and prune it from incompatible and unplayable files
                
                    for(NSURL * tURL in tAssets)
                    {
                        if ([tURL isFileURL]==YES)
                        {
                            NSString * tAbsolutePath;
                            BOOL tIsDirectory;
                            
                            tAbsolutePath=[tURL path];
                            
                            if ([_fileManager fileExistsAtPath:tAbsolutePath isDirectory:&tIsDirectory]==YES)
                            {
                                if (tIsDirectory==NO)
                                {
                                    // Check that the file is of a supported type
                                    
                                    [AVURLAsset audiovisualTypes];
                                    
                                    // A COMPLETER
                                    
                                    [__assetsArray addObject:tURL];
                                }
                                else
                                {
                                    NSError *tError=nil;
                                    
                                    // Add the contents of the directory
                                    
                                    NSArray * tFileNamesArray=[_fileManager contentsOfDirectoryAtPath:tAbsolutePath error:&tError];
                                    
                                    if (tFileNamesArray==nil)
                                    {
                                        // A COMPLETER
                                    }
                                    else
                                    {
                                        for (NSString * tFileName in tFileNamesArray)
                                        {
                                            NSString * tSubPath=[tAbsolutePath stringByAppendingPathComponent:tFileName];
                                            
                                            // Check that the file is of a supported type
                                            
                                            // A COMPLETER
                                            
                                            NSURL *tSubURL=[NSURL fileURLWithPath:tSubPath];
                                            
                                            if (tSubURL!=nil)
                                            {
                                                [__assetsArray addObject:tSubURL];
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        else
                        {
                            // A COMPLETER
                        }
                    }
                
                    NSUInteger tCount=[__assetsArray count];
                
                    if (tCount>0)
                    {
                        if (tCount>1)
                        {
                            if (_randomOrder==YES)
                            {
                                // Shuffle Array
                                
                                [__assetsArray shuffle];
                            }
                        }
                        else
                        {
                            // Only 1 asset
                            
                            // A COMPLETER
                        }
                        
                        // Add observer
                        
                        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
                        
                        // Play the next asset
                        
                        if ([self playNextAsset]==NO)
                        {
                            // No playable asset available
                            
                            // A COMPLETER
                        }
                    }
                }
            }
        }
    }
}

- (void)stopAnimation
{
    // Remove observer
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    // Stop Movie
    
    [_currentAssetMetadataTitle release];
    _currentAssetMetadataTitle=nil;
    
    [_currentAssetMetadataCopyrights release];
    _currentAssetMetadataCopyrights=nil;
    
    [_AVPlayerLayer.player pause];
    
    [_backgroundLayer removeFromSuperlayer];
    
    _backgroundLayer=nil;
    
    [__assetsArray release];
    __assetsArray=nil;
    
    __arrayIndex=0;
    
    // A COMPLETER
#ifndef __TEST_SCREENSAVER__
    [super stopAnimation];
#endif
}

- (BOOL) playNextAsset
{
    NSUInteger tCount=[__assetsArray count];
    AVAsset * tAsset=nil;
    NSUInteger tNextIndex=__arrayIndex;
    
    if (__arrayIndex>=tCount)
    {
        __arrayIndex=0;
    }
    
    while (__arrayIndex<tCount)
    {
        NSURL * tURL=[__assetsArray objectAtIndex:__arrayIndex];
        
        if ([tURL isFileURL]==YES)
        {
            NSString * tAbsolutePath=[tURL path];
            
            if ([_fileManager fileExistsAtPath:tAbsolutePath]==YES)
            {
                tAsset=[AVAsset assetWithURL:tURL];
                
                if ([tAsset isPlayable]==NO)
                {
                    [__assetsArray removeObjectAtIndex:__arrayIndex];
                    
                    tCount=[__assetsArray count];
                    
                    tAsset=nil;
                }
                else
                {
                    break;
                }
            }
        }
        else
        {
            // A COMPLETER
        }
    }
    
    if (tAsset==nil)
    {
        if (tNextIndex>0 && tCount>0)
        {
            // We at least played once asset previously
            
            __arrayIndex=0;
            
            return [self playNextAsset];
        }
        
        return NO;
    }
    
    [tAsset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObjects:@"tracks",@"preferredVolume",@"naturalSize",nil] completionHandler:^(){
        
        if ([tAsset statusOfValueForKey:@"tracks" error:NULL]==AVKeyValueStatusLoaded && [tAsset statusOfValueForKey:@"naturalSize" error:NULL]==AVKeyValueStatusLoaded)
        {
            AVPlayerItem * tAVPlayerItem=[[AVPlayerItem alloc] initWithAsset:tAsset];
            
            if (tAVPlayerItem==nil)
            {
                __arrayIndex++;
                
                [self playNextAsset];
            }
            else
            {
                [tAVPlayerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
                
                AVPlayer * tAVPlayer=[[AVPlayer alloc] initWithPlayerItem:tAVPlayerItem];
                
                [tAVPlayerItem release];
                
                _AVPlayerLayer=[AVPlayerLayer playerLayerWithPlayer:tAVPlayer];
                
                [tAVPlayer release];
                
                if (_AVPlayerLayer==nil)
                {
                    [tAVPlayerItem removeObserver:self forKeyPath:@"status"];
                    
                    // Display an error message instead of the movie
                    
                    // A COMPLETER
                    
                    return;
                }
                
                CGRect tBackgroundFrame=_backgroundLayer.bounds;
                CGRect tFrame=tBackgroundFrame;
                
                if (_scaling==kMovieFrameActualSize)
                {
                    CGSize tAssetSize=tAsset.naturalSize;
                    CGFloat tRatio;
                    CGFloat tYRatio;
                    
                    tRatio=tAssetSize.width/tBackgroundFrame.size.width;
                    tYRatio=tAssetSize.height/tBackgroundFrame.size.height;
                    
                    if (tYRatio>tRatio)
                    {
                        tRatio=tYRatio;
                    }
                    
                    if (tRatio>=1.0f)
                    {
                        tAssetSize.width=round(tAssetSize.width/tRatio);
                        tAssetSize.height=round(tAssetSize.height/tRatio);
                    }
                    
                    if (_randomPosition==YES)
                    {
                        // Make sure we can randomize the position
                        
                        // A COMPLETER
                    }
                    else
                    {
                        if (_drawBorder==YES)
                        {
                            if (tAssetSize.width>(tBackgroundFrame.size.width-2*BORDER_SIZE))
                            {
                                tAssetSize.width=tBackgroundFrame.size.width-2*BORDER_SIZE;
                            }
                            
                            if (tAssetSize.height>(tBackgroundFrame.size.height-2*BORDER_SIZE))
                            {
                                tAssetSize.height=tBackgroundFrame.size.height-2*BORDER_SIZE;
                            }
                        }
                        
                        tFrame.size=tAssetSize;
                        
                        tFrame.origin.x=round(tBackgroundFrame.origin.x+(tBackgroundFrame.size.width-tAssetSize.width)*0.5);
                        tFrame.origin.y=round(tBackgroundFrame.origin.y+(tBackgroundFrame.size.height-tAssetSize.height)*0.5);
                    }
                }
                else
                {
                    if (_scaling==kMovieFrameSizeToFill)
                        _AVPlayerLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;
                    else
                        _AVPlayerLayer.videoGravity=AVLayerVideoGravityResizeAspect;
                    
                    if (_drawBorder==YES)
                    {
                        tFrame=CGRectInset(tBackgroundFrame, BORDER_SIZE, BORDER_SIZE);
                    }
                }
                
                _AVPlayerLayer.frame=tFrame;
                
                [_backgroundLayer addSublayer:_AVPlayerLayer];
                
                // Set Volume
                
                switch(_volumeMode)
                {
                    case kMovieVolumeMute:
                        
                        tAVPlayer.volume=0.0f;
                        
                        break;
                        
                    case kMovieVolumeCustom:
                        
                        tAVPlayer.volume=_volumeLevel;
                        
                        break;
                        
                    default:
                        
                        if ([tAsset statusOfValueForKey:@"preferredVolume" error:NULL]==AVKeyValueStatusLoaded)
                        {
                            tAVPlayer.volume=tAsset.preferredVolume;
                        }
                        else
                        {
                            tAVPlayer.volume=1.0f;
                        }
                        
                        break;
                }
            }
        }
        else
        {
            // A COMPLETER
        }
        
    }];
    
    return YES;
}

#pragma mark - Assets Iteration

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"status"]==YES)
    {
        AVPlayerItem * tPlayerItem=(AVPlayerItem *)object;
        
        [tPlayerItem removeObserver:self forKeyPath:@"status"];
        
        if (tPlayerItem.status==AVPlayerItemStatusReadyToPlay)
        {
            NSLog(@"Start playing asset #%lu",__arrayIndex);
            
            [_AVPlayerLayer.player play];
            
            if (_showMetadata==YES)
            {
                [tPlayerItem.asset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObject:@"availableMetadataFormats"] completionHandler:^(){
            
                    if ([tPlayerItem.asset statusOfValueForKey:@"availableMetadataFormats" error:NULL]==AVKeyValueStatusLoaded)
                    {
                        NSArray * tAvailableMetadataFormats=[tPlayerItem.asset availableMetadataFormats];
                        
                        for(NSString * tFormat in tAvailableMetadataFormats)
                        {
                            if ([tFormat isEqualToString:AVMetadataFormatQuickTimeUserData]==YES)
                            {
                                NSArray * tMetadata=[tPlayerItem.asset metadataForFormat:AVMetadataFormatQuickTimeUserData];
                                NSArray * tMetadataItemsArray;
                                
                                // Title
                                
                                tMetadataItemsArray=[AVMetadataItem metadataItemsFromArray:tMetadata
                                                                                   withKey:AVMetadataCommonKeyTitle
                                                                                  keySpace:AVMetadataKeySpaceCommon];
                                
                                if ([tMetadataItemsArray count]>0)
                                {
                                    _currentAssetMetadataTitle=[[NSString alloc] initWithString:[[tMetadataItemsArray objectAtIndex:0] stringValue]];
                                }
                                
                                // Copyrights
                                
                                tMetadataItemsArray=[AVMetadataItem metadataItemsFromArray:tMetadata
                                                                                   withKey:AVMetadataCommonKeyCopyrights
                                                                                  keySpace:AVMetadataKeySpaceCommon];
                                
                                if ([tMetadataItemsArray count]>0)
                                {
                                    _currentAssetMetadataCopyrights=[[NSString alloc] initWithString:[[tMetadataItemsArray objectAtIndex:0] stringValue]];
                                }
                                
                                // Show Metadata
                                
                                // A COMPLETER
                                
                                if (_metadadataMode==kMovieFrameShowMetadataPeriodically)
                                {
                                    // Add Periodic Observer
                                    
                                    // A COMPLETER
                                }
                                
                                break;
                            }
                        }
                        
                    }
                }];
            }
        }
        else if (tPlayerItem.status==AVPlayerItemStatusFailed)
        {
            // A COMPLETER
        }
    }
}

#pragma mark - Configuration

- (BOOL)hasConfigureSheet
{
    return YES;
}

- (NSWindow*)configureSheet
{
    NSWindow * tWindow;
    
    if (_configurationWindowController==nil)
    {
        _configurationWindowController=[[SHConfigurationWindowController alloc] init];
    }
    
    tWindow=_configurationWindowController.window;
    
    [_configurationWindowController refreshSettings];
    
    return tWindow;
}

#pragma mark - Player Item Observer

- (void)playerItemDidPlayToEnd:(NSNotification *)inNotification
{
    AVPlayerItem * tPlayerItem=(AVPlayerItem *)[inNotification object];
    
    if (tPlayerItem==_AVPlayerLayer.player.currentItem)
    {
        NSLog(@"Finished playing asset #%lu",__arrayIndex);
        
        // Rewind (only one asset and no random position) or play next
    
        if ([__assetsArray count]==1)
        {
            if (_randomPosition==NO)
            {
                AVPlayer * tCurrentPlayer=[_AVPlayerLayer player];
                
                [tCurrentPlayer seekToTime:kCMTimeZero];
                [tCurrentPlayer play];
                
                // A COMPLETER
                
                return;
            }
        }
        
        [_currentAssetMetadataTitle release];
        _currentAssetMetadataTitle=nil;
        
        [_currentAssetMetadataCopyrights release];
        _currentAssetMetadataCopyrights=nil;
        
        [_AVPlayerLayer removeFromSuperlayer];
        _AVPlayerLayer=nil;
        
        __arrayIndex++;
        
        if ([self playNextAsset]==NO)
        {
            // A COMPLETER
        }
    }
}

@end
