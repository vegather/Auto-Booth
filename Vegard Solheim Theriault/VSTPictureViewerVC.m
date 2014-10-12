//
//  VSTPictureViewerVC.m
//  Vegard Solheim Theriault
//
//  Created by Vegard Solheim Theriault on 06/04/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//


#import "VSTPictureViewerVC.h"
#import "VSTHorizontalPickerView.h"
#import "VSTImageFilter.h"
#import "VSTPicture.h"
@import AssetsLibrary;
@import Social;
@import MessageUI;

@interface VSTPictureViewerVC () <VSTHorizontalPickerViewDelegate, UIActionSheetDelegate, MFMessageComposeViewControllerDelegate, MFMailComposeViewControllerDelegate, UINavigationControllerDelegate>

#pragma mark Outlets
@property (weak, nonatomic) IBOutlet UIScrollView *picturesScrollView;
@property (weak, nonatomic) IBOutlet UIPageControl *picturePageControl;
@property (weak, nonatomic) IBOutlet VSTHorizontalPickerView *filterSelector;

#pragma mark Misc
@property (strong, nonatomic) NSMutableArray *imageViews;
@property (strong, nonatomic) VSTImageFilter *imageFilter;
@property (nonatomic) BOOL hasLoaded;
@property (strong, nonatomic) NSArray *availableSharingServices;
@end

@implementation VSTPictureViewerVC


// Available Services
#define USE_ACTIVITY_VIEW_CONTROLLER      YES
#define SHARING_SERVICE_FACEBOOK          @"Facebook"
#define SHARING_SERVICE_TWITTER           @"Twitter"
#define SHARING_SERVICE_MESSAGE           @"Message"
#define SHARING_SERVICE_MAIL              @"Mail"
#define SHARING_SERVICE_PHOTO_LIBRARY     @"Photo Library"


//////////////////////
#pragma mark - Loading
//////////////////////

- (void)awakeFromNib
{
    self.hasLoaded = NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.picturePageControl.numberOfPages = [self.pictures count];
    
    self.filterSelector.delegate = self;
    [self.filterSelector setItemTitles:[VSTImageFilter availableFilters]];
}

- (void)viewDidLayoutSubviews
{
    if (self.hasLoaded == NO) {
        [self loadPictures];
        self.hasLoaded = YES;
    }
}

- (void)loadPictures
{
    if ([self.pictures count] > 0) {
        
        self.imageViews = [[NSMutableArray alloc]init];
        
        // These will be used to set the contentSize of the scrollView
        CGFloat totalWidthInPoints   = 0.0;
        
//        NSLog(@"self.view.frame =     %@", NSStringFromCGRect(self.view.frame));
//        NSLog(@"self.scroller.frame = %@", NSStringFromCGRect(self.picturesScrollView.frame));
        
        for (int i = 0; i < [self.pictures count]; i++) {
            if ([self.pictures[i] isKindOfClass:[VSTPicture class]]) {
                
                UIImage *currentImage = [((VSTPicture *)self.pictures[i]) filteredImage];
                
                CGFloat pictureAreaWidth  = self.picturesScrollView.frame.size.width;
                CGFloat pictureAreaHeight = self.picturesScrollView.frame.size.height - self.picturesScrollView.contentInset.top;
                
                CGFloat imageViewWidth = (currentImage.size.width * pictureAreaHeight) / currentImage.size.height;
                CGFloat spacingBetweenImageViews = MAX(0, (pictureAreaWidth - imageViewWidth) / 2.0);
                
                NSLog(@"pictureAreaWidth: %f, pictureAreaHeight: %f, imageViewWidth: %f, spacingBetweenImageViews: %f, scrollerWidth: %f, scrollerHeight - inset.top: %f", pictureAreaWidth, pictureAreaHeight, imageViewWidth, spacingBetweenImageViews, self.picturesScrollView.frame.size.width, self.picturesScrollView.frame.size.height - self.picturesScrollView.contentInset.top);
                
                NSLog(@"top inset = %.2f", self.picturesScrollView.contentInset.top);
                
                CGRect imageViewFrame = CGRectMake(totalWidthInPoints + spacingBetweenImageViews,
                                                   0,//self.picturesScrollView.contentInset.top,
                                                   MIN(pictureAreaWidth, imageViewWidth),
                                                   pictureAreaHeight);
                
                UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageViewFrame];
                imageView.image = currentImage;
//                imageView.contentMode = UIViewContentModeScaleAspectFill;
//                imageView.clipsToBounds = YES;
                
                [self.imageViews addObject:imageView];
                [self.picturesScrollView addSubview:imageView];

                totalWidthInPoints += MIN(pictureAreaWidth, imageViewWidth) + (2.0 * spacingBetweenImageViews); //imageViewWidth + (2.0 * spacingBetweenImageViews);
                NSLog(@"New totalWidthInPoints: %.2f", totalWidthInPoints);
            }
        }
        [self.picturesScrollView setContentSize:CGSizeMake(totalWidthInPoints, self.picturesScrollView.frame.size.height - self.picturesScrollView.contentInset.top)];
        [self.picturesScrollView setShowsHorizontalScrollIndicator:NO];
        
    }
}




