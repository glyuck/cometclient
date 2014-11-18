
#import "DDCometLongPollingTransport.h"
#import "DDCometClient.h"
#import "DDCometMessage.h"
#import "DDQueue.h"


@interface DDCometLongPollingTransport ()

@property (atomic, weak) DDCometClient *client;
@property (atomic, assign) BOOL shouldCancel;
@property (atomic, strong) NSMutableDictionary *responseDatas;

- (NSURLConnection *)sendMessages:(NSArray *)messages;
- (NSArray *)outgoingMessages;
- (NSURLRequest *)requestWithMessages:(NSArray *)messages;
- (id)keyWithConnection:(NSURLConnection *)connection;

@end

@implementation DDCometLongPollingTransport

- (id)initWithClient:(DDCometClient *)client
{
	if ((self = [super init]))
	{
		self.client = client;
		self.responseDatas = [[NSMutableDictionary alloc] initWithCapacity:2];
	}
	return self;
}


- (void)start
{
	[self performSelectorInBackground:@selector(main) withObject:nil];
}

- (void)cancel
{
	self.shouldCancel = YES;
}

#pragma mark -

- (void)main
{
	do
	{
		@autoreleasepool {
			NSArray *messages = [self outgoingMessages];
			
			BOOL isPolling = NO;
			if ([messages count] == 0)
			{
				if (self.client.state == DDCometStateConnected)
				{
					isPolling = YES;
					DDCometMessage *message = [DDCometMessage messageWithChannel:@"/meta/connect"];
					message.clientID = self.client.clientID;
					message.connectionType = @"long-polling";
					DDCometClientLog(@"Sending long-poll message: %@", message);
					messages = [NSArray arrayWithObject:message];
				}
				else
				{
					[NSThread sleepForTimeInterval:0.01];
				}
			}
			
			NSURLConnection *connection = [self sendMessages:messages];
			if (connection)
			{
				NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
				while ([runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]])
				{
					if (isPolling)
					{
						if (self.shouldCancel)
						{
							self.shouldCancel = NO;
							[connection cancel];
						}
						else
						{
							messages = [self outgoingMessages];
							[self sendMessages:messages];
						}
					}
				}
			}
		}
	} while (self.client.state != DDCometStateDisconnected);
}

- (NSURLConnection *)sendMessages:(NSArray *)messages
{
	NSURLConnection *connection = nil;
	if ([messages count] != 0)
	{
		NSURLRequest *request = [self requestWithMessages:messages];
		connection = [NSURLConnection connectionWithRequest:request delegate:self];
		if (connection)
		{
			NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
			[connection scheduleInRunLoop:runLoop forMode:[runLoop currentMode]];
			[connection start];
		}
	}
	return connection;
}

- (NSArray *)outgoingMessages
{
	NSMutableArray *messages = [NSMutableArray array];
	DDCometMessage *message;
	id<DDQueue> outgoingQueue = [self.client outgoingQueue];
	while ((message = [outgoingQueue removeObject]))
		[messages addObject:message];
	return messages;
}

- (NSURLRequest *)requestWithMessages:(NSArray *)messages
{
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.client.endpointURL];
  
  NSMutableArray *messagesData = [[NSMutableArray alloc] initWithCapacity:[messages count]];
  for (DDCometMessage *message in messages) {
    [messagesData addObject:[message proxyForJson]];
  }
  
	NSData *body = [NSJSONSerialization dataWithJSONObject:messagesData options:0 error:nil];
	
	[request setHTTPMethod:@"POST"];
	[request setValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
	for (NSString *header in self.client.headers) {
		NSString *value = [self.client.headers objectForKey:header];
		[request setValue:value forHTTPHeaderField:header];
	}
	[request setHTTPBody:body];
	
	NSNumber *timeout = [self.client.advice objectForKey:@"timeout"];
	if (timeout)
		[request setTimeoutInterval:([timeout floatValue] / 1000)];
	
	return request;
}

- (id)keyWithConnection:(NSURLConnection *)connection
{
	return [NSNumber numberWithUnsignedInteger:[connection hash]];
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[self.responseDatas setObject:[NSMutableData data] forKey:[self keyWithConnection:connection]];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	NSMutableData *responseData = [self.responseDatas objectForKey:[self keyWithConnection:connection]];
	[responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSData *responseData = [self.responseDatas objectForKey:[self keyWithConnection:connection]];
	[self.responseDatas removeObjectForKey:[self keyWithConnection:connection]];
	
  NSArray *responses = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
	responseData = nil;
	
	id<DDQueue> incomingQueue = [self.client incomingQueue];
	
	for (NSDictionary *messageData in responses)
	{
		DDCometMessage *message = [DDCometMessage messageWithJson:messageData];
		[incomingQueue addObject:message];
	}
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (error.domain == NSURLErrorDomain && error.code == NSURLErrorTimedOut) {
        [self.responseDatas removeObjectForKey:[self keyWithConnection:connection]];
    } else {
        [self.client URLConnectionDidFailWithError:error];
    }
}

@end
