// TTTAttributedLabel.m
//
// Copyright (c) 2011 Mattt Thompson (http://mattt.me)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "TTTAttributedLabel.h"

#import <QuartzCore/QuartzCore.h>
#import <Availability.h>
#import <objc/runtime.h>

static inline CGFLOAT_TYPE CGFloat_sqrt(CGFLOAT_TYPE cgfloat) {
#if CGFLOAT_IS_DOUBLE
    return sqrt(cgfloat);
#else
    return sqrtf(cgfloat);
#endif
}

@interface TTTAttributedLabel ()
@property (readwrite, nonatomic, copy) NSAttributedString *inactiveAttributedText;
@property (readwrite, nonatomic, copy) NSAttributedString *renderedAttributedText;
@property (readwrite, atomic, strong) NSDataDetector *dataDetector;
@property (readwrite, nonatomic, strong) NSArray *linkModels;
@property (readwrite, nonatomic, strong) TTTAttributedLabelLink *activeLink;
@property (readwrite, nonatomic, strong) NSArray *accessibilityElements;

@property (nonatomic, strong) NSLayoutManager *mockLayoutManager;
@property (nonatomic, strong) NSTextStorage *mockTextStorage;
@property (nonatomic, strong) NSTextContainer *mockTextContainer;

- (void) longPressGestureDidFire:(UILongPressGestureRecognizer *)sender;
@end

@implementation TTTAttributedLabel

//+ (void)load {
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0) {
//            Class class = [self class];
//            Class superclass = class_getSuperclass(class);
//
//            NSArray *strings = @[
//                                 NSStringFromSelector(@selector(isAccessibilityElement)),
//                                 NSStringFromSelector(@selector(accessibilityElementCount)),
//                                 NSStringFromSelector(@selector(accessibilityElementAtIndex:)),
//                                 NSStringFromSelector(@selector(indexOfAccessibilityElement:)),
//                                 ];
//
//            for (NSString *string in strings) {
//                SEL selector = NSSelectorFromString(string);
//                IMP superImplementation = class_getMethodImplementation(superclass, selector);
//                Method method = class_getInstanceMethod(class, selector);
//                const char *types = method_getTypeEncoding(method);
//                class_replaceMethod(class, selector, superImplementation, types);
//            }
//        }
//    });
//}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    [self commonInit];

    return self;
}

- (void)commonInit {
    self.userInteractionEnabled = YES;
    self.multipleTouchEnabled = NO;

//    self.textInsets = UIEdgeInsetsZero;

    self.linkModels = [NSArray array];

    NSMutableDictionary *mutableLinkAttributes = [NSMutableDictionary dictionary];
    [mutableLinkAttributes setObject:@(NSUnderlineStyleSingle) forKey:NSUnderlineStyleAttributeName];

    NSMutableDictionary *mutableActiveLinkAttributes = [NSMutableDictionary dictionary];
    [mutableActiveLinkAttributes setObject:@(NSUnderlineStyleNone) forKey:NSUnderlineStyleAttributeName];

    NSMutableDictionary *mutableInactiveLinkAttributes = [NSMutableDictionary dictionary];
    [mutableInactiveLinkAttributes setObject:@(NSUnderlineStyleNone) forKey:NSUnderlineStyleAttributeName];

    [mutableLinkAttributes setObject:[UIColor blueColor] forKey:NSForegroundColorAttributeName];
    [mutableActiveLinkAttributes setObject:[UIColor redColor] forKey:NSForegroundColorAttributeName];
    [mutableInactiveLinkAttributes setObject:[UIColor grayColor] forKey:NSForegroundColorAttributeName];

    self.linkAttributes = [NSDictionary dictionaryWithDictionary:mutableLinkAttributes];
    self.activeLinkAttributes = [NSDictionary dictionaryWithDictionary:mutableActiveLinkAttributes];
    self.inactiveLinkAttributes = [NSDictionary dictionaryWithDictionary:mutableInactiveLinkAttributes];
    _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                   
                                                                                action:@selector(longPressGestureDidFire:)];
    self.longPressGestureRecognizer.delegate = self;
    [self addGestureRecognizer:self.longPressGestureRecognizer];
    
    self.mockLayoutManager = [[NSLayoutManager alloc] init];
    
    self.mockTextContainer = [[NSTextContainer alloc] initWithSize:self.bounds.size];
    self.mockTextContainer.lineFragmentPadding = 0;
    self.mockTextContainer.lineBreakMode = self.lineBreakMode;
    self.mockTextContainer.layoutManager = self.mockLayoutManager;
    [self.mockLayoutManager addTextContainer:self.mockTextContainer];
    
    self.mockTextStorage = [[NSTextStorage alloc] init];
    [self.mockTextStorage addLayoutManager:self.mockLayoutManager];
    self.mockLayoutManager.textStorage = self.mockTextStorage;
}

- (void)dealloc {
//    if (_framesetter) {
//        CFRelease(_framesetter);
//    }
//
//    if (_highlightFramesetter) {
//        CFRelease(_highlightFramesetter);
//    }
    
    if (_longPressGestureRecognizer) {
        [self removeGestureRecognizer:_longPressGestureRecognizer];
    }
}

//#pragma mark -
//
//+ (CGSize)sizeThatFitsAttributedString:(NSAttributedString *)attributedString
//                       withConstraints:(CGSize)size
//                limitedToNumberOfLines:(NSUInteger)numberOfLines
//{
//    if (!attributedString || attributedString.length == 0) {
//        return CGSizeZero;
//    }
//
//    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)attributedString);
//
//    CGSize calculatedSize = CTFramesetterSuggestFrameSizeForAttributedStringWithConstraints(framesetter, attributedString, size, numberOfLines);
//
//    CFRelease(framesetter);
//
//    return calculatedSize;
//}
//
#pragma mark -

//- (void)setAttributedText:(NSAttributedString *)text {
//    if ([text isEqualToAttributedString:_attributedText]) {
//        return;
//    }
//
//    _attributedText = [text copy];
//
//    [self setNeedsFramesetter];
//    [self setNeedsDisplay];
//
//#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
//    if ([self respondsToSelector:@selector(invalidateIntrinsicContentSize)]) {
//        [self invalidateIntrinsicContentSize];
//    }
//#endif
//
//    [super setText:[self.attributedText string]];
//}

//- (NSAttributedString *)renderedAttributedText {
//    if (!_renderedAttributedText) {
//        self.renderedAttributedText = NSAttributedStringBySettingColorFromContext(self.attributedText, self.textColor);
//    }
//
//    return _renderedAttributedText;
//}
//
- (NSArray *) links {
    return [_linkModels valueForKey:@"result"];
}

- (void)setLinkModels:(NSArray *)linkModels {
    _linkModels = linkModels;
    
    self.accessibilityElements = nil;
}

