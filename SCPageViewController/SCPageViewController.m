//
//  SCPageViewController.m
//  SCPageViewController
//
//  Created by Stefan Ceriu on 15/02/2014.
//  Copyright (c) 2014 Stefan Ceriu. All rights reserved.
//

#import "SCPageViewController.h"
#import "SCPageViewControllerScrollView.h"
#import "SCPageLayouterProtocol.h"

#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

@interface SCPageViewController () <UIScrollViewDelegate>

@property (nonatomic, strong) SCPageViewControllerScrollView *scrollView;

@property (nonatomic, assign) NSUInteger currentPage;
@property (nonatomic, assign) NSUInteger numberOfPages;

@property (nonatomic, strong) NSMutableOrderedSet *loadedControllers;
@property (nonatomic, strong) NSMutableArray *visibleControllers;

@property (nonatomic, strong) NSMutableDictionary *pageIndexes;
@property (nonatomic, strong) NSMutableDictionary *visiblePercentages;

@property (nonatomic, assign) BOOL isRotating;

@end

@implementation SCPageViewController
@dynamic bounces;
@dynamic touchRefusalArea;
@dynamic showsScrollIndicators;
@dynamic minimumNumberOfTouches;
@dynamic maximumNumberOfTouches;
@dynamic scrollEnabled;

