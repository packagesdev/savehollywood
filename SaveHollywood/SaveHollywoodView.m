/*
 Copyright (c) 2012-2017, Stephane Sudre
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 - Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 - Neither the name of the WhiteBox nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SaveHollywoodView.h"
#import "SHConfigurationWindowController.h"

#import "SHUserDefaults+Constants.h"

#import "NSColor+String.h"
#import "NSArray+Shuffle.h"

#define BORDER_SIZE		50.0

#define LRAND()                    ((long) (random() & 0x7fffffff))
#define MAXRAND                    (2147483648.0) /* unsigned 1<<31 as a float */

#define METADATA_DISPLAY_DURATION 5.0

NSString * const SHScreenKey=@"screen#";
NSString * const SHScreenKeyKeyed=@"screen.keyed#";
NSString * const SHAssetTimeKey=@"asset.time";
NSString * const SHAssetURLKey=@"asset.url";

NSString * const SHShouldSwitchMutedStateNotification=@"SHShouldSwitchMutedStateNotification";
NSString * const SHShouldIncreaseVolumeNotification=@"SHShouldIncreaseVolumeNotification";
NSString * const SHShouldDecreaseVolumeNotification=@"SHShouldDecreaseVolumeNotification";

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
    NSInteger _metadadataPeriod;
    
    NSTimer * _timer;
    BOOL _liveMuted;
    BOOL _volumeLevelHasBeenModified;
    
    BOOL _audioMainScreen;
    NSInteger _volumeMode;
    float _volumeLevel;
    
	// Workaround for Apple bug in Sierra
	
	BOOL _useKeyedArchiverForLeftOffData;
	
	// Layers
    
    CALayer * _backgroundLayer;
    AVPlayerLayer * _AVPlayerLayer;
    CALayer * _metadataLayer;
    
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

- (NSUInteger)screenIndex;

- (BOOL)playNextAsset:(NSDictionary *)preferredNextAssetDictionary;

- (void)switchMutedState:(NSNotification *)inNotification;
- (void)increaseVolume:(NSNotificationCenter *)inNotification;
- (void)decreaseVolume:(NSNotificationCenter *)inNotification;

- (void)showMetadata:(NSTimer *)inTimer;
- (void)hideMetadata:(id)object;



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
		SInt32 tMajorVersion,tMinorVersion,tBugFixVersion;
		
		Gestalt(gestaltSystemVersionMajor,&tMajorVersion);
		Gestalt(gestaltSystemVersionMinor,&tMinorVersion);
		Gestalt(gestaltSystemVersionBugFix,&tBugFixVersion);
		
		
		_useKeyedArchiverForLeftOffData=(tMajorVersion>10 || (tMajorVersion==10 && tMinorVersion>=12));
		
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

- (void) keyDown:(NSEvent *) inEvent
{
    if (_preview==NO)
    {
        BOOL tCanChangeVolume=(_volumeMode!=kMovieVolumeMute);
        
        NSString * tString=[inEvent characters];
        NSUInteger tLength=[tString length];
        
        for(NSUInteger tIndex=0;tIndex<tLength;tIndex++)
        {
            unichar tChar=[tString characterAtIndex:tIndex];
            
            switch(tChar)
            {
                case 'm':
                case 'M':
                
                    if (tCanChangeVolume==YES)
                    {
                        // Post notification
                        
                        [[NSNotificationCenter defaultCenter] postNotificationName:SHShouldSwitchMutedStateNotification
                                                                            object:nil];
                        
                        return;
                    }
                
                    break;
                
                case NSDownArrowFunctionKey:
                
                    if (tCanChangeVolume==YES)
                    {
                        // Post notification
                        
                        [[NSNotificationCenter defaultCenter] postNotificationName:SHShouldDecreaseVolumeNotification
                                                                            object:nil];
                        
                        return;
                    }
                    
                    break;
                    
                case NSUpArrowFunctionKey:
                    
                    if (tCanChangeVolume==YES)
                    {
                        // Post notification
                        
                        [[NSNotificationCenter defaultCenter] postNotificationName:SHShouldIncreaseVolumeNotification
                                                                            object:nil];
                        
                        return;
                    }
                
                    break;
            }
        }
        
    }
    
    [super keyDown:inEvent];
}

