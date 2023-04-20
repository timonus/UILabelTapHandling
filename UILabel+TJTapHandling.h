//
//  UILabel+TJTapHandling.h
//
//  Created by Tim Johnsen on 4/18/23.
//  Copyright © 2023 tijo. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TJLabelURLHandler <NSObject>

- (void)label:(UILabel *)label didTapURL:(NSURL *)url inRange:(NSRange)range;

@end

@interface UILabel (TJTapHandling)

- (void)addURLHandler:(id<TJLabelURLHandler>)handler;

- (NSInteger)indexOfTappedCharacterAtPoint:(CGPoint)point;

@end

NS_ASSUME_NONNULL_END
