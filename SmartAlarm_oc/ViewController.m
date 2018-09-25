//
//  ViewController.m
//  SmartAlarm_oc
//
//  Created by Jim on 2018/8/16.
//  Copyright © 2018年 Jim. All rights reserved.
//

#import "ViewController.h"
#import <AWSAuthCore/AWSAuthCore.h>
#import <AWSPinpoint/AWSPinpoint.h>
#import "Masonry.h"
#import "AWSSNS.h"
#import "AWSIoT.h"

#define xScreenH               [self getScreenSize].height
#define xScreenW               [self getScreenSize].width
#define CognitoIdentityPoolId  @"us-west-2:cbae569d-0712-42ed-8a56-e31e75e2abe8"
#define IOT_ENDPOINT           @"https://a2lly389btqeax.iot.us-west-2.amazonaws.com"

typedef void(^EventCallBack)(NSString *shadowName,
                             AWSIoTShadowOperationType operation,
                             AWSIoTShadowOperationStatusType status,
                             NSString *clientToken,
                             NSData *payload) ;

@interface ViewController ()
{
}

@property (nonatomic,retain) NSMutableDictionary *thingDictionary;
@property (nonatomic) BOOL updateSuccess;
@property (nonatomic,retain) UILabel *connectStatus;
// thing information
@property (nonatomic,retain) UILabel *batteryLabel;
@property (nonatomic,retain) UILabel *coDensityLabel;
@property (nonatomic,retain) UILabel *productLifeLabel;
@property (nonatomic,retain) UILabel *smokeAlertLabel;
@property (nonatomic,retain) UILabel *smokeErrState;

@property (nonatomic,retain) UIAlertController * alertController;
@property (nonatomic,retain) UIAlertController * smokeAlertController;

@property (nonatomic,retain) UIImageView *LED_imageView;
@property (nonatomic,retain) UIView *loadingView;
@property (nonatomic,retain) UIActivityIndicatorView *indicatorView;

@property (nonatomic,retain) AWSIoTDataManager *iotDataManager;
@property (nonatomic,retain) AWSIoTData *iotData;

@property (nonatomic,retain) UITapGestureRecognizer *tap;
@end


@implementation ViewController

#pragma mark - view life cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self.view setBackgroundColor:[UIColor whiteColor]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didResignActive:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];

    self.updateSuccess = FALSE;
    [self initAWSIOT];
    [self setupUILayout];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:YES ];
    [self connectAWSIOT];
}

- (void)viewDidAppear:(BOOL)animated{
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:YES];
    [self dismissViewControllerAnimated:TRUE completion:nil];
}

