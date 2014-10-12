//
//  VSTHorizontalPickerView.m
//  Vegard Solheim Theriault
//
//  Created by Vegard Solheim Theriault on 06/04/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import "VSTHorizontalPickerView.h"


#define DISTANCE_BETWEEN_LABELS 20
#define DARKEST_TEXT_COLOR      0.0
#define LIGHTEST_TEXT_COLOR     255.0
#define CENTER_FONT             @"HelveticaNeue"
#define SIDE_FONT               @"HelveticaNeue-Light"
#define FONT_SIZE               25


@interface VSTHorizontalPickerView () <UIScrollViewDelegate>
@property (strong, nonatomic) UIScrollView *scrollView;
@property (strong, nonatomic) NSMutableArray *itemLabels;
@property (nonatomic, readwrite) NSUInteger selectedItem;

// The rules of this is such that it is always YES except when someone passes
// NO to the informDelegate parameter of scrollToIndex:informDelegate:. It
// will be set back to YES as soon as the user interacts in some way (see
// scrollViewWillBeginDragging:).
@property (nonatomic) BOOL shouldInformDelegate;

@end

@implementation VSTHorizontalPickerView




//////////////////////////
#pragma mark - Initializer
//////////////////////////

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)awakeFromNib
{
    [self setupUI];
}

- (void)setupUI
{
    NSLog(@"Got frame: %@", NSStringFromCGRect(self.frame));
    CGRect frame = self.frame;
    frame.size.width = [UIScreen mainScreen].bounds.size.width;
    [self setFrame:frame];
    NSLog(@"New frame: %@", NSStringFromCGRect(self.frame));
    
    self.scrollView = [[UIScrollView alloc]initWithFrame:self.bounds];
    self.scrollView.delegate = self;
    [self.scrollView setShowsHorizontalScrollIndicator:NO];
    self.scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
    [self addSubview:self.scrollView];

    self.shouldInformDelegate = YES;
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self
                                                                                action:@selector(tapped:)];
    [self addGestureRecognizer:tapGesture];
}


//////////////////////
#pragma mark - Getters
//////////////////////

- (NSMutableArray *)itemLabels
{
    if (!_itemLabels) {
        _itemLabels = [[NSMutableArray alloc]init];
    }
    return _itemLabels;
}



//////////////////////
#pragma mark - Setters
//////////////////////

- (void)setItemTitles:(NSArray *)itemTitles
{
    // Sets the array of labels, and calls drawLabels.
    _itemTitles = itemTitles;
    [self.itemLabels removeAllObjects];
    
    for (NSString *title in itemTitles) {
        UILabel *tempLabel = [[UILabel alloc] init];
        tempLabel.text = title;
        tempLabel.font = [UIFont fontWithName:CENTER_FONT size:FONT_SIZE];//self.fontSize];
        [self.itemLabels addObject:tempLabel];
    }
    
    [self drawLabels];
}




/////////////////////////////
#pragma mark - Public Methods
/////////////////////////////

- (void)scrollToItemAtIndex:(NSUInteger)index informDelegate:(BOOL)informDelegate
{
    // For the last label, add half the label width. For the rest, add the label
    // width + the distance between the labels. Finally subtract half the
    // width of the scrollView. This will make the label at the selected
    // index be in the center of the scollView.
    if (index < [self.itemLabels count]) {
        self.shouldInformDelegate = informDelegate;
        
        CGFloat offsetX = 0.0;
        
        for (int i = 0; i <= index; i++) {
            if (i == index) {
                offsetX += ((UILabel *)self.itemLabels[i]).frame.size.width / 2.0;
            }
            else {
                offsetX += ((UILabel *)self.itemLabels[i]).frame.size.width;
                offsetX += DISTANCE_BETWEEN_LABELS;
            }
        }
        
        CGPoint offset = self.scrollView.contentOffset;
        offset.x = offsetX - (self.scrollView.frame.size.width / 2.0);
        
        NSLog(@"Screen width:   %.2f", [UIScreen mainScreen].bounds.size.width);
        NSLog(@"Scroller width: %.2f", self.scrollView.frame.size.width);
        
        [self.scrollView setContentOffset:offset animated:YES];
    }
}

- (BOOL)scrolling
{
    return self.scrollView.dragging ||
           self.scrollView.decelerating;
}



//////////////////////////////
#pragma mark - Private Methods
//////////////////////////////

- (NSInteger)indexOfSelectedItem
{
    // Note that we might still be scrolling, so this is not guaranteed
    // to be the one in the callback to the delegate.
    return [self indexOfLabelAtXPosition:[self currentCenter]];
}

