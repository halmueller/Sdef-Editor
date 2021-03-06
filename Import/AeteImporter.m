/*
 *  AeteImporter.m
 *  Sdef Editor
 *
 *  Created by Rainbow Team.
 *  Copyright © 2006 - 2007 Shadow Lab. All rights reserved.
 */

#import "AeteImporter.h"

#import <WonderBox/WBFSFunctions.h>
#import <WonderBox/WBAEFunctions.h>
#import <WonderBox/NSData+WonderBox.h>

#import "SdefSuite.h"
#import "SdefClass.h"
#import "SdefTypedef.h"
#import "SdefDictionary.h"
#import "SdefClassManager.h"

#import "AeteObject.h"

#include <Carbon/Carbon.h>

struct AeteHeader {
  UInt8 majorVersion;
  UInt8 minorVersion;
  UInt16 lang;
  UInt16 script;
  UInt16 suiteCount;
};
typedef struct AeteHeader AeteHeader;

@implementation AeteImporter

static
OSStatus _GetTerminologyFromAppleEvent(AppleEvent *theEvent, NSMutableArray *terminolgies) {
  long count = 0;
  AEDescList aetes = WBAEEmptyDesc();
  
//  OSStatus err = WBAESetStandardAttributes(theEvent);
//  require_noerr(err, bail);
  
  OSStatus err = WBAEAddSInt32(theEvent, keyDirectObject, 0);
  require_noerr(err, bail);
  
  err = WBAESendEventReturnAEDescList(theEvent, &aetes);
  require_noerr(err, bail);

  err = AECountItems(&aetes, &count);
  require_noerr(err, bail);

  for (CFIndex idx = 1; idx <= count; idx++) {
    CFDataRef data = NULL;
    WBAECopyNthCFDataFromDescList(&aetes, idx, typeAETE, NULL, &data);
    if (data) {
      [terminolgies addObject:(id)data];
      CFRelease(data);
    }
  }

bail:
  WBAEDisposeDesc(&aetes);
  return err;
}

- (id)_initWithTarget:(AEDesc *)target NS_METHOD_FAMILY(init) {
  if (self = [super init]) {
    AppleEvent theEvent = {typeNull, nil};
    sd_aetes = [[NSMutableArray alloc] init];
    if (target) {
      OSStatus err = WBAECreateEventWithTarget(target, kASAppleScriptSuite, kGetAEUT, &theEvent);
      require_noerr(err, bail);
      
      err = _GetTerminologyFromAppleEvent(&theEvent, sd_aetes);
      WBAEDisposeDesc(&theEvent);
      
      err = WBAECreateEventWithTarget(target, kASAppleScriptSuite, kGetAETE, &theEvent);
      require_noerr(err, bail);
      
      err = _GetTerminologyFromAppleEvent(&theEvent, sd_aetes);
      WBAEDisposeDesc(&theEvent);
    
      require(sd_aetes && [sd_aetes count], bail);
    }
  }
  return self;
/* On Error */
bail:
  [sd_aetes release];
  sd_aetes = nil;
  [self release];
  self = nil;
  return self;
}

- (id)initWithSystemSuites {
  if ((self = [self _initWithTarget:NULL])) {
    ComponentInstance cpnt;
    OSStatus err = OpenADefaultComponent(kOSAComponentType, kOSAGenericScriptingComponentSubtype, &cpnt);
    if (noErr == err) {
      ComponentInstance asct;
      err = OSAGetScriptingComponent(cpnt, kAppleScriptSubtype, &asct);
      
      if (noErr == err) {
        AEDesc aetes = WBAEEmptyDesc();
        err = OSAGetSysTerminology(asct, kOSAModeNull, 0, &aetes);
        if (noErr == err) {
          CFDataRef data = NULL;
          WBAECopyCFDataFromDescriptor(&aetes, &data);
          if (data) {
            [sd_aetes addObject:(id)data];
            CFRelease(data);
          }
          WBAEDisposeDesc(&aetes);
        }
        CloseComponent(asct);
      }
      CloseComponent(cpnt);
    }
  }
  return self;
}

- (id)initWithApplicationSignature:(OSType)signature {
  AEDesc target;
  OSStatus err = WBAECreateTargetWithSignature(signature, &target);
  if (noErr == err) {
    self = [self _initWithTarget:&target];
  } else {
    [self release];
    self = nil;
  }
  WBAEDisposeDesc(&target);
  if (self) {
    FSRef app;
    sd_dictionary = [[SdefDictionary alloc] init];
    if (noErr == LSGetApplicationForInfo(kLSUnknownType, signature, NULL, kLSRolesAll, &app, NULL)) {
      CFStringRef name = NULL;
      if (noErr == LSCopyDisplayNameForRef(&app, &name) && name) {
        [sd_dictionary setTitle:(NSString *)name];
        CFRelease(name);
      }
    }
  }
  return self;
}

- (id)initWithApplicationBundleIdentifier:(NSString *)identifier {
  AEDesc target;
  OSStatus err = WBAECreateTargetWithBundleID((CFStringRef)identifier, &target);
  if (noErr == err) {
    self = [self _initWithTarget:&target];
  } else {
    [self release];
    self = nil;
  }
  WBAEDisposeDesc(&target);
  /* resolve name */
  if (self) {
    FSRef app;
    sd_dictionary = [[SdefDictionary alloc] init];
    if (noErr == LSGetApplicationForInfo(kLSUnknownType, kLSUnknownType, 
                                         (CFStringRef)identifier, kLSRolesAll, &app, NULL)) {
      CFStringRef name = NULL;
      if (noErr == LSCopyDisplayNameForRef(&app, &name) && name) {
        [sd_dictionary setTitle:(NSString *)name];
        CFRelease(name);
      }
    }
  }
  return self;
}