#pragma mark -

- (NSUInteger)screenIndex
{
    NSWindow * tWindow=self.window;
    NSRect tWindowFrame=[tWindow frame];
    NSArray * tScreensArray=[NSScreen screens];
    __block NSUInteger tFoundIndex=NSNotFound;
    
    [tScreensArray enumerateObjectsUsingBlock:^(NSScreen * bScreen, NSUInteger bIndex, BOOL *bOutStop) {
    
        NSRect tScreenFrame=[bScreen frame];
        
        if (NSContainsRect(tScreenFrame,tWindowFrame)==YES)
        {
            tFoundIndex=bIndex;
            *bOutStop=YES;
        }
    }];
    
    return tFoundIndex;
}

#pragma mark -

- (void)startAnimation
{
#ifdef __TEST_SCREENSAVER__
    NSUserDefaults *tDefaults = [NSUserDefaults standardUserDefaults];
#else
    NSString *tIdentifier = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
    ScreenSaverDefaults *tDefaults = [ScreenSaverDefaults defaultsForModuleWithName:tIdentifier];

    [super startAnimation];
#endif
    
     BOOL tBool=[tDefaults boolForKey:SHUserDefaultsMainDisplayOnly];
    
    if (tBool==NO || _mainScreen==YES)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(increaseVolume:) name:SHShouldIncreaseVolumeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(decreaseVolume:) name:SHShouldDecreaseVolumeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(switchMutedState:) name:SHShouldSwitchMutedStateNotification object:nil];
        
        if (_backgroundLayer==nil)
        {
            _backgroundLayer=[[CALayer alloc] init];
        
            _backgroundLayer.frame=self.layer.bounds;
        
            [self.layer addSublayer:_backgroundLayer];
        
            [_backgroundLayer release];
        }
        
        if (_backgroundLayer!=nil)
        {
            
            
            // Frame
            
                // Scaling
            
            _scaling=[tDefaults integerForKey:SHUserDefaultsFrameScaling];
            
                // Draw Border
            
            _drawBorder=[tDefaults boolForKey:SHUserDefaultsFrameDrawBorder];
            
            _showMetadata=[tDefaults boolForKey:SHUserDefaultsFrameShowMetadata];
            
            _metadadataMode=[tDefaults integerForKey:SHUserDefaultsFrameShowMetadataMode];
            
            _metadadataPeriod=[tDefaults integerForKey:SHUserDefaultsFrameShowMetadataPeriod];
            
                // Random Position
            
            _randomPosition=[tDefaults boolForKey:SHUserDefaultsFrameRandomPosition];
            
                // Background Color
            
            NSColor * tColor=nil;
            NSString * tString=[tDefaults stringForKey:SHUserDefaultsBackgroundColor];
            
            if (tString!=nil)
                tColor=[NSColor colorFromString:tString];
            
            if (tColor==nil)
                tColor=[NSColor blackColor];
            
            _backgroundLayer.backgroundColor=[tColor CGColor];
            
            // Audio
            
            _audioMainScreen=[tDefaults boolForKey:SHUserDefaultsAudioMainDisplayOnly];
            
            // Volume
            
            _liveMuted=NO;

                // Mode
            
            _volumeMode=[tDefaults integerForKey:SHUserDefaultsMovieVolumeMode];
            
                // Custom Value
            
            id tObject=[tDefaults objectForKey:SHUserDefaultsMovieVolumeCustomValue];
            
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
            
            NSArray * tDefaultsArray=[tDefaults objectForKey:SHUserDefaultsAssetsLibrary];
            
            NSMutableArray * tAssets=[NSMutableArray array];
            
            for(NSString * tPath in tDefaultsArray)
            {
                NSURL * tURL=[NSURL fileURLWithPath:tPath];
                
                if (tURL!=nil)
                {
                    [tAssets addObject:tURL];
                }
            }
            
            if ([tAssets count]>0)
            {
                __assetsArray=[[NSMutableArray alloc] initWithCapacity:[tAssets count]];
                
                if (__assetsArray!=nil)
                {
                    // Flatten the list of potential assets and prune it from incompatible and unplayable files
                    NSArray * tAcceptedUTIsArray=[AVURLAsset audiovisualTypes];
                    NSWorkspace  * tSharedWorkspace=[NSWorkspace sharedWorkspace];
                    
                    for(NSURL * tURL in tAssets)
                    {
                        if ([tURL isFileURL]==YES)
                        {
                            NSString * tAbsolutePath=[tURL path];
                            BOOL tIsDirectory;
							
                            if ([_fileManager fileExistsAtPath:tAbsolutePath isDirectory:&tIsDirectory]==YES)
                            {
                                if (tIsDirectory==NO)
                                {
                                    // Check that the file is of a supported type
                                    
                                    NSString * tUTI=[tSharedWorkspace typeOfFile:tAbsolutePath error:NULL];
                                    
                                    if (tUTI!=nil && [tAcceptedUTIsArray containsObject:tUTI]==YES)
                                    {
                                        [__assetsArray addObject:tURL];
                                    }
                                }
                                else
                                {
                                    NSError *tError=nil;
                                    
                                    // Add the contents of the directory
                                    
                                    NSArray * tFileNamesArray=[_fileManager contentsOfDirectoryAtPath:tAbsolutePath error:&tError];
                                    
                                    if (tFileNamesArray==nil)
                                    {
                                        NSLog(@"Unable to get the contents of the directory at path \"%@\"",tAbsolutePath);
                                    }
                                    else
                                    {
                                        for (NSString * tFileName in tFileNamesArray)
                                        {
                                            NSString * tSubPath=[tAbsolutePath stringByAppendingPathComponent:tFileName];
                                            
                                            // Check that the file is of a supported type
                                            
                                            NSString * tUTI=[tSharedWorkspace typeOfFile:tSubPath error:NULL];
                                            
                                            if (tUTI!=nil && [tAcceptedUTIsArray containsObject:tUTI]==YES)
                                            {
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
                        }
                        else
                        {
                            // Remote URL
                            
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
                        
                        // Add observer
                        
                        [[NSNotificationCenter defaultCenter] addObserver:self
                                                                 selector:@selector(playerItemDidPlayToEnd:)
                                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                                   object:nil];
                        
                        //
                        
                        NSDictionary * tLastKnownAssetDictionary=nil;
                        
                        if (_preview==NO)
                        {
                            NSUInteger tScreenIndex=[self screenIndex];
                        
                            if (tScreenIndex!=NSNotFound)
                            {
								NSString * tScreenKey;
								
								if (_useKeyedArchiverForLeftOffData==YES)
									tScreenKey=[NSString stringWithFormat:@"%@%lu",SHScreenKeyKeyed,(unsigned long)tScreenIndex];
								else
									tScreenKey=[NSString stringWithFormat:@"%@%lu",SHScreenKey,(unsigned long)tScreenIndex];
								
								if ([tDefaults boolForKey:SHUserDefaultsAssetsStartWhereLeftOff]==YES)
                                {
                                    NSData * tData=[tDefaults objectForKey:tScreenKey];
                                    
                                    if (tData!=nil)
                                    {
										if (_useKeyedArchiverForLeftOffData==YES)
											tLastKnownAssetDictionary=[NSKeyedUnarchiver unarchiveObjectWithData:tData];
										else
											tLastKnownAssetDictionary=[NSUnarchiver unarchiveObjectWithData:tData];
                                        
                                        if (tLastKnownAssetDictionary==nil)
                                            NSLog(@"Error when unarchiving last known asset for %@",tScreenKey);
                                    }
                                }
                                else
                                {
                                    [tDefaults removeObjectForKey:tScreenKey];
                                }
                            }
                        }
                        
                        // Play the next asset
                        
                        if ([self playNextAsset:tLastKnownAssetDictionary]==YES)
                        {
                            return;
                        }
                    }
                }
            }
                            
            // No playable asset available => Display text
            
            CGRect tBackgroundFrame=_backgroundLayer.bounds;
            CGRect tFrame;
            
            CATextLayer * tWarningTextLayer=[CATextLayer layer];
            
            tWarningTextLayer.font=@"Lucida Grande Bold";
            tWarningTextLayer.alignmentMode=kCAAlignmentCenter;
            tWarningTextLayer.foregroundColor=CGColorGetConstantColor(kCGColorWhite);
            
            if (_preview==YES)
            {
                tWarningTextLayer.fontSize=16;
                
                tFrame=CGRectInset(tBackgroundFrame,20.,0);
                
                tFrame.origin.y=CGRectGetMidY(tBackgroundFrame)-9.0;
                tFrame.size.height=20.;
            }
            else
            {
                tWarningTextLayer.fontSize=35;
                
                tFrame=CGRectInset(tBackgroundFrame,20.,0);
                
                tFrame.origin.y=CGRectGetMidY(tBackgroundFrame)-18.0;
                tFrame.size.height=35.;
            }
            
            tWarningTextLayer.frame=tFrame;
            
            tWarningTextLayer.string=NSLocalizedStringFromTableInBundle(@"No videos",@"Localized",[NSBundle bundleForClass:[self class]],@"");
            
            [_backgroundLayer addSublayer:tWarningTextLayer];
        }
    }
}

- (void)stopAnimation
{
#ifdef __TEST_SCREENSAVER__
    NSUserDefaults *tDefaults = [NSUserDefaults standardUserDefaults];
#else
    NSString *tIdentifier = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
    ScreenSaverDefaults *tDefaults = [ScreenSaverDefaults defaultsForModuleWithName:tIdentifier];
#endif
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideMetadata:) object:nil];
    
    // Remove observers
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SHShouldIncreaseVolumeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SHShouldDecreaseVolumeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SHShouldSwitchMutedStateNotification object:nil];
    
    // Stop Movie

    if (_preview==NO)
    {
        // Save current asset and time if necessary
    
        NSUInteger tScreenIndex=[self screenIndex];
        
        if (tScreenIndex!=NSNotFound)
        {
			NSString * tScreenKey;
			
			if (_useKeyedArchiverForLeftOffData==YES)
				tScreenKey=[NSString stringWithFormat:@"%@%lu",SHScreenKeyKeyed,(unsigned long)tScreenIndex];
			else
				tScreenKey=[NSString stringWithFormat:@"%@%lu",SHScreenKey,(unsigned long)tScreenIndex];
            
            if ([tDefaults boolForKey:SHUserDefaultsAssetsStartWhereLeftOff]==YES)
            {
                NSURL * tCurrentURL=[((AVURLAsset *) _AVPlayerLayer.player.currentItem.asset) URL];
                
                if (tCurrentURL!=nil)
                {
                    CMTime tCurrentTime=[_AVPlayerLayer.player currentTime];
                    NSValue * tValue=[NSValue valueWithCMTime:tCurrentTime];
            
					NSDictionary * tLastAssetDictionary=@{SHAssetTimeKey:tValue,
														  SHAssetURLKey:tCurrentURL};
					
					NSData * tData=nil;
					
					if (_useKeyedArchiverForLeftOffData==YES)
						tData=[NSKeyedArchiver archivedDataWithRootObject:tLastAssetDictionary];
                    else
						tData=[NSArchiver archivedDataWithRootObject:tLastAssetDictionary];
						
                    if (tData!=nil)
                        [tDefaults setObject:tData forKey:tScreenKey];
                }
            }
            else
            {
                [tDefaults removeObjectForKey:tScreenKey];
            }
			
			[tDefaults synchronize];	// Workaround for bug introduced by Apple in Yosemite
        }
    }
    
    [_currentAssetMetadataTitle release];
    _currentAssetMetadataTitle=nil;
    
    [_currentAssetMetadataCopyrights release];
    _currentAssetMetadataCopyrights=nil;
    
    [_AVPlayerLayer.player pause];
    
    if (_timer!=nil)
    {
        [_timer invalidate];
        
        [_timer release];
        _timer=nil;
    }
    
    _AVPlayerLayer=nil;
    [_backgroundLayer removeFromSuperlayer];
    
    _metadataLayer=nil;
    _backgroundLayer=nil;
    
    [__assetsArray release];
    __assetsArray=nil;
    
    __arrayIndex=0;
    
    _liveMuted=NO;
    _volumeLevelHasBeenModified=NO;
    
#ifndef __TEST_SCREENSAVER__
    [super stopAnimation];
#endif
}

- (BOOL) playNextAsset:(NSDictionary *)preferredNextAssetDictionary
{
    NSUInteger tCount=[__assetsArray count];
    AVURLAsset * tAsset=nil;
    NSUInteger tNextIndex=__arrayIndex;
    NSURL * tPreferredNextURL=[preferredNextAssetDictionary objectForKey:SHAssetURLKey];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideMetadata:) object:nil];
    
    if (_timer!=nil)
    {
        [_timer invalidate];
        
        [_timer release];
        
        _timer=nil;
    }
    
    if (__arrayIndex>=tCount)
    {
        __arrayIndex=0;
    }
    
    while (__arrayIndex<tCount)
    {
        NSURL * tURL=__assetsArray[__arrayIndex];
        
        if ([tURL isFileURL]==YES)
        {
            NSString * tAbsolutePath=[tURL path];
            
            if ([_fileManager fileExistsAtPath:tAbsolutePath]==YES)
            {
                tAsset=[AVURLAsset assetWithURL:tURL];
                
                if ([tAsset isPlayable]==NO)
                {
                    [__assetsArray removeObjectAtIndex:__arrayIndex];
                    
                    tCount=[__assetsArray count];
                    
                    tAsset=nil;
                }
                else
                {
                    if (tPreferredNextURL==nil || [tPreferredNextURL isEqualTo:tURL]==YES)
                    {
                        break;
                    }
                    else
                    {
                        __arrayIndex++;
                    }
                }
            }
            else
            {
                [__assetsArray removeObjectAtIndex:__arrayIndex];
                
                tCount=[__assetsArray count];
                
                tAsset=nil;
            }
        }
        else
        {
            // Remote URL
            
                // Skip remote URL for the time being
            
            __arrayIndex++;
            
            // A COMPLETER
        }
    }
    
    if (tAsset==nil)
    {
        if ((tNextIndex>0 || tPreferredNextURL!=nil) && tCount>0)
        {
            // We at least played once asset previously (or we were looking for the last known asset)
            
            __arrayIndex=0;
            
            return [self playNextAsset:nil];
        }
        
        return NO;
    }
    
    AVPlayerItem * tAVPlayerItem=[[AVPlayerItem alloc] initWithAsset:tAsset];
            
    if (tAVPlayerItem==nil)
    {
        __arrayIndex++;
        
        [self playNextAsset:nil];
    }
    else
    {
        AVPlayer * tAVPlayer=[[AVPlayer alloc] initWithPlayerItem:tAVPlayerItem];
        
        [tAVPlayerItem release];
        
        
        [_AVPlayerLayer removeFromSuperlayer];
        _AVPlayerLayer=nil;
        
        _AVPlayerLayer=[AVPlayerLayer playerLayerWithPlayer:tAVPlayer];
        
        [tAVPlayer release];
        
        if (_AVPlayerLayer==nil)
        {
            // Display an error message instead of the movie
            
            // A COMPLETER
            
            return NO;
        }
        
        CGRect tBackgroundFrame=_backgroundLayer.bounds;
        CGRect tFrame=tBackgroundFrame;
        
        if (_scaling==kMovieFrameActualSize)
        {
            CGSize tAssetSize=tAsset.naturalSize;
            
            CGFloat tRatio=tAssetSize.width/tBackgroundFrame.size.width;
            CGFloat tYRatio=tAssetSize.height/tBackgroundFrame.size.height;
            
            if (tYRatio>tRatio)
            {
                tRatio=tYRatio;
            }
            
            if (tRatio>=1.0f)
            {
                tAssetSize.width=round(tAssetSize.width/tRatio);
                tAssetSize.height=round(tAssetSize.height/tRatio);
            }
            
            if (_randomPosition==YES && tRatio<1.0)
            {
                // Make sure we can randomize the position
                
                NSSize tSize=tAssetSize;
                 
                tFrame.origin=SSRandomPointForSizeWithinRect(tAssetSize,tBackgroundFrame);
                tFrame.size=tSize;
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
        
        [_backgroundLayer insertSublayer:_AVPlayerLayer atIndex:0];
        
#ifdef __DEBUG_LOG__
        NSLog(@"Add PlayerLayer");
#endif
        // Set Volume
        
        switch(_volumeMode)
        {
            case kMovieVolumeMute:
                
                _AVPlayerLayer.player.volume=0.0;
                
                break;
                
            case kMovieVolumeNormal:
            
                if (_volumeLevelHasBeenModified==NO)
                {
                    if ([tAsset statusOfValueForKey:@"preferredVolume" error:NULL]==AVKeyValueStatusLoaded)
                    {
                        _volumeLevel=tAsset.preferredVolume;
                    }
                    else
                    {
                        _volumeLevel=1.0f;
                    }
                }
                
            default:
                
                if (_audioMainScreen==NO || _mainScreen==YES)
                {
                    _AVPlayerLayer.player.volume=(_liveMuted==YES) ? 0.0f :_volumeLevel;
                }
                else
                {
                    _AVPlayerLayer.player.volume=0;
                }
                
                break;
        }
        
        NSValue * tValue=[preferredNextAssetDictionary objectForKey:SHAssetTimeKey];
        
        if (tValue!=nil)
        {
            CMTime tSeekTime=[tValue CMTimeValue];
            
            [_AVPlayerLayer.player seekToTime:tSeekTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        }
        
        [_AVPlayerLayer.player play];
        
        if (_preview==NO && _showMetadata==YES)
        {
            CATextLayer * tTitleLayer;
            CATextLayer * tCopyrightLayer;
            
            if (_metadataLayer==nil)
            {
                CGColorRef tTranslucidBlackColor=CGColorCreateGenericGray(0.0,0.5);
                CGRect tRect=_backgroundLayer.bounds;
                
                tRect.size.height=70;
                
                // Dark Background
                
                _metadataLayer=[CALayer layer];
                
                _metadataLayer.frame=tRect;
                _metadataLayer.backgroundColor=tTranslucidBlackColor;
                
                CFRelease(tTranslucidBlackColor);
                
                [_backgroundLayer insertSublayer:_metadataLayer
                                           above:_AVPlayerLayer];
                
                _metadataLayer.opacity=0.0f;
                
                tTitleLayer=[CATextLayer layer];
                
                tTitleLayer.font=@"Lucida Grande Bold";
                tTitleLayer.fontSize=35;
                tTitleLayer.foregroundColor=CGColorGetConstantColor(kCGColorWhite);
                tTitleLayer.frame=CGRectMake(12, 25, tRect.size.width-12,40);
                
                [_metadataLayer addSublayer:tTitleLayer];
                
                tCopyrightLayer=[CATextLayer layer];
                
                tCopyrightLayer.font=@"Lucida Grande";
                tCopyrightLayer.fontSize=15;
                tCopyrightLayer.foregroundColor=CGColorGetConstantColor(kCGColorWhite);
                
                tCopyrightLayer.frame=CGRectMake(12, 2, tRect.size.width-12,18);
                
                [_metadataLayer addSublayer:tCopyrightLayer];
            }
            else
            {
                tTitleLayer=(CATextLayer *)[_metadataLayer sublayers][0];
                tCopyrightLayer=(CATextLayer *)[_metadataLayer sublayers][1];
            }
            
            if (_metadadataMode==kMovieFrameShowMetadataPeriodically)
            {
                _timer=[[NSTimer scheduledTimerWithTimeInterval:_metadadataPeriod target:self selector:@selector(showMetadata:) userInfo:nil repeats:YES] retain];
            }
            
            [tAVPlayerItem.asset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObject:@"availableMetadataFormats"] completionHandler:^(){
             
                 if ([tAVPlayerItem.asset statusOfValueForKey:@"availableMetadataFormats" error:NULL]==AVKeyValueStatusLoaded)
                 {
                     NSArray * tAvailableMetadataFormats=[tAVPlayerItem.asset availableMetadataFormats];
                     
                     if ([tAvailableMetadataFormats containsObject:AVMetadataFormatQuickTimeUserData]==YES)
                     {
                         NSArray * tMetadata=[tAVPlayerItem.asset metadataForFormat:AVMetadataFormatQuickTimeUserData];
                         NSArray * tMetadataItemsArray;
                     
                         // Title
                         
                         if (_currentAssetMetadataTitle==nil)
                         {
                             tMetadataItemsArray=[AVMetadataItem metadataItemsFromArray:tMetadata
                                                                                withKey:AVMetadataCommonKeyTitle
                                                                               keySpace:AVMetadataKeySpaceCommon];
                             
                             if ([tMetadataItemsArray count]>0)
                             {
                                 _currentAssetMetadataTitle=[[NSString alloc] initWithString:[tMetadataItemsArray[0] stringValue]];
                             }
                         }
                         
                         // Copyrights
                         
                         if (_currentAssetMetadataCopyrights==nil)
                         {
                             tMetadataItemsArray=[AVMetadataItem metadataItemsFromArray:tMetadata
                                                                                withKey:AVMetadataCommonKeyCopyrights
                                                                               keySpace:AVMetadataKeySpaceCommon];
                         
                             if ([tMetadataItemsArray count]>0)
                             {
                                 _currentAssetMetadataCopyrights=[[NSString alloc] initWithString:[tMetadataItemsArray[0] stringValue]];
                             }
                         }
                         
                         if (_currentAssetMetadataTitle!=nil || _currentAssetMetadataCopyrights!=nil)
                         {
                             tTitleLayer.string=_currentAssetMetadataTitle;
                             tCopyrightLayer.string=_currentAssetMetadataCopyrights;
                             
                             if (_metadadataMode==kMovieFrameShowMetadataAtStart)
                             {
                                 [self performSelectorOnMainThread:@selector(showMetadata:)
                                                        withObject:nil
                                                     waitUntilDone:NO];
                             }
                         }
                     }
                 }
             }];
         }
    }
    
    return YES;
}

- (void)showMetadata:(NSTimer *)inTimer
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideMetadata:) object:nil];
    
    if (_currentAssetMetadataTitle!=nil || _currentAssetMetadataCopyrights!=nil)
		[_metadataLayer setOpacity:1.0];
    
    [self performSelector:@selector(hideMetadata:) withObject:nil afterDelay:METADATA_DISPLAY_DURATION];
}

