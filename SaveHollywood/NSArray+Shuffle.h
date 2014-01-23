#import <Foundation/Foundation.h>

@interface NSArray (Shuffle)

- (NSArray *)shuffledArray;

@end

@interface NSMutableArray (Shuffle)

- (void)shuffle;

@end