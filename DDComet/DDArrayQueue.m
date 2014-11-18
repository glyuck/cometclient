
#import "DDArrayQueue.h"


@interface DDArrayQueue ()

@property (atomic, strong) NSMutableArray *array;
@property (atomic, weak) id<DDQueueDelegate> delegate;

@end


@implementation DDArrayQueue

- (id)init
{
	if ((self = [super init]))
	{
		self.array = [[NSMutableArray alloc] init];
	}
	return self;
}


- (void)addObject:(id)object
{
	@synchronized(self.array)
	{
		[self.array addObject:object];
	}
	if (self.delegate)
		[self.delegate queueDidAddObject:self];
}

- (id)removeObject
{
	@synchronized(self.array)
	{
		if ([self.array count] == 0)
			return nil;
		id object = [self.array objectAtIndex:0];
		[self.array removeObjectAtIndex:0];
		return object;
	}
}

@end