- (id)initWithFSRef:(FSRef *)aRef {
  if (self = [super init]) {
    ResFileRefNum fileRef;
    OSStatus err = FSOpenResourceFile(aRef, 0, NULL, fsRdPerm, &fileRef);
    if (noErr != err) {
      HFSUniStr255 rsrcName;
      if (noErr == FSGetResourceForkName(&rsrcName)) {
        err = FSOpenResourceFile(aRef, rsrcName.length, rsrcName.unicode, fsRdPerm, &fileRef);
      }
    }
    if(noErr == err) {
      SInt16 count;
      /* Standard Infos */
      count = Count1Resources(kAEUserTerminology);
      sd_aetes = [[NSMutableArray alloc] initWithCapacity:count];
      for (NSInteger idx = 1; idx <= count; idx++) {
        Handle aeteH = Get1IndResource(kAEUserTerminology, idx);
        NSData *aete = [[NSData alloc] initWithHandle:aeteH];
        if (aete) {
          [sd_aetes addObject:aete];
          [aete release];
        }
      }
      /* Extensions */
      count = Count1Resources(kAETerminologyExtension);
      for (NSInteger idx = 1; idx <= count; idx++) {
        Handle aeteH = Get1IndResource(kAETerminologyExtension, idx);
        NSData *aete = [[NSData alloc] initWithHandle:aeteH];
        if (aete) {
          [sd_aetes addObject:aete];
          [aete release];
        }
      }
      CloseResFile(fileRef);
    }
    if (!sd_aetes) {
      [self release];
      self = nil;
    }
  }
  if (self) {
    sd_dictionary = [[SdefDictionary alloc] init];
    CFStringRef name = NULL;
    if (noErr == LSCopyDisplayNameForRef(aRef, &name) && name) {
      [sd_dictionary setTitle:[(NSString *)name stringByDeletingPathExtension]];
      CFRelease(name);
    }
  }
  return self;
}

- (id)initWithContentsOfFile:(NSString *)aFile {
  FSRef aRef;
  if (![aFile getFSRef:&aRef]) {
    [self release];
    self = nil;
  } else {
    self = [self initWithFSRef:&aRef];
  }
  return self;
}

- (void)dealloc {
  [sd_aetes release];
  [sd_dictionary release];
  [super dealloc];
}

#pragma mark -
#pragma mark Parsing
- (BOOL)import {
  if (sd_dictionary && [sd_dictionary hasChildren])
    [sd_dictionary removeAllChildren];
  
  NSUInteger count = [sd_aetes count];
  for (NSUInteger idx = 0; idx < count; idx++) {
    NSData *aete = [sd_aetes objectAtIndex:idx];
    @try {
      BytePtr bytes = (BytePtr)[aete bytes];
      ByteOffset offset = 0;
      AeteHeader *header = (AeteHeader *)bytes;
      bytes += sizeof(AeteHeader);
      offset += sizeof(AeteHeader);
      NSUInteger scount = header->suiteCount;
      while (scount-- > 0) {
        SdefSuite *suite = [[SdefSuite allocWithZone:[self zone]] init];
        bytes += [suite parseData:bytes];
        [suites addObject:suite];
        [suite release];
      }
    } @catch (id exception) {
      SPXLogException(exception);
      [suites removeAllObjects];
      return NO;
    }
  }
  return YES;
}

- (SdefDictionary *)sdefDictionary {
  if (![sd_dictionary hasChildren]) {
    NSArray *items = [self sdefSuites];
    NSUInteger count = [items count];
    for (NSUInteger idx = 0; idx < count; idx++) {
      [sd_dictionary appendChild:[items objectAtIndex:idx]];
    }
  }
  return sd_dictionary;
}

#pragma mark Post Processor
- (BOOL)resolveObjectType:(SdefObject *)obj {
  NSString *type = [obj valueForKey:@"type"];
  BOOL isList = NO;
  if ([type hasPrefix:@"list of"]) {
    isList = YES;
    type = [type substringFromIndex:8];
  }
  NSString *typename = [manager sdefTypeForAeteType:type];
  if (!typename) {
    typename = [[manager sdefTypeWithCode:type inSuite:nil] name];
  }
  if (typename) {
    if (isList) typename = [@"list of " stringByAppendingString:typename];
    [obj setValue:typename forKey:@"type"];
    return YES;
  }
  return NO;
}

- (void)postProcessCleanupClass:(SdefClass *)aClass {
  if ([[aClass properties] count]) {
    SdefProperty *info = [[aClass properties] firstChild];
    if (SdefOSTypeFromString([info code]) == pInherits) {
      id superclass = [manager sdefClassWithCode:[info type] inSuite:nil];
      if (superclass) {
        [aClass setInherits:[superclass name]];
      } else {
        [self addWarning:[NSString stringWithFormat:@"Unable to find superclass: %@", [info type]]
                forValue:[aClass name] node:aClass];
      }
      [info remove];
    } else if (SdefOSTypeFromString([info code]) == kAESpecialClassProperties) {
      if ([[info name] isEqualToString:@"<Plural>"]) {
        /* unregister special classes */
        if ([[aClass properties] count] == 1) {
          NSUInteger idx = [aClass index];
          [(SdefClass *)[[aClass parent] childAtIndex:idx-1] setPlural:[aClass name]];
          [manager removeClass:aClass];
          [aClass remove];
          return;
        } else {
          [aClass setPlural:[aClass name]];
          [[aClass properties] removeChildAtIndex:0];
        }
      } else {
        [self addWarning:@"Unable to import Special Properties" forValue:[aClass name] node:aClass];
      }      
    }
  }
  [super postProcessCleanupClass:aClass];
}

@end
