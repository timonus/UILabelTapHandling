//
//  UILabel+TJTapHandling.m
//
//  Created by Tim Johnsen on 4/18/23.
//  Copyright © 2023 tijo. All rights reserved.
//

#import "UILabel+TJTapHandling.h"

#import <objc/runtime.h>

static const CGFloat kTJTapHandlingDefaultTolerance = 10.0;

// Courtesy of https://christianselig.com/2023/05/instant-pan-gesture-interactions/
static @interface TJTouchesBeganGestureRecognizer : UIGestureRecognizer

@end

__attribute__((objc_direct_members))
@implementation TJTouchesBeganGestureRecognizer

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer
{
    return NO;
}

- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer
{
    return NO;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    self.state = UIGestureRecognizerStateBegan;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    self.state = UIGestureRecognizerStateEnded;
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    self.state = UIGestureRecognizerStateCancelled;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    self.state = UIGestureRecognizerStateEnded;
}

@end

@implementation UILabel (TJTapHandling)

static char *const kURLHandlersKey = "_tj_urlHandlers";

- (void)addURLHandler:(id<TJLabelURLHandler>)handler
{
    NSHashTable *urlHandlers = objc_getAssociatedObject(self, kURLHandlersKey);
    if (!urlHandlers) {
        urlHandlers = [NSHashTable weakObjectsHashTable];
        
        objc_setAssociatedObject(self, kURLHandlersKey, urlHandlers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        self.userInteractionEnabled = YES; // Labels default to userInteractionEnabled = NO
        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_didTap:)]];
        [self addGestureRecognizer:[[TJTouchesBeganGestureRecognizer alloc] initWithTarget:self action:@selector(_touchesChanged:)]];
        
#if 0
        // Useful for debugging tappable regions.
        // Does NOT include hit outsets.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            for (int x = 0; x < self.bounds.size.width; x++) {
                for (int y = 0; y < self.bounds.size.height; y++) {
                    CGPoint p = CGPointMake(x, y);
                    NSInteger index = [self indexOfTappedCharacterAtPoint:p];
                    UIView *v = [[UIView alloc] initWithFrame:(CGRect){p, CGSizeMake(1, 1)}];
                    [self addSubview:v];
                    if (index != NSNotFound && [self.attributedText attribute:NSLinkAttributeName atIndex:index effectiveRange:nil]) {
                        v.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.5];
                    } else {
                        v.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.5];
                    }
                }
            }
        });
#endif
    }
    [urlHandlers addObject:handler];
}

- (void)_didTap:(UITapGestureRecognizer *)recognizer
{
    [self _linkAtPoint:[recognizer locationInView:self] tolerance:kTJTapHandlingDefaultTolerance handler:^(NSURL *url, NSRange range) {
        for (id<TJLabelURLHandler> handler in objc_getAssociatedObject(self, kURLHandlersKey)) {
            [handler label:self didTapURL:url inRange:range];
        }
    }];
}

- (void)_touchesChanged:(UIGestureRecognizer *)recognizer
{
    NSMutableAttributedString *string = [self.attributedText mutableCopy];
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [self _linkAtPoint:[recognizer locationInView:self] tolerance:kTJTapHandlingDefaultTolerance handler:^(NSURL *url, NSRange range) {
            [string addAttribute:NSBackgroundColorAttributeName value:[UIColor secondarySystemFillColor] range:range];
        }];
    } else {
        [string removeAttribute:NSBackgroundColorAttributeName range:NSMakeRange(0, string.length)];
    }
    self.attributedText = string;
}

- (void)_linkAtPoint:(const CGPoint)point tolerance:(CGFloat)tolerance handler:(NS_NOESCAPE void (^)(NSURL *url, NSRange range))handler
{
    NSArray *const tolerances = tolerance > 0 ? @[@0, @(-tolerance),  @(tolerance)] : @[@0];
    for (NSNumber *xOffset in tolerances) {
        for (NSNumber *yOffset in tolerances) {
            const CGPoint adjustedPoint = CGPointMake(point.x + xOffset.doubleValue, point.y + yOffset.doubleValue);
            const NSInteger index = [self indexOfTappedCharacterAtPoint:adjustedPoint];
            if (index != NSNotFound) {
                NSRange range;
                NSURL *const url = [self.attributedText attribute:NSLinkAttributeName atIndex:index effectiveRange:&range];
                if (url) {
                    handler(url, range);
                    return;
                }
            }
        }
    }
}

static char *const kTextStorageKey = "_tj_textStorage";

- (NSInteger)indexOfTappedCharacterAtPoint:(CGPoint)point
{
    // Basically equivalent to https://stackoverflow.com/a/46940367 with caching.
    NSAttributedString *const attributedText = self.attributedText;
    
    NSTextStorage *textStorage = objc_getAssociatedObject(attributedText, kTextStorageKey);
    
    NSLayoutManager *layoutManager;
    NSTextContainer *textContainer;
    
    if ([textStorage isEqual:attributedText]) {
        layoutManager = textStorage.layoutManagers.firstObject;
        textContainer = layoutManager.textContainers.firstObject;
        textContainer.size = self.bounds.size;
    } else {
        textStorage = [[NSTextStorage alloc] initWithAttributedString:attributedText];
        NSAssert([textStorage isEqual:attributedText], @"%s caching failing", __PRETTY_FUNCTION__);
        objc_setAssociatedObject(attributedText, kTextStorageKey, textStorage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        layoutManager = [NSLayoutManager new];
        layoutManager.usesFontLeading = NO;
        textContainer = [[NSTextContainer alloc] initWithSize:self.bounds.size];
        textContainer.lineFragmentPadding = 0.0;
        [layoutManager addTextContainer:textContainer];
        [textStorage addLayoutManager:layoutManager];
    }
    
    textContainer.lineBreakMode = self.lineBreakMode;
    textContainer.maximumNumberOfLines = self.numberOfLines;
    
    const CGRect textBoundingBox = [layoutManager usedRectForTextContainer:textContainer];
    
    const CGPoint textContainerOffset = CGPointMake((self.bounds.size.width - textBoundingBox.size.width) * 0.5 - textBoundingBox.origin.x, (self.bounds.size.height - textBoundingBox.size.height) * 0.5 - textBoundingBox.origin.y);
    const CGPoint locationOfTouchInTextContainer = CGPointMake(point.x - textContainerOffset.x, point.y - textContainerOffset.y);
    CGFloat frac;
    NSInteger index = [layoutManager characterIndexForPoint:locationOfTouchInTextContainer inTextContainer:textContainer fractionOfDistanceBetweenInsertionPoints:&frac];
    
    if (frac == 1.0) {
        return NSNotFound;
    }
    
    return index;
}

@end
