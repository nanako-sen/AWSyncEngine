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


@end
