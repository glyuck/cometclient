
#import <Foundation/Foundation.h>


@interface DDCometMessage : NSObject

@property (nonatomic, strong) NSString *channel;
@property (nonatomic, strong) NSString *version;
@property (nonatomic, strong) NSString *minimumVersion;
@property (nonatomic, strong) NSArray *supportedConnectionTypes;
@property (nonatomic, strong) NSString *clientID;
@property (nonatomic, strong) NSDictionary *advice;
@property (nonatomic, strong) NSString *connectionType;
@property (nonatomic, strong) NSString *ID;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, strong) id data;
@property (nonatomic, strong) NSNumber *successful;
@property (nonatomic, strong) NSString *subscription;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) id ext;

+ (DDCometMessage *)messageWithChannel:(NSString *)channel;

@end

@interface DDCometMessage (JSON)

+ (DDCometMessage *)messageWithJson:(NSDictionary *)jsonData;
- (NSDictionary *)proxyForJson;

@end