//- (void)setNeedsFramesetter {
//    // Reset the rendered attributed text so it has a chance to regenerate
//    self.renderedAttributedText = nil;
//
//    _needsFramesetter = YES;
//}
//
//- (CTFramesetterRef)framesetter {
//    if (_needsFramesetter) {
//        @synchronized(self) {
//            CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)self.renderedAttributedText);
//            [self setFramesetter:framesetter];
//            [self setHighlightFramesetter:nil];
//            _needsFramesetter = NO;
//
//            if (framesetter) {
//                CFRelease(framesetter);
//            }
//        }
//    }
//
//    return _framesetter;
//}
//
//- (void)setFramesetter:(CTFramesetterRef)framesetter {
//    if (framesetter) {
//        CFRetain(framesetter);
//    }
//
//    if (_framesetter) {
//        CFRelease(_framesetter);
//    }
//
//    _framesetter = framesetter;
//}
//
//- (CTFramesetterRef)highlightFramesetter {
//    return _highlightFramesetter;
//}
//
//- (void)setHighlightFramesetter:(CTFramesetterRef)highlightFramesetter {
//    if (highlightFramesetter) {
//        CFRetain(highlightFramesetter);
//    }
//
//    if (_highlightFramesetter) {
//        CFRelease(_highlightFramesetter);
//    }
//
//    _highlightFramesetter = highlightFramesetter;
//}
//
//- (CGFloat)leading {
//    return self.lineSpacing;
//}
//
//- (void)setLeading:(CGFloat)leading {
//    self.lineSpacing = leading;
//}
//
#pragma mark -

- (NSTextCheckingTypes)dataDetectorTypes {
    return self.enabledTextCheckingTypes;
}

- (void)setDataDetectorTypes:(NSTextCheckingTypes)dataDetectorTypes {
    self.enabledTextCheckingTypes = dataDetectorTypes;
}

- (void)setEnabledTextCheckingTypes:(NSTextCheckingTypes)enabledTextCheckingTypes {
    NSParameterAssert(self.attributedText);
    
    if (self.enabledTextCheckingTypes == enabledTextCheckingTypes) {
        return;
    }
    
    _enabledTextCheckingTypes = enabledTextCheckingTypes;

    if (self.enabledTextCheckingTypes) {
        self.dataDetector = [NSDataDetector dataDetectorWithTypes:self.enabledTextCheckingTypes error:nil];
    } else {
        self.dataDetector = nil;
    }
    
    if (self.attributedText && self.enabledTextCheckingTypes) {
        __weak __typeof(self)weakSelf = self;
        NSAttributedString *text = self.attributedText;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            
            NSDataDetector *dataDetector = strongSelf.dataDetector;
            if (dataDetector && [dataDetector respondsToSelector:@selector(matchesInString:options:range:)]) {
                NSArray *results = [dataDetector matchesInString:text.string options:0 range:NSMakeRange(0, text.string.length)];
                if ([results count] > 0) {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        if ([strongSelf.attributedText.string isEqualToString:text.string]) {
                            [strongSelf addLinksWithTextCheckingResults:results attributes:strongSelf.linkAttributes];
                        }
                    });
                }
            }
        });
    }
}

- (void)addLink:(TTTAttributedLabelLink *)link {
    [self addLinks:@[link]];
}

- (void)addLinks:(NSArray *)links {
    NSParameterAssert(self.attributedText);
    
    NSMutableArray *mutableLinkModels = [NSMutableArray arrayWithArray:self.linkModels];
    
    NSMutableAttributedString *mutableAttributedString = [self.attributedText mutableCopy];

    for (TTTAttributedLabelLink *link in links) {
        if (link.attributes) {
            [mutableAttributedString addAttributes:link.attributes range:link.result.range];
        }
    }

    self.attributedText = mutableAttributedString;
//    [self setNeedsDisplay];

    [mutableLinkModels addObjectsFromArray:links];
    
    self.linkModels = [NSArray arrayWithArray:mutableLinkModels];
}

- (TTTAttributedLabelLink *)addLinkWithTextCheckingResult:(NSTextCheckingResult *)result
                                               attributes:(NSDictionary *)attributes
{
    return [self addLinksWithTextCheckingResults:@[result] attributes:attributes].firstObject;
}

- (NSArray *)addLinksWithTextCheckingResults:(NSArray *)results
                                  attributes:(NSDictionary *)attributes
{
    NSMutableArray *links = [NSMutableArray array];
    
    for (NSTextCheckingResult *result in results) {
        NSDictionary *activeAttributes = attributes ? self.activeLinkAttributes : nil;
        NSDictionary *inactiveAttributes = attributes ? self.inactiveLinkAttributes : nil;
        
        TTTAttributedLabelLink *link = [[TTTAttributedLabelLink alloc] initWithAttributes:attributes
                                                                         activeAttributes:activeAttributes
                                                                       inactiveAttributes:inactiveAttributes
                                                                       textCheckingResult:result];
        
        [links addObject:link];
    }
    
    [self addLinks:links];
    
    return links;
}

- (TTTAttributedLabelLink *)addLinkWithTextCheckingResult:(NSTextCheckingResult *)result {
    return [self addLinkWithTextCheckingResult:result attributes:self.linkAttributes];
}

- (TTTAttributedLabelLink *)addLinkToURL:(NSURL *)url
                               withRange:(NSRange)range
{
    return [self addLinkWithTextCheckingResult:[NSTextCheckingResult linkCheckingResultWithRange:range URL:url]];
}

- (TTTAttributedLabelLink *)addLinkToAddress:(NSDictionary *)addressComponents
                                   withRange:(NSRange)range
{
    return [self addLinkWithTextCheckingResult:[NSTextCheckingResult addressCheckingResultWithRange:range components:addressComponents]];
}

- (TTTAttributedLabelLink *)addLinkToPhoneNumber:(NSString *)phoneNumber
                                       withRange:(NSRange)range
{
    return [self addLinkWithTextCheckingResult:[NSTextCheckingResult phoneNumberCheckingResultWithRange:range phoneNumber:phoneNumber]];
}

- (TTTAttributedLabelLink *)addLinkToDate:(NSDate *)date
            withRange:(NSRange)range
{
    return [self addLinkWithTextCheckingResult:[NSTextCheckingResult dateCheckingResultWithRange:range date:date]];
}

- (TTTAttributedLabelLink *)addLinkToDate:(NSDate *)date
                                 timeZone:(NSTimeZone *)timeZone
                                 duration:(NSTimeInterval)duration
                                withRange:(NSRange)range
{
    return [self addLinkWithTextCheckingResult:[NSTextCheckingResult dateCheckingResultWithRange:range date:date timeZone:timeZone duration:duration]];
}

- (TTTAttributedLabelLink *)addLinkToTransitInformation:(NSDictionary *)components
                                              withRange:(NSRange)range
{
    return [self addLinkWithTextCheckingResult:[NSTextCheckingResult transitInformationCheckingResultWithRange:range components:components]];
}

#pragma mark -

- (BOOL)containslinkAtPoint:(CGPoint)point {
    return [self linkAtPoint:point] != nil;
}

- (TTTAttributedLabelLink *)linkAtPoint:(CGPoint)point {
    
    // Stop quickly if none of the points to be tested are in the bounds.
    if (!CGRectContainsPoint(CGRectInset(self.bounds, -15.f, -15.f), point) || self.links.count == 0) {
        return nil;
    }
    
    // Approximates the behavior of UIWebView which will trigger for links on touches within 15pt of the edge.
    return [self linkAtGlyphIndex:[self glyphIndexAtPoint:point]];
//    return [self linkAtCharacterIndex:[self characterIndexAtPoint:point]];
    
//    return [self linkAtCharacterIndex:[self characterIndexAtPoint:point]]
//        ?: [self linkAtRadius:2.5f aroundPoint:point]
//        ?: [self linkAtRadius:5.f aroundPoint:point]
//        ?: [self linkAtRadius:7.5f aroundPoint:point]
//        ?: [self linkAtRadius:12.5f aroundPoint:point]
//        ?: [self linkAtRadius:15.f aroundPoint:point];
}