- (void)hideMetadata:(id)object
{
    [_metadataLayer setOpacity:0.0];
}

#pragma mark - Configuration

- (BOOL)hasConfigureSheet
{
    return YES;
}

- (NSWindow*)configureSheet
{
    if (_configurationWindowController==nil)
		_configurationWindowController=[[SHConfigurationWindowController alloc] init];
    
    NSWindow * tWindow=_configurationWindowController.window;
    
    [_configurationWindowController refreshSettings];
    
    return tWindow;
}



#pragma mark - Player Item Observer

- (void)playerItemDidPlayToEndMainThread:(AVPlayerItem *)inPlayerItem
{
    if (inPlayerItem==_AVPlayerLayer.player.currentItem)
    {
        AVPlayer * tCurrentPlayer=[_AVPlayerLayer player];
        
        if (_timer!=nil)
        {
            [_timer invalidate];
            
            [_timer release];
            _timer=nil;
        }
        
#ifdef __DEBUG_LOG__
        NSLog(@"Finished playing asset #%lu",__arrayIndex);
#endif
        
        // Rewind (only one asset and no random position) or play next
        
        if ([__assetsArray count]==1)
        {
            if (_randomPosition==NO)
            {
                [tCurrentPlayer seekToTime:kCMTimeZero];
                [tCurrentPlayer play];
                
                if (_preview==NO && _showMetadata==YES)
                {
                    if (_metadadataMode==kMovieFrameShowMetadataPeriodically)
                    {
                        _timer=[[NSTimer scheduledTimerWithTimeInterval:_metadadataPeriod target:self selector:@selector(showMetadata:) userInfo:nil repeats:YES] retain];
                    }
                    else
                    {
                        [self showMetadata:nil];
                    }
                }
                
                return;
            }
        }
        
        [self hideMetadata:nil];
        
        [_currentAssetMetadataTitle release];
        _currentAssetMetadataTitle=nil;
        
        [_currentAssetMetadataCopyrights release];
        _currentAssetMetadataCopyrights=nil;
        
        __arrayIndex++;
        
        if ([self playNextAsset:nil]==NO)
        {
            // A COMPLETER
        }
    }
}

