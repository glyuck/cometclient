
#import "DDCometClient.h"
#import <libkern/OSAtomic.h>
#import "DDCometLongPollingTransport.h"
#import "DDCometMessage.h"
#import "DDCometSubscription.h"
#import "DDConcurrentQueue.h"
#import "DDQueueProcessor.h"


@interface DDCometClient ()

@property (nonatomic, copy, readwrite) NSString *clientID;
@property (nonatomic, strong, readwrite) NSURL *endpointURL;
@property (nonatomic, assign, readwrite) DDCometState state;
@property (atomic, copy, readwrite) NSDictionary *advice;
@property (atomic, assign) int32_t messageCounter;
@property (nonatomic, strong) NSMutableDictionary *pendingSubscriptions;
@property (nonatomic, strong) NSMutableArray *subscriptions;
@property (nonatomic, strong) id<DDQueue> outgoingQueue;
@property (nonatomic, strong) id<DDQueue> incomingQueue;
@property (nonatomic, strong) DDCometLongPollingTransport *transport;
@property (nonatomic, strong) DDQueueProcessor *incomingProcessor;

- (NSString *)nextMessageID;
- (void)sendMessage:(DDCometMessage *)message;
- (void)handleMessage:(DDCometMessage *)message;

@end

@implementation DDCometClient

- (id)initWithURL:(NSURL *)endpointURL
{
	if ((self = [super init]))
	{
		self.endpointURL = endpointURL;
		self.pendingSubscriptions = [[NSMutableDictionary alloc] init];
		self.subscriptions = [[NSMutableArray alloc] init];
		self.outgoingQueue = [[DDConcurrentQueue alloc] init];
		self.incomingQueue = [[DDConcurrentQueue alloc] init];
	}
	return self;
}


- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode
{
	self.incomingProcessor = [[DDQueueProcessor alloc] initWithTarget:self selector:@selector(processIncomingMessages)];
	[self.incomingQueue setDelegate:self.incomingProcessor];
	[self.incomingProcessor scheduleInRunLoop:runLoop forMode:mode];
}

- (DDCometMessage *)handshake
{
	if (self.state == DDCometStateConnecting) {
		DDCometClientLog(@"Only one pending handshake allowed at one time.");
		return nil;
	}

	self.state = DDCometStateConnecting;

	DDCometMessage *message = [DDCometMessage messageWithChannel:@"/meta/handshake"];
	message.version = @"1.0";
	message.supportedConnectionTypes = [NSArray arrayWithObject:@"long-polling"];

	[self sendMessage:message];
	return message;
}

- (DDCometMessage *)disconnect
{
	self.state = DDCometStateDisconnecting;

	DDCometMessage *message = [DDCometMessage messageWithChannel:@"/meta/disconnect"];
	[self sendMessage:message];
	return message;
}

- (DDCometMessage *)subscribeToChannel:(NSString *)channel target:(id)target selector:(SEL)selector
{
	return [self subscribeToChannel:channel extensions:nil target:target selector:selector];
}

- (DDCometMessage *)subscribeToChannel:(NSString *)channel extensions:(id)extensions target:(id)target selector:(SEL)selector {
	DDCometMessage *message = [DDCometMessage messageWithChannel:@"/meta/subscribe"];
	message.ID = [self nextMessageID];
	message.subscription = channel;
	message.ext = extensions;
	DDCometSubscription *subscription = [[DDCometSubscription alloc] initWithChannel:channel target:target selector:selector];
	@synchronized(self.pendingSubscriptions)
	{
		[self.pendingSubscriptions setObject:subscription forKey:message.ID];
	}
	[self sendMessage:message];
	return message;
}

- (DDCometMessage *)unsubsubscribeFromChannel:(NSString *)channel target:(id)target selector:(SEL)selector
{
	DDCometMessage *message = [DDCometMessage messageWithChannel:@"/meta/unsubscribe"];
	message.ID = [self nextMessageID];
	message.subscription = channel;
	@synchronized(self.subscriptions)
	{
		NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
		NSUInteger count = [self.subscriptions count];
		for (NSUInteger i = 0; i < count; i++)
		{
			DDCometSubscription *subscription = [self.subscriptions objectAtIndex:i];
			if ([subscription.channel isEqualToString:channel] && subscription.target == target && subscription.selector == selector)
			{
				[indexes addIndex:i]; 
			}
		}
		[self.subscriptions removeObjectsAtIndexes:indexes];
	}
	return message;
}

- (DDCometMessage *)publishData:(id)data toChannel:(NSString *)channel
{
	DDCometMessage *message = [DDCometMessage messageWithChannel:channel];
	message.data = data;
	[self sendMessage:message];
	return message;
}

#pragma mark -

- (void)URLConnectionDidFailWithError:(NSError *)error {
	self.state = DDCometStateDisconnected;
	if (self.delegate && [self.delegate respondsToSelector:@selector(cometClient:URLConnectionDidFailWithError:)])
		[self.delegate cometClient:self URLConnectionDidFailWithError:error];
}

