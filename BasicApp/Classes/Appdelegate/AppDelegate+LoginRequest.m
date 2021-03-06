//
//  AppDelegate+LoginRequest.m
//  KSMovie
//
//  Created by young He on 2018/9/27.
//  Copyright © 2018年 youngHe. All rights reserved.
//

#import "AppDelegate+LoginRequest.h"
#import <objc/runtime.h>
#import "TZLocationManager.h"
#import "PrivacyPermission.h"

@interface AppDelegate()

@end

@implementation AppDelegate (LoginRequest)

#pragma mark - 更新地理位置forAdv
- (void)updateLocationMsg {
    [[TZLocationManager manager] startLocationWithSuccessBlock:^(CLLocation *location, CLLocation *oldLocation) {
        //la 纬度  lo经度
        CLLocationCoordinate2D coordinate = location.coordinate;
        SSLog(@"纬度latitude:%f  经度lo:%f",coordinate.latitude,coordinate.longitude);
        [USERDEFAULTS setObject:[NSString stringWithFormat:@"%f",coordinate.longitude] forKey:LocationLongitude];
        [USERDEFAULTS setObject:[NSString stringWithFormat:@"%f",coordinate.latitude] forKey:LocationLatitude];
        [USERDEFAULTS synchronize];
    } failureBlock:^(NSError *error) {
        
    }];
}

