//
//  CDAEntry.m
//  ContentfulSDK
//
//  Created by Boris Bügling on 04/03/14.
//
//

#import <ContentfulDeliveryAPI/CDAAsset.h>
#import <ContentfulDeliveryAPI/CDAContentType.h>

#import "CDAClient+Private.h"
#import "CDAContentTypeRegistry.h"
#import "CDAEntry+Private.h"
#import "CDAField+Private.h"
#import "CDAResource+Private.h"
#import "CDAUtilities.h"

@interface CDAEntry ()

@property (nonatomic) NSDictionary* localizedFields;

@end

#pragma mark -

@implementation CDAEntry

@synthesize locale = _locale;

#pragma mark -

+(NSString *)CDAType {
    return @"Entry";
}

+(NSArray*)subclasses {
    static dispatch_once_t once;
    static NSArray* subclasses;
    dispatch_once(&once, ^ { subclasses = CDAClassGetSubclasses([self class]); });
    return subclasses;
}

#pragma mark -

-(CLLocationCoordinate2D)CLLocationCoordinate2DFromFieldWithIdentifier:(NSString*)identifier {
    CLLocationCoordinate2D coordinate;
    coordinate.latitude = 0.0;
    coordinate.longitude = 0.0;
    
    if ([self.contentType fieldForIdentifier:identifier].type != CDAFieldTypeLocation) {
        [NSException raise:NSInvalidArgumentException format:@"Field %@ isn't a location.", identifier];
    }
    
    [self.fields[identifier] getBytes:&coordinate length:sizeof(coordinate)];
    return coordinate;
}

-(CDAContentType *)contentType {
    return self.sys[@"contentType"];
}

-(NSString *)description {
    NSMutableDictionary* filteredFields = [self.fields mutableCopy];
    for (CDAField* field in self.contentType.fields) {
        if (field.type == CDAFieldTypeLink) {
            [filteredFields removeObjectForKey:field.identifier];
        }
    }

    /* Better than nothing, but has some \n and \t embedded because of 
     http://www.cocoabuilder.com/archive/cocoa/197297-who-broke-nslog-on-leopard.html#197302 */
    return [NSString stringWithFormat:@"CDAEntry %@ with fields:%@", self.identifier, filteredFields];
}

-(NSDictionary *)fields {
    NSDictionary* localizedFields = self.localizedFields[self.locale];
    return localizedFields ?: @{};
}

-(NSArray*)findUnresolvedResourceOfClass:(Class)class {
    __block NSMutableArray* unresolvedResources = [@[] mutableCopy];
    
    [self resolveLinksWithIncludedAssets:nil entries:nil usingBlock:^CDAResource *(CDAResource *resource, NSDictionary *assets, NSDictionary *entries) {
        if (CDAClassIsOfType([resource class], class) && !resource.fetched) {
            [unresolvedResources addObject:resource];
        }
        
        return nil;
    }];
    
    return [unresolvedResources copy];
}

-(NSArray *)findUnresolvedAssets {
    return [self findUnresolvedResourceOfClass:[CDAAsset class]];
}

-(NSArray *)findUnresolvedEntries {
    return [self findUnresolvedResourceOfClass:[CDAEntry class]];
}

-(id)initWithDictionary:(NSDictionary *)dictionary
                 client:(CDAClient*)client
  localizationAvailable:(BOOL)localizationAvailable {
    self = [super initWithDictionary:dictionary client:client localizationAvailable:localizationAvailable];
    if (self && self.fetched) {
        NSAssert(self.contentType, @"Content-Type needs to be available.");
        
        Class customClass = [self.client.contentTypeRegistry customClassForContentType:self.contentType];
        if (customClass && customClass != [self class]) {
            return [[customClass alloc] initWithDictionary:dictionary
                                                    client:client
                                     localizationAvailable:localizationAvailable];
        }
        
        NSDictionary* fields = dictionary[@"fields"];
        
        if (!fields) {
            return self;
        }
        
        self.localizedFields = [self localizeFieldsFromDictionary:fields];
    }
    return self;
}

-(NSString *)locale {
    return _locale ?: self.defaultLocaleOfSpace;
}

-(NSDictionary *)localizedDictionaryFromDictionary:(NSDictionary *)dictionary
                                         forLocale:(NSString *)locale
                                           default:(BOOL)isDefault {
    NSDictionary* localizedDictionary = [super localizedDictionaryFromDictionary:dictionary
                                                                       forLocale:locale
                                                                         default:isDefault];
    return [self parseDictionary:localizedDictionary];
}

-(id)mapFieldsToObject:(NSObject*)object usingMapping:(NSDictionary*)dictionary {
    [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString* selfKeyPath,
                                                    NSString* objectKeyPath, BOOL *stop) {
        id value = [self valueForKeyPath:selfKeyPath];
        if (CDAClassIsOfType([value class], CDAResource.class) || !value) {
            return;
        }
        
        [object setValue:value forKeyPath:objectKeyPath];
    }];
    
    return object;
}

-(NSDictionary*)parseDictionary:(NSDictionary*)dictionary {
    NSMutableDictionary* fields = [@{} mutableCopy];
    
    NSAssert([dictionary isKindOfClass:[NSDictionary class]],
             @"Entry Fields are expected to be a dictionary.");
    [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString* key, id value, BOOL *stop) {
        CDAField* field = [self.contentType fieldForIdentifier:key];
        NSAssert(field, @"Entry contains unknown field '%@'.", key);
        
        id parsedValue = [field parseValue:value];
        if (parsedValue) {
            fields[key] = parsedValue;
        }
    }];
    
    return [fields copy];
}

