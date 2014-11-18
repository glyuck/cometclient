
#import <Foundation/Foundation.h>
#import "DDQueue.h"


@interface DDQueueProcessor : NSObject <DDQueueDelegate>

+ (DDQueueProcessor *)queueProcessorWithQueue:(id<DDQueue>)queue
									   target:(id)target
									 selector:(SEL)selector;
- (id)initWithTarget:(id)target selector:(SEL)selector;
- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

@end
