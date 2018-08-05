#import <Foundation/Foundation.h>

@interface SHPlayingAssetsRegister : NSObject

+ (SHPlayingAssetsRegister *)sharedRegister;

    @property (readonly,nonatomic) NSArray * allPlayingAssets;

- (BOOL)isPlayingAsset:(id)inAsset;

- (void)addAsset:(id)inAsset;
- (void)removeAsset:(id)inAsset;

@end