//////////////////////
#pragma mark - Getters
//////////////////////

- (VSTImageFilter *)imageFilter
{
    if (!_imageFilter) {
        _imageFilter = [[VSTImageFilter alloc]init];
    }
    return _imageFilter;
}



//////////////////////
#pragma mark - Setters
//////////////////////

//- (void)setPictures:(NSArray *)pictures
//{
//    _pictures = pictures;
//    [self loadPictures];
//}



///////////////////////////////////
#pragma mark - Scroll View Delegate
///////////////////////////////////

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // Without checking if we are dragging, the page control's current page would jump quickly back
    // and forth when the action was used. This is because it was set by the action, and then set
    // back by this until the image was more than half-way across the screen. Then it would be set
    // back to what the action originally sat it to.
    
    if (scrollView.dragging) {
        //Update the pageControl
        self.picturePageControl.currentPage = [self indexOfSelectedImage];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self scrollViewDidStop];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [self scrollViewDidStop];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate
{
    // The user released the finger while dead on an image
    if (decelerate == NO) {
        [self scrollViewDidStop];
    }
}


///////////////////////////////////////////////
#pragma mark - Handling the Picture Scroll View
///////////////////////////////////////////////

- (void)scrollToImageAtIndex:(NSUInteger)index
{
    CGPoint offset = self.picturesScrollView.contentOffset;
    offset.x = index * self.picturesScrollView.frame.size.width;
    [self.picturesScrollView setContentOffset:offset animated:YES];
}

- (void)scrollViewDidStop
{
    NSUInteger selectedIndex = [self indexOfSelectedImage];
    VSTPicture *selectedPicture = self.pictures[selectedIndex];
    if (selectedPicture.filterIndex != self.filterSelector.selectedItem) {
        [self.filterSelector scrollToItemAtIndex:selectedPicture.filterIndex
                                  informDelegate:NO];
    }
}

- (NSUInteger)indexOfSelectedImage
{
    CGFloat pageWidth = self.picturesScrollView.frame.size.width;
    float fractionalPage = self.picturesScrollView.contentOffset.x / pageWidth;
    return lround(fractionalPage);
}

- (void)toSelectedImageApplyFilterAtIndex:(NSUInteger)filterIndex
{
    // Makes sure that we don't apply the filter that is already on the picture.
    NSUInteger selectedPictureIndex = [self indexOfSelectedImage];
    id unknownPicture = self.pictures[selectedPictureIndex];
    
    if ([unknownPicture isKindOfClass:[VSTPicture class]]) {
        VSTPicture *selectedPicture = (VSTPicture *)unknownPicture;
        if (selectedPicture.filterIndex != filterIndex) {
            
            //Update the filter index
            selectedPicture.filterIndex = filterIndex;
            
            UIImage *filteredImage = [selectedPicture filteredImage];
            ((UIImageView *)self.imageViews[[self indexOfSelectedImage]]).image = filteredImage;
        }
    }
}



///////////////////////////////////////
#pragma mark - Filter Selector Delegate
///////////////////////////////////////

- (void)horizontalPickerViewDidSelectItemAtIndex:(NSUInteger)index
{
    [self toSelectedImageApplyFilterAtIndex:index];
}



//////////////////////
#pragma mark - Actions
//////////////////////

- (IBAction)pageControlTapped:(UIPageControl *)sender
{
    [self scrollToImageAtIndex:sender.currentPage];
}

- (IBAction)cameraButtonTapped:(UIBarButtonItem *)sender
{
    [self.delegate pictureViewerDidFinish];
}

- (IBAction)saveButtonTapped:(UIBarButtonItem *)sender
{
    if (USE_ACTIVITY_VIEW_CONTROLLER) {
        
        NSLog(@"getting image");
        UIImage *imageToShare = ((UIImageView *)self.imageViews[[self indexOfSelectedImage]]).image;
        
        NSLog(@"creating activity view");
        UIActivityViewController *activityVC = [[UIActivityViewController alloc]initWithActivityItems:@[imageToShare]
                                                                                applicationActivities:@[]];
        
        NSLog(@"presenting activity view");
        
        [self presentViewController:activityVC animated:YES completion:nil];
        
        NSLog(@"done");
    }
    else {
        UIActionSheet *shareSheet = [[UIActionSheet alloc]initWithTitle:@"Where do you want to share the picture?"
                                                               delegate:self
                                                      cancelButtonTitle:nil
                                                 destructiveButtonTitle:nil
                                                      otherButtonTitles:nil];
        
        NSArray *services = self.availableSharingServices;
        for (NSString *service in services) {
            [shareSheet addButtonWithTitle:service];
        }
        
        [shareSheet addButtonWithTitle:@"Cancel"];
        shareSheet.cancelButtonIndex = [services count];
        
        [shareSheet showInView:self.view];

    }
}



