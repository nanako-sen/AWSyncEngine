//
//  RDUAFParseAPIClient.h
//  RDULoyalty
//
//  Created by Anna Walser on 10/2/13.
//  Copyright (c) 2013 Anna Walser. All rights reserved.
//
#import <AFNetworking/AFHTTPRequestOperationManager.h>

@interface AWAFParseAPIClient : AFHTTPRequestOperationManager

@property (nonatomic,assign) BOOL networkIsReachable;

//+(AWAFParseAPIClient*)sharedClient;

- (NSMutableURLRequest *)GETRequest:(NSString*)requestStr parameters:(NSDictionary *)parameters ;
- (NSMutableURLRequest *)POSTRequestToUrl:(NSString *)resource parameters:(NSDictionary *)parameters;
- (void)simplePostToAPI:(NSString*)resource parameters:(NSDictionary*)parameters;
@end
