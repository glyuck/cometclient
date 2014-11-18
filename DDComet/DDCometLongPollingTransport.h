
#import <Foundation/Foundation.h>


@class DDCometClient;

@interface DDCometLongPollingTransport : NSObject

- (id)initWithClient:(DDCometClient *)client;
- (void)start;
- (void)cancel;

@end