- (void)playerItemDidPlayToEnd:(NSNotification *)inNotification
{
    AVPlayerItem * tPlayerItem=(AVPlayerItem *)[inNotification object];
    
    [self performSelector:@selector(playerItemDidPlayToEndMainThread:)
                 onThread:[NSThread mainThread]
               withObject:tPlayerItem
            waitUntilDone:YES];
}

#pragma mark - Notifications

- (void)increaseVolume:(NSNotificationCenter *)inNotification
{
    if ((_audioMainScreen==NO || _mainScreen==YES) &&
        (_liveMuted==NO))
    {
        AVPlayer * tCurrentPlayer=_AVPlayerLayer.player;
    
        _volumeLevel+=0.1f;
        
        if (_volumeLevel>1.0f)
			_volumeLevel=1.0f;
        
        if (tCurrentPlayer!=nil)
        {
            tCurrentPlayer.volume=_volumeLevel;
            
            _volumeLevelHasBeenModified=YES;
        }
    }
}

- (void)decreaseVolume:(NSNotificationCenter *)inNotification
{
    if ((_audioMainScreen==NO || _mainScreen==YES) &&
        (_liveMuted==NO))
    {
        AVPlayer * tCurrentPlayer=_AVPlayerLayer.player;
    
        _volumeLevel-=0.1f;
        
        if (_volumeLevel<0.0f)
			_volumeLevel=0.0f;
    
        if (tCurrentPlayer!=nil)
        {
            tCurrentPlayer.volume=_volumeLevel;
            
            _volumeLevelHasBeenModified=YES;
        }
    }
}

- (void)switchMutedState:(NSNotification *)inNotification
{
    if (_audioMainScreen==NO || _mainScreen==YES)
    {
        AVPlayer * tCurrentPlayer=_AVPlayerLayer.player;
    
        _liveMuted=!_liveMuted;
        
        if (tCurrentPlayer!=nil)
        {
            tCurrentPlayer.volume=(_liveMuted==YES) ? 0.0f : _volumeLevel;
            
            _volumeLevelHasBeenModified=YES;
        }
    }
}

@end
