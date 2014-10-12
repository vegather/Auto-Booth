//
//  VSTImageFilter.h
//  Vegard Solheim Theriault
//
//  Created by Vegard Solheim Theriault on 08/04/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VSTImageFilter : NSObject

//Index 0 will be the standard image without filters
- (void)applyFilterAtIndex:(NSUInteger)filterIndex
                  forImage:(UIImage **)source;

+ (NSArray *)availableFilters;

@end