#pragma mark - UIApplication Delegate
- (void)didResignActive:(NSNotification *)notification
{
    [self.alertController dismissViewControllerAnimated:YES completion:nil];
    //[self getDemoThingShadow];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - AWS IOT
-(void) initAWSIOT
{
    AWSCognitoCredentialsProvider *credentialsProvider = [[AWSCognitoCredentialsProvider alloc]
                                                          initWithRegionType:AWSRegionUSWest2
                                                          identityPoolId:@"us-west-2:cbae569d-0712-42ed-8a56-e31e75e2abe8"];
    
    AWSEndpoint *endpoint = [[AWSEndpoint alloc] initWithURLString:IOT_ENDPOINT];
    
    AWSServiceConfiguration *configuration = [[AWSServiceConfiguration alloc] initWithRegion:AWSRegionUSWest2
                                                                                    endpoint:endpoint
                                                                         credentialsProvider:credentialsProvider];
    
    [AWSServiceManager defaultServiceManager].defaultServiceConfiguration = configuration;
    
    [AWSIoTDataManager registerIoTDataManagerWithConfiguration:configuration forKey:@"USWest2IoTDataManager"];
    [AWSIoTData registerIoTDataWithConfiguration:configuration forKey:@"USWest2IoTData"];
    _iotDataManager  = [AWSIoTDataManager IoTDataManagerForKey:@"USWest2IoTDataManager"];
    _iotData = [AWSIoTData IoTDataForKey:@"USWest2IoTData"];
    
    NSString *lwtTopic = @"temperature-control-last-will-and-testament";
    NSString *lwtMessage = @"disconnected";
    
    _iotDataManager.mqttConfiguration.lastWillAndTestament.topic = lwtTopic;
    _iotDataManager.mqttConfiguration.lastWillAndTestament.message = lwtMessage;
    _iotDataManager.mqttConfiguration.lastWillAndTestament.qos = AWSIoTMQTTQoSMessageDeliveryAttemptedAtLeastOnce;
}

-(void)connectAWSIOT
{
    [_iotDataManager connectUsingWebSocketWithClientId:@"h062hqbghinicressesn4jt4n"
                                          cleanSession:TRUE
                                        statusCallback:^(AWSIoTMQTTStatus status) {
                                            switch (status) {
                                                    case AWSIoTMQTTStatusConnecting:{
                                                        NSLog(@"status = AWSIoTMQTTStatusConnecting");
                                                        dispatch_async(dispatch_get_main_queue(), ^{
                                                            self.connectStatus.text = @"Connecting...";
                                                            [self loadingStartAnimating];

                                                        });
                                                    }
                                                    break;
                                                    case AWSIoTMQTTStatusConnected:{
                                                        dispatch_async(dispatch_get_main_queue(), ^{
                                                            BOOL result = [self registThisWithShadow ];
                                                            NSLog(@"status = AWSIoTMQTTStatusConnected, result = %d",result);
                                                            if(result){
                                                                NSDate *runUntil = [NSDate dateWithTimeIntervalSinceNow: 2.0 ];
                                                                [[NSRunLoop currentRunLoop] runUntilDate:runUntil];
                                                                [self getDemoThingShadow];
                                                                self.connectStatus.text = @"Connected!";
                                                                [self loadingStopAnimating];
                                                            }
                                                        });
                                                    }
                                                    break;
                                                    case AWSIoTMQTTStatusDisconnected:
                                                        NSLog(@"status = AWSIoTMQTTStatusDisconnected");
                                                        [self loadingStopAnimating];
                                                    break;
                                                    case AWSIoTMQTTStatusConnectionRefused:
                                                        NSLog(@"status = AWSIoTMQTTStatusConnectionRefused");
                                                        [self loadingStopAnimating];
                                                    break;
                                                    case AWSIoTMQTTStatusConnectionError:
                                                        NSLog(@"status = AWSIoTMQTTStatusConnectionError");
                                                        [self loadingStopAnimating];
                                                    break;
                                                    case AWSIoTMQTTStatusProtocolError:
                                                        NSLog(@"status = AWSIoTMQTTStatusProtocolError");
                                                        [self loadingStopAnimating];
                                                    break;
                                                    case AWSIoTMQTTStatusUnknown:
                                                        NSLog(@"status = AWSIoTMQTTStatusUnknown");
                                                        [self loadingStopAnimating];
                                                    break;
                                                default:
                                                    break;
                                            }
                                        }];
}

-(BOOL) registThisWithShadow
{
    //AWSIoTMQTTStatus *mqttConnectStatus = [_iotDataManager getConnectionStatus];
    BOOL result=
    [self.iotDataManager registerWithShadow:@"SmokeSensor_Demo"
                                    options:nil
                              eventCallback:^(NSString *name,
                                              AWSIoTShadowOperationType operation,
                                              AWSIoTShadowOperationStatusType status,
                                              NSString *clientToken,
                                              NSData *payload)
     {
         NSDictionary *jsonDict;
         if(payload != NULL)
         {
             NSError *error;
             jsonDict = [NSJSONSerialization JSONObjectWithData:payload
                                                        options:0
                                                          error:&error];
         }
         switch(status){
                 case AWSIoTShadowOperationStatusTypeAccepted:{
                     NSLog(@"status = AWSIoTShadowOperationStatusTypeAccepted");
                     if(self.thingDictionary == NULL)
                        [self initDeviceStatus:jsonDict];
                     else
                        [self updateDeviceStatus:jsonDict];
                 }
                 break;
                 case AWSIoTShadowOperationStatusTypeRejected:{
                     NSLog(@"status = AWSIoTShadowOperationStatusTypeRejected");
                 }
                 break;
                 case AWSIoTShadowOperationStatusTypeDelta:{
                     //self.updateSuccess = TRUE;
                     NSLog(@"status = AWSIoTShadowOperationStatusTypeDelta");
                 }
                 break;
                 case AWSIoTShadowOperationStatusTypeDocuments:{ // update
                     NSLog(@"status = AWSIoTShadowOperationStatusTypeDocuments");
                     if([[[jsonDict objectForKey:@"current"] objectForKey:@"state"] objectForKey:@"desired"] == NULL && self.updateSuccess)
                     {
                         //self.updateSuccess = false;
                         //[self loadingStopAnimating];
                     }
                     [self updateDeviceStatus:[jsonDict objectForKey:@"current"]];
                     
                 }
                 break;
                 case AWSIoTShadowOperationStatusTypeTimeout:{ 
                     NSLog(@"status = AWSIoTShadowOperationStatusTypeTimeout");
                     dispatch_async(dispatch_get_main_queue(), ^{
                         self.connectStatus.text = @"Timeout! Connect again!";
                     });
                 }
                 break;
                default:
                 break;
         }
     }];
    return result;
}

-(BOOL) getDemoThingShadow
{
    /*
     AWSIoTDataGetThingShadowRequest *getThingShadowRequest = [AWSIoTDataGetThingShadowRequest new];
     getThingShadowRequest.thingName = @"SmokeSensor_Demo";
     [[[_iotData getThingShadow:getThingShadowRequest] continueWithBlock:^id(AWSTask *task) {
     //getThingShadowRequest.
     //NSLog(@"result = %@, error = %@", task.result, task.error);
     return nil;
     }] waitUntilFinished];
     */
    BOOL operationStatus = [self.iotDataManager getShadow:@"SmokeSensor_Demo"];
    NSLog(@"getDemoThingShadow operationStatus = %d",operationStatus);
    return TRUE;//operationStatus;
}

-(void)updateSmokeAlertUI
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if(self.thingDictionary == NULL)
            return;
        /*
        NSString *string;
        string = [NSString stringWithFormat:@"BatteryCapacity = %@", [self.thingDictionary objectForKey:@"BatteryCapacity"]];
        self.batteryLabel.text = string;
        string = [NSString stringWithFormat:@"CO Density      = %@", [self.thingDictionary objectForKey:@"CODensity"]];
        self.coDensityLabel.text = string;
        string = [NSString stringWithFormat:@"Life Cycle      = %@", [self.thingDictionary objectForKey:@"ProductLifeCycle"]];
        self.productLifeLabel.text = string;
        string = [NSString stringWithFormat:@"Smoke Alert     = %@", [self.thingDictionary objectForKey:@"SmokeAlertFlag"]];
        self.smokeAlertLabel.text = string;
        string = [NSString stringWithFormat:@"Error State     = %@", [self.thingDictionary objectForKey:@"SmokeErrState"]];
        self.smokeErrState.text = string;
        */
        if([[self.thingDictionary objectForKey:@"SmokeAlertFlag"] integerValue] != 0 &&
           [[self.thingDictionary objectForKey:@"SmokeMuteFlag"] integerValue] == 0) // Smoke alarm
        {
            //NSLog(@" ============  SmartAlertFlag = %@ SmokeMuteFlag = %@ ============",
            //      [self.thingDictionary objectForKey:@"SmokeAlertFlag"]
            //      ,[self.thingDictionary objectForKey:@"SmokeMuteFlag"]);
            [self.LED_imageView  setImage:[UIImage imageNamed:@"red"]];
            [self showSmokeAlarm];
        }
        else
        {
            [self.smokeAlertController dismissViewControllerAnimated:YES completion:nil];
        }
    });
}