#pragma mark -

- (NSString *)nextMessageID
{
	@synchronized(self) {
		self.messageCounter += 1;
		return [NSString stringWithFormat:@"%d", self.messageCounter];
	}
}

- (void)sendMessage:(DDCometMessage *)message
{
	message.clientID = self.clientID;
	if (!message.ID)
		message.ID = [self nextMessageID];
	DDCometClientLog(@"Sending message: %@", message);
	[self.outgoingQueue addObject:message];
	
	if (self.transport == nil)
	{
		self.transport = [[DDCometLongPollingTransport alloc] initWithClient:self];
		[self.transport start];
	}
}

- (void)handleMessage:(DDCometMessage *)message
{
	DDCometClientLog(@"Message received: %@", message);
	NSString *channel = message.channel;
	if ([channel hasPrefix:@"/meta/"])
	{
		if ([channel isEqualToString:@"/meta/handshake"])
		{
			if ([message.successful boolValue])
			{
				self.clientID = message.clientID;
				
				DDCometMessage *connectMessage = [DDCometMessage messageWithChannel:@"/meta/connect"];
				connectMessage.connectionType = @"long-polling";
				connectMessage.advice = @{@"timeout": @0};
				[self sendMessage:connectMessage];
				
				if (self.delegate && [self.delegate respondsToSelector:@selector(cometClientHandshakeDidSucceed:)])
					[self.delegate cometClientHandshakeDidSucceed:self];
			}
			else
			{
				self.state = DDCometStateDisconnected;
				if (self.delegate && [self.delegate respondsToSelector:@selector(cometClient:handshakeDidFailWithError:)])
					[self.delegate cometClient:self handshakeDidFailWithError:message.error];
			}
		}
		else if ([channel isEqualToString:@"/meta/connect"])
		{
			if (message.advice)
			{
				self.advice = message.advice;
			}
			
			if (![message.successful boolValue])
			{
				self.state = DDCometStateDisconnected;
				if (self.delegate && [self.delegate respondsToSelector:@selector(cometClient:connectDidFailWithError:)])
				{
					[self.delegate cometClient:self connectDidFailWithError:message.error];
				}
		
				// Consider all channel subscriptions expired
				[self.pendingSubscriptions removeAllObjects];
				[self.subscriptions removeAllObjects];
		
				NSString *reconnectAdvice = [self.advice objectForKey:@"reconnect"];
				if ([reconnectAdvice isEqualToString:@"handshake"]) {
					DDCometClientLog(@"Connection failed, retrying handshake as adviced...");
					[self handshake];
				}
			}
			else if (self.state == DDCometStateConnecting)
			{
				self.state = DDCometStateConnected;
				if (self.delegate && [self.delegate respondsToSelector:@selector(cometClientConnectDidSucceed:)])
				{
					[self.delegate cometClientConnectDidSucceed:self];
			}
			}
		}
		else if ([channel isEqualToString:@"/meta/disconnect"])
		{
			self.state = DDCometStateDisconnected;
			[self.transport cancel];
			self.transport = nil;
		}
		else if ([channel isEqualToString:@"/meta/subscribe"])
		{
			DDCometSubscription *subscription = nil;
			@synchronized(self.pendingSubscriptions)
			{
				subscription = [self.pendingSubscriptions objectForKey:message.ID];
				if (subscription)
					[self.pendingSubscriptions removeObjectForKey:message.ID];
			}
			if ([message.successful boolValue])
			{
				if (subscription)
				{
					@synchronized(self.subscriptions)
					{
						[self.subscriptions addObject:subscription];
					}
					
					if (self.delegate && [self.delegate respondsToSelector:@selector(cometClient:subscriptionDidSucceed:)])
						[self.delegate cometClient:self subscriptionDidSucceed:subscription];
				}
			}
			else
			{
				if (self.delegate && [self.delegate respondsToSelector:@selector(cometClient:subscription:didFailWithError:)])
					[self.delegate cometClient:self subscription:subscription didFailWithError:message.error];
			}
		}
		else
		{
			NSLog(@"Unhandled meta message");
		}
	}
	else
	{
		NSMutableArray *subscriptions = [NSMutableArray array];
		@synchronized(self.subscriptions)
		{
			for (DDCometSubscription *subscription in self.subscriptions)
			{
				if ([subscription matchesChannel:message.channel])
					[subscriptions addObject:subscription];
			}
		}
        for (DDCometSubscription *subscription in subscriptions) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
			[subscription.target performSelector:subscription.selector withObject:message];
#pragma clang diagnostic pop
        }
    }
}

- (void)processIncomingMessages
{
	DDCometMessage *message;
	while ((message = [self.incomingQueue removeObject]))
		[self handleMessage:message];
}
@end
