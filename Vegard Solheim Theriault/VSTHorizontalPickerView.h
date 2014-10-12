//
//  VSTHorizontalPickerView.h
//  Vegard Solheim Theriault
//
//  Created by Vegard Solheim Theriault on 06/04/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol VSTHorizontalPickerViewDelegate <NSObject>

- (void)horizontalPickerViewDidSelectItemAtIndex:(NSUInteger)index;

@end


@interface VSTHorizontalPickerView : UIView
@property (strong, nonatomic) id <VSTHorizontalPickerViewDelegate> delegate;
@property (strong, nonatomic) NSArray *itemTitles;
@property (nonatomic, readonly) NSUInteger selectedItem;

- (BOOL)scrolling;
- (void)scrollToItemAtIndex:(NSUInteger)index informDelegate:(BOOL)informDelegate;
@end