-(void) initDeviceStatus:(NSDictionary *)payloadDictionary
{
    if(self.thingDictionary == NULL) // local shadow dictionary
        self.thingDictionary = [[NSMutableDictionary alloc] initWithDictionary:[[payloadDictionary objectForKey:@"state"] objectForKey:@"reported"]];
    [self updateSmokeAlertUI];
    [self startLEDBreath];
}

-(void)updateDeviceStatus:(NSDictionary *)payloadDictionary
{
    if(self.thingDictionary == NULL) // local shadow dictionary
        return;
    
    NSDictionary *reportedArray;
    if([[payloadDictionary objectForKey:@"state"] objectForKey:@"reported"] == NULL)
    {
        NSLog(@"payload do not have \"reported\" Key");
        return;
    }
    if([[payloadDictionary objectForKey:@"state"] objectForKey:@"desired"]  != NULL)
    {
        NSLog(@"payload  have \"desired\" Key");
        return;
    }
    else
        reportedArray = [NSDictionary dictionaryWithDictionary:[[payloadDictionary objectForKey:@"state"] objectForKey:@"reported"]];
    
    if([reportedArray objectForKey:@"BatteryCapacity"])
        [self.thingDictionary setValue:[reportedArray objectForKey:@"BatteryCapacity"] forKey:@"BatteryCapacity"];
    
    if([reportedArray objectForKey:@"CODensity"])
        [self.thingDictionary setValue:[reportedArray objectForKey:@"CODensity"] forKey:@"CODensity"];
    
    if([reportedArray objectForKey:@"ProductLifeCycle"])
        [self.thingDictionary setValue:[reportedArray objectForKey:@"ProductLifeCycle"] forKey:@"ProductLifeCycle"];
    
    if([reportedArray objectForKey:@"SmokeAlertFlag"])
    {
        [self.thingDictionary setValue:[reportedArray objectForKey:@"SmokeAlertFlag"] forKey:@"SmokeAlertFlag"];
    }
    if([reportedArray objectForKey:@"SmokeErrState"])
        [self.thingDictionary setValue:[reportedArray objectForKey:@"SmokeErrState"] forKey:@"SmokeErrState"];
    
    if([reportedArray objectForKey:@"SmokeMuteFlag"])
        [self.thingDictionary setValue:[reportedArray objectForKey:@"SmokeMuteFlag"] forKey:@"SmokeMuteFlag"];
    
    [self updateSmokeAlertUI];
}


