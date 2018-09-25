//
//  AppDelegate.m
//  SmartAlarm_oc
//
//  Created by Jim on 2018/8/16.
//  Copyright © 2018年 Jim. All rights reserved.
//

#import "AppDelegate.h"


@interface AppDelegate ()
@property (nonatomic) BOOL initialized;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    [AWSDDLog sharedInstance].logLevel = AWSDDLogFlagDebug;
    [AWSDDLog addLogger:[AWSDDTTYLogger sharedInstance]];
    
    AWSCognitoCredentialsProvider *credentialsProvider = [[AWSCognitoCredentialsProvider alloc]
                                                          initWithRegionType:AWSRegionUSWest2
                                                          identityPoolId:@"us-west-2:cbae569d-0712-42ed-8a56-e31e75e2abe8"];
    
    AWSServiceConfiguration *configuration = [[AWSServiceConfiguration alloc]
                                              initWithRegion:AWSRegionUSWest2
                                              credentialsProvider:credentialsProvider];
    
    [AWSServiceManager defaultServiceManager].defaultServiceConfiguration = configuration;
    
    /* Override point for customization after application launch.
    UIMutableUserNotificationAction *readAction = [[UIMutableUserNotificationAction alloc] init];
    readAction.identifier = @"READ_IDENTIFIER";
    readAction.title = @"Read";
    readAction.activationMode = UIUserNotificationActivationModeForeground;
    readAction.destructive = NO;
    readAction.authenticationRequired = YES;
    
    UIMutableUserNotificationAction *ignoreAction = [[UIMutableUserNotificationAction alloc] init];
    ignoreAction.identifier = @"IGNORE_IDENTIFIER";
    ignoreAction.title = @"Ignore";
    ignoreAction.activationMode = UIUserNotificationActivationModeBackground;
    ignoreAction.destructive = NO;
    ignoreAction.authenticationRequired = NO;
    
    UIMutableUserNotificationAction *deleteAction = [[UIMutableUserNotificationAction alloc] init];
    deleteAction.identifier = @"DELETE_IDENTIFIER";
    deleteAction.title = @"Delete";
    deleteAction.activationMode = UIUserNotificationActivationModeForeground;
    deleteAction.destructive = YES;
    deleteAction.authenticationRequired = YES;
    
    UIMutableUserNotificationCategory *messageCategory = [[UIMutableUserNotificationCategory alloc] init];
    messageCategory.identifier = @"MESSAGE_CATEGORY";
    [messageCategory setActions:@[readAction, ignoreAction, deleteAction] forContext:UIUserNotificationActionContextDefault];
    [messageCategory setActions:@[readAction, deleteAction] forContext:UIUserNotificationActionContextMinimal];
    
    NSSet *categories = [NSSet setWithObject:messageCategory];
    
    UIUserNotificationType types = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    UIUserNotificationSettings *mySettings = [UIUserNotificationSettings settingsForTypes:types categories:categories];
    
    [[UIApplication sharedApplication] registerUserNotificationSettings:mySettings];
    [[UIApplication sharedApplication] registerForRemoteNotifications];
     */
    
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationSettings* notificationSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    } else {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes: (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    }
    
    if(launchOptions!=nil){
        NSString *msg = [NSString stringWithFormat:@"%@", launchOptions];
        NSLog(@"%@",msg);
        [self createAlert:msg];
    }
    
    return YES;
}

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
    NSLog(@"deviceToken: %@", deviceToken);
    NSUserDefaults *userDef = [NSUserDefaults standardUserDefaults];
    [userDef setObject:deviceToken forKey:@"deviceToken"];
    [userDef synchronize];
    [self subscribeToPushTopicWithDeviceToken:[userDef objectForKey:@"deviceToken"]];

}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error{
    NSLog(@"Failed to register with error : %@", error);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    application.applicationIconBadgeNumber = 0;
    NSString *msg = [NSString stringWithFormat:@"%@", userInfo];
    NSLog(@"%@",msg);
    [self createAlert:msg];
}

- (void)createAlert:(NSString *)msg {
    /*
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Message Received"
                                                        message:[NSString stringWithFormat:@"%@", msg]
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
     */
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL*)url
{
    //接受傳過來的參數
    NSString *text = [[url host] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    /* UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"OPEN"
                                                        message:text
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
    */
    NSLog(@"handleOpenURL = %@",text);
    return YES;
}

- (void)application:(UIApplication *) application handleActionWithIdentifier:(NSString *)identifier
forRemoteNotification:(NSDictionary *)notification completionHandler:(void (^)())completionHandler{
    if ([identifier isEqualToString:@"READ_IDENTIFIER"]){
        NSString *msg = [NSString stringWithFormat:@"%@", @"read"];
        [self createAlert:msg];
    }else if ([identifier isEqualToString:@"DELETE_IDENTIFIER"]){
        NSString *msg = [NSString stringWithFormat:@"%@", @"delete"];
        [self createAlert:msg];
    }
    
    completionHandler();
}

- (void)subscribeToPushTopicWithDeviceToken:(NSData *)deviceToken
{
    AWSSNS *sns = [AWSSNS defaultSNS];
    AWSSNSCreatePlatformEndpointInput *endpointRequest = [AWSSNSCreatePlatformEndpointInput new];
    //get some device's IDs
    NSString *userDeviceName = [[UIDevice currentDevice] name];
    NSString *userDevicePlatform = [[UIDevice currentDevice] model];
    
    //get SNS settings
    NSString *myPlatformApplicationArn;
    #ifdef DEBUG
        myPlatformApplicationArn = @"arn:aws:sns:us-west-2:714007251465:app/APNS_SANDBOX/AmazonMobilePush";
    #else
        myPlatformApplicationArn = @"arn:aws:sns:us-west-2:714007251465:app/APNS/AmazonMobilePush";
    #endif
    NSString *myTopicArn = @"arn:aws:sns:us-west-2:714007251465:SmokeSensor_Demo_APP";
    
    endpointRequest.platformApplicationArn = myPlatformApplicationArn;
    NSString * deviceTokenString = [[[[deviceToken description]
                                      stringByReplacingOccurrencesOfString: @"<" withString: @""]
                                      stringByReplacingOccurrencesOfString: @">" withString: @""]
                                      stringByReplacingOccurrencesOfString: @" " withString: @""];
    endpointRequest.token = deviceTokenString;
    endpointRequest.customUserData = [NSString stringWithFormat:@"%@ - %@", userDevicePlatform, userDeviceName];
    
    [[[sns createPlatformEndpoint:endpointRequest] continueWithSuccessBlock:^id(AWSTask *task) {
        
        AWSSNSCreateEndpointResponse *response = task.result;
        
        AWSSNSSubscribeInput *subscribeRequest = [AWSSNSSubscribeInput new];
        subscribeRequest.endpoint = response.endpointArn;
        subscribeRequest.protocols = @"application";
        subscribeRequest.topicArn = myTopicArn;
        
        return [sns subscribe:subscribeRequest];
        
    }] continueWithBlock:^id(AWSTask *task) {
        
        if (task.cancelled) {
            NSLog(@"AWS SNS Task cancelled!");
        }
        else if (task.error) {
            NSLog(@"%s file: %s line: %d - AWS SNS Error occurred: [%@]", __FUNCTION__, __FILE__, __LINE__, task.error);
        }
        else {
            NSLog(@"AWS SNS Task Success.");
        }
        return nil;
    }];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