- (TTTAttributedLabelLink *)linkAtRadius:(const CGFloat)radius aroundPoint:(CGPoint)point {
    const CGFloat diagonal = CGFloat_sqrt(2 * radius * radius);
    const CGPoint deltas[] = {
        CGPointMake(0, -radius), CGPointMake(0, radius), // Above and below
        CGPointMake(-radius, 0), CGPointMake(radius, 0), // Beside
        CGPointMake(-diagonal, -diagonal), CGPointMake(-diagonal, diagonal),
        CGPointMake(diagonal, diagonal), CGPointMake(diagonal, -diagonal) // Diagonal
    };
    const size_t count = sizeof(deltas) / sizeof(CGPoint);
    
    TTTAttributedLabelLink *link = nil;
    
    for (NSInteger i = 0; i < count && link.result == nil; i ++) {
        CGPoint currentPoint = CGPointMake(point.x + deltas[i].x, point.y + deltas[i].y);
        link = [self linkAtGlyphIndex:[self glyphIndexAtPoint:currentPoint]];
    }
    
    return link;
}

- (TTTAttributedLabelLink *)linkAtGlyphIndex:(NSUInteger)idx {
    NSEnumerator *enumerator = [self.linkModels reverseObjectEnumerator];
    TTTAttributedLabelLink *link = nil;

    NSRange characterRange = [self.mockLayoutManager characterRangeForGlyphRange:NSMakeRange(idx, 1)
                                                                actualGlyphRange:NULL];

    while ((link = [enumerator nextObject])) {
        if (NSLocationInRange(characterRange.location, link.result.range)) {
            return link;
        }
    }

    return nil;
}

- (NSUInteger) glyphIndexAtPoint:(CGPoint)p {
    CGFloat fraction = 0;

    NSUInteger idx = [self.mockLayoutManager glyphIndexForPoint:p
                                                inTextContainer:self.mockTextContainer
                                 fractionOfDistanceThroughGlyph:&fraction];

    return idx;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
- (CGRect)boundingRectForCharacterRange:(NSRange)range {
    NSMutableAttributedString *mutableAttributedString = [self.attributedText mutableCopy];

    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:mutableAttributedString];

    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [textStorage addLayoutManager:layoutManager];

    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:self.bounds.size];
    [layoutManager addTextContainer:textContainer];

    NSRange glyphRange;
    [layoutManager characterRangeForGlyphRange:range actualGlyphRange:&glyphRange];

    return [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
}
#endif