#pragma SUBSCRICE_PHONENUMBER
- (void)subscribeToPushTopicWithDeviceToken:(NSString *)phoneNumber
{
    AWSSNS *sns = [AWSSNS defaultSNS];
    NSString *myTopicArn = @"arn:aws:sns:us-west-2:714007251465:SmokeSensor_Demo_SMS";
    AWSSNSSubscribeInput *subscribeRequest = [AWSSNSSubscribeInput new];
    subscribeRequest.endpoint  = phoneNumber;
    subscribeRequest.protocols = @"sms";
    subscribeRequest.topicArn = myTopicArn;
    [sns subscribe:subscribeRequest completionHandler:^(AWSSNSSubscribeResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"AWSSNS Subscribe Error: %@", error);
        } else {
            NSLog(@"AWSSNS Subscribe Success: %@", response);
            NSUserDefaults *userDef = [NSUserDefaults standardUserDefaults];
            [userDef setObject:[response.subscriptionArn copy] forKey:@"phoneNumberARN"];
            [userDef synchronize];
        }
        [self loadingStopAnimating];
    }];
}

- (void)unscribeToPushTopicWithDeviceToken:(NSString *)phoneNumber
{
    AWSSNS *sns = [AWSSNS defaultSNS];
    AWSSNSUnsubscribeInput *subscribeRequest = [AWSSNSUnsubscribeInput new];
    NSUserDefaults *userDef = [NSUserDefaults standardUserDefaults];
    subscribeRequest.subscriptionArn = [userDef objectForKey:@"phoneNumberARN"];
    [sns unsubscribe:subscribeRequest];
}

#pragma mark - Button methods
-(IBAction)testButtonPressed:(id)sender
{
    if([[self.thingDictionary objectForKey:@"SmokeAlertFlag"] integerValue] == 0) // 正常待機
    {
        [self showCheckupAlert];
    }
    else // [[self.thingDictionary objectForKey:@"SmokeAlertFlag"] integerValue] != 0
    {
        // 報警狀態如果不是靜音，重新問要不要靜音
        if([[self.thingDictionary objectForKey:@"SmokeMuteFlag"] integerValue] == 0)
        {
            [self updateSmokeAlertUI];
        }
        // 如果靜音，按下則無效
    }
}

