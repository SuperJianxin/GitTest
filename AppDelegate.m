//
//  AppDelegate.m
//  iFamily
//
//  Created by letianpai1 on 15/1/27.
//  Copyright (c) 2015年 SpiralBird. All rights reserved.
//

#import "AppDelegate.h"
#import "IFModelLayer.h"
#import "IFUserManager.h"
#import "IFTaskDetailViewController.h"
#import "IFAlarmViewController.h"
#import "IFImportantDayDetailController.h"
#import "FENavigationController.h"
#import "BPush.h"
#import "WeChatShareWrapper.h"
#import "IFModelLayer.h"
#import "MBProgressHUD.h"
#import "LTPDeviceInfo.h"
#import "LTPInterfaceTokenManager.h"
#import "LTPPushMessageProcesser.h"
#import "FEIntroductionView.h"
#import "IFCommentBusiness.h"
#import "IFLocalAlarmManager.h"
#import "IFImportantDayBusiness.h"
#import "IFTaskBusiness.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define InviteUserTipAlertViewTag 10
#define AlarmAlertViewTag 2

@interface AppDelegate ()
<WXApiDelegate,
UIAlertViewDelegate>
{
    BOOL showingInviteAlert;
    BOOL showingInviteTipAlert;
    BOOL showLoginView;
    MBProgressHUD *HUD;
    
    NSDictionary *inviteUserInfo;
    SystemSoundID soundID;
}

@end

@implementation AppDelegate

+ (AppDelegate *)shareAppdalegate
{
    //
    return (AppDelegate *)[UIApplication sharedApplication].delegate;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    //初始化网络请求检测
    self.interfaceErrorObserver=[[IFInterfaceErrorObserver alloc] init];
    
    [self registerPush];
    [self register3PartySDK:launchOptions];
    [self registerNotificationForRelationChange];
    
    if (![IFUserManager currentUser]) {
        [self openLoginView];
    }
    else
    {
        [self updateUserInfo];
    }
    
    //是否第一次启动
    BOOL launched=[[NSUserDefaults standardUserDefaults] boolForKey:LaunchFirstUserKey];
    if (!launched) {
        
        /*
        FEIntroductionView *launchView=[[FEIntroductionView alloc] initWithFrame:self.window.bounds];
        [self.window addSubview:launchView];
         */
        
        //取消所有的闹钟
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
    }
    
    return YES;
}

#pragma mark 初始化App
- (void) registerPush
{
    if([[UIApplication sharedApplication] respondsToSelector:@selector(registerForRemoteNotifications)])
    {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings
                                                                             settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge)
                                                                             categories:nil]];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }
    else
    {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
         (UIRemoteNotificationTypeBadge |
          UIRemoteNotificationTypeSound |
          UIRemoteNotificationTypeAlert)];
    }
}

- (void) register3PartySDK:(NSDictionary *)launchOptions
{
    //初始化百度SDK
    [BPush setupChannel:launchOptions];
    [BPush setDelegate:self];
    //初始化微信SDK
    [WeChatShareWrapper initWeixinShareWithAppId:kWeChatAppID];
}

- (void) registerNotificationForRelationChange
{
    //处理绑定关系的改变
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bindedUserNoti:)
                                                 name:LTPUserBindRelationNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bindedUserNoti:)
                                                 name:LTPUserUnBindRelationNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bindedUserNoti:)
                                                 name:LTPUserChangeBindRelationNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inviteUserNoti:)
                                                 name:LTPUserBeInvitedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userForceLoginoutNoti:)
                                                 name:LTPUserForceLogOutNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(showInviteTip:)
                                                 name:ShowInviteTipNitification
                                               object:nil];
    
}

#pragma mark App状态切换
- (void) openMainView
{
    UIStoryboard *storyboard = self.window.rootViewController.storyboard;
    UIViewController* cont = [storyboard instantiateInitialViewController];
    
    self.window.rootViewController = cont;
    [self.window makeKeyAndVisible];
}

