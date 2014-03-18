//
//  CCCSyncEngineFileManager.h
//  CCCKerbside
//
//  Created by Anna Walser on 1/21/14.
//  Copyright (c) 2014 Anna Walser. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AWSyncEngineFileManager : NSObject

- (void)writeJSONResponse:(id)response toDiskForClassWithName:(NSString *)className atKey:(NSString*)jsonKey;
- (NSDictionary *)JSONDictionaryForClassWithName:(NSString *)className;
- (void)deleteJSONDataRecordsForClassWithName:(NSString *)className;
@end
