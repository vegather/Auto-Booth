//
//  MWLocationManager.m
//  MOON Atlas
//
//  Created by Vegard Solheim Theriault on 14/09/14.
//  Copyright (c) 2014 MOON Wearables. All rights reserved.
//

#import "MWLocationManager.h"
@import CoreLocation;

@interface MWLocationManager () <CLLocationManagerDelegate>
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (copy) void (^returnBlock)(CLLocation *location, NSError *error);
@property (strong, nonatomic) NSTimer *timeoutTimer;
@property (strong, nonatomic) NSDate *lastReceivedLocationData; // To avoid dublicate locations
@end

@implementation MWLocationManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        [_locationManager requestWhenInUseAuthorization];
        _locationManager.activityType = CLActivityTypeOther; //Fitness only records when there is movement
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        _locationManager.distanceFilter = kCLDistanceFilterNone;
        
        _lastReceivedLocationData = [NSDate distantPast];
        
        NSLog(@"Done initializing");
    }
    
    return self;
}

- (void)getCurrentLocationWithTimeout:(NSTimeInterval)timeout
                withCompletionHandler:(void (^)(CLLocation *location, NSError *error))completionHandler
{
    if ([CLLocationManager locationServicesEnabled]) {
        
        self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:timeout
                                                             target:self
                                                           selector:@selector(timedOut)
                                                           userInfo:nil
                                                            repeats:NO];
        
        self.returnBlock = completionHandler;
        
        // switch fucked up...
        if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
            NSLog(@"Authorization status: Always");
            [self.locationManager startUpdatingLocation];
        }
        else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedWhenInUse) {
            NSLog(@"Authorization status: When in use");
            [self.locationManager startUpdatingLocation];
        }
        else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
            NSLog(@"Authorization status: Denied");
            NSString *description = @"MOON Atlas is not allowed to use your location. Head over to the Settings app and enable locations.";
            NSError *missingLocationServiceError = [NSError errorWithDomain:@"MWLocationManagerError"
                                                                       code:504
                                                                   userInfo:@{NSLocalizedDescriptionKey : description}];
            completionHandler(nil, missingLocationServiceError);
        }
        else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
            NSLog(@"Authorization status: Not determined");
            [_locationManager requestWhenInUseAuthorization];
            [self getCurrentLocationWithTimeout:timeout withCompletionHandler:completionHandler];
        }
        else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted) {
            NSLog(@"Authorizatrion status: Restricted");
            
            NSString *description = @"MOON Atlas is not allowed to use your location. There are some restrictions on location services for this device.";
            NSError *missingLocationServiceError = [NSError errorWithDomain:@"MWLocationManagerError"
                                                                       code:503
                                                                   userInfo:@{NSLocalizedDescriptionKey : description}];
            completionHandler(nil, missingLocationServiceError);
        }
    } else {
        NSLog(@"Location services is NOT enabled");
        NSString *description = @"Could not get your location. You should head over to settings and enable location services for MOON Room";
        NSError *missingLocationServiceError = [NSError errorWithDomain:@"MWLocationManagerError"
                                                                   code:502
                                                               userInfo:@{NSLocalizedDescriptionKey : description}];
        completionHandler(nil, missingLocationServiceError);
    }
    
}

- (void)timedOut
{
    NSString *description = @"Location service timed out";
    NSError *timedOutError = [NSError errorWithDomain:@"MWLocationManagerError"
                                                 code:501
                                             userInfo:@{NSLocalizedDescriptionKey : description}];
    self.returnBlock(nil, timedOutError);
}




/////////////////////////////
#pragma mark - Location Manager Delegate
/////////////////////////////

#define MAX_LOCATION_AGE 10         // I want location data that is less than 10 seconds old
#define MAX_LOCATION_ACCURACY 100   // Don't need location data more accurate than 100 meters
#define TIME_TO_AVOID_DUBLICATE 1   // If I get location data again in less than 1 seconds, I don't want it

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [self.timeoutTimer invalidate];
    
    NSLog(@"Did update locations: %@", locations);
    CLLocation *mostRecentLocation = [locations lastObject];
    
    if (ABS([mostRecentLocation.timestamp timeIntervalSinceNow]) < MAX_LOCATION_AGE &&
        mostRecentLocation.horizontalAccuracy <= MAX_LOCATION_ACCURACY &&
        ABS([self.lastReceivedLocationData timeIntervalSinceDate:mostRecentLocation.timestamp]) > TIME_TO_AVOID_DUBLICATE)
    {
        self.lastReceivedLocationData = mostRecentLocation.timestamp;
        [self.locationManager stopUpdatingLocation];
        self.returnBlock(mostRecentLocation, nil);
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [self.timeoutTimer invalidate];
    
    NSLog(@"Location manager failed: %@", error);
    [self.locationManager stopUpdatingLocation];
    
    NSString *description = [NSString stringWithFormat:@"An error occured while getting your location: %@", error.localizedDescription];
    NSError *locationManagerFailedError = [NSError errorWithDomain:@"MWLocationManagerError"
                                                              code:500
                                                          userInfo:@{NSLocalizedDescriptionKey : description}];
    self.returnBlock(nil, locationManagerFailedError);
}


@end