-(IBAction)showDeviceDetail:(id)sender
{
    /*
     BatteryCapacity = 1;
     CODensity = 0;
     ProductLifeCycle = 10000;
     SmokeAlertFlag = 0;
     SmokeErrState = 0;
     SmokeMuteFlag = 0;
     */
    float usageDay = ([[self.thingDictionary objectForKey:@"ProductLifeCycle"] floatValue] / 36500) * 100;
    
    NSString *str = [NSString stringWithFormat:
    @"\nBattery Capacity : %@ %% \n\nCO Density : %@ PPM\n\nProduct Life : %d%% \n\nError State : %@\n",
                     [self.thingDictionary objectForKey:@"BatteryCapacity"],
                     [self.thingDictionary objectForKey:@"CODensity"],
                     (int)usageDay,
                     [self.thingDictionary objectForKey:@"SmokeErrState"]];
    
    self.alertController = [UIAlertController
                                 alertControllerWithTitle:@"Device Information"
                                 message:str
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    NSMutableAttributedString *messageText = [[NSMutableAttributedString alloc] initWithString: str];
    [messageText addAttribute:NSFontAttributeName
                        value:[UIFont systemFontOfSize:15]
                        range:NSMakeRange(0, [str length])];
    [messageText addAttribute:NSForegroundColorAttributeName
                        value:[UIColor darkGrayColor]
                        range:NSMakeRange(0, [str length])];
    [self.alertController setValue:messageText forKey:@"attributedMessage"];
    
    //Add Buttons
    UIAlertAction* yesButton = [UIAlertAction
                                actionWithTitle:@"OK"
                                style:UIAlertActionStyleCancel
                                handler:^(UIAlertAction * action) {
                                    //Handle your yes please button action here
                                    // 不做任何事
                                }];
    //Add your buttons to alert controller
    [self.alertController addAction:yesButton];
    [self presentViewController:self.alertController animated:YES completion:nil];
}

-(IBAction) showSetPhoneNumber:(id)sender
{
    NSUserDefaults *userDef = [NSUserDefaults standardUserDefaults];
    NSString *str;
    if([userDef objectForKey:@"phoneNumber"] != NULL){
        str = [NSString stringWithFormat:@"\nReset phone number to rescive SMS alarm.\n\n%@",
                         [userDef objectForKey:@"phoneNumber"]];
    }
    else{
        str = [NSString stringWithFormat:@"Enter phone number to rescive SMS alarm."];
        // 13510420818
    }
        
    self.alertController = [UIAlertController alertControllerWithTitle:@"Emergency Receiver"
                                                               message:str
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [self.alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        //这里可设置对象的属性以及点击回调
        textField.keyboardType = UIKeyboardTypePhonePad;
        textField.placeholder = @"+Contry code & number";
        textField.tag = 1;
        //监听编辑内容改变
        //[textField addTarget:self action:@selector(textFieldAction:)
        //                forControlEvents:UIControlEventEditingChanged];
    }];
    
    NSMutableAttributedString *messageText = [[NSMutableAttributedString alloc] initWithString: str];
    [messageText addAttribute:NSFontAttributeName
                        value:[UIFont systemFontOfSize:15]
                        range:NSMakeRange(0, [str length])];
    [messageText addAttribute:NSForegroundColorAttributeName
                        value:[UIColor darkGrayColor]
                        range:NSMakeRange(0, [str length])];
    
    [self.alertController setValue:messageText forKey:@"attributedMessage"];
    
    UIAlertAction *enter = [UIAlertAction actionWithTitle:@"Enter"
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction * _Nonnull action)
                            {
                                if([[self.alertController.textFields firstObject].text length] != 0)
                                {
                                    [self loadingStartAnimating];
                                    [[self.alertController.textFields firstObject] endEditing:YES];
                                    NSUserDefaults *userDef = [NSUserDefaults standardUserDefaults];
                                    if([userDef objectForKey:@"phoneNumber"] != NULL)
                                    {
                                        NSString *phoneSTR = [NSString stringWithFormat:@"%@",[userDef objectForKey:@"phoneNumber"]];
                                        // 電話若不同，取消上次電話的訂閱
                                        if( ![[self.alertController.textFields firstObject].text isEqualToString: phoneSTR])
                                            [self unscribeToPushTopicWithDeviceToken:phoneSTR];
                                    }
                                    // 以這次電話新增訂閱
                                    [self subscribeToPushTopicWithDeviceToken:[self.alertController.textFields firstObject].text];
                                    [userDef setObject:[self.alertController.textFields firstObject].text forKey:@"phoneNumber"];
                                    [userDef synchronize];
                                }
                            }];
    [self.alertController addAction:enter];
    [self presentViewController:self.alertController animated:YES completion:nil];
    // 增加点击事件
    UIWindow *alertWindow = (UIWindow *)[UIApplication sharedApplication].windows.lastObject;
    self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                        action:@selector(hideAlert)];
    [alertWindow addGestureRecognizer:_tap];
}

