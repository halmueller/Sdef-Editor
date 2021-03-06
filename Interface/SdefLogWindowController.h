//
//  SdefLogWindowController.h
//  Sdef Editor
//
//  Created by Jean-Daniel Dupas on 18/07/13.
//
//

#import <Cocoa/Cocoa.h>

@interface SdefLogWindowController : NSWindowController {
@private
  NSTextView *_logView;
}

@property(nonatomic, assign) IBOutlet NSTextView *logView;

- (void)setText:(NSString *)message;

@end