//- (void)drawFramesetter:(CTFramesetterRef)framesetter
//       attributedString:(NSAttributedString *)attributedString
//              textRange:(CFRange)textRange
//                 inRect:(CGRect)rect
//                context:(CGContextRef)c
//{
//    CGMutablePathRef path = CGPathCreateMutable();
//    CGPathAddRect(path, NULL, rect);
//    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, textRange, path, NULL);
//
//    [self drawBackground:frame inRect:rect context:c];
//
//    CFArrayRef lines = CTFrameGetLines(frame);
//    NSInteger numberOfLines = self.numberOfLines > 0 ? MIN(self.numberOfLines, CFArrayGetCount(lines)) : CFArrayGetCount(lines);
//    BOOL truncateLastLine = (self.lineBreakMode == TTTLineBreakByTruncatingHead || self.lineBreakMode == TTTLineBreakByTruncatingMiddle || self.lineBreakMode == TTTLineBreakByTruncatingTail);
//
//    CGPoint lineOrigins[numberOfLines];
//    CTFrameGetLineOrigins(frame, CFRangeMake(0, numberOfLines), lineOrigins);
//
//    for (CFIndex lineIndex = 0; lineIndex < numberOfLines; lineIndex++) {
//        CGPoint lineOrigin = lineOrigins[lineIndex];
//        CGContextSetTextPosition(c, lineOrigin.x, lineOrigin.y);
//        CTLineRef line = CFArrayGetValueAtIndex(lines, lineIndex);
//
//        CGFloat descent = 0.0f;
//        CTLineGetTypographicBounds((CTLineRef)line, NULL, &descent, NULL);
//
//        // Adjust pen offset for flush depending on text alignment
//        CGFloat flushFactor = TTTFlushFactorForTextAlignment(self.textAlignment);
//
//        if (lineIndex == numberOfLines - 1 && truncateLastLine) {
//            // Check if the range of text in the last line reaches the end of the full attributed string
//            CFRange lastLineRange = CTLineGetStringRange(line);
//
//            if (!(lastLineRange.length == 0 && lastLineRange.location == 0) && lastLineRange.location + lastLineRange.length < textRange.location + textRange.length) {
//                // Get correct truncationType and attribute position
//                CTLineTruncationType truncationType;
//                CFIndex truncationAttributePosition = lastLineRange.location;
//                TTTLineBreakMode lineBreakMode = self.lineBreakMode;
//
//                // Multiple lines, only use UILineBreakModeTailTruncation
//                if (numberOfLines != 1) {
//                    lineBreakMode = TTTLineBreakByTruncatingTail;
//                }
//
//                switch (lineBreakMode) {
//                    case TTTLineBreakByTruncatingHead:
//                        truncationType = kCTLineTruncationStart;
//                        break;
//                    case TTTLineBreakByTruncatingMiddle:
//                        truncationType = kCTLineTruncationMiddle;
//                        truncationAttributePosition += (lastLineRange.length / 2);
//                        break;
//                    case TTTLineBreakByTruncatingTail:
//                    default:
//                        truncationType = kCTLineTruncationEnd;
//                        truncationAttributePosition += (lastLineRange.length - 1);
//                        break;
//                }
//
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Wdeprecated-declarations"
//                NSAttributedString *attributedTruncationString = self.attributedTruncationToken;
//                if (!attributedTruncationString) {
//                    NSString *truncationTokenString = self.truncationTokenString;
//                    if (!truncationTokenString) {
//                        truncationTokenString = @"\u2026"; // Unicode Character 'HORIZONTAL ELLIPSIS' (U+2026)
//                    }
//                    
//                    NSDictionary *truncationTokenStringAttributes = self.truncationTokenStringAttributes;
//                    if (!truncationTokenStringAttributes) {
//                        truncationTokenStringAttributes = [attributedString attributesAtIndex:(NSUInteger)truncationAttributePosition effectiveRange:NULL];
//                    }
//                    
//                    attributedTruncationString = [[NSAttributedString alloc] initWithString:truncationTokenString attributes:truncationTokenStringAttributes];
//                }
//                CTLineRef truncationToken = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attributedTruncationString);
//#pragma clang diagnostic pop
//
//                // Append truncationToken to the string
//                // because if string isn't too long, CT wont add the truncationToken on it's own
//                // There is no change of a double truncationToken because CT only add the token if it removes characters (and the one we add will go first)
//                NSMutableAttributedString *truncationString = [[attributedString attributedSubstringFromRange:NSMakeRange((NSUInteger)lastLineRange.location, (NSUInteger)lastLineRange.length)] mutableCopy];
//                if (lastLineRange.length > 0) {
//                    // Remove any newline at the end (we don't want newline space between the text and the truncation token). There can only be one, because the second would be on the next line.
//                    unichar lastCharacter = [[truncationString string] characterAtIndex:(NSUInteger)(lastLineRange.length - 1)];
//                    if ([[NSCharacterSet newlineCharacterSet] characterIsMember:lastCharacter]) {
//                        [truncationString deleteCharactersInRange:NSMakeRange((NSUInteger)(lastLineRange.length - 1), 1)];
//                    }
//                }
//                [truncationString appendAttributedString:attributedTruncationString];
//                CTLineRef truncationLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)truncationString);
//
//                // Truncate the line in case it is too long.
//                CTLineRef truncatedLine = CTLineCreateTruncatedLine(truncationLine, rect.size.width, truncationType, truncationToken);
//                if (!truncatedLine) {
//                    // If the line is not as wide as the truncationToken, truncatedLine is NULL
//                    truncatedLine = CFRetain(truncationToken);
//                }
//
//                CGFloat penOffset = (CGFloat)CTLineGetPenOffsetForFlush(truncatedLine, flushFactor, rect.size.width);
//                CGContextSetTextPosition(c, penOffset, lineOrigin.y - descent - self.font.descender);
//
//                CTLineDraw(truncatedLine, c);
//                
//                NSRange linkRange;
//                if ([attributedTruncationString attribute:NSLinkAttributeName atIndex:0 effectiveRange:&linkRange]) {
//                    NSRange tokenRange = [truncationString.string rangeOfString:attributedTruncationString.string];
//                    NSRange tokenLinkRange = NSMakeRange((NSUInteger)(lastLineRange.location+lastLineRange.length)-tokenRange.length, (NSUInteger)tokenRange.length);
//                    
//                    [self addLinkToURL:[attributedTruncationString attribute:NSLinkAttributeName atIndex:0 effectiveRange:&linkRange] withRange:tokenLinkRange];
//                }
//
//                CFRelease(truncatedLine);
//                CFRelease(truncationLine);
//                CFRelease(truncationToken);
//            } else {
//                CGFloat penOffset = (CGFloat)CTLineGetPenOffsetForFlush(line, flushFactor, rect.size.width);
//                CGContextSetTextPosition(c, penOffset, lineOrigin.y - descent - self.font.descender);
//                CTLineDraw(line, c);
//            }
//        } else {
//            CGContextSetTextPosition(c, lineOrigin.x, lineOrigin.y - descent - self.font.descender);
//            CTLineDraw(line, c);
//        }
//    }
//
//    [self drawStrike:frame inRect:rect context:c];
//
//    CFRelease(frame);
//    CFRelease(path);
//}
//
//- (void)drawBackground:(CTFrameRef)frame
//                inRect:(CGRect)rect
//               context:(CGContextRef)c
//{
//    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frame);
//    CGPoint origins[[lines count]];
//    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), origins);
//
//    CFIndex lineIndex = 0;
//    for (id line in lines) {
//        CGFloat ascent = 0.0f, descent = 0.0f, leading = 0.0f;
//        CGFloat width = (CGFloat)CTLineGetTypographicBounds((__bridge CTLineRef)line, &ascent, &descent, &leading) ;
//
//        for (id glyphRun in (__bridge NSArray *)CTLineGetGlyphRuns((__bridge CTLineRef)line)) {
//            NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes((__bridge CTRunRef) glyphRun);
//            CGColorRef strokeColor = (__bridge CGColorRef)[attributes objectForKey:kTTTBackgroundStrokeColorAttributeName];
//            CGColorRef fillColor = (__bridge CGColorRef)[attributes objectForKey:kTTTBackgroundFillColorAttributeName];
//            UIEdgeInsets fillPadding = [[attributes objectForKey:kTTTBackgroundFillPaddingAttributeName] UIEdgeInsetsValue];
//            CGFloat cornerRadius = [[attributes objectForKey:kTTTBackgroundCornerRadiusAttributeName] floatValue];
//            CGFloat lineWidth = [[attributes objectForKey:kTTTBackgroundLineWidthAttributeName] floatValue];
//
//            if (strokeColor || fillColor) {
//                CGRect runBounds = CGRectZero;
//                CGFloat runAscent = 0.0f;
//                CGFloat runDescent = 0.0f;
//
//                runBounds.size.width = (CGFloat)CTRunGetTypographicBounds((__bridge CTRunRef)glyphRun, CFRangeMake(0, 0), &runAscent, &runDescent, NULL) + fillPadding.left + fillPadding.right;
//                runBounds.size.height = runAscent + runDescent + fillPadding.top + fillPadding.bottom;
//
//                CGFloat xOffset = 0.0f;
//                CFRange glyphRange = CTRunGetStringRange((__bridge CTRunRef)glyphRun);
//                switch (CTRunGetStatus((__bridge CTRunRef)glyphRun)) {
//                    case kCTRunStatusRightToLeft:
//                        xOffset = CTLineGetOffsetForStringIndex((__bridge CTLineRef)line, glyphRange.location + glyphRange.length, NULL);
//                        break;
//                    default:
//                        xOffset = CTLineGetOffsetForStringIndex((__bridge CTLineRef)line, glyphRange.location, NULL);
//                        break;
//                }
//
//                runBounds.origin.x = origins[lineIndex].x + rect.origin.x + xOffset - fillPadding.left - rect.origin.x;
//                runBounds.origin.y = origins[lineIndex].y + rect.origin.y - fillPadding.bottom - rect.origin.y;
//                runBounds.origin.y -= runDescent;
//
//                // Don't draw higlightedLinkBackground too far to the right
//                if (CGRectGetWidth(runBounds) > width) {
//                    runBounds.size.width = width;
//                }
//
//                CGPathRef path = [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(UIEdgeInsetsInsetRect(runBounds, self.linkBackgroundEdgeInset), lineWidth, lineWidth) cornerRadius:cornerRadius] CGPath];
//
//                CGContextSetLineJoin(c, kCGLineJoinRound);
//
//                if (fillColor) {
//                    CGContextSetFillColorWithColor(c, fillColor);
//                    CGContextAddPath(c, path);
//                    CGContextFillPath(c);
//                }
//
//                if (strokeColor) {
//                    CGContextSetStrokeColorWithColor(c, strokeColor);
//                    CGContextAddPath(c, path);
//                    CGContextStrokePath(c);
//                }
//            }
//        }
//
//        lineIndex++;
//    }
//}

