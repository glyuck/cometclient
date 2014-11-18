
#import "DDConcurrentQueue.h"
#import <libkern/OSAtomic.h>


@interface DDConcurrentQueueNode : NSObject

@property (atomic, strong) id object;
@property (atomic, strong, readonly) DDConcurrentQueueNode *next;

- (BOOL)compareNext:(DDConcurrentQueueNode *)old andSet:(DDConcurrentQueueNode *)new;

@end

@interface DDConcurrentQueueNode ()

@property (atomic, strong, readwrite) DDConcurrentQueueNode *next;

@end

@implementation DDConcurrentQueueNode


- (id)initWithObject:(id)object
{
	if ((self = [super init]))
	{
		self.object = object;
	}
	return self;
}

- (BOOL)compareNext:(DDConcurrentQueueNode *)old andSet:(DDConcurrentQueueNode *)new
{
	@synchronized (self) {
		if (old == self.next) {
			self.next = new;
			return YES;
		}
		return NO;
	}
}

@end

@interface DDConcurrentQueue ()

@property (atomic, strong) DDConcurrentQueueNode *head;
@property (atomic, strong) DDConcurrentQueueNode *tail;
@property (atomic, weak) id<DDQueueDelegate> delegate;


- (BOOL)compareHead:(DDConcurrentQueueNode *)old andSet:(DDConcurrentQueueNode *)new;
- (BOOL)compareTail:(DDConcurrentQueueNode *)old andSet:(DDConcurrentQueueNode *)new;

@end

@implementation DDConcurrentQueue

- (id)init
{
	if ((self = [super init]))
	{
		DDConcurrentQueueNode *node = [[DDConcurrentQueueNode alloc] init];
		self.head = node;
		self.tail = node;
	}
	return self;
}

- (void)addObject:(id)object
{
	DDConcurrentQueueNode *node = [[DDConcurrentQueueNode alloc] initWithObject:object];
	while (YES)
	{
		DDConcurrentQueueNode *tail = self.tail;
		DDConcurrentQueueNode *next = tail.next;
		if (tail == self.tail)
		{
			if (next == nil)
			{
				if ([tail compareNext:next andSet:node])
				{
					[self compareTail:tail andSet:node];
					break;
				}
			}
			else
			{
				[self compareTail:tail andSet:node];
			}
		}
	}
	if (self.delegate)
		[self.delegate queueDidAddObject:self];
}

- (id)removeObject
{
	while (YES)
	{
		DDConcurrentQueueNode *head = self.head;
		DDConcurrentQueueNode *tail = self.tail;
		DDConcurrentQueueNode *first = head.next;
		if (head == self.head)
		{
			if (head == tail)
			{
				if (first == nil)
					return nil;
				else
					[self compareTail:tail andSet:first];
			}
			else if ([self compareHead:head andSet:first])
			{
				id object = first.object;
				if (object != nil)
				{
					first.object = nil;
					return object;
				}
				// else skip over deleted item, continue loop
			}
		}
	}
}

- (BOOL)compareHead:(DDConcurrentQueueNode *)old andSet:(DDConcurrentQueueNode *)new
{
	@synchronized(self) {
		if (old == self.head) {
			self.head = new;
			return YES;
		}
		return NO;
	}
}

- (BOOL)compareTail:(DDConcurrentQueueNode *)old andSet:(DDConcurrentQueueNode *)new
{
	@synchronized(self) {
		if (old == self.tail) {
			self.tail = new;
			return YES;
		}
		return NO;
	}
}

@end
