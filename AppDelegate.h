//
//  AppDelegate.h
//  iFamily
//
//  Created by letianpai1 on 15/1/27.
//  Copyright (c) 2015年 SpiralBird. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "IFInterfaceErrorObserver.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) IFInterfaceErrorObserver *interfaceErrorObserver;

+ (AppDelegate *)shareAppdalegate;

//打开主界面
- (void) openMainView;
//打开登录界面
- (void) openLoginView;


@end

