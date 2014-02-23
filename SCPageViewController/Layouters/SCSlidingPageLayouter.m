//
//  SCSlidingPageLayouter.m
//  SCPageViewController
//
//  Created by Stefan Ceriu on 15/02/2014.
//  Copyright (c) 2014 Stefan Ceriu. All rights reserved.
//

#import "SCSlidingPageLayouter.h"

@implementation SCSlidingPageLayouter

- (CGRect)currentFrameForViewController:(UIViewController *)viewController
                              withIndex:(NSUInteger)index
                          contentOffset:(CGPoint)contentOffset
                             finalFrame:(CGRect)finalFrame
                   inPageViewController:(SCPageViewController *)pageViewController
{
    if(index == 0) {
        return finalFrame;
    }
    
    if(self.navigationType == SCPageLayouterNavigationTypeVertical) {
        finalFrame.origin.y = MAX(finalFrame.origin.y - finalFrame.size.height, MIN(CGRectGetMaxY(finalFrame) - CGRectGetHeight(finalFrame), CGRectGetHeight(pageViewController.view.bounds) - CGRectGetHeight(finalFrame) + contentOffset.y));
    } else {
        finalFrame.origin.x = MAX(finalFrame.origin.x - finalFrame.size.width, MIN(CGRectGetMaxX(finalFrame) - CGRectGetWidth(finalFrame), CGRectGetWidth(pageViewController.view.bounds) - CGRectGetWidth(finalFrame) + contentOffset.x));
    }
    
    return finalFrame;
}

@end