//- (void)drawStrike:(CTFrameRef)frame
//            inRect:(__unused CGRect)rect
//           context:(CGContextRef)c
//{
//    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frame);
//    CGPoint origins[[lines count]];
//    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), origins);
//
//    CFIndex lineIndex = 0;
//    for (id line in lines) {
//        CGFloat ascent = 0.0f, descent = 0.0f, leading = 0.0f;
//        CGFloat width = (CGFloat)CTLineGetTypographicBounds((__bridge CTLineRef)line, &ascent, &descent, &leading) ;
//
//        for (id glyphRun in (__bridge NSArray *)CTLineGetGlyphRuns((__bridge CTLineRef)line)) {
//            NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes((__bridge CTRunRef) glyphRun);
//            BOOL strikeOut = [[attributes objectForKey:kTTTStrikeOutAttributeName] boolValue];
//            NSInteger superscriptStyle = [[attributes objectForKey:(id)kCTSuperscriptAttributeName] integerValue];
//
//            if (strikeOut) {
//                CGRect runBounds = CGRectZero;
//                CGFloat runAscent = 0.0f;
//                CGFloat runDescent = 0.0f;
//
//                runBounds.size.width = (CGFloat)CTRunGetTypographicBounds((__bridge CTRunRef)glyphRun, CFRangeMake(0, 0), &runAscent, &runDescent, NULL);
//                runBounds.size.height = runAscent + runDescent;
//
//                CGFloat xOffset = 0.0f;
//                CFRange glyphRange = CTRunGetStringRange((__bridge CTRunRef)glyphRun);
//                switch (CTRunGetStatus((__bridge CTRunRef)glyphRun)) {
//                    case kCTRunStatusRightToLeft:
//                        xOffset = CTLineGetOffsetForStringIndex((__bridge CTLineRef)line, glyphRange.location + glyphRange.length, NULL);
//                        break;
//                    default:
//                        xOffset = CTLineGetOffsetForStringIndex((__bridge CTLineRef)line, glyphRange.location, NULL);
//                        break;
//                }
//                runBounds.origin.x = origins[lineIndex].x + xOffset;
//                runBounds.origin.y = origins[lineIndex].y;
//                runBounds.origin.y -= runDescent;
//
//                // Don't draw strikeout too far to the right
//                if (CGRectGetWidth(runBounds) > width) {
//                    runBounds.size.width = width;
//                }
//
//				switch (superscriptStyle) {
//					case 1:
//						runBounds.origin.y -= runAscent * 0.47f;
//						break;
//					case -1:
//						runBounds.origin.y += runAscent * 0.25f;
//						break;
//					default:
//						break;
//				}
//
//                // Use text color, or default to black
//                id color = [attributes objectForKey:(id)kCTForegroundColorAttributeName];
//                if (color) {
//                    if ([color isKindOfClass:[UIColor class]]) {
//                        CGContextSetStrokeColorWithColor(c, [color CGColor]);
//                    } else {
//                        CGContextSetStrokeColorWithColor(c, (__bridge CGColorRef)color);
//                    }
//                } else {
//                    CGContextSetGrayStrokeColor(c, 0.0f, 1.0);
//                }
//
//                CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)self.font.fontName, self.font.pointSize, NULL);
//                CGContextSetLineWidth(c, CTFontGetUnderlineThickness(font));
//                CFRelease(font);
//
//                CGFloat y = CGFloat_round(runBounds.origin.y + runBounds.size.height / 2.0f);
//                CGContextMoveToPoint(c, runBounds.origin.x, y);
//                CGContextAddLineToPoint(c, runBounds.origin.x + runBounds.size.width, y);
//
//                CGContextStrokePath(c);
//            }
//        }
//
//        lineIndex++;
//    }
//}

#pragma mark - TTTAttributedLabel

- (void)setText:(id)text {
    [super setText:text];
    
//    self.activeLink = nil;
//    self.linkModels = [NSArray array];
    
    self.mockTextStorage.attributedString = nil;
}

- (void) setAttributedText:(NSAttributedString *)attributedText {
    [super setAttributedText:attributedText];
    
//    _activeLink = nil;
//    self.linkModels = [NSArray array];
    
    [self.attributedText enumerateAttribute:NSLinkAttributeName inRange:NSMakeRange(0, self.attributedText.length) options:0 usingBlock:^(id value, __unused NSRange range, __unused BOOL *stop) {
        if (value) {
            NSURL *URL = [value isKindOfClass:[NSString class]] ? [NSURL URLWithString:value] : value;
            if (URL) {
                [self addLinkToURL:URL withRange:range];
            }
        }
    }];
    
    self.mockTextStorage.attributedString = self.attributedText;
}

- (void) setNumberOfLines:(NSInteger)numberOfLines {
    [super setNumberOfLines:numberOfLines];
    self.mockTextContainer.maximumNumberOfLines = numberOfLines;
}

- (void) setLineBreakMode:(NSLineBreakMode)lineBreakMode {
    [super setLineBreakMode:lineBreakMode];
    self.mockTextContainer.lineBreakMode = lineBreakMode;
}

//- (void)setText:(id)text
//afterInheritingLabelAttributesAndConfiguringWithBlock:(NSMutableAttributedString * (^)(NSMutableAttributedString *mutableAttributedString))block
//{
//    NSMutableAttributedString *mutableAttributedString = nil;
//    if ([text isKindOfClass:[NSString class]]) {
//        mutableAttributedString = [[NSMutableAttributedString alloc] initWithString:text attributes:NSAttributedStringAttributesFromLabel(self)];
//    } else {
//        mutableAttributedString = [[NSMutableAttributedString alloc] initWithAttributedString:text];
//        [mutableAttributedString addAttributes:NSAttributedStringAttributesFromLabel(self) range:NSMakeRange(0, [mutableAttributedString length])];
//    }
//
//    if (block) {
//        mutableAttributedString = block(mutableAttributedString);
//    }
//
//    [self setText:mutableAttributedString];
//}

- (void)setActiveLink:(TTTAttributedLabelLink *)activeLink {
    NSLog(@"set active link: %@", activeLink);
    
    if (!activeLink) {
        NSLog(@"ruh roh");
    }
    
    _activeLink = activeLink;
    
    NSDictionary *activeAttributes = activeLink.activeAttributes ?: self.activeLinkAttributes;

    if (_activeLink && activeAttributes.count > 0) {
        if (!self.inactiveAttributedText) {
            self.inactiveAttributedText = [self.attributedText copy];
        }

        NSMutableAttributedString *mutableAttributedString = [self.inactiveAttributedText mutableCopy];
        if (_activeLink.result.range.length > 0 && NSLocationInRange(NSMaxRange(_activeLink.result.range) - 1, NSMakeRange(0, self.inactiveAttributedText.length))) {
            [mutableAttributedString addAttributes:activeAttributes range:_activeLink.result.range];
        }

        self.attributedText = mutableAttributedString;
//        [self setNeedsDisplay];

        [CATransaction flush];
    } else if (self.inactiveAttributedText) {
        self.attributedText = self.inactiveAttributedText;
        self.inactiveAttributedText = nil;

//        [self setNeedsDisplay];
    }
}

//#pragma mark - UILabel
//
//- (void)setHighlighted:(BOOL)highlighted {
//    [super setHighlighted:highlighted];
//    [self setNeedsDisplay];
//}

