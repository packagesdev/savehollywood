
#import "SHSettings.h"

#ifndef __TEST_SCREENSAVER__
#import <ScreenSaver/ScreenSaver.h>
#endif

#import "NSColor+String.h"

NSString * const SHUserDefaultsAssetsRandomOrder=@"assets.randomOrder";
NSString * const SHUserDefaultsAssetsStartWhereLeftOff=@"assets.startWhereLeftOff";
NSString * const SHUserDefaultsAssetsLibrary=@"assets.library";

NSString * const SHUserDefaultsFrameScaling=@"frame.scaling";
NSString * const SHUserDefaultsFrameRandomPosition=@"frame.randomPosition";

NSString * const SHUserDefaultsFrameDrawBorder=@"frame.drawBorder";
NSString * const SHUserDefaultsFrameShowMetadata=@"frame.showMetadata";
NSString * const SHUserDefaultsFrameShowMetadataMode=@"frame.showMetadata.mode";
NSString * const SHUserDefaultsFrameShowMetadataPeriod=@"frame.showMetadata.period";


NSString * const SHUserDefaultsBackgroundColor=@"frame.background.color";

NSString * const SHUserDefaultsAudioMainDisplayOnly=@"movie.audio.mainDisplayOnly";

NSString * const SHUserDefaultsMovieVolumeMode=@"movie.volume.mode";

NSString * const SHUserDefaultsMovieVolumeCustomValue=@"movie.volume.value";

NSString * const SHUserDefaultsMainDisplayOnly=@"screen.mainDisplayOnly";

NSString * const SHSharedLockUserDefaultsRepresentationPath=@"/Library/Preferences/fr.whitebox.SaveHollywood.locked.plist";

static BOOL sSettingsAreLocked=NO;

@implementation SHSettings

+ (SHSettings *)settings
{
	NSDictionary * tRepresentation=[NSDictionary dictionaryWithContentsOfFile:SHSharedLockUserDefaultsRepresentationPath];
	
	if (tRepresentation==nil)
	{
		sSettingsAreLocked=NO;
		
#ifdef __TEST_SCREENSAVER__
		NSUserDefaults *tDefaults = [NSUserDefaults standardUserDefaults];
#else
		NSString *tIdentifier = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
		ScreenSaverDefaults *tDefaults = [ScreenSaverDefaults defaultsForModuleWithName:tIdentifier];
#endif
	
		tRepresentation=[tDefaults dictionaryRepresentation];
	}
	else
	{
		sSettingsAreLocked=YES;
	}
	
	return [[[SHSettings alloc] initWithDictionaryRepresentation:tRepresentation] autorelease];
}

+ (BOOL)isConfigurationLocked
{
	return [[NSFileManager defaultManager] fileExistsAtPath:SHSharedLockUserDefaultsRepresentationPath];
}

- (instancetype)initWithDictionaryRepresentation:(NSDictionary *)inDictionary
{
	self=[super init];
	
	if (self!=nil)
	{
		id tValue=inDictionary[SHUserDefaultsAssetsRandomOrder];
		
		if (tValue==nil)
		{
			[self resetSettings];
		}
		else
		{
			_randomOrder=[inDictionary[SHUserDefaultsAssetsRandomOrder] boolValue];
			_startWhereLeftOff=[inDictionary[SHUserDefaultsAssetsStartWhereLeftOff] boolValue];
			
			NSArray * tArray=inDictionary[SHUserDefaultsAssetsLibrary];
			
			if (tArray==nil)
				tArray=@[];
			
			_assets=[tArray mutableCopy];
			
			_scaling=[inDictionary[SHUserDefaultsFrameScaling] integerValue];
			_randomPosition=[inDictionary[SHUserDefaultsFrameRandomPosition] boolValue];
			
			_drawBorder=[inDictionary[SHUserDefaultsFrameDrawBorder] boolValue];
			_showMetadata=[inDictionary[SHUserDefaultsFrameShowMetadata] boolValue];
			_showMetadataMode=[inDictionary[SHUserDefaultsFrameShowMetadataMode] integerValue];
			_showMetadataPeriod=[inDictionary[SHUserDefaultsFrameShowMetadataPeriod] integerValue];
			
			NSString * tString=inDictionary[SHUserDefaultsBackgroundColor];;
			
			if (tString!=nil)
				_backgroundColor=[[NSColor colorFromString:tString] copy];
			
			if (_backgroundColor==nil)
				_backgroundColor=[NSColor blackColor];
			
			_audioMainScreenOnly=[inDictionary[SHUserDefaultsAudioMainDisplayOnly] boolValue];
			_audioMode=[inDictionary[SHUserDefaultsMovieVolumeMode] integerValue];
			_audioVolume=[inDictionary[SHUserDefaultsMovieVolumeCustomValue] integerValue];
			
			
			_mainDisplayOnly=[inDictionary[SHUserDefaultsMainDisplayOnly] boolValue];
		}
		
		return self;
	}
	
	return nil;
}

- (NSDictionary *)dictionaryRepresentation
{
	NSMutableDictionary * tMutableDictionary=[NSMutableDictionary dictionary];
	
	if (tMutableDictionary!=nil)
	{
		tMutableDictionary[SHUserDefaultsAssetsRandomOrder]=@(self.randomOrder);
		tMutableDictionary[SHUserDefaultsAssetsStartWhereLeftOff]=@(self.startWhereLeftOff);
		
		tMutableDictionary[SHUserDefaultsAssetsLibrary]=[[self.assets copy] autorelease];
		
		tMutableDictionary[SHUserDefaultsFrameScaling]=@(self.scaling);
		tMutableDictionary[SHUserDefaultsFrameRandomPosition]=@(self.randomPosition);
		
		tMutableDictionary[SHUserDefaultsFrameDrawBorder]=@(self.drawBorder);
		tMutableDictionary[SHUserDefaultsFrameShowMetadata]=@(self.showMetadata);
		tMutableDictionary[SHUserDefaultsFrameShowMetadataMode]=@(self.showMetadataMode);
		tMutableDictionary[SHUserDefaultsFrameShowMetadataPeriod]=@(self.showMetadataPeriod);
		
		tMutableDictionary[SHUserDefaultsBackgroundColor]=[self.backgroundColor stringValue];
		
		tMutableDictionary[SHUserDefaultsAudioMainDisplayOnly]=@(self.audioMainScreenOnly);
		tMutableDictionary[SHUserDefaultsMovieVolumeMode]=@(self.audioMode);
		tMutableDictionary[SHUserDefaultsMovieVolumeCustomValue]=@(self.audioVolume);
		
		tMutableDictionary[SHUserDefaultsMainDisplayOnly]=@(self.mainDisplayOnly);
	}
	
	return [tMutableDictionary copy];
}

- (void)resetSettings
{
	self.randomOrder=NO;
	self.startWhereLeftOff=NO;
	
	self.assets=[NSMutableArray array];
	
	self.scaling=SHMovieScaleProportionallyUpOrDown;
	self.randomPosition=NO;
	
	self.drawBorder=NO;
	self.showMetadata=NO;
	self.showMetadataMode=kMovieFrameShowMetadataAtStart;
	self.showMetadataPeriod=SHUserDefaultsFrameShowMetadataPeriodMinimumValue;
	
	self.backgroundColor=[NSColor blackColor];
	
	self.audioMainScreenOnly=NO;
	self.audioMode=SHMovieAudioVolumeNormal;
	self.audioVolume=1.0;
	
	self.mainDisplayOnly=NO;
}

@end