- (void) openLoginView
{
    UIStoryboard *storyboard = self.window.rootViewController.storyboard;
    UIViewController* cont = (UIViewController*)[storyboard instantiateViewControllerWithIdentifier:@"LoginAndRegisterNav"];
    
    self.window.rootViewController = cont;
    [self.window makeKeyAndVisible];
    
    showLoginView=YES;
}

#pragma mark 用户状态更新
- (void) bindedUserNoti:(NSNotification *)noti
{
    FELOG(@"bindedUserNoti:%@",noti.name);
    
    if (showLoginView) {
        return;
    }
    
    HUD=[[MBProgressHUD alloc] initWithView:self.window.rootViewController.view];
    HUD.userInteractionEnabled=YES;
    HUD.removeFromSuperViewOnHide=YES;
    HUD.dimBackground=YES;
    HUD.labelText=@"正在重新加载...";
    HUD.labelFont=[UIFont boldSystemFontOfSize:22];
    [self.window.rootViewController.view addSubview:HUD];
    [HUD show:YES];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)( 2* NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //重新加载主界面
        [self openMainView];
        [HUD hide:YES];
    });
}

- (void) inviteUserNoti:(NSNotification *)noti
{
    FELOG(@"接收到邀请：%@",noti.userInfo);

    inviteUserInfo=noti.userInfo;
    NSString *fromName=[noti.userInfo objectForKey:LTPUserBeInvitedFromFullNameInfoKey];
    
    if (!showingInviteAlert) {
        [IFUserManager updateUserInfoForUser:[IFUserManager currentUser] WithCompletion:nil];
        
        NSString *alertStr=[NSString stringWithFormat:@"“%@”邀请您进入家庭",fromName];
        UIAlertView *alert=[[UIAlertView alloc] initWithTitle:@"消息"
                                                      message:alertStr
                                                     delegate:self
                                            cancelButtonTitle:@"确定"
                                            otherButtonTitles:nil, nil];
        alert.delegate=self;
        [alert show];
    }
}

- (void) userForceLoginoutNoti:(NSNotification *)noti
{
    [@"该用户在其他设备登录" showInAlertViewWithTitle:nil];
    [[AppDelegate shareAppdalegate] openLoginView];
}

- (void) updateUserInfo
{
    if ([IFUserManager currentUser]) {
        if ([LTPInterfaceTokenManager shareManager].token.length>0
            &&![LTPInterfaceTokenManager shareManager].timeout) {
            
            //更新重要的日期
            [IFImportantDayBusiness updateCachedDayInfo];
            //更新下一次提醒
            [IFTaskBusiness updateNextUpdatetime];
            
            [[LTPInterfaceTokenManager shareManager] updateTokenWithUser:[IFUserManager currentUser] WithCompletion:^(NSString *uid) {
                FELOG(@"更新token成功");
                
                IFUser *user=[IFUserManager currentUser];
                
                //更新用户信息
                [IFUserManager updateUserInfoForUser:user WithCompletion:^(BOOL bStatus, id data, NSError *error) {
                    if(![IFUserManager currentUser].hasCouple)
                    {
                        [[NSNotificationCenter defaultCenter] postNotificationName:ShowInviteTipNitification object:nil];
                    }
                }];
                
                //获取最新评论数量
                [IFCommentBusiness getNewCommentCountWithCompletion:^(BOOL success, NSError *error) {
                    if (success) {
                        [[NSNotificationCenter defaultCenter] postNotificationName:GetNewMessageCountNitification object:nil];
                    }
                }];
                
            } failure:^(NSError *error) {
                FELOG(@"更新token失败:%@",error);
                
            }];
        }
        else
        {
            IFUser *user=[IFUserManager currentUser];
            [IFUserManager updateUserInfoForUser:user WithCompletion:^(BOOL bStatus, id data, NSError *error) {
                if(![IFUserManager currentUser].hasCouple)
                {
                    [[NSNotificationCenter defaultCenter] postNotificationName:ShowInviteTipNitification object:nil];
                }
                
            }];
        }
    }
}