// Fixes crash when loading from a UIStoryboard
//- (UIColor *)textColor {
//	UIColor *color = [super textColor];
//	if (!color) {
//		color = [UIColor blackColor];
//	}
//
//	return color;
//}
//
//- (void)setTextColor:(UIColor *)textColor {
//    UIColor *oldTextColor = self.textColor;
//    [super setTextColor:textColor];
//
//    // Redraw to allow any ColorFromContext attributes a chance to update
//    if (textColor != oldTextColor) {
//        [self setNeedsFramesetter];
//        [self setNeedsDisplay];
//    }
//}

//- (CGRect)textRectForBounds:(CGRect)bounds
//     limitedToNumberOfLines:(NSInteger)numberOfLines
//{
//    bounds = UIEdgeInsetsInsetRect(bounds, self.textInsets);
//    if (!self.attributedText) {
//        return [super textRectForBounds:bounds limitedToNumberOfLines:numberOfLines];
//    }
//
//    CGRect textRect = bounds;
//
//    // Calculate height with a minimum of double the font pointSize, to ensure that CTFramesetterSuggestFrameSizeWithConstraints doesn't return CGSizeZero, as it would if textRect height is insufficient.
//    textRect.size.height = MAX(self.font.lineHeight * MAX(2, numberOfLines), bounds.size.height);
//
//    // Adjust the text to be in the center vertically, if the text size is smaller than bounds
//    CGSize textSize = CTFramesetterSuggestFrameSizeWithConstraints([self framesetter], CFRangeMake(0, (CFIndex)[self.attributedText length]), NULL, textRect.size, NULL);
//    textSize = CGSizeMake(CGFloat_ceil(textSize.width), CGFloat_ceil(textSize.height)); // Fix for iOS 4, CTFramesetterSuggestFrameSizeWithConstraints sometimes returns fractional sizes
//
//    if (textSize.height < bounds.size.height) {
//        CGFloat yOffset = 0.0f;
//        switch (self.verticalAlignment) {
//            case TTTAttributedLabelVerticalAlignmentCenter:
//                yOffset = CGFloat_floor((bounds.size.height - textSize.height) / 2.0f);
//                break;
//            case TTTAttributedLabelVerticalAlignmentBottom:
//                yOffset = bounds.size.height - textSize.height;
//                break;
//            case TTTAttributedLabelVerticalAlignmentTop:
//            default:
//                break;
//        }
//
//        textRect.origin.y += yOffset;
//    }
//
//    return textRect;
//}

#pragma mark - UIAccessibilityElement

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000

- (BOOL)isAccessibilityElement {
    return NO;
}

- (NSInteger)accessibilityElementCount {
    return (NSInteger)[[self accessibilityElements] count];
}

- (id)accessibilityElementAtIndex:(NSInteger)index {
    return [[self accessibilityElements] objectAtIndex:(NSUInteger)index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element {
    return (NSInteger)[[self accessibilityElements] indexOfObject:element];
}

- (NSArray *)accessibilityElements {
    if (!_accessibilityElements) {
        @synchronized(self) {
            NSMutableArray *mutableAccessibilityItems = [NSMutableArray array];

            for (TTTAttributedLabelLink *link in self.linkModels) {
                NSString *sourceText = [self.text isKindOfClass:[NSString class]] ? self.text : [(NSAttributedString *)self.text string];

                NSString *accessibilityLabel = [sourceText substringWithRange:link.result.range];
                NSString *accessibilityValue = link.accessibilityValue;

                if (accessibilityLabel) {
                    UIAccessibilityElement *linkElement = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
                    linkElement.accessibilityTraits = UIAccessibilityTraitLink;
                    linkElement.accessibilityFrame = [self convertRect:[self boundingRectForCharacterRange:link.result.range] toView:self.window];
                    linkElement.accessibilityLabel = accessibilityLabel;

                    if (![accessibilityLabel isEqualToString:accessibilityValue]) {
                        linkElement.accessibilityValue = accessibilityValue;
                    }

                    [mutableAccessibilityItems addObject:linkElement];
                }
            }

            UIAccessibilityElement *baseElement = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
            baseElement.accessibilityLabel = [super accessibilityLabel];
            baseElement.accessibilityHint = [super accessibilityHint];
            baseElement.accessibilityValue = [super accessibilityValue];
            baseElement.accessibilityFrame = [self convertRect:self.bounds toView:self.window];
            baseElement.accessibilityTraits = [super accessibilityTraits];

            [mutableAccessibilityItems addObject:baseElement];

            self.accessibilityElements = [NSArray arrayWithArray:mutableAccessibilityItems];
        }
    }

    return _accessibilityElements;
}
#endif

#pragma mark - UIView

- (void) setFrame:(CGRect)frame {
    [super setFrame:frame];
    self.mockTextContainer.size = self.bounds.size;
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    self.mockTextContainer.size = self.bounds.size;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.mockTextContainer.size = self.bounds.size;
}

- (void)tintColorDidChange {
    if (!self.inactiveLinkAttributes || [self.inactiveLinkAttributes count] == 0) {
        return;
    }

    BOOL isInactive = (self.tintAdjustmentMode == UIViewTintAdjustmentModeDimmed);

    NSMutableAttributedString *mutableAttributedString = [self.attributedText mutableCopy];
    for (TTTAttributedLabelLink *link in self.linkModels) {
        NSDictionary *attributesToRemove = isInactive ? link.attributes : link.inactiveAttributes;
        NSDictionary *attributesToAdd = isInactive ? link.inactiveAttributes : link.attributes;
        
        [attributesToRemove enumerateKeysAndObjectsUsingBlock:^(NSString *name, __unused id value, __unused BOOL *stop) {
            if (NSMaxRange(link.result.range) <= mutableAttributedString.length) {
                [mutableAttributedString removeAttribute:name range:link.result.range];
            }
        }];

        if (attributesToAdd) {
            if (NSMaxRange(link.result.range) <= mutableAttributedString.length) {
                [mutableAttributedString addAttributes:attributesToAdd range:link.result.range];
            }
        }
    }

    self.attributedText = mutableAttributedString;

//    [self setNeedsDisplay];
}

- (UIView *)hitTest:(CGPoint)point
          withEvent:(UIEvent *)event
{
    if (![self linkAtPoint:point] || !self.userInteractionEnabled || self.hidden || self.alpha < 0.01) {
        return [super hitTest:point withEvent:event];
    }

    return self;
}

#pragma mark - UIResponder

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)canPerformAction:(SEL)action
              withSender:(__unused id)sender
{
    return (action == @selector(copy:));
}

- (void)touchesBegan:(NSSet *)touches
           withEvent:(UIEvent *)event
{
    NSLog(@"BEGAN!");
    UITouch *touch = [touches anyObject];

    self.activeLink = [self linkAtPoint:[touch locationInView:self]];

    if (!self.activeLink) {
        [super touchesBegan:touches withEvent:event];
    }
    
    NSLog(@"  (with active link: %@)", (self.activeLink ? @"YES" : @"NO"));

}

- (void)touchesMoved:(NSSet *)touches
           withEvent:(UIEvent *)event
{
    NSLog(@"  MOVED! Active Link: %@", (self.activeLink ? @"YES" : @"NO"));
    
    if (self.activeLink) {
        UITouch *touch = [touches anyObject];

        if (self.activeLink != [self linkAtPoint:[touch locationInView:self]]) {
            self.activeLink = nil;
        }
    } else {
        [super touchesMoved:touches withEvent:event];
    }
}

- (void)touchesEnded:(NSSet *)touches
           withEvent:(UIEvent *)event
{
    NSLog(@"ENDED! Active Link: %@", (self.activeLink ? @"YES" : @"NO"));

    if (self.activeLink) {
        NSTextCheckingResult *result = self.activeLink.result;
        self.activeLink = nil;

        switch (result.resultType) {
            case NSTextCheckingTypeLink:
                if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithURL:)]) {
                    [self.delegate attributedLabel:self didSelectLinkWithURL:result.URL];
                    return;
                }
                break;
            case NSTextCheckingTypeAddress:
                if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithAddress:)]) {
                    [self.delegate attributedLabel:self didSelectLinkWithAddress:result.addressComponents];
                    return;
                }
                break;
            case NSTextCheckingTypePhoneNumber:
                if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithPhoneNumber:)]) {
                    [self.delegate attributedLabel:self didSelectLinkWithPhoneNumber:result.phoneNumber];
                    return;
                }
                break;
            case NSTextCheckingTypeDate:
                if (result.timeZone && [self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithDate:timeZone:duration:)]) {
                    [self.delegate attributedLabel:self didSelectLinkWithDate:result.date timeZone:result.timeZone duration:result.duration];
                    return;
                } else if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithDate:)]) {
                    [self.delegate attributedLabel:self didSelectLinkWithDate:result.date];
                    return;
                }
                break;
            case NSTextCheckingTypeTransitInformation:
                if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithTransitInformation:)]) {
                    [self.delegate attributedLabel:self didSelectLinkWithTransitInformation:result.components];
                    return;
                }
            default:
                break;
        }

        // Fallback to `attributedLabel:didSelectLinkWithTextCheckingResult:` if no other delegate method matched.
        if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithTextCheckingResult:)]) {
            [self.delegate attributedLabel:self didSelectLinkWithTextCheckingResult:result];
        }
    } else {
        [super touchesEnded:touches withEvent:event];
    }
}

