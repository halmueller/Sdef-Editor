//
//  SdefContents.m
//  SDef Editor
//
//  Created by Grayfox on 04/01/05.
//  Copyright 2005 Shadow Lab. All rights reserved.
//

#import "SdefContents.h"
#import "SdefClass.h"
#import "SdefDocument.h"

@implementation SdefContents
#pragma mark Protocols Implementations
- (id)copyWithZone:(NSZone *)aZone {
  SdefContents *copy = [super copyWithZone:aZone];
  copy->sd_owner = nil;
  copy->sd_access = sd_access;
  return copy;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [super encodeWithCoder:aCoder];
  [aCoder encodeInt:sd_access forKey:@"SCAccess"];
  [aCoder encodeConditionalObject:sd_owner forKey:@"SCOwner"];
  
}

- (id)initWithCoder:(NSCoder *)aCoder {
  if (self = [super initWithCoder:aCoder]) {
    sd_access = [aCoder decodeIntForKey:@"SCAccess"];
    sd_owner = [aCoder decodeObjectForKey:@"SCOwner"];
  }
  return self;
}

#pragma mark -
+ (SdefObjectType)objectType {
  return kSdefContentsType;
}

+ (NSString *)defaultIconName {
  return @"Content";
}

- (void)dealloc {
  [super dealloc];
}

#pragma mark -
- (void)sdefInit {
  [super sdefInit];
  [self setRemovable:NO];
}

- (unsigned)access {
  return sd_access;
}
- (void)setAccess:(unsigned)newAccess {
  [[[self undoManager] prepareWithInvocationTarget:self] setAccess:sd_access];
  sd_access = newAccess;
}

- (id)owner {
  return sd_owner;
}

- (void)setOwner:(SdefObject *)anObject {
  sd_owner = anObject;
}

- (id)firstParentOfType:(SdefObjectType)aType {
  id owner = [self owner];
  return ([owner objectType] == aType) ? owner : [owner firstParentOfType:aType];
}

@end
