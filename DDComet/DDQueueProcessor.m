
#import "DDQueueProcessor.h"


void DDQueueProcessorPerform(void *info);

@interface DDQueueProcessor ()

@property (atomic, weak) id target;
@property (atomic, assign) SEL selector;
@property (atomic, assign) CFRunLoopSourceRef source;
@property (atomic, strong) NSRunLoop *runLoop;
@property (atomic, copy) NSString *mode;

@end


@implementation DDQueueProcessor

+ (DDQueueProcessor *)queueProcessorWithQueue:(id<DDQueue>)queue
									   target:(id)target
									 selector:(SEL)selector
{
	DDQueueProcessor *processor = [[DDQueueProcessor alloc] initWithTarget:target selector:selector];
	[queue setDelegate:processor];
	[processor scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
	return processor;
}

- (id)initWithTarget:(id)target selector:(SEL)selector
{
	if ((self = [super init]))
	{
		self.target = target;
		self.selector = selector;
		
		CFRunLoopSourceContext context =
		{
			0, (__bridge void *)(self), NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			DDQueueProcessorPerform
		};
		
		self.source = CFRunLoopSourceCreate(NULL, 0, &context);
	}
	return self;
}

- (void)dealloc
{
	if (self.runLoop)
		CFRunLoopRemoveSource([self.runLoop getCFRunLoop], self.source, (__bridge CFStringRef)self.mode);

	CFRelease(self.source);
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode
{
	@synchronized(self)
	{
		CFRunLoopAddSource([runLoop getCFRunLoop], self.source, (__bridge CFStringRef)mode);
		self.runLoop = runLoop;
		self.mode = mode;
	}
}

- (void)queueDidAddObject:(id<DDQueue>)queue
{
	CFRunLoopSourceSignal(self.source);
	CFRunLoopWakeUp([self.runLoop getCFRunLoop]);
}

- (void)makeTargetPeformSelector
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	[self.target performSelector:self.selector];
#pragma clang diagnostic pop
}

@end

void DDQueueProcessorPerform(void *info)
{
	DDQueueProcessor *processor = (__bridge DDQueueProcessor *)(info);
	[processor makeTargetPeformSelector];
}
