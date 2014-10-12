//
//  VSTPictureViewerVC.h
//  Vegard Solheim Theriault
//
//  Created by Vegard Solheim Theriault on 06/04/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import <UIKit/UIKit.h>



@protocol VSTPictureViewerDelegate <NSObject>

- (void)pictureViewerDidFinish;

@end


@interface VSTPictureViewerVC : UIViewController

@property (strong, nonatomic) id <VSTPictureViewerDelegate> delegate;
@property (strong, nonatomic) NSArray *pictures;    // of VSTPictures

@end