- (id)init
{
    if(self = [super init]) {
        
        self.loadedControllers = [NSMutableOrderedSet orderedSet];
        self.visibleControllers = [NSMutableArray array];
        self.pageIndexes = [NSMutableDictionary dictionary];
        self.visiblePercentages = [NSMutableDictionary dictionary];
        
        self.numberOfPagesPreloadedBeforeCurrentPage = 1;
        self.numberOfPagesPreloadedAfterCurrentPage = 1;
        self.pagingEnabled = YES;
        
        self.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        self.animationDuration = 0.25f;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.view setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    
    self.scrollView = [[SCPageViewControllerScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
    self.scrollView.delegate = self;
    
    [self.view addSubview:self.scrollView];
    
    [self reloadData];
}

- (void)viewWillLayoutSubviews
{
    [self tilePages];
    [self updateFramesAndTriggerAppearanceCallbacks];
    [self updateContentSize];
}

#pragma mark - Public Methods

- (void)reloadData
{
    for(UIViewController *controller in self.loadedControllers) {
        [controller willMoveToParentViewController:nil];
        [controller.view removeFromSuperview];
        [controller removeFromParentViewController];
    }
    
    self.numberOfPages = [self.dataSource numberOfPagesInPageViewController:self];
    
    [self tilePages];
    [self updateFramesAndTriggerAppearanceCallbacks];
    [self updateContentSize];
}

- (void)navigateToPageAtIndex:(NSUInteger)pageIndex
                     animated:(BOOL)animated
                   completion:(void(^)())completion
{
    CGRect finalFrame = [self.layouter finalFrameForPageAtIndex:pageIndex inPageViewController:self];
    
    if(self.layouter.navigationType == SCPageLayouterNavigationTypeVertical) {
        [self.scrollView setContentOffset:CGPointMake(0, CGRectGetMinY(finalFrame)) withTimingFunction:self.timingFunction duration:self.animationDuration completion:completion];
    } else {
        [self.scrollView setContentOffset:CGPointMake(CGRectGetMinX(finalFrame), 0) withTimingFunction:self.timingFunction duration:self.animationDuration completion:completion];
    }
}

- (NSArray *)visibleViewControllers
{
    return [self.visibleControllers copy];
}

- (CGFloat)visiblePercentageForViewController:(UIViewController *)viewController
{
    if(![self.visibleControllers containsObject:viewController]) {
        return 0.0f;
    }
    
    return [self.visiblePercentages[@([viewController hash])] floatValue];
}

#pragma mark - Page Management

- (void)updateContentSize
{
    if(self.isRotating) {
        [self.scrollView setContentSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
        return;
    }
    
    CGRect frame = [self.layouter finalFrameForPageAtIndex:self.numberOfPages - 1 inPageViewController:self];
    
    if(self.layouter.navigationType == SCPageLayouterNavigationTypeVertical) {
        [self.scrollView setContentSize:CGSizeMake(0, CGRectGetMaxY(frame))];
    } else {
        [self.scrollView setContentSize:CGSizeMake(CGRectGetMaxX(frame), 0)];
    }
}

- (void)tilePages
{
    self.currentPage = [self calculateCurrentPage];
    
    NSInteger firstNeededPageIndex = self.currentPage - self.numberOfPagesPreloadedBeforeCurrentPage;
    firstNeededPageIndex = MAX(firstNeededPageIndex, 0);
    
    
    NSInteger lastNeededPageIndex  = self.currentPage + self.numberOfPagesPreloadedAfterCurrentPage;
    lastNeededPageIndex  = MIN(lastNeededPageIndex, ((int)self.numberOfPages - 1));
    
    NSMutableSet *removedPages = [NSMutableSet set];
    
    for (UIViewController *page in self.loadedControllers) {
        NSUInteger pageIndex = [self.pageIndexes[@(page.hash)] unsignedIntegerValue];
        
        if (pageIndex < firstNeededPageIndex || pageIndex > lastNeededPageIndex) {
            [removedPages addObject:page];
            [self.pageIndexes removeObjectForKey:@(page.hash)];
            
            [page willMoveToParentViewController:nil];
            [page.view removeFromSuperview];
            [page removeFromParentViewController];
        }
    }
    [self.loadedControllers minusSet:removedPages];
    
    for (int index = firstNeededPageIndex; index <= lastNeededPageIndex; index++) {
        
        if (![self isDisplayingPageForIndex:index]) {
            UIViewController *page = [self.dataSource pageViewController:self viewControllerForPageAtIndex:index];;
            
            [self.loadedControllers addObject:page];
            [self.pageIndexes setObject:@(index) forKey:@(page.hash)];
            
            [page willMoveToParentViewController:self];
            [self addChildViewController:page];
            
            if(index > self.currentPage) {
                [self.scrollView insertSubview:page.view atIndex:0];
            } else {
                [self.scrollView addSubview:page.view];
            }
        }
    }
}

- (NSUInteger)calculateCurrentPage
{
	int page;
    if(self.layouter.navigationType == SCPageLayouterNavigationTypeVertical) {
        page = self.scrollView.contentOffset.y / CGRectGetHeight(self.view.bounds) + 0.5f;
    } else {
        page = self.scrollView.contentOffset.x / CGRectGetWidth(self.view.bounds) + 0.5f;
    }
    
	page = MIN(page, self.numberOfPages - 1);
	page = MAX(page, 0);
    
    return page;
}

- (BOOL)isDisplayingPageForIndex:(NSUInteger)index
{
    BOOL foundPage = NO;
    for (UIViewController *page in self.loadedControllers) {
        
        NSUInteger pageIndex = [self.pageIndexes[@(page.hash)] unsignedIntegerValue];
        if (pageIndex == index) {
            foundPage = YES;
            break;
        }
    }
    return foundPage;
}

#pragma mark Appearance callbacks and framesetting

- (void)updateFramesAndTriggerAppearanceCallbacks
{
    __block CGRect remainder = self.scrollView.bounds;
    
    NSArray *sortedPages = [self.loadedControllers sortedArrayUsingComparator:^NSComparisonResult(UIViewController *obj1, UIViewController *obj2) {
        NSUInteger firstPageIndex = [self.pageIndexes[@(obj1.hash)] unsignedIntegerValue];
        NSUInteger secondPageIndex = [self.pageIndexes[@(obj2.hash)] unsignedIntegerValue];
        
        return [@(firstPageIndex) compare:@(secondPageIndex)];
    }];
    
    [sortedPages enumerateObjectsUsingBlock:^(UIViewController *viewController, NSUInteger idx, BOOL *stop) {
        
        NSUInteger pageIndex = [self.pageIndexes[@(viewController.hash)] unsignedIntegerValue];
        
        CGRect nextFrame =  [self.layouter currentFrameForViewController:viewController
                                                               withIndex:pageIndex
                                                           contentOffset:self.scrollView.contentOffset
                                                              finalFrame:[self.layouter finalFrameForPageAtIndex:pageIndex inPageViewController:self]
                                                    inPageViewController:self];
        
        CGRect intersection = CGRectIntersection(remainder, nextFrame);
        // If a view controller's frame does intersect the remainder then it's visible
        BOOL visible = self.layouter.navigationType == SCPageLayouterNavigationTypeVertical ? (CGRectGetHeight(intersection) > 0.0f) : (CGRectGetWidth(intersection) > 0.0f);
        
        if(visible) {
            if(self.layouter.navigationType == SCPageLayouterNavigationTypeVertical) {
                [self.visiblePercentages setObject:@(roundf((CGRectGetHeight(intersection) * 1000) / CGRectGetHeight(nextFrame))/1000.0f) forKey:@([viewController hash])];
            } else {
                [self.visiblePercentages setObject:@(roundf((CGRectGetWidth(intersection) * 1000) / CGRectGetWidth(nextFrame))/1000.0f) forKey:@([viewController hash])];
            }
        }
        
        remainder = [self subtractRect:intersection fromRect:remainder withEdge:[self edgeFromOffset:self.scrollView.contentOffset]];
        
        // Finally, trigger appearance callbacks and new frame
        if(visible && ![self.visibleControllers containsObject:viewController]) {
            [self.visibleControllers addObject:viewController];
            [viewController beginAppearanceTransition:YES animated:NO];
            [viewController.view setFrame:nextFrame];
            [viewController endAppearanceTransition];
            
            if([self.delegate respondsToSelector:@selector(pageViewController:didShowViewController:atIndex:)]) {
                [self.delegate pageViewController:self didShowViewController:viewController atIndex:pageIndex];
            }
            
        } else if(!visible && [self.visibleControllers containsObject:viewController]) {
            [self.visibleControllers removeObject:viewController];
            [viewController beginAppearanceTransition:NO animated:NO];
            [viewController.view setFrame:nextFrame];
            [viewController endAppearanceTransition];
            
            if([self.delegate respondsToSelector:@selector(pageViewController:didHideViewController:atIndex:)]) {
                [self.delegate pageViewController:self didHideViewController:viewController atIndex:pageIndex];
            }
            
        } else {
            [viewController.view setFrame:nextFrame];
        }
    }];
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods
{
    return NO;
}

#pragma mark Pagination

- (void)adjustTargetContentOffset:(inout CGPoint *)targetContentOffset withVelocity:(CGPoint)velocity
{
    if(!self.pagingEnabled && self.continuousNavigationEnabled) {
        return;
    }
    
    // Enumerate through all the pages and figure out which one contains the targeted offset
    for(NSUInteger pageIndex = 0; pageIndex < self.numberOfPages; pageIndex ++) {
        
        CGRect frame = [self.layouter finalFrameForPageAtIndex:pageIndex inPageViewController:self];
        
        CGRect frameWithPadding = CGRectOffset(CGRectInset(frame, -self.layouter.interItemSpacing/2, 0), self.layouter.interItemSpacing/2, 0);
        
        if(CGRectContainsPoint(frameWithPadding, *targetContentOffset)) {
            
            // If the velocity is zero then jump to the closest navigation step
            if(CGPointEqualToPoint(CGPointZero, velocity)) {
                
                switch (self.layouter.navigationType) {
                    case SCPageLayouterNavigationTypeVertical:
                    {
                        CGPoint previousStepOffset = [self nextStepOffsetForFrame:frame velocity:CGPointMake(0.0f, -1.0f) contentOffset:*targetContentOffset paginating:YES];
                        CGPoint nextStepOffset = [self nextStepOffsetForFrame:frame velocity:CGPointMake(0.0f, 1.0f) contentOffset:*targetContentOffset paginating:YES];
                        
                        *targetContentOffset = ABS(targetContentOffset->y - previousStepOffset.y) > ABS(targetContentOffset->y - nextStepOffset.y) ? nextStepOffset : previousStepOffset;
                        break;
                    }
                    case SCPageLayouterNavigationTypeHorizontal:
                    {
                        CGPoint previousStepOffset = [self nextStepOffsetForFrame:frame velocity:CGPointMake(-1.0f, 0.0f) contentOffset:*targetContentOffset paginating:YES];
                        CGPoint nextStepOffset = [self nextStepOffsetForFrame:frame velocity:CGPointMake(1.0f, 0.0f) contentOffset:*targetContentOffset paginating:YES];
                        
                        *targetContentOffset = ABS(targetContentOffset->x - previousStepOffset.x) > ABS(targetContentOffset->x - nextStepOffset.x) ? nextStepOffset : previousStepOffset;
                        break;
                    }
                }
                
            } else {
                // Calculate the next step of the pagination (either a navigationStep or a controller edge)
                *targetContentOffset = [self nextStepOffsetForFrame:frame velocity:velocity contentOffset:*targetContentOffset paginating:YES];
            }
            
            // Pagination fix for iOS 5.x
            if(SYSTEM_VERSION_LESS_THAN(@"6.0")) {
                targetContentOffset->y += 0.1f;
                targetContentOffset->x += 0.1f;
            }
            
            break;
        }
    }
}

- (CGPoint)nextStepOffsetForFrame:(CGRect)finalFrame
                         velocity:(CGPoint)velocity
                    contentOffset:(CGPoint)contentOffset
                       paginating:(BOOL)paginating

{
    CGPoint nextStepOffset = CGPointZero;
    
    if(velocity.y > 0.0f) {
        nextStepOffset.y = CGRectGetMaxY(finalFrame) + [self.layouter interItemSpacing];
    } else if(velocity.x > 0.0f) {
        nextStepOffset.x = CGRectGetMaxX(finalFrame) + [self.layouter interItemSpacing];
    }
    
    else if(velocity.y < 0.0f) {
        nextStepOffset.y = CGRectGetMinY(finalFrame);
    }
    else if(velocity.x < 0.0f) {
        nextStepOffset.x = CGRectGetMinX(finalFrame);
    }
    
    return nextStepOffset;
}

#pragma mark - Properties and forwarding

- (BOOL)showsScrollIndicators
{
    return [self.scrollView showsHorizontalScrollIndicator] && [self.scrollView showsVerticalScrollIndicator];
}

- (void)setShowsScrollIndicators:(BOOL)showsScrollIndicators
{
    [self.scrollView setShowsHorizontalScrollIndicator:showsScrollIndicators];
    [self.scrollView setShowsVerticalScrollIndicator:showsScrollIndicators];
}

// Forward touchRefusalArea, bounces, scrollEnabled, minimum and maximum numberOfTouches
- (id)forwardingTargetForSelector:(SEL)aSelector
{
    if([self.scrollView respondsToSelector:aSelector]) {
        return self.scrollView;
    } else if([self.scrollView.panGestureRecognizer respondsToSelector:aSelector]) {
        return self.scrollView.panGestureRecognizer;
    }
    
    return self;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self tilePages];
    [self updateFramesAndTriggerAppearanceCallbacks];
    
    if([self.delegate respondsToSelector:@selector(pageViewController:didNavigateToOffset:)]) {
        [self.delegate pageViewController:self didNavigateToOffset:self.scrollView.contentOffset];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if([self.delegate respondsToSelector:@selector(pageViewController:didNavigateToPageAtIndex:)]) {
        [self.delegate pageViewController:self didNavigateToPageAtIndex:self.currentPage];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if(decelerate == NO) {
        if([self.delegate respondsToSelector:@selector(pageViewController:didNavigateToPageAtIndex:)]) {
            [self.delegate pageViewController:self didNavigateToPageAtIndex:self.currentPage];
        }
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    if([self.delegate respondsToSelector:@selector(pageViewController:didNavigateToPageAtIndex:)]) {
        [self.delegate pageViewController:self didNavigateToPageAtIndex:self.currentPage];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    // Bouncing target content offset when fix.
    // When trying to adjust content offset while bouncing the velocity drops down to almost nothing.
    // Seems to be an internal UIScrollView issue
    if(self.scrollView.contentOffset.y < 0.0f) {
        targetContentOffset->y = 0.0f;
    } else if(self.scrollView.contentOffset.x < 0.0f) {
        targetContentOffset->x = 0.0f;
    } else if(self.scrollView.contentOffset.y > ABS(self.scrollView.contentSize.height - CGRectGetHeight(self.scrollView.bounds))) {
        targetContentOffset->y = self.scrollView.contentSize.height - CGRectGetHeight(self.scrollView.bounds);
    } else if(self.scrollView.contentOffset.x > ABS(self.scrollView.contentSize.width - CGRectGetWidth(self.scrollView.bounds))) {
        targetContentOffset->x = self.scrollView.contentSize.width - CGRectGetWidth(self.scrollView.bounds);
    }
    // Normal pagination
    else {
        [self adjustTargetContentOffset:targetContentOffset withVelocity:velocity];
    }
}

#pragma mark - Rotation

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    self.isRotating = YES;
    [self updateContentSize];
    [self.scrollView addObserver:self forKeyPath:@"contentSize" options:0 context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if(self.isRotating) {
        
        CGRect finalFrame = [self.layouter finalFrameForPageAtIndex:self.currentPage inPageViewController:self];
        
        if(self.layouter.navigationType == SCPageLayouterNavigationTypeVertical) {
            [self.scrollView setContentOffset:CGPointMake(0, CGRectGetMinY(finalFrame))];
        } else {
            [self.scrollView setContentOffset:CGPointMake(CGRectGetMinX(finalFrame), 0)];
        }
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.scrollView removeObserver:self forKeyPath:@"contentSize"];
    self.isRotating = NO;
    [self updateContentSize];
}

#pragma mark - Helpers

- (CGRect)subtractRect:(CGRect)r2 fromRect:(CGRect)r1 withEdge:(CGRectEdge)edge
{
    CGRect intersection = CGRectIntersection(r1, r2);
    if (CGRectIsNull(intersection)) {
        return r1;
    }
    
    float chopAmount = (edge == CGRectMinXEdge || edge == CGRectMaxXEdge) ? CGRectGetWidth(intersection) : CGRectGetHeight(intersection);
    
    CGRect remainder, throwaway;
    CGRectDivide(r1, &throwaway, &remainder, chopAmount, edge);
    return remainder;
}

- (CGRectEdge)edgeFromOffset:(CGPoint)offset
{
    CGRectEdge edge = -1;
    
    if(self.layouter.navigationType == SCPageLayouterNavigationTypeHorizontal) {
        if(offset.x >= 0.0f) {
            edge = CGRectMinXEdge;
        } else if(offset.x < 0.0f) {
            edge = CGRectMaxXEdge;
        }
    }
    
    if(self.layouter.navigationType == SCPageLayouterNavigationTypeVertical) {
        if(offset.y >= 0.0f) {
            edge = CGRectMinYEdge;
        } else if(offset.y < 0.0f) {
            edge = CGRectMaxYEdge;
        }
    }
    
    return edge;
}

@end