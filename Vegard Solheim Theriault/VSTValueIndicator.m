//
//  VSTValueIndicator.m
//  Vegard Solheim Theriault
//
//  Created by Vegard Solheim Theriault on 09/04/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import "VSTValueIndicator.h"


#define ALPHA_FOR_HIGHLIGHTED   1.0
#define ALPHA_FOR_DIMMED        0.4
#define FONT_FOR_HIGHLIGHTED    @"HelveticaNeue"
#define FONT_FOR_DIMMED         @"HelveticaNeue-Light"
#define FONT_SIZE               50

@interface VSTValueIndicator ()
@property (strong, nonatomic) NSMutableArray *labels;
@end

@implementation VSTValueIndicator


////////////////////
#pragma mark - Setup
////////////////////

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
    self.opaque = NO;
    self.backgroundColor = [UIColor clearColor];
    self.maxValue = 3;
    self.value = 0;
}



//////////////////////
#pragma mark - Setters
//////////////////////

- (void)setValue:(NSUInteger)value
{
    _value = (value > self.maxValue) ? self.maxValue : value;
        
    for (UILabel *label in self.labels) {
        if ([label.text integerValue] <= _value) {
            // Highlighted
            label.alpha = ALPHA_FOR_HIGHLIGHTED;
            label.font = [UIFont fontWithName:FONT_FOR_HIGHLIGHTED size:FONT_SIZE];
        }
        else {
            // Dimmed
            label.alpha = ALPHA_FOR_DIMMED;
            label.font = [UIFont fontWithName:FONT_FOR_DIMMED size:FONT_SIZE];
        }
    }
}

- (void)setMaxValue:(NSUInteger)maxValue
{
    _maxValue = maxValue;
    [self setNeedsDisplay];
}


//////////////////////
#pragma mark - Getters
//////////////////////

- (NSMutableArray *)labels
{
    if (!_labels) {
        _labels = [[NSMutableArray alloc]init];
    }
    return _labels;
}



//////////////////////
#pragma mark - Drawing
//////////////////////

- (void)drawRect:(CGRect)rect
{
    for (UILabel *label in self.labels) {
        [label removeFromSuperview];
    }
    
    CGFloat pointsPerLabel = self.frame.size.width / self.maxValue;
    
    for (int i = 0; i < self.maxValue; i++) {
        
        //Set every label to dimmed state
        CGRect labelFrame = CGRectMake(i * pointsPerLabel, 0, pointsPerLabel, self.frame.size.height);
        UILabel *label = [[UILabel alloc]initWithFrame:labelFrame];
        label.font = [UIFont fontWithName:FONT_FOR_DIMMED size:FONT_SIZE];
        label.textColor = [UIColor whiteColor];
        label.alpha = ALPHA_FOR_DIMMED;
        label.text = [NSString stringWithFormat:@"%d", i + 1];
        label.textAlignment = NSTextAlignmentCenter;
        
        [self.labels addObject:label];
        [self addSubview:label];
    }
}

@end
