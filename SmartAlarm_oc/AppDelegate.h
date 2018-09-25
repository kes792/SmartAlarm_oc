//
//  AppDelegate.h
//  SmartAlarm_oc
//
//  Created by Jim on 2018/8/16.
//  Copyright © 2018年 Jim. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AWSAuthCore/AWSAuthCore.h>
#import <AWSPinpoint/AWSPinpoint.h>
#import <AWSUserPoolsSignIn/AWSUserPoolsSignIn.h>
#import "AWSSNS.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property(atomic) AWSPinpoint *pinpoint;


@end

