//
//  RDUMapping.h
//  RDULoyalty
//
//  Created by Anna Walser on 10/8/13.
//  Copyright (c) 2013 Anna Walser. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface AWSyncMappingObject : NSObject

@property (nonatomic, assign) Class moClass;
@property (nonatomic, strong) NSString *requestAPIResource;
@property (nonatomic, strong) NSString *jsonRootAttribute;
@property (nonatomic, strong) NSDictionary *attributesMappingDictionary;
/*  NSSet of RRDUMapping ojbects*/
// relation
@property (nonatomic, strong) NSString *relationshipNameOnParent;
@property (nonatomic, strong) NSSet *relatedMappingObjects;

//post
@property (nonatomic, strong) NSDictionary *postDataDictionary;

//update
@property (nonatomic, assign) BOOL doUpdateObject;
@property (nonatomic, strong) NSString *uniquePropertyName;
@property (nonatomic, strong) NSString *uniqueJsonAttributeName;
@property (nonatomic, strong) NSDictionary *setKeysToValuesOnUpdate;

//relation
@property (nonatomic, strong) NSString *relatedJsonRootAttributeName;

/**
 * GET REQUEST
 * uniqueIdName only needed if needs deletion NO (-> only records which are not in the store are getting inserted - no update fo existing records)
 */



/**
 *  POST
 */

+ (AWSyncMappingObject*)mappingForPost:(NSDictionary*)params fromURL:(NSString*)urlString;
//+ (RDUSyncMappingObject*)mappingForPostForClass:(Class)mClassName fromResource:(NSString*)mResource atKey:(NSString*)key attributeMapping:(NSDictionary*)mMapping relatedObjects:(NSSet*)mRelatedObjects forProperty:(NSString *)prop uniqueIdName:(NSString*)uid needsDeletion:(BOOL)del postParams:(NSDictionary*)params;



- (NSString*)className;
@end

@interface NSMutableArray (findObjects)
- (BOOL)containsObjectWithClass:(Class)c;

@end
