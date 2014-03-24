//
//  RDUMapping.h
//  RDULoyalty
//
//  Created by Anna Walser on 10/8/13.
//  Copyright (c) 2013 Anna Walser. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface AWSyncMappingObject : NSObject

@property (nonatomic, assign) Class objectClass;
@property (nonatomic, strong) NSString *requestAPIResource;
@property (nonatomic, strong) NSString *jsonRootAttribute;
@property (nonatomic, strong) NSDictionary *attributeMapping;
/*  NSSet of RRDUMapping ojbects*/
// relation
@property (nonatomic, strong) NSString *relationshipNameOnParent;
@property (nonatomic, strong) NSSet *relatedMappingObjects;

//post
@property (nonatomic, strong) NSDictionary *postDataDictionary;

//update
@property (nonatomic, assign) BOOL doUpdate;
@property (nonatomic, strong) NSString *uniquePropertyName;
@property (nonatomic, strong) NSString *uniqueJsonAttributeName;
//@property (nonatomic, strong) NSDictionary *setKeysToValuesOnUpdate;
@property (nonatomic, readonly) NSString *resetProperty;
@property (nonatomic, readonly) id resetToValue;
@property (nonatomic, readonly) NSString *updateRuleProperty;
@property (nonatomic, readonly) NSString *updateRuleAttribute;
@property (nonatomic, readonly) NSComparisonResult updateComparisonResult;


//relation
@property (nonatomic, strong) NSString *relatedJsonRootAttributeName;

/**
 * GET REQUEST
 * uniqueIdName only needed if needs deletion NO (-> only records which are not in the store are getting inserted - no update fo existing records)
 */
+ (AWSyncMappingObject*)baseMappingForClass:(Class)class fromApiResource:(NSString*)apiResource attributeMapping:(NSDictionary*)mappingDict atKey:(NSString*)key;

- (void)setRelationshipName:(NSString *)relationshipName atJsonAttributeKey:(NSString*)jsonAttribute;

- (void)setUpdateObjectAtUniqueProperty:(NSString*)uniquePropertyName mappedToJsonAttribute:(NSString*)jsonAttribute;
- (void)resetProperty:(NSString*)property toValue:(id)value;
- (void)defineUniqueProperty:(NSString*)uniquePropertyName mappedToJsonAttribute:(NSString*)jsonAttribute;
/* update rules only with nsdate property types */
- (void)defineUpdateRuleForProperty:(NSString*)updateRuleProperty andJsonAttribute:(NSString*)updateRuleAttribute comparisonResult:(NSComparisonResult)comparisonResult;

/**
 *  POST
 */

+ (AWSyncMappingObject*)baseMappingPOSTForClass:(Class)class fromApiResource:(NSString*)apiResource postParams:(NSDictionary*)params atKey:(NSString*)key;




- (NSString*)className;
@end

@interface NSMutableArray (findObjects)
- (BOOL)containsObjectWithClass:(Class)c;

@end