///////////////////////////////
#pragma mark - Sharing Services
///////////////////////////////

- (NSArray *)availableSharingServices
{
    // Need to check these every time, because they might change.
    NSMutableArray *services = [[NSMutableArray alloc]initWithArray:@[SHARING_SERVICE_PHOTO_LIBRARY]]; // Save is always available
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook]) {
        [services addObject:SHARING_SERVICE_FACEBOOK];
    }
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) {
        [services addObject:SHARING_SERVICE_TWITTER];
    }
    if ([MFMessageComposeViewController canSendText] && [MFMessageComposeViewController canSendAttachments]) {
        [services addObject:SHARING_SERVICE_MESSAGE];
    }
    if ([MFMailComposeViewController canSendMail]) {
        [services addObject:SHARING_SERVICE_MAIL];
    }
    
    _availableSharingServices = [services copy];
    return _availableSharingServices;
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSArray *services = self.availableSharingServices; // So I don't ask all services for their availability for each service
    
    if (buttonIndex < [services count]) {
        if ([services[buttonIndex] isEqualToString:SHARING_SERVICE_PHOTO_LIBRARY]) {
            // Save
            id picture = self.pictures[[self indexOfSelectedImage]];
            if ([picture isKindOfClass:[VSTPicture class]]) {
                [(VSTPicture *)picture saveImageToDisk];
            }
        }
        else if ([services[buttonIndex] isEqualToString:SHARING_SERVICE_FACEBOOK]) {
            // Facebook
            [self showSLComposerForServiceType:SLServiceTypeFacebook];
        }
        else if ([services[buttonIndex] isEqualToString:SHARING_SERVICE_TWITTER]) {
            // Twitter
            [self showSLComposerForServiceType:SLServiceTypeTwitter];
        }
        else if ([services[buttonIndex] isEqualToString:SHARING_SERVICE_MESSAGE]) {
            // Message
            [self showMessageComposer];
        }
        else if ([services[buttonIndex] isEqualToString:SHARING_SERVICE_MAIL]) {
            // Mail
            [self showMailComposer];
        }
    }
}


#pragma mark Message
- (void)showMessageComposer
{
    UIImage *image = ((UIImageView *)self.imageViews[[self indexOfSelectedImage]]).image;
    NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
    
    MFMessageComposeViewController *messageComposer = [[MFMessageComposeViewController alloc]init];
    [messageComposer addAttachmentData:imageData
                        typeIdentifier:@"kUTTypeJPEG" //https://developer.apple.com/library/mac/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html
                              filename:((VSTPicture *)self.pictures[[self indexOfSelectedImage]]).pictureName];
    messageComposer.messageComposeDelegate = self;
    
    [self presentViewController:messageComposer animated:YES completion:NULL];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}


#pragma mark Mail
- (void)showMailComposer
{
    UIImage *image = ((UIImageView *)self.imageViews[[self indexOfSelectedImage]]).image;
    NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
    
    MFMailComposeViewController *mailComposer = [[MFMailComposeViewController alloc]init];
    [mailComposer addAttachmentData:imageData
                           mimeType:@"image/jpeg" //http://www.iana.org/assignments/media-types/media-types.xhtml#image
                           fileName:((VSTPicture *)self.pictures[[self indexOfSelectedImage]]).pictureName];
    mailComposer.mailComposeDelegate = self;
    
    [self presentViewController:mailComposer animated:YES completion:NULL];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}


#pragma mark Social Services
- (void)showSLComposerForServiceType:(NSString *)serviceType
{
    SLComposeViewController *composerVC = [SLComposeViewController composeViewControllerForServiceType:serviceType];
    [composerVC addImage:((UIImageView *)self.imageViews[[self indexOfSelectedImage]]).image];
    [self presentViewController:composerVC animated:YES completion:NULL];
}

- (NSString *)humanReadableNameForServiceType:(NSString *)serviceType
{
    if ([serviceType isEqualToString:SLServiceTypeFacebook]) {
        return @"Facebook";
    }
    else if ([serviceType isEqualToString:SLServiceTypeTwitter]) {
        return @"Twitter";
    }
    else {
        return @"unknown service";
    }
}

@end
