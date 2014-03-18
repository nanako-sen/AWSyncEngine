//
//  RDUAFParseAPIClient.m
//  RDULoyalty
//
//  Created by Anna Walser on 10/2/13.
//  Copyright (c) 2013 Anna Walser. All rights reserved.
//

#import "AWAFParseAPIClient.h"


@implementation AWAFParseAPIClient

@synthesize networkIsReachable = _networkIsReachable;

//+ (AWAFParseAPIClient*)sharedClient
//{
//    static dispatch_once_t once;
//    static id sharedInstance;
//    dispatch_once(&once, ^{
////        sharedInstance =  [[AWAFParseAPIClient alloc] initWithBaseURL:[NSURL URLWithString:self.base]];
//    });
//    return sharedInstance;
//
////    SHARED_INSTANCE_USING_BLOCK(^{ return [[AWAFParseAPIClient alloc] initWithBaseURL:[NSURL URLWithString:kCCCBaseURLString]];})
//}

- (NSMutableURLRequest *)GETRequest:(NSString*)resource parameters:(NSDictionary *)parameters
{
    NSString *URL = [NSString stringWithFormat:@"%@%@",[self.baseURL absoluteString],resource];
    NSError *error;
    return [self.requestSerializer requestWithMethod:@"GET" URLString:URL parameters:parameters error:&error];
    
}

- (NSMutableURLRequest *)POSTRequestToUrl:(NSString *)resource parameters:(NSDictionary *)parameters
{
    NSString *URL = [NSString stringWithFormat:@"%@%@",[self.baseURL absoluteString],resource];
    NSError *error;
    return [[AFJSONRequestSerializer serializer] requestWithMethod:@"POST" URLString:URL parameters:parameters error:&error];
}


- (void)simplePostToAPI:(NSString*)resource parameters:(NSDictionary*)parameters
{
   
}

//- (NSMutableURLRequest *)GETRequestForAllRecordsOfClass:(NSString *)className updatedAfterDate:(NSDate *)updatedDate {
//    NSMutableURLRequest *request = nil;
//    NSDictionary *parameters = nil;
//    if (updatedDate) {
//        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
//        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.'999Z'"];
//        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
//        
//        NSString *jsonString = [NSString
//                                stringWithFormat:@"{\"updatedAt\":{\"$gte\":{\"__type\":\"Date\",\"iso\":\"%@\"}}}",
//                                [dateFormatter stringFromDate:updatedDate]];
//        
//        parameters = [NSDictionary dictionaryWithObject:jsonString forKey:@"where"];
//    }
//    
//    request = [self GETRequestForClass:className parameters:parameters];
//    return request;
//}
@end
