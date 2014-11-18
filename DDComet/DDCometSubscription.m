
#import "DDCometSubscription.h"

@interface DDCometSubscription ()

@property (nonatomic, copy, readwrite) NSString *channel;
@property (nonatomic, weak, readwrite) id target;
@property (nonatomic, assign, readwrite) SEL selector;

@end


@implementation DDCometSubscription

- (id)initWithChannel:(NSString *)channel target:(id)target selector:(SEL)selector
{
	if ((self = [super init]))
	{
		self.channel = channel;
		self.target = target;
		self.selector = selector;
	}
	return self;
}


- (BOOL)matchesChannel:(NSString *)channel
{
	if ([self.channel isEqualToString:channel])
		return YES;
	if ([self.channel hasSuffix:@"/**"])
	{
		NSString *prefix = [self.channel substringToIndex:([self.channel length] - 2)];
		if ([channel hasPrefix:prefix])
			return YES;
	}
	else if ([self.channel hasSuffix:@"/*"])
	{
		NSString *prefix = [self.channel substringToIndex:([self.channel length] - 1)];
		if ([channel hasPrefix:prefix] && [[channel substringFromIndex:([self.channel length] - 1)] rangeOfString:@"*"].location == NSNotFound)
			return YES;
	}
	return NO;
}

@end