-(NSDictionary*)resolveLinksInDictionary:(NSDictionary*)dictionary
                      withIncludedAssets:(NSDictionary*)assets
                                 entries:(NSDictionary*)entries
                              usingBlock:(CDAResource* (^)(CDAResource* resource, NSDictionary* assets,
                                                           NSDictionary* entries))resolver {
    NSMutableDictionary* fields = [dictionary mutableCopy];
    
    [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString* key, id value, BOOL *stop) {
        CDAField* field = [self.contentType fieldForIdentifier:key];
        
        if (field.type == CDAFieldTypeArray && [value isKindOfClass:[NSArray class]]) {
            NSArray* array = value;
            
            if (array.count > 0 && CDAClassIsOfType([[array firstObject] class], CDAResource.class)) {
                NSMutableArray* newArray = [@[] mutableCopy];
                
                for (CDAResource* resource in array) {
                    CDAResource* possibleResource = resolver(resource, assets, entries);
                    [newArray addObject:possibleResource ?: resource];
                }
                
                fields[key] = [newArray copy];
            }
        }
        
        if (field.type == CDAFieldTypeLink && CDAClassIsOfType([value class], CDAResource.class)) {
            CDAResource* possibleResource = resolver(value, assets, entries);
            
            fields[key] = possibleResource ?: value;
        }
    }];
    
    return [fields copy];
}

-(void)resolveLinksWithIncludedAssets:(NSDictionary*)assets entries:(NSDictionary*)entries {
    [self resolveLinksWithIncludedAssets:assets
                                 entries:entries
                              usingBlock:^CDAResource *(CDAResource *resource, NSDictionary *assets,
                                                        NSDictionary *entries) {
                                  return [self resolveSingleResource:resource
                                                  withIncludedAssets:assets
                                                             entries:entries];
                              }];
}

-(void)resolveLinksWithIncludedAssets:(NSDictionary*)assets
                              entries:(NSDictionary*)entries
                           usingBlock:(CDAResource* (^)(CDAResource* resource, NSDictionary* assets,
                                                        NSDictionary* entries))resolver {
    NSMutableDictionary* localizedFields = [@{} mutableCopy];
    
    [self.localizedFields enumerateKeysAndObjectsUsingBlock:^(NSString* key,
                                                              NSDictionary* fields,
                                                              BOOL *stop) {
        localizedFields[key] = [self resolveLinksInDictionary:fields
                                           withIncludedAssets:assets
                                                      entries:entries
                                                   usingBlock:resolver];
    }];
    
    self.localizedFields = [localizedFields copy];
}

-(CDAResource*)resolveSingleResource:(CDAResource*)resource
               withIncludedAssets:(NSDictionary*)assets
                          entries:(NSDictionary*)entries {
    if (!resource.fetched) {
        NSString* linkType = resource.sys[@"linkType"];
        
        if ([linkType isEqualToString:@"Asset"]) {
            return assets[resource.identifier];
        }
        
        if ([linkType isEqualToString:@"Entry"]) {
            return entries[resource.identifier];
        }
    }
    
    if ([resource isKindOfClass:[CDAEntry class]]) {
        CDAEntry* entry = entries[resource.identifier];
        NSDate *resourceDate = resource.sys[@"updatedAt"];
        NSDate *entryDate = entry.sys[@"updatedAt"];
        if ([resourceDate compare:entryDate] == NSOrderedAscending) {
            return entry;
        }
    }
    
    if ([resource isKindOfClass:[CDAAsset class]]) {
        CDAAsset* asset = assets[resource.identifier];
        NSDate *resourceDate = resource.sys[@"updatedAt"];
        NSDate *assetDate = asset.sys[@"updatedAt"];
        if ([resourceDate compare:assetDate] == NSOrderedAscending) {
            return asset;
        }
    }
    
    return nil;
}

-(void)resolveWithSuccess:(void (^)(CDAResponse *, CDAResource *))success
                  failure:(void (^)(CDAResponse *, NSError *))failure {
    if (self.fetched) {
        [super resolveWithSuccess:success failure:failure];
        return;
    }
    
    [self.client fetchEntryWithIdentifier:self.identifier
                                  success:^(CDAResponse *response, CDAEntry *entry) {
                                      if (success) {
                                          success(response, entry);
                                      }
                                  } failure:failure];
}

-(void)setClient:(CDAClient *)client {
    [super setClient:client];

    for (NSDictionary* fields in self.localizedFields.allValues) {
        for (id field in fields.allValues) {
            if ([field isKindOfClass:NSArray.class]) {
                for (id subField in field) {
                    [self setClient:client forField:subField];
                }
            }

            [self setClient:client forField:field];
        }
    }
}

-(void)setClient:(CDAClient*)client forField:(id)field {
    if ([field respondsToSelector:@selector(setClient:)]) {
        CDAResource* resource = (CDAResource*)field;
        if (!resource.client) {
            resource.client = self.client;
        }
    }
}

-(void)setLocale:(NSString *)locale {
    if (_locale == locale) {
        return;
    }
    
    if ([self.localizedFields.allKeys containsObject:locale]) {
        _locale = locale;
    } else {
        _locale = self.defaultLocaleOfSpace;
    }
}

-(void)setValue:(id)value forFieldWithName:(NSString *)key {
    NSMutableDictionary* allFields = [self.localizedFields mutableCopy];
    NSMutableDictionary* currentFields = [self.localizedFields[self.locale] mutableCopy];

    currentFields[key] = value;
    allFields[self.locale] = currentFields;
    
    self.localizedFields = allFields;
}

@end