- (void)touchesCancelled:(NSSet *)touches
               withEvent:(UIEvent *)event
{
    NSLog(@"CANCELLED! Active Link: %@", (self.activeLink ? @"YES" : @"NO"));

    if (self.activeLink) {
        self.activeLink = nil;
    } else {
        [super touchesCancelled:touches withEvent:event];
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return [self containslinkAtPoint:[touch locationInView:self]];
}

#pragma mark - UILongPressGestureRecognizer

- (void)longPressGestureDidFire:(UILongPressGestureRecognizer *)sender {
    switch (sender.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint touchPoint = [sender locationInView:self];
            NSTextCheckingResult *result = [self linkAtPoint:touchPoint].result;
            
            if (result) {
                switch (result.resultType) {
                    case NSTextCheckingTypeLink:
                        if ([self.delegate respondsToSelector:@selector(attributedLabel:didLongPressLinkWithURL:atPoint:)]) {
                            [self.delegate attributedLabel:self didLongPressLinkWithURL:result.URL atPoint:touchPoint];
                            return;
                        }
                        break;
                    case NSTextCheckingTypeAddress:
                        if ([self.delegate respondsToSelector:@selector(attributedLabel:didLongPressLinkWithAddress:atPoint:)]) {
                            [self.delegate attributedLabel:self didLongPressLinkWithAddress:result.addressComponents atPoint:touchPoint];
                            return;
                        }
                        break;
                    case NSTextCheckingTypePhoneNumber:
                        if ([self.delegate respondsToSelector:@selector(attributedLabel:didLongPressLinkWithPhoneNumber:atPoint:)]) {
                            [self.delegate attributedLabel:self didLongPressLinkWithPhoneNumber:result.phoneNumber atPoint:touchPoint];
                            return;
                        }
                        break;
                    case NSTextCheckingTypeDate:
                        if (result.timeZone && [self.delegate respondsToSelector:@selector(attributedLabel:didLongPressLinkWithDate:timeZone:duration:atPoint:)]) {
                            [self.delegate attributedLabel:self didLongPressLinkWithDate:result.date timeZone:result.timeZone duration:result.duration atPoint:touchPoint];
                            return;
                        } else if ([self.delegate respondsToSelector:@selector(attributedLabel:didLongPressLinkWithDate:atPoint:)]) {
                            [self.delegate attributedLabel:self didLongPressLinkWithDate:result.date atPoint:touchPoint];
                            return;
                        }
                        break;
                    case NSTextCheckingTypeTransitInformation:
                        if ([self.delegate respondsToSelector:@selector(attributedLabel:didLongPressLinkWithTransitInformation:atPoint:)]) {
                            [self.delegate attributedLabel:self didLongPressLinkWithTransitInformation:result.components atPoint:touchPoint];
                            return;
                        }
                    default:
                        break;
                }
                
                // Fallback to `attributedLabel:didLongPressLinkWithTextCheckingResult:atPoint:` if no other delegate method matched.
                if ([self.delegate respondsToSelector:@selector(attributedLabel:didLongPressLinkWithTextCheckingResult:atPoint:)]) {
                    [self.delegate attributedLabel:self didLongPressLinkWithTextCheckingResult:result atPoint:touchPoint];
                }
            }
            break;
        }
        default:
            break;
    }
}

#pragma mark - UIResponderStandardEditActions

- (void)copy:(__unused id)sender {
    [[UIPasteboard generalPasteboard] setString:self.text];
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];

    [coder encodeObject:@(self.enabledTextCheckingTypes) forKey:NSStringFromSelector(@selector(enabledTextCheckingTypes))];

    [coder encodeObject:self.linkModels forKey:NSStringFromSelector(@selector(linkModels))];
    if ([NSMutableParagraphStyle class]) {
        [coder encodeObject:self.linkAttributes forKey:NSStringFromSelector(@selector(linkAttributes))];
        [coder encodeObject:self.activeLinkAttributes forKey:NSStringFromSelector(@selector(activeLinkAttributes))];
        [coder encodeObject:self.inactiveLinkAttributes forKey:NSStringFromSelector(@selector(inactiveLinkAttributes))];
    }
    [coder encodeObject:@(self.shadowRadius) forKey:NSStringFromSelector(@selector(shadowRadius))];
    [coder encodeObject:@(self.highlightedShadowRadius) forKey:NSStringFromSelector(@selector(highlightedShadowRadius))];
    [coder encodeCGSize:self.highlightedShadowOffset forKey:NSStringFromSelector(@selector(highlightedShadowOffset))];
    [coder encodeObject:self.highlightedShadowColor forKey:NSStringFromSelector(@selector(highlightedShadowColor))];
    [coder encodeObject:@(self.kern) forKey:NSStringFromSelector(@selector(kern))];
