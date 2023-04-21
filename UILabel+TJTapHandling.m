//
//  UILabel+TJTapHandling.m
//
//  Created by Tim Johnsen on 4/18/23.
//  Copyright © 2023 tijo. All rights reserved.
//

#import "UILabel+TJTapHandling.h"

#import <objc/runtime.h>

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
    }
    [urlHandlers addObject:handler];
}

- (void)_didTap:(UITapGestureRecognizer *)recognizer
{
    const NSInteger index = [self indexOfTappedCharacterAtPoint:[recognizer locationInView:self]];
    if (index != NSNotFound) {
        NSRange range;
        NSURL *const url = [self.attributedText attribute:NSLinkAttributeName atIndex:index effectiveRange:&range];
        if (url) {
            for (id<TJLabelURLHandler> handler in objc_getAssociatedObject(self, kURLHandlersKey)) {
                [handler label:self didTapURL:url inRange:range];
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
