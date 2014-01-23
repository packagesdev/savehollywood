#import "NSArray+Shuffle.h"

#include <stdlib.h>

@implementation NSArray (Shuffle)

- (NSArray *)shuffledArray
{
    NSMutableArray * tMutableArray=[[self mutableCopy] autorelease];
    
    [tMutableArray shuffle];
    
    return tMutableArray;
}

@end

@implementation NSMutableArray (Shuffle)

- (void)shuffle
{
    NSUInteger tIndex,tCount=[self count];
    
    for(tIndex=0;tIndex<tCount;tIndex++)
    {
        // Select a random element between i and end of array to swap with.
        NSUInteger tCountLeft=tCount-tIndex;
        NSUInteger tOtherIndex = (NSUInteger) arc4random_uniform((u_int32_t) tCountLeft) + tIndex;
        
        [self exchangeObjectAtIndex:tIndex withObjectAtIndex:tOtherIndex];
    }
}

@end