- (NSInteger)indexOfLabelAtXPosition:(CGFloat)xPos
{
    // Adds a "detection field" around each of the labels. It then figures out which of the detection
    // fields has the xPos inside of it. The label inside that detection field is the one whos index
    // will be returned
    NSUInteger currentStartOfDetectionField = 0;
    NSInteger index = 0;
    BOOL found = NO;
    
    for (UILabel *label in self.itemLabels) {
        NSUInteger lengthOfDetectionField = label.frame.size.width + (DISTANCE_BETWEEN_LABELS / 2.0);
        
        if (xPos > currentStartOfDetectionField &&
            xPos <= currentStartOfDetectionField + lengthOfDetectionField)
        {
            found = YES;
            break;
        }
        else {
            index++;
            currentStartOfDetectionField += lengthOfDetectionField + (DISTANCE_BETWEEN_LABELS / 2.0);
        }
    }
    
    if (found == NO) {
        index = -1; // Return invalid value if the label was not found
    }
    return index;
}

- (CGFloat)currentCenter
{
    // Finds the current center based on the offset.
    return self.scrollView.contentOffset.x + (self.scrollView.frame.size.width / 2.0);
}

- (void)scrollerDidFinishScrolling
{
    // Get the selected label, and return its index to the delegate
    NSInteger index = [self indexOfSelectedItem];
    if (self.shouldInformDelegate) {
        [self.delegate horizontalPickerViewDidSelectItemAtIndex:index];
    }
    if (index >= 0) {
        self.selectedItem = index;
    }
}



//////////////////////
#pragma mark - Drawing
//////////////////////

- (void)drawLabels
{
    CGFloat totalWidth = 0.0;
    for (UILabel *label in self.itemLabels) {
        CGRect labelFrame = CGRectMake(totalWidth,
                                       (self.frame.size.height - label.intrinsicContentSize.height) / 2,
                                       label.intrinsicContentSize.width,
                                       label.intrinsicContentSize.height);
        [label setFrame:labelFrame];
        [self.scrollView addSubview:label];
        
        totalWidth += label.intrinsicContentSize.width;
        if (label != [self.itemLabels lastObject]) totalWidth += DISTANCE_BETWEEN_LABELS;
    }
    
    //Set the insets so that the first and last labels can be moved to the middle, but not further
    CGFloat leftInset  = 0.0;
    CGFloat rightInset = 0.0;
    if ([[self.itemLabels firstObject] isKindOfClass:[UILabel class]] &&
        [[self.itemLabels lastObject]  isKindOfClass:[UILabel class]]) {
        leftInset  = (self.frame.size.width / 2.0) - (((UILabel *)[self.itemLabels firstObject]).frame.size.width / 2.0);
        rightInset = (self.frame.size.width / 2.0) - (((UILabel *)[self.itemLabels lastObject ]).frame.size.width / 2.0);
    }
    [self.scrollView setContentInset:UIEdgeInsetsMake(0, leftInset, 0, rightInset)];
    
    [self.scrollView setContentSize:CGSizeMake(totalWidth, self.frame.size.height)];
}




