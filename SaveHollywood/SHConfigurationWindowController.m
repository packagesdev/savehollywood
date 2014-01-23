/*
 Copyright (c) 2012-2013, Stephane Sudre
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 - Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 - Neither the name of the WhiteBox nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SHConfigurationWindowController.h"

#import <ScreenSaver/ScreenSaver.h>

#import "NSColor+String.h"
#import "NSIndexSet+Analysis.h"

#import "SHUserDefaults+Constants.h"

#import <AVFoundation/AVFoundation.h>

#import "SHSlider.h"
#import "SHAssetTableCellView.h"

#import "SHAboutBoxWindowController.h"

NSString * const SHConfigurationAssetPath=@"Path";
NSString * const SHConfigurationAssetIcon=@"Icon";
NSString * const SHConfigurationAssetFolder=@"Folder";
NSString * const SHConfigurationAssetFolderAssetsCount=@"Count";
NSString * const SHConfigurationAssetDuration=@"Duration";
NSString * const SHConfigurationAssetNotFound=@"NotFound";

NSString * const SHNotificationAssetPath=@"Path";
NSString * const SHNotificationAssetDurationString=@"DurationString";
NSString * const SHNotificationAssetFolderAssetsCount=@"Count";

NSString * const SHPasteboardTypeSelectedRows=@"savehollywood.pasterboardType.selectedRows";

@interface SHConfigurationWindowController ()
{
    // UI
    
    IBOutlet NSButton * _randomOrderCheckBox;
    
    IBOutlet NSTableView *_assetsTableView;
    
    IBOutlet NSButton *_addButton;
    IBOutlet NSButton *_deleteButton;
    
    IBOutlet NSMatrix *_frameScalingMatrix;
    IBOutlet NSButton *_frameRandomPositionCheckBox;
    
    IBOutlet NSButton *_frameDrawBorderCheckBox;
    IBOutlet NSButton * _frameShowMetatadaCheckBox;
    IBOutlet NSMatrix * _frameShowMetatadaModeMatrix;
    IBOutlet SHSlider * _frameShowMetatadaPeriodSlider;
    IBOutlet NSTextField * _frameShowMetatadaPeriodLiveValueLabel;
    
    IBOutlet NSColorWell *_backgroundColorWell;
    
    IBOutlet NSButton *_audioMainScreenCheckBox;
    IBOutlet NSMatrix *_volumeMatrix;
    IBOutlet NSButton *_volumeMuteButton;
    IBOutlet NSSlider *_volumeSlider;
    IBOutlet NSButton *_volumeFullButton;
    
    IBOutlet NSButton * _mainScreenCheckBox;
    
    // Data
    
    NSMutableArray *_cachedAssetsArray;
    
    NSIndexSet *_internalDragData;
}

+ (NSImage *)createIconForFileType:(NSString *)inFileType;
+ (NSImage *)createIconForFile:(NSString *)inPath;

- (void) updateAssetDuration:(id)inObject;
- (void) updateAssetsCount:(id)inObject;

- (IBAction)showInFinder:(id)sender;

- (IBAction)addAsset:(id)sender;
- (IBAction)removeAssets:(id)sender;

- (IBAction)switchFrameScaling:(id)sender;

- (IBAction)switchShowMetadata:(id)sender;
- (IBAction)switchShowMetadataMode:(id)sender;
- (IBAction)setPeriodWithSlider:(id)sender;

- (IBAction)switchVolumeMode:(id)sender;

- (IBAction)setVolumeMute:(id)sender;
- (IBAction)setVolumeFull:(id)sender;

- (IBAction)showAboutBox:(id)sender;

- (IBAction)closeDialog:(id)sender;

// Notifications

- (void)shouldShowValueLabel:(NSNotification *)inNotification;
- (void)shouldHideValueLabel:(NSNotification *)inNotification;

@end

@implementation SHConfigurationWindowController

+ (NSImage *)createIconForFileType:(NSString *)inFileType
{
    NSImage * tImage;
    
	tImage=[[NSWorkspace sharedWorkspace] iconForFileType:inFileType];
    
	[tImage setSize:NSMakeSize(16.,16.)];
    
    return tImage;
}

+ (NSImage *)createIconForFile:(NSString *)inPath
{
    NSImage * tImage;
    
	tImage=[[NSWorkspace sharedWorkspace] iconForFile:inPath];
    
	[tImage setSize:NSMakeSize(16.,16.)];
    
    return tImage;
}

#pragma mark -

- (NSString *)windowNibName
{
    return @"SHConfigurationWindowController";
}

#pragma mark -

- (void)windowDidLoad
{
    NSImage * tImage;
    NSBundle * tVolumeMenuBundle;
    NSURL * tURL;
    
    [super windowDidLoad];
    
    // Set the speaker icons
    
    tVolumeMenuBundle=[NSBundle bundleWithPath:@"/System/Library/CoreServices/Menu Extras/Volume.menu"];
    
    tURL=[tVolumeMenuBundle URLForResource:@"Volume1" withExtension:@"pdf"];
    
    if (tURL!=nil)
    {
        tImage=[[NSImage alloc] initWithContentsOfURL:tURL];
    
        if (tImage!=nil)
        {
            [_volumeMuteButton setImage:tImage];
            [tImage release];
        }
    }
    
    tURL=[tVolumeMenuBundle URLForResource:@"Volume4" withExtension:@"pdf"];
    
    if (tURL!=nil)
    {
        tImage=[[NSImage alloc] initWithContentsOfURL:tURL];
        
        if (tImage!=nil)
        {
            [_volumeFullButton setImage:tImage];
            [tImage release];
        }
    }
    
    // Register for D&D
    
    [_assetsTableView registerForDraggedTypes:[NSArray arrayWithObjects:SHPasteboardTypeSelectedRows,NSFilenamesPboardType,nil]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(shouldShowValueLabel:)
                                                 name:SHSliderValueDidBeginEditingNotification
                                               object:_frameShowMetatadaPeriodSlider];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(shouldHideValueLabel:)
                                                 name:SHSliderValueDidEndEditingNotification
                                               object:_frameShowMetatadaPeriodSlider];
}

#pragma mark -

- (void)refreshSettings
{
#ifdef __TEST_SCREENSAVER__
    NSUserDefaults *tDefaults = [NSUserDefaults standardUserDefaults];
#else
    NSString *tIdentifier = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
    ScreenSaverDefaults *tDefaults = [ScreenSaverDefaults defaultsForModuleWithName:tIdentifier];
#endif
    BOOL tBool;
    NSInteger tInteger;
    float tFloat;
    id tObject;
    NSString *tString;
    NSColor *tColor=nil;
    NSFileManager * tFileManager=[NSFileManager defaultManager];
    NSArray * tAssetsArray;
    
    // Assets
    
        // Random Order
    
    tBool=[tDefaults boolForKey:SHUserDefaultsAssetsRandomOrder];
    
    [_randomOrderCheckBox setState:(tBool==YES) ? NSOnState : NSOffState];
    
        // List
    
    _cachedAssetsArray=[[NSMutableArray alloc] initWithCapacity:3];
    
    tAssetsArray=[tDefaults objectForKey:SHUserDefaultsAssetsLibrary];
    
    for(NSString * tPath in tAssetsArray)
    {
        NSMutableDictionary * tMutableDictionary=[NSMutableDictionary dictionaryWithObject:tPath forKey:SHConfigurationAssetPath];
        BOOL isDirectory;
        
        if ([tFileManager fileExistsAtPath:tPath isDirectory:&isDirectory]==YES)
        {
            [tMutableDictionary setObject:[NSNumber numberWithBool:isDirectory] forKey:SHConfigurationAssetFolder];
        }
        else
        {
            [tMutableDictionary setObject:[NSNumber numberWithBool:YES] forKey:SHConfigurationAssetNotFound];
        }
        
        [_cachedAssetsArray addObject:tMutableDictionary];
    }
    
    // Frame
    
        // Scaling
    
    tInteger=[tDefaults integerForKey:SHUserDefaultsFrameScaling];
    
    [_frameScalingMatrix selectCellWithTag:tInteger];
    
    [_frameRandomPositionCheckBox setEnabled:(tInteger==kMovieFrameActualSize)];
    
        // Random Position
    
    tBool=[tDefaults boolForKey:SHUserDefaultsFrameRandomPosition];
    
    [_frameRandomPositionCheckBox setState:(tBool==YES) ? NSOnState : NSOffState];
    
        // Draw Border
    
    tBool=[tDefaults boolForKey:SHUserDefaultsFrameDrawBorder];
    
    [_frameDrawBorderCheckBox setState:(tBool==YES) ? NSOnState : NSOffState];
    
        // Show Metadata
    
    tBool=[tDefaults boolForKey:SHUserDefaultsFrameShowMetadata];
    
    [_frameShowMetatadaCheckBox setState:(tBool==YES) ? NSOnState : NSOffState];
    
    [_frameShowMetatadaModeMatrix setEnabled:tBool];
    
    tInteger=[tDefaults integerForKey:SHUserDefaultsFrameShowMetadataMode];
    
    [_frameShowMetatadaModeMatrix selectCellWithTag:tInteger];
    
    [_frameShowMetatadaPeriodSlider setEnabled:(tBool==YES && (tInteger==kMovieFrameShowMetadataPeriodically))];
    
    
    if ([tDefaults  objectForKey:SHUserDefaultsFrameShowMetadataPeriod]==nil)
        tInteger=SHUserDefaultsFrameShowMetadataPeriodMinimumValue;
    else
        tInteger=[tDefaults integerForKey:SHUserDefaultsFrameShowMetadataPeriod];
    
    [_frameShowMetatadaPeriodSlider setIntegerValue:tInteger];
    [_frameShowMetatadaPeriodLiveValueLabel setStringValue:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%ld seconds",@"Localized",[NSBundle bundleForClass:[self class]],@""),tInteger]];
    
    [_frameShowMetatadaPeriodLiveValueLabel setHidden:YES];
    
        // Background Color
    
    tString=[tDefaults stringForKey:SHUserDefaultsBackgroundColor];
    
    if (tString!=nil)
        tColor=[NSColor colorFromString:tString];
    
    if (tColor==nil)
        tColor=[NSColor blackColor];
    
    [_backgroundColorWell setColor:tColor];
    
    // Audio
    
    tBool=[tDefaults boolForKey:SHUserDefaultsAudioMainDisplayOnly];
    
    [_audioMainScreenCheckBox setState:(tBool==YES) ? NSOnState : NSOffState];
    
    // Volume
    
    tInteger=[tDefaults integerForKey:SHUserDefaultsMovieVolumeMode];
    
    [_volumeMatrix selectCellWithTag:tInteger];
    
    if (tInteger!=kMovieVolumeCustom)
    {
        [_volumeMuteButton setEnabled:NO];
        [_volumeSlider setEnabled:NO];
        [_volumeFullButton setEnabled:NO];
    }
    else
    {
        [_volumeMuteButton setEnabled:YES];
        [_volumeSlider setEnabled:YES];
        [_volumeFullButton setEnabled:YES];
    }
    
    tObject=[tDefaults objectForKey:SHUserDefaultsMovieVolumeCustomValue];
    
    if (tObject!=nil)
    {
        tFloat=[tDefaults floatForKey:SHUserDefaultsMovieVolumeCustomValue];
        [_volumeSlider setFloatValue:tFloat];
    }
    
    // Main Display Only
    
    tBool=[tDefaults boolForKey:SHUserDefaultsMainDisplayOnly];
    
    [_mainScreenCheckBox setState:(tBool==YES) ? NSOnState : NSOffState];
    
    [_assetsTableView reloadData];
}

#pragma mark -

- (void) updateAssetDuration:(id)inObject
{
    NSDictionary * tDictionary=(NSDictionary *) inObject;
    NSString * tPath=[tDictionary objectForKey:SHNotificationAssetPath];
    
    if (tPath!=nil)
    {
        for(NSMutableDictionary * tAssetDictionary in _cachedAssetsArray)
        {
            if ([[tAssetDictionary objectForKey:SHConfigurationAssetPath] isEqualToString:tPath]==YES)
            {
                [tAssetDictionary setObject:[tDictionary objectForKey:SHNotificationAssetDurationString] forKey:SHConfigurationAssetDuration];
            
                // Save selection
                
                NSIndexSet * tSelection=[_assetsTableView selectedRowIndexes];
                
                [_assetsTableView reloadData];
                
                // Restore selection
                
                [_assetsTableView selectRowIndexes:tSelection byExtendingSelection:NO];
                
                break;
            }
        }
    }
}

- (void) getAssetDurationThread:(NSString *)inPath
{
    if (inPath!=nil)
    {
        NSAutoreleasePool * tPool=[NSAutoreleasePool new];
    
        NSURL * tURL=[NSURL fileURLWithPath:inPath];
        
        if (tURL!=nil)
        {
            AVURLAsset *tAVAsset=[AVURLAsset URLAssetWithURL:tURL options:nil];
            
            if (tAVAsset!=nil)
            {
                CMTime tTime=tAVAsset.duration;
                Float64 tSeconds=CMTimeGetSeconds(tTime);
                
                unsigned int tNumberOfHours=tSeconds/(3600.0);
                tSeconds=tSeconds-(Float64)tNumberOfHours*3600.0;
                
                unsigned int tNumberOfMinutes=tSeconds/60.0;
                tSeconds=tSeconds-(Float64)tNumberOfMinutes*60.0;
                
                unsigned int tNumberOfSeconds=tSeconds;
                
                [self performSelectorOnMainThread:@selector(updateAssetDuration:)
                                       withObject:[NSDictionary dictionaryWithObjectsAndKeys:inPath,SHNotificationAssetPath,
                                                                                                 [NSString stringWithFormat:@"%02u:%02u:%02u",tNumberOfHours,tNumberOfMinutes,tNumberOfSeconds],SHNotificationAssetDurationString,
                                                                                                  nil]
                                        waitUntilDone:NO];
            }
        }
        
        [tPool drain];
    }
}

- (void) updateAssetsCount:(id)inObject
{
    NSDictionary * tDictionary=(NSDictionary *) inObject;
    NSString * tPath=[tDictionary objectForKey:SHNotificationAssetPath];
    
    if (tPath!=nil)
    {
        for(NSMutableDictionary * tAssetDictionary in _cachedAssetsArray)
        {
            if ([[tAssetDictionary objectForKey:SHConfigurationAssetPath] isEqualToString:tPath]==YES)
            {
                [tAssetDictionary setObject:[tDictionary objectForKey:SHNotificationAssetFolderAssetsCount] forKey:SHConfigurationAssetFolderAssetsCount];
                
                // Save selection
                
                NSIndexSet * tSelection=[_assetsTableView selectedRowIndexes];
                
                [_assetsTableView reloadData];
                
                // Restore selection
                
                [_assetsTableView selectRowIndexes:tSelection byExtendingSelection:NO];
                
                break;
            }
        }
    }
}

- (void) getAssetsCountThread:(NSString *)inPath
{
    if (inPath!=nil)
    {
        NSAutoreleasePool * tPool=[NSAutoreleasePool new];
        
        NSFileManager * tFileManager=[NSFileManager defaultManager];
        NSUInteger tCount=0;
        BOOL isDirectory;
        
        if ([tFileManager fileExistsAtPath:inPath isDirectory:&isDirectory]==YES && isDirectory==YES)
        {
            NSArray * tArray=[tFileManager contentsOfDirectoryAtPath:inPath error:NULL];
            NSArray * tUTIsArray=[AVURLAsset audiovisualTypes];
            
            for(NSString * tFileName in tArray)
            {
                NSString * tFilePath=[inPath stringByAppendingPathComponent:tFileName];
                
                if ([tFileManager fileExistsAtPath:tFilePath isDirectory:&isDirectory]==YES && isDirectory==NO)
                {
                    NSString * tFileUTI;
                    NSURL * tURL=[NSURL fileURLWithPath:tFilePath];
                    
                    if ([tURL getResourceValue:&tFileUTI forKey:NSURLTypeIdentifierKey error:NULL]==YES)
                    {
                        if ([tUTIsArray containsObject:tFileUTI]==YES)
                        {
                            AVURLAsset *tAVAsset=[AVURLAsset URLAssetWithURL:tURL options:nil];
                            
                            if (tAVAsset.isPlayable==YES)
                            {
                                tCount++;
                            }
                        }
                    }
                }
            }
        }
        
        [self performSelectorOnMainThread:@selector(updateAssetsCount:)
                               withObject:[NSDictionary dictionaryWithObjectsAndKeys:inPath,SHNotificationAssetPath,
                                                                                     [NSNumber numberWithUnsignedInteger:tCount],SHNotificationAssetFolderAssetsCount,
                                                                                     nil]
                            waitUntilDone:NO];
        
        [tPool drain];
    }
}

#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)inMenuItem
{
    SEL tAction=[inMenuItem action];
    
    if (tAction==@selector(showInFinder:))
    {
        NSInteger tClickedRow=[_assetsTableView clickedRow];
        
        if (tClickedRow!=-1)
        {
            NSIndexSet * tIndexSet=[_assetsTableView selectedRowIndexes];
            NSDictionary * tDictionary;
            NSString * tAssetPath;
            NSFileManager * tFileManager=[NSFileManager defaultManager];
            
            if ([tIndexSet containsIndex:tClickedRow]==NO)
            {
                tDictionary=[_cachedAssetsArray objectAtIndex:tClickedRow];
                
                tAssetPath=[tDictionary objectForKey:SHConfigurationAssetPath];
                
                if (tAssetPath!=nil)
                {
                    return [tFileManager fileExistsAtPath:tAssetPath];
                }
            }
            else
            {
                NSUInteger tCount=[tIndexSet count];
                
                for(tDictionary in [_cachedAssetsArray objectsAtIndexes:tIndexSet])
                {
                    tAssetPath=[tDictionary objectForKey:SHConfigurationAssetPath];
                    
                    if (tAssetPath!=nil)
                    {
                        if ([tFileManager fileExistsAtPath:tAssetPath]==NO)
                        {
                            tCount--;
                        }
                    }
                }
                
                return (tCount>0);
            }
        }
    }
    
    return YES;
}

- (IBAction)showInFinder:(id)sender
{
    NSInteger tClickedRow=[_assetsTableView clickedRow];
    
    if (tClickedRow!=-1)
    {
        NSIndexSet * tIndexSet=[_assetsTableView selectedRowIndexes];
        NSDictionary * tDictionary;
        NSString * tAssetPath;
        
        if ([tIndexSet containsIndex:tClickedRow]==NO)
        {
            tDictionary=[_cachedAssetsArray objectAtIndex:tClickedRow];
            
            tAssetPath=[tDictionary objectForKey:SHConfigurationAssetPath];
            
            if (tAssetPath!=nil)
            {
                [[NSWorkspace sharedWorkspace] selectFile:tAssetPath inFileViewerRootedAtPath:@""];
            }
        }
        else
        {
            for(tDictionary in [_cachedAssetsArray objectsAtIndexes:tIndexSet])
            {
                tAssetPath=[tDictionary objectForKey:SHConfigurationAssetPath];
                
                if (tAssetPath!=nil)
                {
                    [[NSWorkspace sharedWorkspace] selectFile:tAssetPath inFileViewerRootedAtPath:@""];
                }
            }
        }
    }
}

- (IBAction)addAsset:(id)sender
{
    NSOpenPanel *tOpenPanel;
    
    tOpenPanel=[NSOpenPanel openPanel];
    
    if (tOpenPanel!=nil)
    {
        NSInteger tResult;
        
        [tOpenPanel setDelegate:self];
        [tOpenPanel setCanChooseDirectories:YES];
        [tOpenPanel setAllowsMultipleSelection:YES];
        [tOpenPanel setAllowedFileTypes:[AVURLAsset audiovisualTypes]];
        [tOpenPanel setTitle:NSLocalizedStringFromTableInBundle(@"Add video or folder",@"Localized",[NSBundle bundleForClass:[self class]],@"")];
        [tOpenPanel setPrompt:NSLocalizedStringFromTableInBundle(@"Add",@"Localized",[NSBundle bundleForClass:[self class]],@"")];
        
        tResult=[tOpenPanel runModal];
        
        if (tResult==NSFileHandlingPanelOKButton)
        {
            NSArray * tURLs=[tOpenPanel URLs];
            NSMutableIndexSet * tMutableIndexSet=[NSMutableIndexSet indexSet];
            NSUInteger tCount=[_cachedAssetsArray count];
            NSFileManager * tFileManager=[NSFileManager defaultManager];
            
            for(NSURL * tURL in tURLs)
            {
                if ([tURL isFileURL]==YES)
                {
                    NSString * tPath=[tURL path];
                    BOOL tFound=NO;
                    
                    NSMutableDictionary * tMutableDictionary=[NSMutableDictionary dictionaryWithObject:tPath forKey:SHConfigurationAssetPath];
                    BOOL isDirectory;
                    
                    if ([tFileManager fileExistsAtPath:tPath isDirectory:&isDirectory]==YES)
                    {
                        [tMutableDictionary setObject:[NSNumber numberWithBool:isDirectory] forKey:SHConfigurationAssetFolder];
                    }
                    else
                    {
                        [tMutableDictionary setObject:[NSNumber numberWithBool:YES] forKey:SHConfigurationAssetNotFound];
                    }
                    
                    for(NSDictionary * tAssetDictionary in _cachedAssetsArray)
                    {
                        NSString * tAssetPath=[tAssetDictionary objectForKey:SHConfigurationAssetPath];
                        
                        if ([tAssetPath caseInsensitiveCompare:tPath]==NSOrderedSame)
                        {
                            tFound=YES;
                            break;
                        }
                    }
                    
                    if (tFound==NO)
                    {
                        [_cachedAssetsArray addObject:tMutableDictionary];
                        
                        [tMutableIndexSet addIndex:tCount];
                        tCount++;
                    }
                }
            }
            
            if ([tMutableIndexSet count]>0)
            {
                [_assetsTableView reloadData];
                
                [_assetsTableView selectRowIndexes:tMutableIndexSet byExtendingSelection:NO];
            }
        }
    }
}

- (IBAction)removeAssets:(id)sender
{
    NSIndexSet * tIndexSet=[_assetsTableView selectedRowIndexes];
    
    [_cachedAssetsArray removeObjectsAtIndexes:tIndexSet];
    
    [_assetsTableView deselectAll:nil];
    
    [_assetsTableView reloadData];
}

- (IBAction)switchFrameScaling:(id)sender
{
    [_frameRandomPositionCheckBox setEnabled:([[sender selectedCell] tag]==kMovieFrameActualSize)];
}

- (IBAction)switchShowMetadata:(id)sender
{
    BOOL tBool=([sender state]==NSOnState);
    NSInteger tTag=[[_frameShowMetatadaModeMatrix selectedCell] tag];
    
    [_frameShowMetatadaModeMatrix setEnabled:tBool];
    
    [_frameShowMetatadaPeriodSlider setEnabled:tBool && (tTag==kMovieFrameShowMetadataPeriodically)];
}

- (IBAction)switchShowMetadataMode:(id)sender
{
    NSInteger tTag=[[sender selectedCell] tag];
    
    [_frameShowMetatadaPeriodSlider setEnabled:(tTag==kMovieFrameShowMetadataPeriodically)];
}

- (IBAction)setPeriodWithSlider:(id)sender
{
    [_frameShowMetatadaPeriodLiveValueLabel setStringValue:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%ld seconds",@"Localized",[NSBundle bundleForClass:[self class]],@""),[sender integerValue]]];
}

- (IBAction)switchVolumeMode:(id)sender
{
    NSInteger tTag=[[sender selectedCell] tag];
    
    if (tTag!=kMovieVolumeCustom)
    {
        [_volumeMuteButton setEnabled:NO];
        [_volumeSlider setEnabled:NO];
        [_volumeFullButton setEnabled:NO];
    }
    else
    {
        [_volumeMuteButton setEnabled:YES];
        [_volumeSlider setEnabled:YES];
        [_volumeFullButton setEnabled:YES];
    }
}

- (IBAction)setVolumeMute:(id)sender
{
    [_volumeSlider setFloatValue:0.0f];
}

- (IBAction)setVolumeFull:(id)sender
{
    [_volumeSlider setFloatValue:1.0f];
}

- (IBAction)showAboutBox:(id)sender
{
    static SHAboutBoxWindowController * sAboutBoxWindowController=nil;
    
    if (sAboutBoxWindowController==nil)
    {
        sAboutBoxWindowController=[SHAboutBoxWindowController new];
    }
    
    if ([sAboutBoxWindowController.window isVisible]==NO)
    {
        [sAboutBoxWindowController.window center];
    }
    
    [sAboutBoxWindowController.window makeKeyAndOrderFront:nil];
}

- (IBAction)closeDialog:(id)sender
{
    if ([sender tag]==NSOKButton)
    {
#ifdef __TEST_SCREENSAVER__
        NSUserDefaults *tDefaults = [NSUserDefaults standardUserDefaults];
#else
        NSString *tIdentifier = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
        ScreenSaverDefaults *tDefaults = [ScreenSaverDefaults defaultsForModuleWithName:tIdentifier];
#endif
        NSInteger tInteger;
        NSColor *tColor;
        NSString *tString;
        
        // Assets
        
            // Random Order
        
        [tDefaults setBool:([_randomOrderCheckBox state]==NSOnState) forKey:SHUserDefaultsAssetsRandomOrder];

            // List
        
        NSMutableArray * tAssetsArray=[NSMutableArray array];
        
        for(NSDictionary * tAssetDictionary in _cachedAssetsArray)
        {
            NSString * tAssetPath=[tAssetDictionary objectForKey:SHConfigurationAssetPath];
            
            if (tAssetPath!=nil)
                [tAssetsArray addObject:tAssetPath];
        }
        
        [tDefaults setObject:tAssetsArray
                      forKey:SHUserDefaultsAssetsLibrary];
        
        // Frame
        
            // Scaling
        
        tInteger=[[_frameScalingMatrix selectedCell] tag];
        
        [tDefaults setInteger:tInteger forKey:SHUserDefaultsFrameScaling];
        
            // Random Position
        
        [tDefaults setBool:([_frameRandomPositionCheckBox state]==NSOnState) forKey:SHUserDefaultsFrameRandomPosition];
        
            // Draw Border
        
        [tDefaults setBool:([_frameDrawBorderCheckBox state]==NSOnState) forKey:SHUserDefaultsFrameDrawBorder];
        
            // Show Metadata
        
        [tDefaults setBool:([_frameShowMetatadaCheckBox state]==NSOnState) forKey:SHUserDefaultsFrameShowMetadata];
        
            // Show Metadata mode
        
        tInteger=[[_frameShowMetatadaModeMatrix selectedCell] tag];
        
        [tDefaults setInteger:tInteger forKey:SHUserDefaultsFrameShowMetadataMode];
        
        if (tInteger==kMovieFrameShowMetadataPeriodically)
            [tDefaults setInteger:[_frameShowMetatadaPeriodSlider integerValue] forKey:SHUserDefaultsFrameShowMetadataPeriod];
        
        // Color
        
        tColor=[_backgroundColorWell color];
        
        if (tColor!=nil)
        {
            tString=[tColor stringValue];
            
            if (tString!=nil)
                [tDefaults setObject:tString forKey:SHUserDefaultsBackgroundColor];
        }
        
        // Audio
        
        [tDefaults setBool:([_audioMainScreenCheckBox state]==NSOnState) forKey:SHUserDefaultsAudioMainDisplayOnly];
        
        // Volume
        
        tInteger=[[_volumeMatrix selectedCell] tag];
        
        [tDefaults setInteger:tInteger forKey:SHUserDefaultsMovieVolumeMode];
        
        if (tInteger==kMovieVolumeCustom)
            [tDefaults setFloat:[_volumeSlider floatValue] forKey:SHUserDefaultsMovieVolumeCustomValue];
        
        // Main Screen Only
        
        [tDefaults setBool:([_mainScreenCheckBox state]==NSOnState) forKey:SHUserDefaultsMainDisplayOnly];
        
        [tDefaults synchronize];
    }
    
    [_assetsTableView deselectAll:nil];
    
    [NSApp endSheet:self.window];
}

#pragma mark - NSTableView DataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)inTableView
{
    if (inTableView==_assetsTableView)
        return [_cachedAssetsArray count];
    
    return 0;
}

- (NSView *)tableView:(NSTableView *)inTableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)inRow
{
    if (inTableView==_assetsTableView)
    {
        SHAssetTableCellView * tAssetTableView = [inTableView makeViewWithIdentifier:@"AssetView" owner:self];
        
        NSMutableDictionary * tAssetDictionary=[_cachedAssetsArray objectAtIndex:inRow];
        NSNumber * tNumber;

        tNumber=[tAssetDictionary objectForKey:SHConfigurationAssetNotFound];
        
        if (tNumber==nil)
        {
            // Icon
            
            NSImage * tIcon=[tAssetDictionary objectForKey:SHConfigurationAssetIcon];
            
            if (tIcon==nil)
            {
                tIcon=[[NSWorkspace sharedWorkspace] iconForFile:[tAssetDictionary objectForKey:SHConfigurationAssetPath]];
                
                if (tIcon!=nil)
                    [tAssetDictionary setObject:tIcon forKey:SHConfigurationAssetIcon];
            }
            
            if ([[tAssetDictionary objectForKey:SHConfigurationAssetFolder] boolValue]==YES)
            {
                [tAssetTableView.textField setHidden:YES];
                [tAssetTableView.durationLabel setHidden:YES];
                [tAssetTableView.folderNameLabel setHidden:NO];
                [tAssetTableView.folderAssetsCountLabel setHidden:NO];
                
                [tAssetTableView.folderNameLabel setStringValue:[[tAssetDictionary objectForKey:SHConfigurationAssetPath] lastPathComponent]];
                
                [tAssetTableView.folderNameLabel setTextColor:[NSColor blackColor]];
            
                tAssetTableView.imageView.image=tIcon;
                
                // Number of assets at first level of folder
                
                NSNumber * tNumber=[tAssetDictionary objectForKey:SHConfigurationAssetFolderAssetsCount];
                
                if (tNumber==nil)
                {
                    [tAssetTableView.folderAssetsCountLabel setStringValue:@"-"];
                    
                    [NSThread detachNewThreadSelector:@selector(getAssetsCountThread:) toTarget:self withObject:[tAssetDictionary objectForKey:SHConfigurationAssetPath]];
                }
                else
                {
                    [tAssetTableView.folderAssetsCountLabel setUnsignedIntegerValue:[tNumber unsignedIntegerValue]];
                }
            }
            else
            {
                [tAssetTableView.textField setHidden:NO];
                [tAssetTableView.durationLabel setHidden:NO];
                [tAssetTableView.folderNameLabel setHidden:YES];
                [tAssetTableView.folderAssetsCountLabel setHidden:YES];
                
                [tAssetTableView.textField setStringValue:[[tAssetDictionary objectForKey:SHConfigurationAssetPath] lastPathComponent]];
                
                tAssetTableView.imageView.image=tIcon;
                
                NSString * tString;
                
                // Duration
                
                tString=[tAssetDictionary objectForKey:SHConfigurationAssetDuration];
                
                if (tString==nil)
                {
                    // Find the duration in a detached thread
                    
                    [tAssetTableView.durationLabel setStringValue:@"--:--:--"];
                    
                    [NSThread detachNewThreadSelector:@selector(getAssetDurationThread:) toTarget:self withObject:[tAssetDictionary objectForKey:SHConfigurationAssetPath]];
                }
                else
                {
                    [tAssetTableView.durationLabel setStringValue:tString];
                }
            }
        }
        else
        {
            [tAssetTableView.textField setHidden:YES];
            [tAssetTableView.durationLabel setHidden:YES];
            [tAssetTableView.folderNameLabel setHidden:NO];
            [tAssetTableView.folderAssetsCountLabel setHidden:YES];
            
            [tAssetTableView.folderNameLabel setStringValue:[[tAssetDictionary objectForKey:SHConfigurationAssetPath] lastPathComponent]];
            
            [tAssetTableView.folderNameLabel setTextColor:[NSColor redColor]];
            
            tAssetTableView.imageView.image=[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kUnknownFSObjectIcon)];
        }
        
        return tAssetTableView;
    }
    
    return nil;
}

- (BOOL)tableView:(NSTableView *)inTableView writeRowsWithIndexes:(NSIndexSet *)inIndexSet toPasteboard:(NSPasteboard *)inPasteboard
{
    if (inTableView==_assetsTableView)
    {
        if ([inIndexSet count]>0)
        {
            [inPasteboard declareTypes:[NSArray arrayWithObject:SHPasteboardTypeSelectedRows] owner:nil];
            
            [_internalDragData release];
            _internalDragData=[inIndexSet retain];
            
            [inPasteboard setData:[NSData data] forType:SHPasteboardTypeSelectedRows];
        
            return YES;
        }
    }
    
    return NO;
}

- (NSDragOperation)tableView:(NSTableView *)inTableView validateDrop:(id <NSDraggingInfo>)inDraggingInfo proposedRow:(NSInteger)inRow proposedDropOperation:(NSTableViewDropOperation)inDropOperation
{
    if (inTableView==_assetsTableView && inDropOperation==NSTableViewDropAbove)
    {
        NSPasteboard * tPasteboard;
        NSString * tPasteboardType;
        
        tPasteboard=[inDraggingInfo draggingPasteboard];
        
        tPasteboardType=[tPasteboard availableTypeFromArray:[NSArray arrayWithObjects:SHPasteboardTypeSelectedRows,NSFilenamesPboardType,nil]];
        
        if ([tPasteboardType isEqualToString:SHPasteboardTypeSelectedRows]==YES)
        {
            if ([_internalDragData containsOnlyOneRange]==YES)
            {
                NSUInteger tFirstIndex=[_internalDragData firstIndex];
                NSUInteger tLastIndex=[_internalDragData lastIndex];
                
                if (inRow>=tFirstIndex && inRow<=(tLastIndex+1))
                    return NSDragOperationNone;
            }
            else
            {
                if ([_internalDragData containsIndex:(inRow-1)]==YES)
                    return NSDragOperationNone;
            }
            
            return NSDragOperationMove;
        }
        else if ([tPasteboardType isEqualToString:NSFilenamesPboardType]==YES)
        {
            // Check whether the files can be accepted (same as Open panel in 2 steps)
            
            NSArray * tFilesArray = [tPasteboard propertyListForType:NSFilenamesPboardType];
            NSFileManager * tFileManager=[NSFileManager defaultManager];
            NSWorkspace * tSharedWorkspace=[NSWorkspace sharedWorkspace];
            NSArray * tAcceptedUTIsArray=[AVURLAsset audiovisualTypes];
            BOOL tFoundAtLeastOne=NO;
            
            for (NSString * tFile in tFilesArray)
            {
                // Check that the path is not already in the list
                
                BOOL tFound=NO;
                
                for(NSDictionary * tAssetDictionary in _cachedAssetsArray)
                {
                    NSString * tAssetPath=[tAssetDictionary objectForKey:SHConfigurationAssetPath];
                    
                    if ([tAssetPath caseInsensitiveCompare:tFile]==NSOrderedSame)
                    {
                        tFound=YES;
                        break;
                    }
                }
                
                if (tFound==NO)
                {
                    BOOL isDirectory;
                    
                    if ([tFileManager fileExistsAtPath:tFile isDirectory:&isDirectory]==YES)
                    {
                        if (isDirectory==YES)
                        {
                            tFoundAtLeastOne=YES;
                            break;
                        }
                        else
                        {
                            NSString * tUTI=[tSharedWorkspace typeOfFile:tFile error:NULL];
                            
                            if (tUTI!=nil)
                            {
                                if ([tAcceptedUTIsArray containsObject:tUTI]==YES)
                                {
                                    tFoundAtLeastOne=YES;
                                    break;
                                }
                            }
                        }
                    }
                }
            }
            
            if (tFoundAtLeastOne==YES)
                return NSDragOperationCopy;
        }
    }
    
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)inTableView acceptDrop:(id <NSDraggingInfo>)inDraggingInfo row:(NSInteger)inRow dropOperation:(NSTableViewDropOperation)inDropOperation
{
    if (inTableView==_assetsTableView)
    {
        NSPasteboard * tPasteboard;
        NSString * tPasteboardType;
        NSMutableArray * tNewAssets=nil;
        
        tPasteboard=[inDraggingInfo draggingPasteboard];
        
        tPasteboardType=[tPasteboard availableTypeFromArray:[NSArray arrayWithObjects:SHPasteboardTypeSelectedRows,NSFilenamesPboardType,nil]];
        
        if ([tPasteboardType isEqualToString:SHPasteboardTypeSelectedRows]==YES)
        {
            NSUInteger tIndex=[_internalDragData firstIndex];
            
            tNewAssets=[[[_cachedAssetsArray objectsAtIndexes:_internalDragData] mutableCopy] autorelease];
            
            while (tIndex!=NSNotFound)
            {
                if (tIndex<inRow)
                    inRow--;
                
                tIndex=[_internalDragData indexGreaterThanIndex:tIndex];
            }
            
            [_cachedAssetsArray removeObjectsAtIndexes:_internalDragData];
        }
        else if ([tPasteboardType isEqualToString:NSFilenamesPboardType]==YES)
        {
            NSArray * tFilesArray = [tPasteboard propertyListForType:NSFilenamesPboardType];
            NSFileManager * tFileManager=[NSFileManager defaultManager];
            
            tNewAssets=[NSMutableArray array];
            
            for(NSString * tFile in tFilesArray)
            {
                BOOL tFound=NO;
                
                for(NSDictionary * tAssetDictionary in _cachedAssetsArray)
                {
                    NSString * tAssetPath=[tAssetDictionary objectForKey:SHConfigurationAssetPath];
                    
                    if ([tAssetPath caseInsensitiveCompare:tFile]==NSOrderedSame)
                    {
                        tFound=YES;
                        break;
                    }
                }
                
                if (tFound==NO)
                {
                    BOOL isDirectory;
                    
                    if ([tFileManager fileExistsAtPath:tFile isDirectory:&isDirectory]==YES)
                    {
                        if (isDirectory==YES)
                        {
                            NSMutableDictionary * tMutableDictionary=[NSMutableDictionary dictionaryWithObject:tFile forKey:SHConfigurationAssetPath];
                            
                            [tMutableDictionary setObject:[NSNumber numberWithBool:YES] forKey:SHConfigurationAssetFolder];
                            
                            [tNewAssets addObject:tMutableDictionary];
                        }
                        else
                        {
                            NSURL * tFileURL=[NSURL fileURLWithPath:tFile];
                            
                            if (tFileURL!=nil)
                            {
                                AVURLAsset *tAVAsset=[AVURLAsset URLAssetWithURL:tFileURL options:nil];
                            
                                if (tAVAsset.isPlayable==YES)
                                {
                                    NSMutableDictionary * tMutableDictionary=[NSMutableDictionary dictionaryWithObject:tFile forKey:SHConfigurationAssetPath];
                                    
                                    [tMutableDictionary setObject:[NSNumber numberWithBool:NO] forKey:SHConfigurationAssetFolder];
                                    
                                    [tNewAssets addObject:tMutableDictionary];
                                }
                            }
                        }
                    }
                }
            }
        }
        
        NSUInteger tCount=[tNewAssets count];
        
        if (tCount>0)
        {
            [_cachedAssetsArray insertObjects:tNewAssets
                                    atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(inRow,tCount)]];
            
            [_assetsTableView reloadData];
            
            // Update selection
            
            [_assetsTableView selectRowIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(inRow,tCount)]
                          byExtendingSelection:NO];
            
            return YES;
        }
        else
        {
            NSBeep();
        }
    }
    
    return NO;
}

#pragma mark - NSSavePanel delegate

- (BOOL)panel:(id)sender validateURL:(NSURL *)inURL error:(NSError **)outError
{
    if ([inURL isFileURL]==YES)
    {
        NSFileManager * tFileManager=[NSFileManager defaultManager];
        BOOL tIsDirectory;
        
        if ([tFileManager fileExistsAtPath:[inURL path] isDirectory:&tIsDirectory]==YES && tIsDirectory==YES)
            return YES;
    }
    
    AVURLAsset *tAVAsset=[AVURLAsset URLAssetWithURL:inURL options:nil];
    
    if (tAVAsset.isPlayable==NO)
    {
        // A COMPLETER
        
        return NO;
    }
    
    return YES;
}

#pragma mark - Notifications

- (void)tableViewSelectionDidChange:(NSNotification *)inNotification
{
    [_deleteButton setEnabled:[_assetsTableView numberOfSelectedRows]>0];
}

- (void)shouldShowValueLabel:(NSNotification *)inNotification
{
    [_frameShowMetatadaPeriodLiveValueLabel setHidden:NO];
}

- (void)shouldHideValueLabel:(NSNotification *)inNotification
{
    [_frameShowMetatadaPeriodLiveValueLabel setHidden:YES];
}

@end
