//
//  ASDictionaryStream.h
//  Sdef Editor
//
//  Created by Grayfox on 28/02/05.
//  Copyright 2005 Shadow Lab. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#pragma mark Types Definition
struct ASDictionaryStyle {
  UInt32 position;
  SInt16 fontWidth;
  SInt16 fontAscent;
  SInt16 fontFamily;
  Style fontStyle;
  Byte b1;
  UInt16 fontSize;
  UInt16 red;
  UInt16 green;
  UInt16 blue;
};
typedef struct ASDictionaryStyle ASDictionaryStyle;

typedef enum {
  kASStyleComment,
  kASStyleStandard,
  kASStyleLanguageKeyword,
  kASStyleApplicationKeyword,
} ASDictionaryStyleType;

#pragma mark -
extern NSDictionary *ASDictionaryStringForAttributedString(NSAttributedString *aString);
extern NSAttributedString *AttributedStringForASDictionaryString(NSDictionary *content);

#pragma mark -
@interface ASDictionaryStream : NSObject {
@private
  NSMutableData *as_styles;
  NSMutableString *as_string;
  ASDictionaryStyle as_style;
}

- (id)initWithString:(NSString *)aString;
- (id)initWithAttributedString:(NSAttributedString *)aString;

- (id)initWithASDictionaryString:(NSDictionary *)aDictionary;

- (NSString *)string;
- (NSDictionary *)asDictionaryString;
- (NSAttributedString *)attributedString;

- (void)appendString:(NSString *)aString;
- (void)appendFormat:(NSString *)format, ...;

- (void)setASDictionaryStyle:(ASDictionaryStyleType)aStyle;

- (void)setFont:(NSFont *)aFont;

- (void)setSize:(FMFontSize)aSize;
- (void)setStyle:(FMFontStyle)aStyle;
- (void)setFontFamily:(NSString *)name;
- (void)setFontFamily:(NSString *)fontName style:(FMFontStyle)aStyle size:(FMFontSize)aSize;

- (void)setBold:(BOOL)flag;
- (void)setItalic:(BOOL)flag;
- (void)setUnderline:(BOOL)flag;

- (void)setColor:(NSColor *)aColor;

/*!
    @method     setRed:green:blue:
    @abstract   Set current style color. Value are 16 bit unsigned integer (0 - 65535)
    @param      red Red component
    @param      green Green component
    @param      blue Blue component
*/
- (void)setRed:(UInt16)red green:(UInt16)green blue:(UInt16)blue;

- (void)closeStyle;

@end