- (void)hideAlert
{
    UIWindow *alertWindow = (UIWindow *)[UIApplication sharedApplication].windows.lastObject;
    [alertWindow removeGestureRecognizer:_tap];
    [self.alertController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Tool
//取得目前螢幕高度（已根據ios8的調整）
-(CGSize)getScreenSize {
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    if ((NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_7_1) && UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
        return CGSizeMake(screenSize.height, screenSize.width);
    }
    return screenSize;
}

-(void) loadingStartAnimating
{
    if([self.indicatorView isAnimating])
        return;
    _loadingView = [[UIView alloc] initWithFrame:self.view.bounds];
    [_loadingView setBackgroundColor:[UIColor blackColor]];
    [_loadingView setAlpha:0];
    [self.view addSubview:_loadingView];
    
    _indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
                     UIActivityIndicatorViewStyleWhiteLarge];
    [_indicatorView setFrame:self.view.bounds];
    [self.view addSubview:_indicatorView];
    
     __weak ViewController* weakSelf = self;
    [UIView animateWithDuration:0.5f
                          delay:0.0f
                        options:(UIViewAnimationOptionTransitionCrossDissolve)
                     animations:^{
                         [self.loadingView setAlpha:0.7];
                     } completion:^(BOOL finished){
                         [weakSelf.indicatorView startAnimating];
                     }];
}

-(void) loadingStopAnimating
{
    dispatch_async(dispatch_get_main_queue(), ^{
       
        __weak ViewController* weakSelf = self;
        [UIView animateWithDuration:0.5f
                              delay:0.0f
                            options:(UIViewAnimationOptionTransitionCrossDissolve)
                         animations:^{
                             [weakSelf.loadingView setAlpha:0];
                             [weakSelf.indicatorView setAlpha:0];
                         } completion:^(BOOL finished){
                              [self.indicatorView stopAnimating];
                             [weakSelf.loadingView removeFromSuperview];
                             [weakSelf.indicatorView removeFromSuperview];
                         }];
    });
}

#pragma mark - UI
-(void) setupUILayout
{
    UIImageView *back_imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"back"]];
    [self.view addSubview:back_imageView];
    [back_imageView mas_remakeConstraints:^(MASConstraintMaker *make){
        make.size.mas_equalTo(self.view);
    }];
    
    _LED_imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"green"]];
    [self.view addSubview:_LED_imageView];
    [_LED_imageView setAlpha:0];
    [_LED_imageView mas_remakeConstraints:^(MASConstraintMaker *make){
        make.size.mas_equalTo(self.view);
    }];
    
    UIButton *connectBTN = [UIButton buttonWithType:UIButtonTypeCustom];
    [connectBTN setBackgroundImage:[UIImage imageNamed:@"testBTN"] forState:UIControlStateNormal];
    //[connectBTN setTitle:@"TEST/SILENSE\nWEEKLY" forState:UIControlStateNormal];
    //[connectBTN setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    //[connectBTN.titleLabel setNumberOfLines:2];
    //[connectBTN.titleLabel setTextAlignment:NSTextAlignmentCenter];
    //[connectBTN.titleLabel setFont:[UIFont boldSystemFontOfSize:9]];
    [connectBTN addTarget:self action:@selector(testButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:connectBTN];
    [connectBTN mas_remakeConstraints:^(MASConstraintMaker *make){
        make.size.mas_equalTo(xScreenW/4);
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.bottom.mas_equalTo(self.view.mas_centerY).with.offset(10);
        
    }];
    
    UILabel *roomLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, xScreenW, 25)];
    roomLabel.text = @"BEDROOM";
    [roomLabel setTextColor:[UIColor darkGrayColor]];
    [roomLabel setTextAlignment:NSTextAlignmentCenter];
    roomLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.view addSubview:roomLabel];
    [roomLabel mas_remakeConstraints:^(MASConstraintMaker *make){
        make.width.equalTo(self.view.mas_width);
        make.height.mas_equalTo(25);
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.top.mas_equalTo(50);//.with.offset(15);
    }];
    
    /*
    self.connectStatus = [[UILabel alloc] initWithFrame:CGRectMake((xScreenW-250)/2, 40 + xScreenW/2 + 10, 250, 30)];
    self.connectStatus.text = @"Disconnect";
    [self.connectStatus setTextColor:[UIColor blueColor]];
    [self.connectStatus setTextAlignment:NSTextAlignmentCenter];
    self.connectStatus.font = [UIFont boldSystemFontOfSize:18.0];
    //[self.view addSubview:self.connectStatus];
    
    self.batteryLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, xScreenW, 20)];
    self.batteryLabel.text = @"";
    [self.batteryLabel setTextColor:[UIColor darkGrayColor]];
    [self.batteryLabel setTextAlignment:NSTextAlignmentLeft];
    self.batteryLabel.font = [UIFont boldSystemFontOfSize:16];
    //[self.view addSubview:self.batteryLabel];
    
    self.coDensityLabel = [[UILabel alloc] initWithFrame:CGRectMake((xScreenW-250)/2, 120 + xScreenW/2 + 10, 250, 30)];
    self.coDensityLabel.text = @"null";
    [self.coDensityLabel setTextColor:[UIColor darkGrayColor]];
    [self.coDensityLabel setTextAlignment:NSTextAlignmentLeft];
    self.coDensityLabel.font = [UIFont boldSystemFontOfSize:20];
    //[self.view addSubview:self.coDensityLabel];
    
    self.productLifeLabel = [[UILabel alloc] initWithFrame:CGRectMake((xScreenW-250)/2, 160 + xScreenW/2 + 10, 250, 30)];
    self.productLifeLabel.text = @"null";
    [self.productLifeLabel setTextColor:[UIColor darkGrayColor]];
    [self.productLifeLabel setTextAlignment:NSTextAlignmentLeft];
    self.productLifeLabel.font = [UIFont boldSystemFontOfSize:20];
    //[self.view addSubview:self.productLifeLabel];
    
    self.smokeAlertLabel = [[UILabel alloc] initWithFrame:CGRectMake((xScreenW-250)/2, 200 + xScreenW/2 + 10, 250, 30)];
    self.smokeAlertLabel.text = @"null";
    [self.smokeAlertLabel setTextColor:[UIColor darkGrayColor]];
    [self.smokeAlertLabel setTextAlignment:NSTextAlignmentLeft];
    self.smokeAlertLabel.font = [UIFont boldSystemFontOfSize:20];
    //[self.view addSubview:self.smokeAlertLabel];
    
    self.smokeErrState = [[UILabel alloc] initWithFrame:CGRectMake((xScreenW-250)/2, 240 + xScreenW/2 + 10, 250, 30)];
    self.smokeErrState.text = @"null";
    [self.smokeErrState setTextColor:[UIColor darkGrayColor]];
    [self.smokeErrState setTextAlignment:NSTextAlignmentLeft];
    self.smokeErrState.font = [UIFont boldSystemFontOfSize:20];
    //[self.view addSubview:self.smokeErrState];
    */
    
    UIButton *setPhonenumberBTN = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [setPhonenumberBTN setBackgroundImage:[UIImage imageNamed:@"setPhone"]
                                  forState:UIControlStateNormal];
    //[setPhonenumberBTN setBackgroundColor:[UIColor greenColor]];
    [setPhonenumberBTN addTarget:self
                          action:@selector(showSetPhoneNumber:)
                forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:setPhonenumberBTN];
    [setPhonenumberBTN mas_remakeConstraints:^(MASConstraintMaker *make){
        make.size.mas_equalTo(xScreenW/5);
        make.left.mas_equalTo(self.view.mas_left).with.offset(60);
        make.bottom.mas_equalTo(self.view.mas_bottom).with.offset(-30);
    }];
    
    UIButton *detailBTN = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [detailBTN setBackgroundImage:[UIImage imageNamed:@"detailBTN"]
                                 forState:UIControlStateNormal];
    //[detailBTN setBackgroundColor:[UIColor greenColor]];
    [detailBTN addTarget:self
                          action:@selector(showDeviceDetail:)
                forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:detailBTN];
    [detailBTN mas_remakeConstraints:^(MASConstraintMaker *make){
        make.size.mas_equalTo(xScreenW/5);
        make.right.mas_equalTo(self.view.mas_right).with.offset(-60);
        make.bottom.mas_equalTo(self.view.mas_bottom).with.offset(-30);
    }];
    
}

