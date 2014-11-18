
#import "DDCometMessage.h"

@interface NSDate (ISO8601)

+ (NSDate *)dateWithISO8601String:(NSString *)string;
- (NSString *)ISO8601Representation;

@end

@implementation NSDate (ISO8601)

+ (NSDate *)dateWithISO8601String:(NSString *)string
{
	NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
	[fmt setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
	return [fmt dateFromString:string];
}

- (NSString *)ISO8601Representation
{
	NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
	[fmt setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
	return [fmt stringFromDate:self];
}

@end

@interface NSError (Bayeux)

+ (NSError *)errorWithBayeuxFormat:(NSString *)string;
- (NSString *)bayeuxFormat;

@end

@implementation NSError (Bayeux)

+ (NSError *)errorWithBayeuxFormat:(NSString *)string
{
  NSInteger code = 0;
  NSString *description = nil;
 
  NSArray *components = [string componentsSeparatedByString:@":"];
  if ([components count] == 3) {
    code = [[components objectAtIndex:0] integerValue];
    description = [components objectAtIndex:2];
  } else {
    description = @"An unknown error occurred.";
  }
  
  NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, nil];
	return [[NSError alloc] initWithDomain:@"" code:code userInfo:userInfo];
}

- (NSString *)bayeuxFormat
{
	NSString *args = @"";
	NSArray *components = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%ld", (long)[self code]], args, [self localizedDescription], nil];
	return [components componentsJoinedByString:@":"];
}

@end

@implementation DDCometMessage

+ (DDCometMessage *)messageWithChannel:(NSString *)channel
{
	DDCometMessage *message = [[DDCometMessage alloc] init];
	message.channel = channel;
	return message;
}

@end

@implementation DDCometMessage (JSON)

+ (DDCometMessage *)messageWithJson:(NSDictionary *)jsonData
{
	DDCometMessage *message = [[DDCometMessage alloc] init];
	for (NSString *key in [jsonData keyEnumerator])
	{
		id object = [jsonData objectForKey:key];
		
		if ([key isEqualToString:@"channel"])
			message.channel = object;
		else if ([key isEqualToString:@"version"])
			message.version = object;
		else if ([key isEqualToString:@"minimumVersion"])
			message.minimumVersion = object;
		else if ([key isEqualToString:@"supportedConnectionTypes"])
			message.supportedConnectionTypes = object;
		else if ([key isEqualToString:@"clientId"])
			message.clientID = object;
		else if ([key isEqualToString:@"advice"])
			message.advice = object;
		else if ([key isEqualToString:@"connectionType"])
			message.connectionType = object;
		else if ([key isEqualToString:@"id"])
			message.ID = object;
		else if ([key isEqualToString:@"timestamp"])
			message.timestamp = [NSDate dateWithISO8601String:object];
		else if ([key isEqualToString:@"data"])
			message.data = object;
		else if ([key isEqualToString:@"successful"])
			message.successful = object;
		else if ([key isEqualToString:@"subscription"])
			message.subscription = object;
		else if ([key isEqualToString:@"error"])
			message.error = [NSError errorWithBayeuxFormat:object];
		else if ([key isEqualToString:@"ext"])
			message.ext = object;
	}
	return message;
}

- (NSDictionary *)proxyForJson
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	if (self.channel)
		[dict setObject:self.channel forKey:@"channel"];
	if (self.version)
		[dict setObject:self.version forKey:@"version"];
	if (self.minimumVersion)
		[dict setObject:self.minimumVersion forKey:@"minimumVersion"];
	if (self.supportedConnectionTypes)
		[dict setObject:self.supportedConnectionTypes forKey:@"supportedConnectionTypes"];
	if (self.clientID)
		[dict setObject:self.clientID forKey:@"clientId"];
	if (self.advice)
		[dict setObject:self.advice forKey:@"advice"];
	if (self.connectionType)
		[dict setObject:self.connectionType forKey:@"connectionType"];
	if (self.ID)
		[dict setObject:self.ID forKey:@"id"];
	if (self.timestamp)
		[dict setObject:[self.timestamp ISO8601Representation] forKey:@"timestamp"];
	if (self.data)
		[dict setObject:self.data forKey:@"data"];
	if (self.successful)
		[dict setObject:self.successful forKey:@"successful"];
	if (self.subscription)
		[dict setObject:self.subscription forKey:@"subscription"];
	if (self.error)
		[dict setObject:[self.error bayeuxFormat] forKey:@"error"];
	if (self.ext)
		[dict setObject:self.ext forKey:@"ext"];
	return dict;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ %@", [super description], [self proxyForJson]];
}

@end
