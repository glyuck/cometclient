
#import <Foundation/Foundation.h>

#ifdef DEBUG
  #define DDCometClientLog(format, ...) NSLog(format, ##__VA_ARGS__)
#else
  #define DDCometClientLog(format, ...)
#endif

@class DDCometLongPollingTransport;
@class DDCometMessage;
@class DDCometSubscription;
@class DDQueueProcessor;
@protocol DDCometClientDelegate;
@protocol DDQueue;

typedef enum
{
	DDCometStateDisconnected,
	DDCometStateConnecting,
	DDCometStateConnected,
	DDCometStateDisconnecting
} DDCometState;

@interface DDCometClient : NSObject

@property (nonatomic, copy, readonly) NSString *clientID;
@property (nonatomic, strong, readonly) NSURL *endpointURL;
@property (nonatomic, assign, readonly) DDCometState state;
@property (nonatomic, copy) NSDictionary *headers;
@property (atomic, copy, readonly) NSDictionary *advice;
@property (nonatomic, weak) id<DDCometClientDelegate> delegate;

- (id)initWithURL:(NSURL *)endpointURL;
- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;
- (DDCometMessage *)handshake;
- (DDCometMessage *)disconnect;
- (DDCometMessage *)subscribeToChannel:(NSString *)channel target:(id)target selector:(SEL)selector;
- (DDCometMessage *)subscribeToChannel:(NSString *)channel extensions:(id)extensions target:(id)target selector:(SEL)selector;
- (DDCometMessage *)unsubsubscribeFromChannel:(NSString *)channel target:(id)target selector:(SEL)selector;
- (DDCometMessage *)publishData:(id)data toChannel:(NSString *)channel;

@end

@interface DDCometClient (Internal)

- (id<DDQueue>)outgoingQueue;
- (id<DDQueue>)incomingQueue;
- (void)URLConnectionDidFailWithError:(NSError *)error;

@end

@protocol DDCometClientDelegate <NSObject>
@optional
- (void)cometClient:(DDCometClient *)client URLConnectionDidFailWithError:(NSError *)error;
- (void)cometClientHandshakeDidSucceed:(DDCometClient *)client;
- (void)cometClient:(DDCometClient *)client handshakeDidFailWithError:(NSError *)error;
- (void)cometClientConnectDidSucceed:(DDCometClient *)client;
- (void)cometClient:(DDCometClient *)client connectDidFailWithError:(NSError *)error;
- (void)cometClient:(DDCometClient *)client subscriptionDidSucceed:(DDCometSubscription *)subscription;
- (void)cometClient:(DDCometClient *)client subscription:(DDCometSubscription *)subscription didFailWithError:(NSError *)error;
@end
