//
//  CCCSyncEngineFileManager.m
//  CCCKerbside
//
//  Created by Anna Walser on 1/21/14.
//  Copyright (c) 2014 Anna Walser. All rights reserved.
//

#import "AWSyncEngineFileManager.h"

@implementation AWSyncEngineFileManager

#pragma mark - File Processing

- (void)deleteAllJSONDataRecords
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *directory = [[self JSONDataRecordsDirectory] absoluteString];
    NSError *error = nil;
    for (NSString *file in [fm contentsOfDirectoryAtPath:directory error:&error]) {
        if (![fm removeItemAtPath:[NSString stringWithFormat:@"%@%@", directory, file] error:&error]) {
            NSLog(@"Error deleting files :%@",error);
        }
    }
    
}

- (void)deleteJSONDataRecordsForClassWithName:(NSString *)className
{
    NSURL *url = [NSURL URLWithString:className relativeToURL:[self JSONDataRecordsDirectory]];
    NSError *error = nil;
    BOOL deleted = [[NSFileManager defaultManager] removeItemAtURL:url error:&error];
    if (!deleted) {
        NSLog(@"Unable to delete JSON Records at %@, reason: %@", url, error);
    }
}

- (NSDictionary *)JSONDictionaryForClassWithName:(NSString *)className
{
    NSURL *fileURL = [NSURL URLWithString:className relativeToURL:[self JSONDataRecordsDirectory]];
    return [NSDictionary dictionaryWithContentsOfURL:fileURL];
}

- (NSArray *)JSONDataRecordsForClass:(NSString *)className atKey:(NSString*)jsonKey sortedByKey:(NSString *)key {
    NSDictionary *JSONDictionary = [self JSONDictionaryForClassWithName:className];
    NSArray *records = [JSONDictionary objectForKey:jsonKey];
    return [records sortedArrayUsingDescriptors:[NSArray arrayWithObject:
                                                 [NSSortDescriptor sortDescriptorWithKey:key ascending:YES]]];
}

#pragma mark - File Management

- (NSURL *)applicationCacheDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSURL *)JSONDataRecordsDirectory{
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *url = [NSURL URLWithString:@"JSONRecords/" relativeToURL:[self applicationCacheDirectory]];
    NSError *error = nil;
    if (![fileManager fileExistsAtPath:[url path]]) {
        [fileManager createDirectoryAtPath:[url path] withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    return url;
}


- (void)writeJSONResponse:(id)response toDiskForClassWithName:(NSString *)className atKey:(NSString*)jsonKey
{
    NSURL *fileURL = [NSURL URLWithString:className relativeToURL:[self JSONDataRecordsDirectory]];
    if (![(NSDictionary *)response writeToFile:[fileURL path] atomically:YES]) {
        //NSLog(@"Error saving response to disk, will attempt to remove NSNull values and try again.");
        // remove NSNulls and try again - NSNull objects can get serilized to disc as you can't save nothing
        NSDictionary *records = [response objectForKey:jsonKey];
        NSArray *nullFreeRecords = [self removeNSNullFromJSONRecord:records];
        //        for (NSDictionary *record in records) {
        //            NSMutableDictionary *nullFreeRecord = [NSMutableDictionary dictionaryWithDictionary:record];
        //            for (NSString*key in record) {
        //                id obj = [nullFreeRecord objectForKey:key];
        //                if ([obj isKindOfClass:[NSNull class]]) {
        //                    [nullFreeRecord setValue:nil forKey:key];
        //                }
        //                //if obj is nsarray
        //
        //
        //            }
        //            [nullFreeRecords addObject:nullFreeRecord];
        //
        //
        ////            [record enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        ////                if ([obj isKindOfClass:[NSArray class]]) {
        ////
        ////                    NSMutableArray *nullFreeSubRecords = [NSMutableArray array];
        ////                    for (NSDictionary *subRecord in obj) {
        ////                        //NSLog(@"nested dict for key: %@",key);
        ////                        NSMutableDictionary *nullFreeSubRecord = [NSMutableDictionary dictionaryWithDictionary:subRecord];
        ////                        [subRecord enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        ////                            if ([obj isKindOfClass:[NSNull class]]) {
        ////                                [nullFreeSubRecord setValue:nil forKey:key];
        ////                            }
        ////                        }];
        ////                        [nullFreeSubRecords addObject:nullFreeSubRecord];
        ////                    }
        ////                    [nullFreeRecord setValue:nullFreeSubRecords forKey:key];
        ////                }
        ////                if ([obj isKindOfClass:[NSNull class]]) {
        ////                    [nullFreeRecord setValue:nil forKey:key];
        ////                }
        ////            }];
        ////            [nullFreeRecords addObject:nullFreeRecord];
        //        }
        
        NSDictionary *nullFreeDictionary = [NSDictionary dictionaryWithObject:nullFreeRecords forKey:jsonKey];
        
        if (![nullFreeDictionary writeToFile:[fileURL path] atomically:YES]) {
            NSLog(@"Failed all attempts to save response to disk: %@", response);
        }
    }
}

- (NSArray*)removeNSNullFromJSONRecord:(NSDictionary*)records
{
    NSMutableArray *nullFreeRecords = [NSMutableArray array];
    for (NSDictionary *record in records) {
        NSMutableDictionary *nullFreeRecord = [NSMutableDictionary dictionaryWithDictionary:record];
        for (NSString*key in record) {
            id obj = [nullFreeRecord objectForKey:key];
            if ([obj isKindOfClass:[NSNull class]]) {
                [nullFreeRecord setValue:nil forKey:key];
            }
            if ([obj isKindOfClass:[NSArray class]]) {
                NSArray *nullFreeSubRecords = [self removeNSNullFromJSONRecord:obj];
                [nullFreeRecord setValue:nullFreeSubRecords forKey:key];
            }
        }
        [nullFreeRecords addObject:nullFreeRecord];
    }
    return [nullFreeRecords copy];
}


@end