/*
- (void)checks {
    [[SSRequest request] GET:CheckVersionStateUrl parameters:nil success:^(SSRequest *request, id response) {

        NSDictionary *dic = response[@"data"];
        if (dic) {
            if ([dic[@"examine"] boolValue]) {
                [USERDEFAULTS setObject:@"1" forKey:isCK];
            }else {
                [USERDEFAULTS setObject:@"0" forKey:isCK];
            }
        }else {
            [USERDEFAULTS setObject:@"0" forKey:isCK];
        }
        [USERDEFAULTS synchronize];
        
        [self checksFinish];
      
    } failure:^(SSRequest *request, NSString *errorMsg) {
        SSMBToast(errorMsg, MainWindow);
        [NOTIFICATION postNotificationName:FIRSTRegisterFailNoti object:nil];
    }];
}

- (void)checksFinish
{
    [self updateLocationMsg];
    if(!IS_LOGIN) {
        NSString *anonymous = [USERDEFAULTS objectForKey:isAnonymous];
        if (anonymous) {
            if([anonymous integerValue] == 1) {
                [self anonymousLogin];
            }else {
                
            }
        }else {
            [self anonymousRegisterWithAnimation:NO];
        }
        
    }else {
        [self getUserVipMsg];
        [self getUserDownloadMsg];
        [self getDragShowAdvCountMsg];
        [self getFullScreenAdvMsg];
    }
}

// 匿名注册
- (void)anonymousRegisterWithAnimation:(BOOL)isAnimation {
    if (isAnimation) {
        SSGifShow(MainWindow, @"加载中");
    }
    [[SSRequest request] POSTAboutLogin:AnonymousRegisterUrl parameters:nil success:^(SSRequest *request, id response) {
        
        if (isAnimation) {
            SSDissMissAllGifHud(MainWindow, NO);
        }
        
        [USERDEFAULTS setObject:@"1" forKey:FIRSTRegisterSuccess];
        [USERDEFAULTS synchronize];
        if (response[@"data"]) {
            [[UserManager shareManager] saveUserDataWithDic:response[@"data"]];
        }else {
            [USERDEFAULTS setObject:@"0" forKey:FIRSTRegisterSuccess];
            [USERDEFAULTS synchronize];
            [NOTIFICATION postNotificationName:FIRSTRegisterFailNoti object:nil];
        }
        
    } failure:^(SSRequest *request, NSString *errorMsg) {
        
        if(isAnimation) {
            SSDissMissAllGifHud(MainWindow, NO);
        }
        
        SSMBToast(errorMsg, MainWindow);
        
        [USERDEFAULTS setObject:@"0" forKey:FIRSTRegisterSuccess];
        [USERDEFAULTS synchronize];
        [NOTIFICATION postNotificationName:FIRSTRegisterFailNoti object:nil];
        
    }];
}

- (void)anonymousLogin {
    [[SSRequest request] POSTAboutLogin:AnonymousLoginUrl parameters:nil success:^(SSRequest *request, id response) {
        
        [[UserManager shareManager] saveUserDataWithDic:response[@"data"]];

    } failure:^(SSRequest *request, NSString *errorMsg) {
        SSMBToast(errorMsg, MainWindow);
        [USERDEFAULTS setObject:@"0" forKey:FIRSTRegisterSuccess];
        [USERDEFAULTS synchronize];
        [NOTIFICATION postNotificationName:FIRSTRegisterFailNoti object:nil];
    }];
}

- (void)getUserVipMsg {
    [[SSRequest request]GET:VIPUserMsgUrl parameters:nil success:^(SSRequest *request, id response) {
        
        SSLog(@"%@",response);
        VIPAllAccountInfoModel *m = [VIPAllAccountInfoModel mj_objectWithKeyValues:response[@"data"]];
        if (m.rightsAccountInfo && m.rightsAccountInfo.expireAt.length>0) {
            [USERDEFAULTS setObject:m.rightsAccountInfo.expireAt forKey:VIPExpireTime];
            [USERDEFAULTS setObject:@"1" forKey:isVIPUser];
        }else {
            [USERDEFAULTS setObject:@"0" forKey:VIPExpireTime];
            [USERDEFAULTS setObject:@"0" forKey:isVIPUser];
        }
        [USERDEFAULTS synchronize];
        
    } failure:^(SSRequest *request, NSString *errorMsg) {
        
        [USERDEFAULTS setObject:@"0" forKey:VIPExpireTime];
        [USERDEFAULTS setObject:@"0" forKey:isVIPUser];
        [USERDEFAULTS synchronize];
        
    }];
}

- (void)getUserDownloadMsg {
    [[SSRequest request]GET:DownloadMaxCountMsgUrl parameters:nil success:^(SSRequest *request, id response) {
        
        SSLog(@"%@",response);

        NSDictionary *dic = response[@"data"];
        if(dic && dic[@"currentDownloadNum"]) {
            [USERDEFAULTS setObject:dic[@"currentDownloadNum"] forKey:MaxDownloadCount];
            [USERDEFAULTS synchronize];
            
            NSInteger newCount = [dic[@"currentDownloadNum"] integerValue];
            // 通知
            [[NSNotificationCenter defaultCenter] postNotificationName:LJDownloadMaxConcurrentCountChangeNotification object:[NSNumber numberWithInteger:newCount]];
        }
        
    } failure:^(SSRequest *request, NSString *errorMsg) {
        
    }];
}

- (void)getDragShowAdvCountMsg {
    [[SSRequest request]GET:DragShowAdvCountUrl parameters:nil success:^(SSRequest *request, id response) {
        
        SSLog(@"%@",response);
        
        NSDictionary *dic = response[@"data"];
        if(dic && dic[@"count"]) {
            [USERDEFAULTS setObject:dic[@"count"] forKey:DragShowAdvCount];
            [USERDEFAULTS synchronize];
        }
        
    } failure:^(SSRequest *request, NSString *errorMsg) {
        
    }];
}


- (void)getSplashAdvMsg {

    [[BuryingPointManager shareManager] buryingPointWithEventID:BP_AppSplashRequest andParameters:@{AD_NAME:@"GDT"}];
    
    NSDictionary *dic = [USER_MANAGER getAdvParamDicWithPositionID:kGDTPositionId_splash slotWidth:ScreenWidth slotHeight:ScreenHeight];
   
    [[SSRequest request]POST:Adv_SplashUrl parameters:dic.mutableCopy success:^(SSRequest *request, id response) {
        
        if(response[@"data"]) {  //有广告.
            AdvertisementModel *m = [AdvertisementModel mj_objectWithKeyValues:response[@"data"]];
            [m refreshModel];
            self.advModel = m;
            switch (m.adType) {
                case ADTypeGDT:
                {
                    [self splashAdvWithGDT:m];
                }
                    break;
                case ADTypeKS:
                {
                    [self showApiSplashAdv];
                }
                    break;
                default:
                    break;
            }
        }
        
    } failure:^(SSRequest *request, NSString *errorMsg) {
        SSLog(@"");
    }];
}

- (void)splashAdvWithGDT:(AdvertisementModel *)model {
    //reqCallBackList
    [USER_MANAGER callBackAdvWithUrls:model.reqCallBackList];
    
    //设置开屏底部自定义LogoView，展示半屏开屏广告
    UIView *_bottomView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, ScreenWidth, self.sizeH(100))];
    UIImageView *logo = [[UIImageView alloc] initWithImage:[UIImage imageWithData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SplashBottomLogo" ofType:@"png"]]]];
    logo.frame = CGRectMake(0, 0, ScreenWidth, self.sizeH(40));
    logo.center = _bottomView.center;
    logo.contentMode = UIViewContentModeScaleAspectFit;
    [_bottomView addSubview:logo];
    logo.center = _bottomView.center;
    _bottomView.backgroundColor = [UIColor whiteColor];
    
    self.splashAd = [[GDTSplashAd alloc] initWithAppId:kGDTMobSDKAppId placementId:model.positionCode];
    self.splashAd.delegate = self;
    self.splashAd.fetchDelay = 3;
    
    UIImage *splashImage = [UIImage imageNamed:@"SplashNormal"];
    if (isIPhoneXSeries()) {
        splashImage = [UIImage imageNamed:@"SplashX"];
    } else if ([UIScreen mainScreen].bounds.size.height == 480) {
        splashImage = [UIImage imageNamed:@"SplashSmall"];
    }
    self.splashAd.backgroundImage = splashImage;
    [self.splashAd loadAdAndShowInWindow:MainWindow withBottomView:_bottomView skipView:nil];
}

- (void)setSplashAd:(GDTSplashAd *)splashAd {
    objc_setAssociatedObject(self, splashAdKey, splashAd, OBJC_ASSOCIATION_RETAIN);
}

- (GDTSplashAd *)splashAd {
    return objc_getAssociatedObject(self, splashAdKey);
}

-(void)setAdvModel:(AdvertisementModel *)advModel {
    objc_setAssociatedObject(self, advModelKey, advModel, OBJC_ASSOCIATION_RETAIN);
}

-(AdvertisementModel *)advModel {
    return objc_getAssociatedObject(self, advModelKey);
}

//-----------delegate
- (void)splashAdSuccessPresentScreen:(GDTSplashAd *)splashAd
{
    [USER_MANAGER callBackAdvWithUrls:self.advModel.fillCallBackList];
}

- (void)splashAdFailToPresent:(GDTSplashAd *)splashAd withError:(NSError *)error
{
    SSLog(@"%s%@",__FUNCTION__,error);
}

- (void)splashAdExposured:(GDTSplashAd *)splashAd
{
    [USER_MANAGER callBackAdvWithUrls:self.advModel.showCallBackUrlList];
    [[BuryingPointManager shareManager] buryingPointWithEventID:BP_AppSplashShow andParameters:@{AD_NAME:@"GDT"}];
}

- (void)splashAdClicked:(GDTSplashAd *)splashAd
{
    [USER_MANAGER callBackAdvWithUrls:self.advModel.clickCallBackUrlList];
    [[BuryingPointManager shareManager] buryingPointWithEventID:BP_AppSplashClick andParameters:@{AD_NAME:@"GDT"}];
}

- (void)splashAdApplicationWillEnterBackground:(GDTSplashAd *)splashAd
{
    SSLog(@"%s",__FUNCTION__);
}

- (void)splashAdWillClosed:(GDTSplashAd *)splashAd
{
    SSLog(@"%s",__FUNCTION__);
}

- (void)splashAdClosed:(GDTSplashAd *)splashAd
{
    SSLog(@"%s",__FUNCTION__);
    self.splashAd = nil;
}

- (void)splashAdWillPresentFullScreenModal:(GDTSplashAd *)splashAd
{
    SSLog(@"%s",__FUNCTION__);
}

- (void)splashAdDidPresentFullScreenModal:(GDTSplashAd *)splashAd
{
    SSLog(@"%s",__FUNCTION__);
}

- (void)splashAdWillDismissFullScreenModal:(GDTSplashAd *)splashAd
{
    SSLog(@"%s",__FUNCTION__);
}

- (void)splashAdDidDismissFullScreenModal:(GDTSplashAd *)splashAd
{
    SSLog(@"%s",__FUNCTION__);
}

//-(void)setLocation:(CLLocation *)location {
//    objc_setAssociatedObject(self, locationKey, location, OBJC_ASSOCIATION_RETAIN);
//}
//
//-(CLLocation *)location {
//    return objc_getAssociatedObject(self, locationKey);
//}

- (void)updateUserAgent {
    UIWebView *webView = [[UIWebView alloc]initWithFrame:CGRectZero];
    NSString *userAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
    [USERDEFAULTS setObject:userAgent forKey:@"webUserAgent"];
    [USERDEFAULTS synchronize];
}

- (void)initTTAdv {
    [BUAdSDKManager setAppID:JRTTAdvAppId];
    [BUAdSDKManager setIsPaidApp:NO];
#if DEBUG
    //是否打开log信息，默认没有
        [BUAdSDKManager setLoglevel:BUAdSDKLogLevelDebug];
#endif
}

//长片累计播放了 百分之多少 之后, 显示全屏视频广告
- (void)getFullScreenAdvMsg {
//    [[SSRequest request]GET:FullScreenAdvPercentUrl parameters:nil success:^(SSRequest *request, id response) {
//
//        SSLog(@"%@",response);
//
//        NSArray *arr = response[@"data"];
//        if(arr) {
////            [USERDEFAULTS setObject:dic[@"count"] forKey:DragShowAdvCount];
////            [USERDEFAULTS synchronize];
//        }
//
//    } failure:^(SSRequest *request, NSString *errorMsg) {
//
//    }];
}

//-----------API_Splash_Adv---------//
- (void)showApiSplashAdv {
    
    [USER_MANAGER callBackAdvWithUrls:self.advModel.showCallBackUrlList];
    
    SplashScreenView *advertiseView = [[SplashScreenView alloc] initWithFrame:self.window.bounds];
    advertiseView.advModel = self.advModel;
    advertiseView.imgLinkUrl = self.advModel.goToUrl;
    //设置广告页显示的时间
    [advertiseView showSplashScreenWithTime:3 andImgUrl:self.advModel.url];
}
*/
@end
