//
//  CoreDataIssues.m
//  ContentfulSDK
//
//  Created by Boris Bügling on 03/09/14.
//
//

#import "CDAClient+Private.h"
#import "CoreDataBaseTestCase.h"
#import "CoreDataManager.h"
#import "Group.h"
#import "LinkedEntry.h"
#import "Member.h"

@interface CoreDataIssues : CoreDataBaseTestCase

@end

#pragma mark -

@implementation CoreDataIssues

//-(void)buildPersistenceManagerWithDefaultClient:(BOOL)defaultClient {
//    self.client = [CDAClient new];
//    self.query = @{ @"order": @"sys.createdAt" };
//
//    [super buildPersistenceManagerWithDefaultClient:NO];
//}

-(CDAPersistenceManager*)createPersistenceManagerWithClient:(CDAClient*)client {
    if ([client.spaceKey isEqualToString:@"vfvjfjyjrbbp"]) {
        return [[CoreDataManager alloc] initWithClient:client dataModelName:@"LinkedData"];
    }

    return [super createPersistenceManagerWithClient:client];
}

#pragma mark -

// FIXME: This test is deprecated
//-(void)testMissingEntity {
//    StartBlock();
//
//    self.client = [[CDAClient alloc] initWithSpaceKey:@"vfvjfjyjrbbp"
//                                          accessToken:@"422588c021896d2ae01eaf2d68faa720aaf6da4b361e7c99e9afac6feacb498b"];
//    [super buildPersistenceManagerWithDefaultClient:NO];
//
//    [self.persistenceManager setClass:LinkedEntry.class forEntriesOfContentTypeWithIdentifier:@"3IeewiEyqc4sKeUWSoicuk"];
//    [self.persistenceManager setMapping:@{ @"fields.title": @"name", @"fields.link": @"link" }forEntriesOfContentTypeWithIdentifier:@"3IeewiEyqc4sKeUWSoicuk"];
//
//    [self.persistenceManager performSynchronizationWithSuccess:^{
//        NSArray* entries = [self.persistenceManager fetchEntriesFromDataStore];
//
//        XCTAssertEqual(entries.count, 1UL, @"");
//        XCTAssertEqualObjects([entries.firstObject name], @"B", @"");
//
//        EndBlock();
//    } failure:^(CDAResponse *response, NSError *error) {
//        XCTFail(@"Error: %@", error);
//
//        EndBlock();
//    }];
//
//    WaitUntilBlockCompletes();
//}

-(void)testToManyRelationship {
    StartBlock();

    self.client = [[CDAClient alloc] initWithSpaceKey:@"a3rsszoo7qqp" accessToken:@"57a1ef74e87e234bed4d3f932ec945a82dae641d6ea2b2435ea2837de94d6be5"];
    [super buildPersistenceManagerWithDefaultClient:NO];

    [self.persistenceManager setClass:Group.class forEntriesOfContentTypeWithIdentifier:@"20iFrEKPwgoq6KAyeSqww8"];
    [self.persistenceManager setMapping:@{ @"fields.title": @"title", @"fields.members": @"members" }forEntriesOfContentTypeWithIdentifier:@"20iFrEKPwgoq6KAyeSqww8"];

    [self.persistenceManager setClass:Member.class forEntriesOfContentTypeWithIdentifier:@"12pXFbTH9cWqWo06Oigeyu"];
    [self.persistenceManager setMapping:@{ @"fields.name": @"title", @"fields.group": @"group" } forEntriesOfContentTypeWithIdentifier:@"12pXFbTH9cWqWo06Oigeyu"];

    [self.persistenceManager performSynchronizationWithSuccess:^{
        for (Group* group in [(CoreDataManager*)self.persistenceManager fetchEntriesOfContentTypeWithIdentifier:@"20iFrEKPwgoq6KAyeSqww8" matchingPredicate:nil]) {
            XCTAssertNotNil(group, @"");

            if ([group.identifier isEqualToString:@"8UEOnseV2gQY8GUOG8csc"]) {
                XCTAssertEqual(group.members.count, 2UL, @"");

                for (Member* member in group.members) {
                    XCTAssertNotNil(member, @"");
                    XCTAssertTrue([member isKindOfClass:Member.class], @"");
                }
            } else {
                XCTAssertEqual(group.members.count, 0UL, @"");
            }
        }

        EndBlock();
    } failure:^(CDAResponse *response, NSError *error) {
        XCTFail(@"Error: %@", error);

        EndBlock();
    }];

    WaitUntilBlockCompletes();
}

-(void)testUnmappedContentType {
    StartBlock();

    [self.persistenceManager performSynchronizationWithSuccess:^{
        XCTAssertTrue(true, @"");

        EndBlock();
    } failure:^(CDAResponse *response, NSError *error) {
        XCTFail(@"Error: %@", error);

        EndBlock();
    }];

    WaitUntilBlockCompletes();
}

@end