///////////////////////////////////
#pragma mark - Scroll View Delegate
///////////////////////////////////

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    self.shouldInformDelegate = YES;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self scrollerDidFinishScrolling];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [self scrollerDidFinishScrolling];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate
{
    //If the user released the scroller when an item is dead in the center
    if (decelerate == NO) {
        [self scrollerDidFinishScrolling];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // If a label is the center one, its font will be set to CENTER_FONT, and its textColor will
    // be set to DARKEST_TEXT_COLOR. Otherwise its font will be set to SIDE_FONT. Its
    // textColor will interpolated based on the labels distance from the center, and the values
    // of DARKEST_TEXT_COLOR and LIGHTEST_TEXT_COLOR.
    for (int i = 0; i < [self.itemLabels count]; i++) {
        UILabel *currentLabel = self.itemLabels[i];
        
        if (i == [self indexOfSelectedItem]) {
            
            currentLabel.font = [UIFont fontWithName:CENTER_FONT size:FONT_SIZE];//self.fontSize];
            currentLabel.textColor = [UIColor colorWithWhite:DARKEST_TEXT_COLOR/255.0 alpha:1.0];
        }
        else {
            currentLabel.font = [UIFont fontWithName:SIDE_FONT size:FONT_SIZE];//self.fontSize];
            CGFloat distanceFromCenter = 0.0;
            CGFloat center = [self currentCenter];
            if (currentLabel.center.x < center) {
                // To the left
                // Gets the upper left corner
                distanceFromCenter = center - (currentLabel.frame.origin.x + currentLabel.frame.size.width);
            }
            else if (currentLabel.center.x > center) {
                // To the right
                // Gets the upper right corner
                distanceFromCenter = currentLabel.frame.origin.x - center;
            }
            else {
                NSLog(@"Should not happen");
            }
            
            CGFloat ratio = distanceFromCenter / (self.scrollView.frame.size.width / 2.0);
            CGFloat whiteValue = (LIGHTEST_TEXT_COLOR - DARKEST_TEXT_COLOR) * ratio;
            currentLabel.textColor = [UIColor colorWithWhite:whiteValue / 255.0 alpha:1.0];
        }
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView
                     withVelocity:(CGPoint)velocity
              targetContentOffset:(inout CGPoint *)targetContentOffset
{
    CGFloat initialTarget = targetContentOffset->x;
    
    // Figure out the which label has a center closest to the targetContentOffset. It then sets the
    // targetContentOffset, so that the scrollView moves to that label.
    CGFloat targetCenterX = targetContentOffset->x + (self.scrollView.frame.size.width / 2.0);
    CGFloat centerXForClosestLabel = 0.0;
    for (UILabel *label in self.itemLabels) {
        if (ABS(label.center.x - targetCenterX) < ABS(centerXForClosestLabel - targetCenterX)) {
            centerXForClosestLabel = label.center.x;
        }
    }
    
    targetContentOffset->x = centerXForClosestLabel - (self.scrollView.frame.size.width / 2.0);
    
    // There was a glitch when there was not enough velocity to get all the way to the next item.
    // It would sort of jump back to where it started. The jump happened due to a conflict between the
    // direction of the velocity and where the recalculated target is compared to where the current offset is.
    // This solution detects when that jump will happen, sets the targetContentOffset to the current
    // contentOffset, so it doesn's have an effect anymore, and scrolls smoothly back to where it was.
    CGFloat recalculatedTarget = targetContentOffset->x;
    CGFloat currentOffset = scrollView.contentOffset.x;
    CGFloat currentCenter = currentOffset + (self.scrollView.frame.size.width / 2.0);
    
    if (velocity.x > 0) {
        if (initialTarget > currentOffset && recalculatedTarget < currentOffset) {
            
            // Glitch while scrolling towards the right
            targetContentOffset->x = currentOffset; // Preventing the targetContentOffset to move the offset
            
            // Finding the label one step to the left
            NSUInteger indexOfPreviousLabel = 0;
            for (int i = 0; i < [self.itemLabels count]; i++) {
                UILabel *currentLabel = (UILabel *)self.itemLabels[i];
                if (currentLabel.center.x < currentCenter) {
                    indexOfPreviousLabel++;
                }
                else {
                    break;
                }
            }
            indexOfPreviousLabel--; // This technique gives us one index too high
            [self scrollToItemAtIndex:indexOfPreviousLabel informDelegate:YES];
        }
    }
    else if (velocity.x < 0) {
        if (initialTarget < currentOffset && recalculatedTarget > currentOffset) {
            
            // Glitch while scrolling towards the left
            targetContentOffset->x = currentOffset; // Preventing the targetContentOffset to move the offset
            
            // Finding the label one step to the right
            NSUInteger indexOfPreviousLabel = (int)[self.itemLabels count] - 1;
            for (int i = (int)[self.itemLabels count] - 1; i > -1; i--) { // Starting with the last label
                UILabel *currentLabel = (UILabel *)self.itemLabels[i];
                if (currentLabel.center.x > currentCenter) {
                    indexOfPreviousLabel--;
                }
                else {
                    break;
                }
            }
            indexOfPreviousLabel++; // This technique gives us one index too low
            [self scrollToItemAtIndex:indexOfPreviousLabel informDelegate:YES];
        }
    }
}



//////////////////////
#pragma mark - Actions
//////////////////////

- (void)tapped:(UITapGestureRecognizer *)recognizer
{
    if ([self scrolling] == NO) {
        CGPoint location = [recognizer locationInView:self];
        CGFloat xPosInScrollViewsContentSize = self.scrollView.contentOffset.x + location.x;
        NSInteger tappedItemIndex = [self indexOfLabelAtXPosition:xPosInScrollViewsContentSize];
        if (tappedItemIndex >= 0 ) {
            [self scrollToItemAtIndex:tappedItemIndex informDelegate:YES];
        }
    }
}

@end