-(void) startLEDBreath
{
    dispatch_async(dispatch_get_main_queue(), ^{
        __weak ViewController* weakSelf = self;
        if([[self.thingDictionary objectForKey:@"SmokeAlertFlag"] integerValue] != 0) // Smoke alarm
            [self.LED_imageView  setImage:[UIImage imageNamed:@"red"]];
        else
            [self.LED_imageView  setImage:[UIImage imageNamed:@"green"]];
        
        
        [UIView transitionWithView:self.LED_imageView
                          duration:1
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
                            if( (int)[weakSelf.LED_imageView alpha] == 0)
                                [weakSelf.LED_imageView setAlpha:1];
                            else
                                [weakSelf.LED_imageView setAlpha:0];
                            
                        }
                        completion:^(BOOL finished){
                            [weakSelf startLEDBreath];
                        }];
    });
    
}

-(void) showSmokeAlarm
{
    [self.alertController dismissViewControllerAnimated:YES completion:nil];

    self.smokeAlertController = [UIAlertController
                                 alertControllerWithTitle:@"Alarm"
                                 message:@"We got smoke alarm right now!"
                                 preferredStyle:UIAlertControllerStyleAlert];
    //Add Buttons
    UIAlertAction* yesButton = [UIAlertAction
                                actionWithTitle:@"Keep Alarm"
                                style:UIAlertActionStyleDestructive
                                handler:^(UIAlertAction * action) {
                                     [self showEmergencyCallAlert];
                                }];
    
    UIAlertAction* noButton = [UIAlertAction
                               actionWithTitle:@"Silence"
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * action) {
                                   //Handle no, thanks button
                                   /*新增 desired 給設備端
                                    {
                                    "state":{
                                    "desired":{
                                    "SmokeAlertFlag" : 3
                                    },
                                    },
                                    }*/
                                   NSNumber *SmokeAlertFlg = [NSNumber numberWithInt:1];
                                   NSDictionary *dic = [NSDictionary dictionaryWithObject:SmokeAlertFlg forKey:@"SmokeMuteFlag"];
                                   NSDictionary *desiredDic = [NSDictionary dictionaryWithObject:dic forKey:@"desired"];
                                   NSDictionary *stateDic = [NSDictionary dictionaryWithObject:desiredDic forKey:@"state"];
                                   
                                   NSString *jsonString = nil;
                                   NSError *error;
                                   NSData *jsonData = [NSJSONSerialization dataWithJSONObject:stateDic
                                                                                      options:NSJSONWritingPrettyPrinted
                                                                                        error:&error];
                                   if (! jsonData) {
                                       NSLog(@"Got an error: %@", error);
                                   } else {
                                       jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                                   }
                                   self.updateSuccess = [self.iotDataManager updateShadow:@"SmokeSensor_Demo" jsonString:jsonString];
                                   //NSLog(@"self.updateSuccess = %d", self.updateSuccess);
                                   [self showEmergencyCallAlert];
                                   //if(self.updateSuccess)
                                    //   [self loadingStartAnimating];
                               }];
    //Add your buttons to alert controller
    [self.smokeAlertController addAction:yesButton];
    [self.smokeAlertController addAction:noButton];
    [self presentViewController:self.smokeAlertController animated:YES completion:nil];
}