- (void) showInviteTip:(NSNotification *)noti
{
    if ([NSStringFromClass([self.window.rootViewController.presentedViewController class]) isEqualToString:@"FENavigationController"]) {
        return;
    }
    
    if (!showingInviteTipAlert) {
        UIAlertView *alertView=[[UIAlertView alloc] initWithTitle:@"提示"
                                                          message:@"邀请个伙伴，就可以更Happy的玩耍我们的App~"
                                                         delegate:self
                                                cancelButtonTitle:@"下次再说"
                                                otherButtonTitles:@"去邀请", nil];
        
        alertView.tag=InviteUserTipAlertViewTag;
        [alertView show];
    }
    
}

#pragma mark App delegate
- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    FELOG(@"remote noti:%@",userInfo);
    
    [BPush handleNotification:userInfo];
    [LTPPushMessageProcesser processPushUserInfo:userInfo];
}

-(void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    
    IFAlarmViewController *alarm=[[IFAlarmViewController alloc] init];
    alarm.alarmNotification=notification;
    [[AppDelegate shareAppdalegate].window.rootViewController presentViewController:alarm
                                                                           animated:NO
                                                                         completion:nil];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    
    [BPush registerDeviceToken:deviceToken]; // 必须
    [BPush bindChannel];
}

- (BOOL) application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
    return [WXApi handleOpenURL:url delegate:self];
}

- (BOOL) application:(UIApplication *)application
             openURL:(NSURL *)url
   sourceApplication:(NSString *)sourceApplication
          annotation:(id)annotation
{
    return [WXApi handleOpenURL:url delegate:self];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [[IFSQLiteDataManager shareManager] saveContext];
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    if ([application applicationIconBadgeNumber]>0) {
        [application setApplicationIconBadgeNumber:0];
    }
    
    //更新用户信息
    [self updateUserInfo];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (![LTPDeviceInfo enablePush]) {
            NSString *alert=@"需要你打开‘通知’功能后才能使用。请打开‘设置’->‘通知’，找到我们的App，打开通知开关";
            [alert showInAlertViewWithTitle:nil];
        }
    });
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [[IFSQLiteDataManager shareManager] saveContext];
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - UIAlertView Delegate
- (void) willPresentAlertView:(UIAlertView *)alertView
{
    if (alertView.tag==InviteUserTipAlertViewTag) {
        showingInviteTipAlert=YES;
    }
}

- (void) alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView.tag==InviteUserTipAlertViewTag) {
        showingInviteTipAlert=NO;
    }
}

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag==AlarmAlertViewTag)
    {
        AudioServicesDisposeSystemSoundID(soundID);
    }
    else if (alertView.tag==InviteUserTipAlertViewTag)
    {
        if (buttonIndex==1) {
            UIStoryboard *storyboard = [AppDelegate shareAppdalegate].window.rootViewController.storyboard;
            UIViewController* cont = (UIViewController*)[storyboard instantiateViewControllerWithIdentifier:@"InviteCodeNav"];
            
            [self.window.rootViewController presentViewController:cont animated:YES completion:nil];
        }
    }
}

#pragma mark 微信回调
-(void) onReq:(BaseReq*)req
{
    FELOG(@"%@",req);
}

-(void) onResp:(BaseResp*)resp
{
    if ([resp isKindOfClass:[SendAuthResp class]]) {
        SendAuthResp *loginResp=(SendAuthResp *)resp;
        switch (loginResp.errCode) {
            case 0:
                FELOG(@"授权成功");
                FELOG(@"code:%@",loginResp.code);
                [[NSNotificationCenter defaultCenter] postNotificationName:WeChatAuthSuccessNitification
                                                                    object:loginResp.code];
                break;
            case -2:
                [@"您取消了微信授权" showInAlertViewWithTitle:nil];
                [[NSNotificationCenter defaultCenter] postNotificationName:WeChatAuthFailNitification
                                                                    object:nil];
                break;
            case -4:
                [@"您拒绝了微信授权" showInAlertViewWithTitle:nil];
                [[NSNotificationCenter defaultCenter] postNotificationName:WeChatAuthFailNitification
                                                                    object:nil];
                break;
            default:
                break;
        }
    }
}

#pragma mark push回调
- (void) onMethod:(NSString*)method response:(NSDictionary*)data
{
    if ([BPushRequestMethod_Bind isEqualToString:method])
    {
        FELOG(@"%@",data);
    }
}

@end