//    [coder encodeObject:@(self.firstLineIndent) forKey:NSStringFromSelector(@selector(firstLineIndent))];
//    [coder encodeObject:@(self.lineSpacing) forKey:NSStringFromSelector(@selector(lineSpacing))];
//    [coder encodeUIEdgeInsets:self.textInsets forKey:NSStringFromSelector(@selector(textInsets))];
//    [coder encodeInteger:self.verticalAlignment forKey:NSStringFromSelector(@selector(verticalAlignment))];
//
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Wdeprecated-declarations"
//    [coder encodeObject:self.truncationTokenString forKey:NSStringFromSelector(@selector(truncationTokenString))];
//#pragma clang diagnostic pop

    [coder encodeObject:self.attributedText forKey:NSStringFromSelector(@selector(attributedText))];
    [coder encodeObject:self.text forKey:NSStringFromSelector(@selector(text))];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (!self) {
        return nil;
    }

    [self commonInit];

    if ([coder containsValueForKey:NSStringFromSelector(@selector(enabledTextCheckingTypes))]) {
        self.enabledTextCheckingTypes = [[coder decodeObjectForKey:NSStringFromSelector(@selector(enabledTextCheckingTypes))] unsignedLongLongValue];
    }

    if ([NSMutableParagraphStyle class]) {
        if ([coder containsValueForKey:NSStringFromSelector(@selector(linkAttributes))]) {
            self.linkAttributes = [coder decodeObjectForKey:NSStringFromSelector(@selector(linkAttributes))];
        }

        if ([coder containsValueForKey:NSStringFromSelector(@selector(activeLinkAttributes))]) {
            self.activeLinkAttributes = [coder decodeObjectForKey:NSStringFromSelector(@selector(activeLinkAttributes))];
        }

        if ([coder containsValueForKey:NSStringFromSelector(@selector(inactiveLinkAttributes))]) {
            self.inactiveLinkAttributes = [coder decodeObjectForKey:NSStringFromSelector(@selector(inactiveLinkAttributes))];
        }
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(links))]) {
        NSArray *oldLinks = [coder decodeObjectForKey:NSStringFromSelector(@selector(links))];
        [self addLinksWithTextCheckingResults:oldLinks attributes:nil];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(linkModels))]) {
        self.linkModels = [coder decodeObjectForKey:NSStringFromSelector(@selector(linkModels))];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(shadowRadius))]) {
        self.shadowRadius = [[coder decodeObjectForKey:NSStringFromSelector(@selector(shadowRadius))] floatValue];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(highlightedShadowRadius))]) {
        self.highlightedShadowRadius = [[coder decodeObjectForKey:NSStringFromSelector(@selector(highlightedShadowRadius))] floatValue];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(highlightedShadowOffset))]) {
        self.highlightedShadowOffset = [coder decodeCGSizeForKey:NSStringFromSelector(@selector(highlightedShadowOffset))];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(highlightedShadowColor))]) {
        self.highlightedShadowColor = [coder decodeObjectForKey:NSStringFromSelector(@selector(highlightedShadowColor))];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(kern))]) {
        self.kern = [[coder decodeObjectForKey:NSStringFromSelector(@selector(kern))] floatValue];
    }

//    if ([coder containsValueForKey:NSStringFromSelector(@selector(firstLineIndent))]) {
//        self.firstLineIndent = [[coder decodeObjectForKey:NSStringFromSelector(@selector(firstLineIndent))] floatValue];
//    }
//
//    if ([coder containsValueForKey:NSStringFromSelector(@selector(lineSpacing))]) {
//        self.lineSpacing = [[coder decodeObjectForKey:NSStringFromSelector(@selector(lineSpacing))] floatValue];
//    }
//
//    if ([coder containsValueForKey:NSStringFromSelector(@selector(minimumLineHeight))]) {
//        self.minimumLineHeight = [[coder decodeObjectForKey:NSStringFromSelector(@selector(minimumLineHeight))] floatValue];
//    }
//
//    if ([coder containsValueForKey:NSStringFromSelector(@selector(maximumLineHeight))]) {
//        self.maximumLineHeight = [[coder decodeObjectForKey:NSStringFromSelector(@selector(maximumLineHeight))] floatValue];
//    }
//
//    if ([coder containsValueForKey:NSStringFromSelector(@selector(textInsets))]) {
//        self.textInsets = [coder decodeUIEdgeInsetsForKey:NSStringFromSelector(@selector(textInsets))];
//    }
//
//    if ([coder containsValueForKey:NSStringFromSelector(@selector(verticalAlignment))]) {
//        self.verticalAlignment = [coder decodeIntegerForKey:NSStringFromSelector(@selector(verticalAlignment))];
//    }
//
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Wdeprecated-declarations"
//    if ([coder containsValueForKey:NSStringFromSelector(@selector(truncationTokenString))]) {
//        self.truncationTokenString = [coder decodeObjectForKey:NSStringFromSelector(@selector(truncationTokenString))];
//    }

#pragma clang diagnostic pop

    if ([coder containsValueForKey:NSStringFromSelector(@selector(attributedText))]) {
        self.attributedText = [coder decodeObjectForKey:NSStringFromSelector(@selector(attributedText))];
    } else {
        self.text = super.text;
    }
    
    return self;
}

@end

#pragma mark - TTTAttributedLabelLink

@implementation TTTAttributedLabelLink

- (instancetype)initWithAttributes:(NSDictionary *)attributes
                  activeAttributes:(NSDictionary *)activeAttributes
                inactiveAttributes:(NSDictionary *)inactiveAttributes
                textCheckingResult:(NSTextCheckingResult *)result {
    
    if ((self = [super init])) {
        _result = result;
        _attributes = [attributes copy];
        _activeAttributes = [activeAttributes copy];
        _inactiveAttributes = [inactiveAttributes copy];
    }
    
    return self;
}

- (instancetype)initWithAttributesFromLabel:(TTTAttributedLabel*)label
                         textCheckingResult:(NSTextCheckingResult *)result {
    
    return [self initWithAttributes:label.linkAttributes
                   activeAttributes:label.activeLinkAttributes
                 inactiveAttributes:label.inactiveLinkAttributes
                 textCheckingResult:result];
}

#pragma mark - Accessibility

- (NSString *) accessibilityValue {
    if ([_accessibilityValue length] == 0) {
        switch (self.result.resultType) {
            case NSTextCheckingTypeLink:
                _accessibilityValue = self.result.URL.absoluteString;
                break;
            case NSTextCheckingTypePhoneNumber:
                _accessibilityValue = self.result.phoneNumber;
                break;
            case NSTextCheckingTypeDate:
                _accessibilityValue = [NSDateFormatter localizedStringFromDate:self.result.date
                                                                     dateStyle:NSDateFormatterLongStyle
                                                                     timeStyle:NSDateFormatterLongStyle];
                break;
            default:
                break;
        }
    }
    
    return _accessibilityValue;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.result forKey:NSStringFromSelector(@selector(result))];
    [aCoder encodeObject:self.attributes forKey:NSStringFromSelector(@selector(attributes))];
    [aCoder encodeObject:self.activeAttributes forKey:NSStringFromSelector(@selector(activeAttributes))];
    [aCoder encodeObject:self.inactiveAttributes forKey:NSStringFromSelector(@selector(inactiveAttributes))];
    [aCoder encodeObject:self.accessibilityValue forKey:NSStringFromSelector(@selector(accessibilityValue))];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super init])) {
        _result = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(result))];
        _attributes = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(attributes))];
        _activeAttributes = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(activeAttributes))];
        _inactiveAttributes = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(inactiveAttributes))];
        self.accessibilityValue = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(accessibilityValue))];
    }
    
    return self;
}

@end