-(void) showCheckupAlert
{
    NSString *str = @"\nPress the button on X-Sense Smoke Alarm to run a Safety Checkup.";
    self.alertController = [UIAlertController
                                 alertControllerWithTitle:@"Safety Checkup"
                                                    message:str
                                                preferredStyle:UIAlertControllerStyleAlert];
    
    NSMutableAttributedString *messageText = [[NSMutableAttributedString alloc] initWithString: str];
    [messageText addAttribute:NSFontAttributeName
                        value:[UIFont systemFontOfSize:13]
                        range:NSMakeRange(0, [str length])];
    [messageText addAttribute:NSForegroundColorAttributeName
                        value:[UIColor darkGrayColor]
                        range:NSMakeRange(0, [str length])];
    [self.alertController setValue:messageText forKey:@"attributedMessage"];

    //Add Buttons
    UIAlertAction* yesButton = [UIAlertAction
                                actionWithTitle:@"OK"
                                style:UIAlertActionStyleCancel
                                handler:^(UIAlertAction * action) {
                                    //Handle your yes please button action here
                                    // 不做任何事
                                }];
    //Add your buttons to alert controller
    [self.alertController addAction:yesButton];
    [self presentViewController:self.alertController animated:YES completion:nil];
}

-(void) showEmergencyCallAlert{
    
    NSUserDefaults *userDef = [NSUserDefaults standardUserDefaults];
    NSString *str;
    NSString *titleString = @"Make a phone call";

    if([userDef objectForKey:@"phoneNumber"] == NULL)
        return;
        
    str = [NSString stringWithFormat:@"\n%@\n\nCheck Smoke Alarm immediately.",
            [userDef objectForKey:@"phoneNumber"]];
    
    self.alertController = [UIAlertController
                                 alertControllerWithTitle:titleString
                                 message:str
                                 preferredStyle:UIAlertControllerStyleActionSheet];
    //修改title
    NSMutableAttributedString *alertControllerStr = [[NSMutableAttributedString alloc] initWithString:titleString];
    [alertControllerStr addAttribute:NSForegroundColorAttributeName
                               value:[UIColor redColor]
                               range:NSMakeRange(0, titleString.length)];
    [alertControllerStr addAttribute:NSFontAttributeName
                               value:[UIFont boldSystemFontOfSize:17]
                               range:NSMakeRange(0, titleString.length)];
    [self.alertController setValue:alertControllerStr forKey:@"attributedTitle"];
    
    //Add Buttons
    UIAlertAction* yesButton = [UIAlertAction
                                actionWithTitle:@"Cancel"
                                style:UIAlertActionStyleCancel
                                handler:^(UIAlertAction * action) {
                                    // 不做任何事
                                }];
    
    UIAlertAction* noButton = [UIAlertAction
                               actionWithTitle:@"Call"
                               style:UIAlertActionStyleDestructive
                               handler:^(UIAlertAction * action) {
                                   
                                   NSString *telephoneNumber= [userDef objectForKey:@"phoneNumber"];
                                   NSString * telStr = [NSString stringWithFormat:@"tel:%@",telephoneNumber];
                                   if (@available(iOS 10.0, *)) {
                                       [[UIApplication sharedApplication] openURL:[NSURL URLWithString:telStr]
                                                                          options:nil
                                                                completionHandler:^(BOOL success) {}];
                                   } else {
                                       [[UIApplication sharedApplication] openURL:[NSURL URLWithString:telStr]];
                                   }
                               }];
    
    //Add your buttons to alert controller
    [self.alertController addAction:yesButton];
    [self.alertController addAction:noButton];
    [self presentViewController:self.alertController animated:YES completion:nil];
}

@end
