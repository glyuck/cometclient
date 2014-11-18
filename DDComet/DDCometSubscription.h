
#import <Foundation/Foundation.h>


@interface DDCometSubscription : NSObject

@property (nonatomic, copy, readonly) NSString *channel;
@property (nonatomic, weak, readonly) id target;
@property (nonatomic, assign, readonly) SEL selector;

- (id)initWithChannel:(NSString *)channel target:(id)target selector:(SEL)selector;
- (BOOL)matchesChannel:(NSString *)channel;

@end
