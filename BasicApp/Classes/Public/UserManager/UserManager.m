//
//  UserManager.m
//  NewTarget
//  Copyright © 2016年  rw. All rights reserved.
//

#import "UserManager.h"
#import "AFNetworkReachabilityManager.h"
#import "LoginViewController.h"
#import "LEEAlert.h"
#import "UINavigationController+WXSTransition.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import "sys/utsname.h"
#import "AppDelegate+LoginRequest.h"
#import "AppDelegate+GeTuiSDK.h"
#import <AdSupport/AdSupport.h>
#import <UMAnalytics/MobClick.h>
#import "JQFMDB.h"
#import "BAShareManage.h"
#import "MineViewController.h"
#import "SimulateIDFA.h"

@interface UserManager()
@property (nonatomic,copy)  void(^comple)(void);
@end

@implementation UserManager

NSString *const ShortVideoAdvShowKey = @"ShortVideoAdvShowKey";
NSString *const DailyPopOutKey = @"DailyPopOutKey";

#define MaxHistoryCount 200  //观看历史最大保存数量

+(id)shareManager {
    static UserManager * manager = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

- (instancetype)init {
    if (self = [super init]) {
        _isLogin = NO;
    }return self;
}

// 判断是否登录
-(BOOL)isLogin {
    NSString *isLogin = [USERDEFAULTS objectForKey:isAnonymous];
    if (isLogin) {
        if([isLogin integerValue] == 1) {
            return NO;
        }else {
            return YES;
        }
    }else {
        return NO;
    }
}

//是否VIP
-(BOOL)isVIPUser {
    NSString *isVIP = [USERDEFAULTS objectForKey:isVIPUser];

    if (isVIP) {
        if([isVIP integerValue] == 1) {
            NSString *expireTimeStr = [USERDEFAULTS objectForKey:VIPExpireTime];
            NSString *expireDate = [Helper convertDateWithTime:expireTimeStr];
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            
            [dateFormatter setDateFormat:@"yyyy-MM-dd"];
            
            NSDate *dateEx = [dateFormatter dateFromString:expireDate];
            
            NSComparisonResult re = [dateEx compare:[NSDate date]];
            if (re == NSOrderedSame) {
                return YES;
            }else if (re == NSOrderedDescending){  //down
                return YES;
            }else {  //up
                return NO;
            }
        }else {
            return NO;
        }
    }else {
        return NO;
    }
}

/**
 *  保存数据
 */
- (void)saveUserDataWithDic:(NSDictionary *)dic {
    [USERDEFAULTS setObject:dic forKey:USER_DATA];
    [USERDEFAULTS setObject:dic[@"anonymous"] forKey:isAnonymous];
    [USERDEFAULTS setObject:@"0" forKey:isVIPUser];
    [USERDEFAULTS setObject:dic[@"createTime"] forKey:CREATE_Time];
    [USERDEFAULTS setObject:dic[@"credential"] forKey:CREDENTIAL];
    [USERDEFAULTS setObject:dic[@"nickName"] forKey:USER_NickName];
    [USERDEFAULTS setObject:dic[@"id"] forKey:USER_ID];
    [USERDEFAULTS setObject:dic[@"portrait"] forKey:USER_ICON];
    [USERDEFAULTS setObject:dic[@"userName"] forKey:USER_UserName];
    [USERDEFAULTS setObject:@"3" forKey:MaxDownloadCount];
    [USERDEFAULTS synchronize];
    
    if ([dic[@"anonymous"] integerValue]==1) { //匿名注册 or 匿名登录 成功, 通知首页请求数据
        [NOTIFICATION postNotificationName:AnonymousSuccessNoti object:nil];
    }else {  //正常登录成功, 绑定个推别名
        [g_App bindGeTuiWithIsBind:YES];
    }
    
    [g_App getUserVipMsg];
    [g_App getUserDownloadMsg];
    [g_App getDragShowAdvCountMsg];
    [g_App getFullScreenAdvMsg];
    
    [NOTIFICATION postNotificationName:RefreshUserMsgNoti object:nil];

}

- (void)removeUserAllData {
    [USERDEFAULTS removeObjectForKey:USER_DATA];
    [USERDEFAULTS removeObjectForKey:isAnonymous];
    [USERDEFAULTS removeObjectForKey:isVIPUser];
    [USERDEFAULTS removeObjectForKey:CREATE_Time];
    [USERDEFAULTS removeObjectForKey:CREDENTIAL];
    [USERDEFAULTS removeObjectForKey:USER_NickName];
    [USERDEFAULTS removeObjectForKey:USER_ID];
    [USERDEFAULTS removeObjectForKey:USER_ICON];
    [USERDEFAULTS removeObjectForKey:USER_UserName];
    [USERDEFAULTS removeObjectForKey:MaxDownloadCount];
    [USERDEFAULTS removeObjectForKey:DragShowAdvCount];
    [USERDEFAULTS synchronize];
}

// *  保存首页分类
- (void)saveHomeCategoryWithDic:(NSDictionary *)dic {
    [USERDEFAULTS setObject:dic forKey:@"HomeCategory"];
    [USERDEFAULTS synchronize];
}

//UserID
- (NSString *)getUserID {
    NSString * userID = [USERDEFAULTS objectForKey:[USER_ID copy]];
    return userID ? userID : @"";
}

//用户头像UrlString
-(NSString *)getUserIcon {
    if (![self isLogin]) {
        return @"";
    }
    NSString * str = [USERDEFAULTS objectForKey:USER_ICON];
    return str ? str : @"";
}

-(NSString *)getUserNickName {
    if (![self isLogin]) {
        return @"";
    }
    NSString * str = [USERDEFAULTS objectForKey:USER_NickName];
    return str ? str : @"";
}

//USER_UserName
-(NSString *)getUserName {
    if (![self isLogin]) {
        return @"";
    }
    NSString * str = [USERDEFAULTS objectForKey:USER_UserName];
    return str ? str : @"";
}

-(NSInteger)getMaxDownloadCount {
    NSString *str = [USERDEFAULTS objectForKey:MaxDownloadCount];
    if (str) {
        if ([str integerValue] > 0) {
            return  [str integerValue];
        }else {
            return 3;
        }
    }else {
        return 3;
    }
}

-(NSInteger)getDragShowAdvCount {
    NSString *str = [USERDEFAULTS objectForKey:DragShowAdvCount];
    if (str) {
        if ([str integerValue] > 0) {
            return  [str integerValue];
        }else {
            return 0;
        }
    }else {
        return 0;
    }
}

/**
 * token
 **/
-(NSString *)userToken
{
    NSString * str = [USERDEFAULTS objectForKey:@"token"];
    return str?str:@"";
}
/**
 * 头像url
 */
-(NSString *)avatarUrl
{
    NSString * str = [USERDEFAULTS objectForKey:[Avatar copy]];
    return str?str:@"";
}
/**
 *  缓存的名字
 */
-(NSString *)CEUserName
{
    NSString * str = [USERDEFAULTS objectForKey:@"nickName"];
    return str?[NSString stringWithFormat:@"%@",[USERDEFAULTS objectForKey:@"nickName"]]:@"";
}

/**
 * 用户手机
 */
-(NSString*)mobile
{
    NSString * mobile = [USERDEFAULTS objectForKey:@"mobile"]?[USERDEFAULTS objectForKey:@"mobile"]:@"";
    return mobile;
}

-(void)saveMobileWith:(NSString *)str
{
    [USERDEFAULTS setObject:str forKey:[MOBILE copy]];
    [USERDEFAULTS synchronize];
}
/**
 * 通过键获取值
 **/
-(id)dataStrForKey:(NSString*)key
{
    id data = [USERDEFAULTS objectForKey:USER_DATA];
    if(data!=nil){
    id  str=  [data isKindOfClass:[NSDictionary class]]?data[key]:@"";
    return str?str:@"";
    }else
        return @"";
    
}
/**
 * 修改头像
 **/
-(void)reloadAvatar:(NSString *)imgUrl
{
    [USERDEFAULTS setObject:imgUrl forKey:USER_ICON];
    [USERDEFAULTS synchronize];
}
/**
 * 修改昵称
 **/
-(void)reloadNickName:(NSString *)name
{
    [USERDEFAULTS setObject:name forKey:USER_NickName];
    [USERDEFAULTS synchronize];
}

-(void)gotoLogin {
    LoginViewController * login = [[LoginViewController alloc]init];
    KSBaseNavViewController  * nav = [[KSBaseNavViewController alloc]initWithRootViewController:login];
    KSBaseNavViewController * selNav = g_App.tabBarVC.selectedViewController;
    KSBaseViewController * baseView = (KSBaseViewController*)selNav.topViewController;
    [baseView wxs_presentViewController:nav makeTransition:^(WXSTransitionProperty *transition) {
        transition.animationType =  WXSTransitionAnimationTypeInsideThenPush;
        transition.backGestureEnable = NO;
        transition.backGestureType = WXSGestureTypePanRight;
    }];
}

/** 从某个vc去登录, 成功后返回这个vc*/
- (void)gotoLoginFromVC:(UIViewController *)vcFrom {
    LoginViewController * login = [[LoginViewController alloc]init];
    login.vcFrom = vcFrom;
    login.hidesBottomBarWhenPushed = YES;
    [vcFrom.navigationController pushViewController:login animated:YES];
}

//是否是测试服
//YES测试服
//NO正式服
-(BOOL)isDevStatus {
    if ([USERDEFAULTS objectForKey:@"isDevStatusKey"]) {
        NSString *isDev = [USERDEFAULTS objectForKey:@"isDevStatusKey"];
        return [isDev boolValue];
    }else {
        [USERDEFAULTS setObject:@"1" forKey:@"isDevStatusKey"];
        [USERDEFAULTS synchronize];
        return YES;
    }
}

-(BOOL)isCK {
    NSString *isIR = [USERDEFAULTS objectForKey:isCK];
    if (isIR) {
        return [isIR boolValue];
    }else {
        return NO;
    }
}

//服务器地址, 非登录类接口
-(NSString*)serverAddress {
    return [self isDevStatus] ? DevServerURL_Normal : ServerURL_Normal;
}

//服务器地址, 登录类接口
-(NSString*)serverAddressWithLogin {
    return [self isDevStatus] ? DevServerURL_Login : ServerURL_Login;
}

//非登录类 公钥
-(NSString*)publicKey {
    return [self isDevStatus] ? DevPUBLIC_KEY_Normal: PUBLIC_KEY_Normal;
}

//登录类 公钥
-(NSString*)publicKeyWithLogin {
    return [self isDevStatus] ? DevPUBLIC_KEY_Login : PUBLIC_KEY_Login;
}

//获取User-Agent
-(NSString*)getUserAgent {
    if([USERDEFAULTS objectForKey:@"webUserAgent"]) {
        return [USERDEFAULTS objectForKey:@"webUserAgent"];
    }else {
        UIWebView *webView = [[UIWebView alloc]initWithFrame:CGRectZero];
        NSString *userAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
        [USERDEFAULTS setObject:userAgent forKey:@"webUserAgent"];
        [USERDEFAULTS synchronize];
        return userAgent;
    }
}

//获取版本号
- (NSString *)getVersionStr {
    NSDictionary *infoDic = [[NSBundle mainBundle] infoDictionary];
    return infoDic[@"CFBundleShortVersionString"];
}

//获取SIM Type   //  0:未知 1：中国移动 2: 中国联通 3: 中国电信
- (NSString *)getSimType {
    CTTelephonyNetworkInfo *networkInfo = [[CTTelephonyNetworkInfo
                                            alloc] init];
    CTCarrier *carrier = networkInfo.subscriberCellularProvider;
    NSString *carrier_country_code = carrier.isoCountryCode;
    if (carrier_country_code == nil) {
        carrier_country_code = @"";
    }
    //国家编号
    NSString *CountryCode = carrier.mobileCountryCode;
    if (CountryCode == nil) {
        CountryCode = @"";
    }
    //网络供应商编码
    NSString *NetworkCode = carrier.mobileNetworkCode;
    if (NetworkCode == nil)
    {
        NetworkCode = @"";
    }
    NSString *mobile_country_code = [NSString
                                     stringWithFormat:@"%@%@",CountryCode,NetworkCode];
    if (mobile_country_code == nil)
    {
        mobile_country_code = @"";
    }
    NSString *carrier_name = @"00";
    NSString *code = [carrier mobileNetworkCode];
    if ([code isEqualToString:@"00"] || [code isEqualToString:@"02"] || [code isEqualToString:@"07"]) {
        //移动
        carrier_name = @"01";
    }
    if ([code isEqualToString:@"03"] || [code isEqualToString:@"05"])
    {
        // ret = @"电信";
        carrier_name = @"03";
    }
    if ([code isEqualToString:@"01"] || [code isEqualToString:@"06"])
    {
        // ret = @"联通";
        carrier_name = @"02";
    }
    return carrier_name;
}

//获取网络环境
/**
 * 联网方式
 * 0: 其它
 * 1: WIFI
 * 2: 2G
 * 3: 3G
 * 4: 4G
 */
- (NSString *)getNetWorkType {
    
    if (IS_IPhoneXorXs || Is_IPhoneXSMax) {
        UIApplication *app = [UIApplication sharedApplication];
        id statusBar = [app valueForKeyPath:@"statusBar"];
        id statusBarView = [statusBar valueForKeyPath:@"statusBar"];
        UIView *foregroundView = [statusBarView valueForKeyPath:@"foregroundView"];
        
        NSArray *subviews = [[foregroundView subviews][2] subviews];
        
        for (id subview in subviews) {
            
            if ([subview isKindOfClass:NSClassFromString(@"_UIStatusBarWifiSignalView")]) {
                
                return @"01";  // wifi网
            }else if ([subview isKindOfClass:NSClassFromString(@"_UIStatusBarStringView")]) {
                
                NSString *str = [subview valueForKeyPath:@"_originalText"]; // @"text" @"originalText"一样
                if ([str isEqualToString:@"4G"]) {
                    return @"04";  // 4G网
                }else if([str isEqualToString:@"3G"]){
                    return @"03"; // 3G网
                }else{
                    return @"02"; // 2G网
                }
            }
        }
        return @"00";  // 无网络
    }
    
    
    NSString *stateString = @"00";
    NSArray * children;
    UIApplication *application = [UIApplication sharedApplication];
    if ([[application valueForKeyPath:@"_statusBar"] isKindOfClass:NSClassFromString(@"UIStatusBar_Modern")]) {
        //适配iOS 11 获取不到网络状态
        children = [[[[application valueForKeyPath:@"_statusBar"]
                      valueForKeyPath:@"_statusBar"]
                     valueForKeyPath:@"foregroundView"]
                    subviews];
    } else {
        children = [[[application valueForKeyPath:@"_statusBar"]
                     valueForKeyPath:@"foregroundView"]
                    subviews];
    }
    int type = 0;
    for (id child in children) {
        if ([child isKindOfClass:[NSClassFromString(@"UIStatusBarDataNetworkItemView")
                                  class]]) {
            type = [[child valueForKeyPath:@"dataNetworkType"] intValue];
        }
    }
    switch (type) {
        case 0:
            stateString = @"00";  //@"notReachable";
            break;
        case 1:
            stateString = @"02";   //@"2G";
            break;
        case 2:
            stateString = @"03";   //@"3G";
            break;
        case 3:
            stateString = @"04";   //@"4G";
            break;
        case 4:
            stateString = @"04";  //@"LTE";  3.9G
            break;
        case 5:
            stateString = @"01";   //@"wifi";
            break;
        default:
            break;
    }
    return stateString;
}

//获取证书--->拼接token用
- (NSString *)getCredential {
    NSString *cre = [USERDEFAULTS objectForKey:[CREDENTIAL copy]];
    return cre ? cre : @"";
}

// (单位毫秒)  当前时间 + (上次请求开始请求时的时间 - 上次请求成功时的时间)
- (NSString *)getTimeForToken {
    
    NSNumber *str = [USERDEFAULTS objectForKey:LastRequestDurTime];
    long long lastTime = 0;
    if (str) {
        lastTime = [str longLongValue];
    }
    
    NSString *timeStr = [NSString stringWithFormat:@"%llu",[Tool getCurrentTimeMillsNum] + lastTime];
    return timeStr;
}

//获取dpi 屏幕密度
- (NSString*)getDpi {
    if (IS_IPhonePlus) {
        return @"4.01";
    }else if (IS_IPhoneXorXs || Is_IPhoneXSMax) {  //X  Xs  XsMax
        return @"4.58";
    }else {
        return @"3.26";
    }
}

//获取设备序列号
- (NSString*)getUUID {
    return [UIDevice currentDevice].uuid;
}

//获取手机型号
- (NSString*)getDeviceName {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *platform = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    if([platform isEqualToString:@"iPhone1,1"])return@"iPhone 2G";
    if([platform isEqualToString:@"iPhone1,2"])return@"iPhone 3G";
    if([platform isEqualToString:@"iPhone2,1"])return@"iPhone 3GS";
    if([platform isEqualToString:@"iPhone3,1"])return@"iPhone 4";
    if([platform isEqualToString:@"iPhone3,2"])return@"iPhone 4";
    if([platform isEqualToString:@"iPhone3,3"])return@"iPhone 4";
    if([platform isEqualToString:@"iPhone4,1"])return@"iPhone 4S";
    if([platform isEqualToString:@"iPhone5,1"])return@"iPhone 5";
    if([platform isEqualToString:@"iPhone5,2"])return@"iPhone 5";
    if([platform isEqualToString:@"iPhone5,3"])return@"iPhone 5c";
    if([platform isEqualToString:@"iPhone5,4"])return@"iPhone 5c";
    if([platform isEqualToString:@"iPhone6,1"])return@"iPhone 5s";
    if([platform isEqualToString:@"iPhone6,2"])return@"iPhone 5s";
    if([platform isEqualToString:@"iPhone7,1"])return@"iPhone 6 Plus";
    if([platform isEqualToString:@"iPhone7,2"])return@"iPhone 6";
    if([platform isEqualToString:@"iPhone8,1"])return@"iPhone 6s";
    if([platform isEqualToString:@"iPhone8,2"])return@"iPhone 6s Plus";
    if([platform isEqualToString:@"iPhone8,4"])return@"iPhone SE";
    if([platform isEqualToString:@"iPhone9,1"])return@"iPhone 7";
    if([platform isEqualToString:@"iPhone9,2"])return@"iPhone 7 Plus";
    if([platform isEqualToString:@"iPhone10,1"]) return@"iPhone 8";
    if([platform isEqualToString:@"iPhone10,4"]) return@"iPhone 8";
    if([platform isEqualToString:@"iPhone10,2"]) return@"iPhone 8 Plus";
    if([platform isEqualToString:@"iPhone10,5"]) return@"iPhone 8 Plus";
    if([platform isEqualToString:@"iPhone10,3"]) return@"iPhone X";
    if([platform isEqualToString:@"iPhone10,6"]) return@"iPhone X";
    if ([platform isEqualToString:@"iPhone11,8"]) return @"iPhone_XR";
    if ([platform isEqualToString:@"iPhone11,2"]) return @"iPhone_XS";
    if ([platform isEqualToString:@"iPhone11,4"] || [platform isEqualToString:@"iPhone11,6"]) return @"iPhone_XS_Max";
    
    if([platform isEqualToString:@"iPod1,1"])return@"iPod Touch 1G";
    if([platform isEqualToString:@"iPod2,1"])return@"iPod Touch 2G";
    if([platform isEqualToString:@"iPod3,1"])return@"iPod Touch 3G";
    if([platform isEqualToString:@"iPod4,1"])return@"iPod Touch 4G";
    if([platform isEqualToString:@"iPod5,1"])return@"iPod Touch 5G";
    if([platform isEqualToString:@"iPad1,1"])return@"iPad 1G";
    if([platform isEqualToString:@"iPad2,1"])return@"iPad 2";
    if([platform isEqualToString:@"iPad2,2"])return@"iPad 2";
    if([platform isEqualToString:@"iPad2,3"])return@"iPad 2";
    if([platform isEqualToString:@"iPad2,4"])return@"iPad 2";
    if([platform isEqualToString:@"iPad2,5"])return@"iPad Mini 1G";
    if([platform isEqualToString:@"iPad2,6"])return@"iPad Mini 1G";
    if([platform isEqualToString:@"iPad2,7"])return@"iPad Mini 1G";
    if([platform isEqualToString:@"iPad3,1"])return@"iPad 3";
    if([platform isEqualToString:@"iPad3,2"])return@"iPad 3";
    if([platform isEqualToString:@"iPad3,3"])return@"iPad 3";
    if([platform isEqualToString:@"iPad3,4"])return@"iPad 4";
    if([platform isEqualToString:@"iPad3,5"])return@"iPad 4";
    if([platform isEqualToString:@"iPad3,6"])return@"iPad 4";
    if([platform isEqualToString:@"iPad4,1"])return@"iPad Air";
    if([platform isEqualToString:@"iPad4,2"])return@"iPad Air";
    if([platform isEqualToString:@"iPad4,3"])return@"iPad Air";
    if([platform isEqualToString:@"iPad4,4"])return@"iPad Mini 2G";
    if([platform isEqualToString:@"iPad4,5"])return@"iPad Mini 2G";
    if([platform isEqualToString:@"iPad4,6"])return@"iPad Mini 2G";
    if([platform isEqualToString:@"iPad4,7"])return@"iPad Mini 3";
    if([platform isEqualToString:@"iPad4,8"])return@"iPad Mini 3";
    if([platform isEqualToString:@"iPad4,9"])return@"iPad Mini 3";
    if([platform isEqualToString:@"iPad5,1"])return@"iPad Mini 4";
    if([platform isEqualToString:@"iPad5,2"])return@"iPad Mini 4";
    if([platform isEqualToString:@"iPad5,3"])return@"iPad Air 2";
    if([platform isEqualToString:@"iPad5,4"])return@"iPad Air 2";
    if([platform isEqualToString:@"iPad6,3"])return@"iPad Pro 9.7";
    if([platform isEqualToString:@"iPad6,4"])return@"iPad Pro 9.7";
    if([platform isEqualToString:@"iPad6,7"])return@"iPad Pro 12.9";
    if([platform isEqualToString:@"iPad6,8"])return@"iPad Pro 12.9";
    if([platform isEqualToString:@"i386"])return@"iPhone Simulator";
    if([platform isEqualToString:@"x86_64"])return@"iPhone Simulator";
    return platform;
}

//应用发布渠道
- (NSString*)getAppPubChannel {
    return @"appstore";
}

/** 短视频交互: 赞 踩 */
-(void)shortVideoInteractWithPar:(NSDictionary *)par success:(void (^)(id))success failure:(void (^)(NSString *))failure {
    [[SSRequest request]POST:ShortVideoInterationUrl parameters:par.mutableCopy success:^(SSRequest *request, id response) {
        
        SSLog(@"%@",response);
        if(success) {
            success(response);
        }
    } failure:^(SSRequest *request, NSString *errorMsg) {
        if(failure) {
            failure(errorMsg);
        }
    }];
}

/** 视频收藏, 取消收藏 */
- (void)videoCollectionWithPar:(NSDictionary *)par andIsCollection:(BOOL)isCollection success:(void (^)(id))success failure:(void (^)(NSString *))failure {
    [[SSRequest request]POST:isCollection ? VideoCollectUrl : VideoCancelCollectUrl parameters:par.mutableCopy success:^(SSRequest *request, id response) {
        
        SSLog(@"%@",response);
        if(success) {
            success(response);
        }
    } failure:^(SSRequest *request, NSString *errorMsg) {
        if(failure) {
            failure(errorMsg);
        }
    }];
}

/** 请求后台 解析视频Url  engine 为RE002   */
- (void)analyseVideoUrlWithModel:(VDCommonModel *)model success:(void (^)(id response))success failure:(void (^)(NSString *errMsg))failure {

    MediaSourceResultModel *mSource = model.mediaSourceResultList[model.indexSelectForSource];
    MediaTipResultModel *mTip = model.episodeDataArray[model.indexSelectForEpisode];
    NSDictionary *par = @{@"programId" : model.idForModel,
                          @"assetType" : model.type,
                          @"source" : mSource.idForModel,
                          @"mediaId" : mTip.mediaId,
                          @"url" : mTip.originLink
                          };
    [[SSRequest request]POST:AnalyseVideoUrlUrl parameters:par.mutableCopy success:^(SSRequest *request, id response) {
        
        SSLog(@"%@",response);
    
        if(success) {
            success(response);
        }
        
    } failure:^(SSRequest *request, NSString *errorMsg) {
        if(failure) {
            failure(errorMsg);
        }
    }];
}

//内购-存储-购买凭证
-(void)iapSaveReceipt:(NSDictionary *)receipt
{
    NSString *docPath = [self filePath];
    NSString *filePath = [NSString  stringWithFormat:@"%@/%@IAPReceipt.plist",docPath,[self getUUID]];
    //使用一个数组来接收数据
    NSArray *array = [NSArray arrayWithContentsOfFile:filePath];
    if(array == nil)
    {
        array = @[];
    }
    NSMutableArray * dataArr = [NSMutableArray arrayWithArray:array];
    
    __block BOOL isHave = NO;
    
    [dataArr enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj[@"order"] isEqualToString:receipt[@"order"]]) {
            isHave = YES;
            *stop = YES;
        }
    }];
    
    if(isHave) {
        [dataArr addObject:receipt];
    }
    
    [[dataArr copy] writeToFile:filePath atomically:YES];
}

//查找-删除-购买凭证
-(void)deleteReceipt:(NSDictionary *)receipt
{
    NSString *docPath = [self filePath];
    NSString *filePath = [NSString  stringWithFormat:@"%@/%@IAPReceipt.plist",docPath,[self getUUID]];
    //使用一个数组来接受数据
    NSArray *array = [NSArray arrayWithContentsOfFile:filePath];
    if(array == nil)
    {
        array = @[];
    }
    NSMutableArray * dataArr = [NSMutableArray arrayWithArray:array];
    [dataArr enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj[@"order"] isEqualToString:receipt[@"order"]]) {
            [dataArr removeObject:obj];
        }
    }];
    
    [[dataArr copy] writeToFile:filePath atomically:YES];
}

//获取-存储的 购买凭证
-(NSArray *)getReceiptList
{
    NSString *docPath = [self filePath];
    NSString *filePath = [NSString  stringWithFormat:@"%@/%@IAPReceipt.plist",docPath,[self getUUID]];
    //使用一个数组来接受数据
    NSArray *array = [NSArray arrayWithContentsOfFile:filePath];
    
    return array?array:@[];
}

-(NSString *)filePath {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
}

//IAP
- (void)iapWithParameters:(NSDictionary *)dic success:(void (^)(id))success failure:(void (^)(NSString *))failure
{
    NSString * urlStr  = @"";  //KURLSTR(ServerAddress,IAPUrl);
    
    [[SSRequest request] POST:urlStr parameters:dic.mutableCopy success:^(SSRequest *request, id response) {
        
        //等待编辑
        if([response[@"succeed"] integerValue] == 1)
        {
            success(response);
        }else{
            if ([response[@"errMsg"] isEqualToString:@"测试成功"]) {
                success(response);
            }else {
                SSMBToast(response[@"errMsg"], MainWindow);
            }
        }
        
    } failure:^(SSRequest *request, NSString *errorMsg) {
        failure(errorMsg);
    }];
}


//---有券  用券购买影片
- (void)useTicketWithDic:(NSDictionary*)dic success:(void (^)(id response))success failure:(void (^)(NSString *errMsg))failure {

    [[SSRequest request] POST:UseTicketBuyVideoUrl parameters:dic.mutableCopy success:^(SSRequest *request, id response) {
        
        success(response);
        
    } failure:^(SSRequest *request, NSString *errorMsg) {
        failure(errorMsg);
        SSMBToast(errorMsg, MainWindow);
    }];
    
}



//搜索历史-存储
-(void)searchHistorySaveWithWord:(NSString *)word
{
    NSString *docPath = [self filePath];
    NSString *filePath = [NSString  stringWithFormat:@"%@/%@SearchHistoryWord.plist",docPath,[self getUUID]];
    //使用一个数组来接收数据
    NSArray *array = [NSArray arrayWithContentsOfFile:filePath];
    if(array == nil)
    {
        array = @[];
    }
    NSMutableArray * dataArr = [NSMutableArray arrayWithArray:array];
    if([dataArr containsObject:word]) {
        [dataArr removeObject:word];
    }
    [dataArr insertObject:word atIndex:0];

    [[dataArr copy] writeToFile:filePath atomically:YES];
}

//查找-删除-搜索历史
-(void)searchHistoryDeleteWithWord:(NSString *)receipt
{
    NSString *docPath = [self filePath];
    NSString *filePath = [NSString  stringWithFormat:@"%@/%@SearchHistoryWord.plist",docPath,[self getUUID]];
    //使用一个数组来接受数据
    NSArray *array = [NSArray arrayWithContentsOfFile:filePath];
    if(array == nil)
    {
        array = @[];
    }
    NSMutableArray * dataArr = [NSMutableArray arrayWithArray:array];
    if([dataArr containsObject:receipt])
    {
        [dataArr removeObject:receipt];
    }
    
    [[dataArr copy] writeToFile:filePath atomically:YES];
}

//清空-搜索历史
-(void)searchHistoryDeleteAll {
    NSString *docPath = [self filePath];
    NSString *filePath = [NSString  stringWithFormat:@"%@/%@SearchHistoryWord.plist",docPath,[self getUUID]];
    [@[] writeToFile:filePath atomically:YES];
}

//获取存储的搜索历史
-(NSArray *)getSearchHistorySaveList
{
    NSString *docPath = [self filePath];
    NSString *filePath = [NSString  stringWithFormat:@"%@/%@SearchHistoryWord.plist",docPath,[self getUUID]];
    //使用一个数组来接受数据
    NSArray *array = [NSArray arrayWithContentsOfFile:filePath];
    return array?array:@[];
}

//登录后, 请求热门搜索词并保存
- (void)loadAndSaveHotSearchWord {
    
    [[SSRequest request]GET:SearchHotWordUrl parameters:nil success:^(SSRequest *request, id response) {
    
        NSMutableArray *hotWordArray = [NSMutableArray array];
        hotWordArray = [HotSearchWordModel mj_objectArrayWithKeyValuesArray:response[@"data"]];
        
        if (hotWordArray.count>0) {
            NSString *docPath = [self filePath];
            NSString *filePath = [NSString  stringWithFormat:@"%@/%@UserSaveData.plist",docPath,[self getUUID]];
            //使用一个字典
            NSDictionary *dicUser = [NSDictionary dictionaryWithContentsOfFile:filePath];
            if(dicUser == nil)
            {
                dicUser = [NSDictionary dictionary];
            }
            NSMutableDictionary * dic = [NSMutableDictionary dictionaryWithDictionary:dicUser];
            [dic setObject:response[@"data"] forKey:@"HotSearchWordDic"];
            [[dic copy] writeToFile:filePath atomically:YES];
            
            //找到搜索框里显示的推荐词, 发送通知给topSearchView
            [hotWordArray enumerateObjectsUsingBlock:^(HotSearchWordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (obj.keyWordType == KeyWordType_Recom) {
                    [NOTIFICATION postNotificationName:SEARCH_HotWord_Noti object:self userInfo:@{@"word":obj.word}];
                    return;
                }
            }];
        }
        
    } failure:^(SSRequest *request, NSString *errorMsg) {
        
    }];
    
}

- (NSArray *)getSavedHotSearchWordArray {
    NSString *docPath = [self filePath];
    NSString *filePath = [NSString  stringWithFormat:@"%@/%@UserSaveData.plist",docPath,[self getUUID]];
    //使用一个字典
    NSDictionary *dicUser = [NSDictionary dictionaryWithContentsOfFile:filePath];
    if(dicUser == nil)
    {
        return @[];
    }
    if ([dicUser.allKeys containsObject:@"HotSearchWordDic"]) {
        NSDictionary *hotwordDic = [dicUser objectForKey:@"HotSearchWordDic"];
        NSMutableArray *hotWordArray = [NSMutableArray array];
        hotWordArray = [HotSearchWordModel mj_objectArrayWithKeyValuesArray:hotwordDic];
        [hotWordArray enumerateObjectsUsingBlock:^(HotSearchWordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.keyWordType == KeyWordType_Recom) {
                [hotWordArray removeObject:obj];
            }
        }];
        return hotWordArray;
    }else {
        return @[];
    }
}

//获取保存的热搜词 占位热词
- (NSString *)getSavedHotSearchWordForPlaceHolder {
    NSString *docPath = [self filePath];
    NSString *filePath = [NSString  stringWithFormat:@"%@/%@UserSaveData.plist",docPath,[self getUUID]];
    //使用一个字典
    NSDictionary *dicUser = [NSDictionary dictionaryWithContentsOfFile:filePath];
    if(dicUser == nil)
    {
        return @"";
    }
    if ([dicUser.allKeys containsObject:@"HotSearchWordDic"]) {
        NSDictionary *hotwordDic = [dicUser objectForKey:@"HotSearchWordDic"];
        NSMutableArray *hotWordArray = [NSMutableArray array];
        hotWordArray = [HotSearchWordModel mj_objectArrayWithKeyValuesArray:hotwordDic];
        __block NSString *returnStr = @"";
        [hotWordArray enumerateObjectsUsingBlock:^(HotSearchWordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.keyWordType == KeyWordType_Recom) {
                 returnStr = obj.word;
                *stop = YES;
            }
        }];
        return returnStr;
    }else {
        return @"";
    }
}

//观看历史-存储
-(void)watchHistorySaveWithWord:(NSString *)word {
    
}

//查找-删除-观看历史
-(void)watchHistoryDeleteWithWord:(NSString *)receipt {
    
}

//获取存储的观看历史
-(NSArray *)getWatchHistorySaveList {
    return [NSArray array];
}

//获取广告公共参数
-(NSDictionary*)getAdvParamDicWithPositionID:(NSString *)positionID slotWidth:(NSInteger)advWidth slotHeight:(NSInteger)advHeight {
    
    NSDictionary *advDic = @{@"appPositionId" : positionID,
                             @"idfa" : [self getIDFA],
                             @"manufacturer" : @"Apple",
                             @"model" : [self getDeviceName],  //手机型号
                             @"screenWidth" : @(ScreenWidth),
                             @"screenHeight" : @(ScreenHeight),
                             @"mobileCarriers" : [self getSimType],  //0:未知 1：中国移动 2: 中国联通 3: 中国电信
                             @"imsi" : @"",
                             @"longitude" : [USER_MANAGER getLocationLongitude],
                             @"latitude" : [USER_MANAGER getLocationLatitude],
                             @"network" : [self getNetWorkType],
                             @"mac" : @"",
                             @"imei" : @"",
                             @"dpi" : [self getDpi],
                             @"orient" : @"0",
                             @"adid" : @"",  //安卓编号
                             @"ua" : [self getUserAgent],
                             @"brand" : @"Apple",
                             @"mobileCarriersId" : @"",
                             @"slotWidth" : @(advHeight),  //广告位宽高
                             @"slotHeight" : @(advWidth)
                             };
    return advDic;
}

- (NSString *)getLocationLongitude {
    NSString *longitue = [NSString stringWithFormat:@"%@", [USERDEFAULTS objectForKey:LocationLongitude]];
    return [USERDEFAULTS objectForKey:LocationLongitude] ? longitue : @"";
}

- (NSString *)getLocationLatitude {
    NSString *latitude = [NSString stringWithFormat:@"%@", [USERDEFAULTS objectForKey:LocationLatitude]];
    return  [USERDEFAULTS objectForKey:LocationLatitude] ? latitude : @"";
}

- (NSString *)getIDFA {
    
    if (iOS10Later) {
        if([[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled]) {
            NSString *idfa = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
            return idfa;
        }else {
            NSString *idfa = [SimulateIDFA createSimulateIDFA];
            return idfa;
        }
    }else {
        NSString *idfa = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
        return idfa;
    }
}

//广告展示相关 上报
- (void)callBackAdvWithUrls:(NSArray*)urls {
    if (urls.count==0) {
        return;
    }
    for (NSString *url in urls) {
        [[SSRequest request]AdvReportGET:url success:^(SSRequest *request, id response) {
            
        } failure:^(SSRequest *request, NSString *errorMsg) {
            
        }];
    }
}

//广告误点:   YES:今天点过了  NO:今天未点
- (BOOL)getAdvClickPercentWithAdvID:(NSString*)advID {
    if (advID.length==0) {
        return YES;
    }
    
    NSString *todayDate = [Tool dateStringForAdvClickCacheKey];
    if([USERDEFAULTS objectForKey:AdvClickPercentCacheKey]) {
        NSDictionary *dic = [USERDEFAULTS objectForKey:AdvClickPercentCacheKey];
        if([dic.allKeys containsObject:todayDate]) {
            NSArray *arrToday = [dic objectForKey:todayDate];
            if ([arrToday containsObject:advID]) {
                return YES;
            }else {
                NSMutableArray *arrNewToday = [NSMutableArray arrayWithArray:arrToday];
                [arrNewToday addObject:advID];
                
                NSMutableDictionary *dicNew = [NSMutableDictionary dictionaryWithDictionary:dic];
                [dicNew setObject:[arrNewToday copy] forKey:todayDate];
                [USERDEFAULTS setObject:[dicNew copy] forKey:AdvClickPercentCacheKey];
                [USERDEFAULTS synchronize];
                return NO;
            }
        }else {
            NSArray *arr = @[advID];
            NSDictionary *dic = @{todayDate : arr};
            [USERDEFAULTS setObject:dic forKey:AdvClickPercentCacheKey];
            [USERDEFAULTS synchronize];
            return NO;
        }
        
    }else {
        NSArray *arr = @[advID];
        NSDictionary *dic = @{todayDate : arr};
        [USERDEFAULTS setObject:dic forKey:AdvClickPercentCacheKey];
        [USERDEFAULTS synchronize];
        return NO;
    }
}

//判断 滑动进度条 是否 出广告
- (BOOL)isShowAdvWhenDragVideoWithVideoID:(NSString*)videoID {
    if (videoID.length==0) {
        return NO;
    }
    NSInteger MaxShowNum = [self getDragShowAdvCount];
    NSString *DragKey = @"DragShowAdvKey";
    NSString *todayDate = [Tool dateStringForAdvClickCacheKey];
    if([USERDEFAULTS objectForKey:DragKey]) {
        NSDictionary *dic = [USERDEFAULTS objectForKey:DragKey];
        if([dic.allKeys containsObject:todayDate]) {
            NSMutableDictionary *dicToday = [[dic objectForKey:todayDate] mutableCopy];
            if ([dicToday.allKeys containsObject:videoID]) {
                NSInteger num = [[dicToday objectForKey:videoID] integerValue];
                if (num<MaxShowNum) {
                    num = num + 1;
                    [dicToday setValue:String_Integer(num) forKey:videoID];
                    NSDictionary *newDic = @{todayDate : [dicToday copy]};
                    [USERDEFAULTS setObject:newDic forKey:DragKey];
                    [USERDEFAULTS synchronize];
                    return YES;
                }else {
                    return NO;
                }
            }else {
                [dicToday setValue:@"1" forKey:videoID];
                NSDictionary *dic = @{todayDate : [dicToday copy]};
                [USERDEFAULTS setObject:dic forKey:DragKey];
                [USERDEFAULTS synchronize];
                return YES;
            }
        }else {
            NSDictionary *videoDic = @{videoID : @"1"};
            NSDictionary *dic = @{todayDate : videoDic};
            [USERDEFAULTS setObject:dic forKey:DragKey];
            [USERDEFAULTS synchronize];
            return YES;
        }
        
    }else {
        NSDictionary *videoDic = @{videoID : @"1"};
        NSDictionary *dic = @{todayDate : videoDic};
        [USERDEFAULTS setObject:dic forKey:DragKey];
        [USERDEFAULTS synchronize];
        return YES;
    }
}

//短视频(推荐页第一个 or 详情页)广告:   NO:今天展示过了,不展示  YES:今天未展示, 展示
- (BOOL)isShowShortVideoDayOnceAdvWithShortVideoID:(NSString*)svID {
    if ([self isVIPUser] || (svID.length==0)) return NO;
    
    NSString *todayDate = [Tool dateStringForAdvClickCacheKey];
    if([USERDEFAULTS objectForKey:ShortVideoAdvShowKey]) {
        NSDictionary *dic = [USERDEFAULTS objectForKey:ShortVideoAdvShowKey];
        if([dic.allKeys containsObject:todayDate]) {
            NSArray *arrToday = [dic objectForKey:todayDate];
            if ([arrToday containsObject:svID]) {
                return NO;
            }else {
                return YES;
            }
        }else {
            return YES;
        }
    }else {
        return YES;
    }
}

//短视频当天展示过广告, 调用   点击跳过 or 倒计时完
- (void)showShortVideoDayOnceAdvSuccessWithShortVideoID:(NSString *)svID {
    if ([self isVIPUser] || (svID.length==0)) return;
    
    NSString *todayDate = [Tool dateStringForAdvClickCacheKey];
    
    if([USERDEFAULTS objectForKey:ShortVideoAdvShowKey]) {
        NSDictionary *dic = [USERDEFAULTS objectForKey:ShortVideoAdvShowKey];
        if([dic.allKeys containsObject:todayDate]) {
            NSArray *arrToday = [dic objectForKey:todayDate];
            if ([arrToday containsObject:svID]) {
                
            }else {
                NSMutableArray *arrNewToday = [NSMutableArray arrayWithArray:arrToday];
                [arrNewToday addObject:svID];
                
                NSMutableDictionary *dicNew = [NSMutableDictionary dictionaryWithDictionary:dic];
                [dicNew setObject:[arrNewToday copy] forKey:todayDate];
                [USERDEFAULTS setObject:[dicNew copy] forKey:ShortVideoAdvShowKey];
                [USERDEFAULTS synchronize];
            }
        }else {
            NSArray *arr = @[svID];
            NSDictionary *dic = @{todayDate : arr};
            [USERDEFAULTS setObject:dic forKey:ShortVideoAdvShowKey];
            [USERDEFAULTS synchronize];
        }
        
    }else {
        NSArray *arr = @[svID];
        NSDictionary *dic = @{todayDate : arr};
        [USERDEFAULTS setObject:dic forKey:ShortVideoAdvShowKey];
        [USERDEFAULTS synchronize];
    }
}


// 根据model里面的时间字段进行排序, 观看历史只保留前 MaxHistoryCount 条
- (NSArray *)sortedArrayUsingComparatorByPaymentTimeWithDataArr:(NSArray<WatchHistoryCacheModel *> *)dataArr{
    
    NSArray *sortArray = [dataArr sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        WatchHistoryCacheModel *model1 = obj1;
        WatchHistoryCacheModel *model2 = obj2;
        
        if ([model1.updateTime doubleValue] < [model2.updateTime doubleValue]) {
            return NSOrderedDescending;
        } else if ([model1.updateTime doubleValue] > [model2.updateTime doubleValue]) {
            return NSOrderedAscending;
        }
        return NSOrderedSame;
    }];
    
    //观看历史只保留前 MaxHistoryCount 条
    if (sortArray.count>MaxHistoryCount) {
        NSArray *arrShow = [sortArray subarrayWithRange:NSMakeRange(0,MaxHistoryCount)];
        NSMutableArray *arrDelete = [[sortArray subarrayWithRange:NSMakeRange(MaxHistoryCount, sortArray.count-MaxHistoryCount)] mutableCopy];
        
        if (arrDelete.count>0) {
            NSMutableArray *parArr = [NSMutableArray array];
            [arrDelete enumerateObjectsUsingBlock:^(WatchHistoryCacheModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSString * pi = [NSString stringWithFormat:@"'%@'", obj.pi];
                [parArr addObject:pi];
            }];
            NSString *deletePi = [parArr componentsJoinedByString:@","];
            NSString *deleteStr = [NSString stringWithFormat:@"WHERE pi IN (%@)",deletePi];;
            JQFMDB *db = [JQFMDB shareDatabase];
            [db jq_inDatabase:^{  //保证线程安全删除数据
                [db jq_deleteTable:CACHE_Table whereFormat:deleteStr];
            }];
        }
        return arrShow;
    }else {
        return sortArray;
    }
}

//分享模块弹框创建前, 根据判断显示弹框高度
- (NSInteger)getShareNumBeforeShowShareViewWithNotInterest:(BOOL)isInterest {
    NSArray * arrayAll = @[@"微信",@"朋友圈",@"QQ",@"微博",@"举报",@"反馈报错",@"不感兴趣"];
    
    NSMutableArray *array = [NSMutableArray arrayWithArray:arrayAll];
    
    if (![[BAShareManage ba_shareManage] ba_UMSocialIsInstall:UMSocialPlatformType_WechatSession]) {
        [array removeObjectsInArray:@[@"微信",@"朋友圈"]];
    }
    
    if (![[BAShareManage ba_shareManage] ba_UMSocialIsInstall:UMSocialPlatformType_QQ]) {
        [array removeObject:@"QQ"];
    }
    
    if (!isInterest) {
        [array removeObject:@"不感兴趣"];
    }
    //每行4个;
    NSInteger num = array.count/4;
    if (array.count%4>0) {
        num +=1;
    }
    return num;
}

//消息通知
- (BOOL)getNotiStatusWithType:(NotiType)type {
    switch (type) {
        case NotiType_All:
        {
            NSString *isNoti = [USERDEFAULTS objectForKey:NotiTypeAll];
            if (isNoti) {
                return [isNoti boolValue];
            }else {
                return YES;
            }
        }
            break;
        case NotiType_System:
        {
            NSString *isNoti = [USERDEFAULTS objectForKey:NotiTypeSystem];
            if (isNoti) {
                return [isNoti boolValue];
            }else {
                return YES;
            }
        }
            break;
        case NotiType_Comment:
        {
            NSString *isNoti = [USERDEFAULTS objectForKey:NotiTypeComment];
            if (isNoti) {
                return [isNoti boolValue];
            }else {
                return YES;
            }
        }
            break;
        case NotiType_Like:
        {
            NSString *isNoti = [USERDEFAULTS objectForKey:NotiTypeLike];
            if (isNoti) {
                return [isNoti boolValue];
            }else {
                return YES;
            }
        }
            break;
        case NotiType_Video:
        {
            NSString *isNoti = [USERDEFAULTS objectForKey:NotiTypeVideo];
            if (isNoti) {
                return [isNoti boolValue];
            }else {
                return YES;
            }
        }
            break;
        case NotiType_SignOrActivity:
        {
            NSString *isNoti = [USERDEFAULTS objectForKey:NotiTypeSignOrActivity];
            if (isNoti) {
                return [isNoti boolValue];
            }else {
                return YES;
            }
        }
            break;
        default:
            break;
    }
}

//抽奖页面为H5请求后台数据成功后,数据callBack给H5
- (void)requestMsgForH5WithIsPost:(BOOL)isPost url:(NSString*)url params:(NSDictionary*)params success:(void (^)(id response))success failure:(void(^)(NSString* errMsg))failure {
    
    if (!isPost) {
        [[SSRequest request]GET:url parameters:params ? params.mutableCopy : nil success:^(SSRequest *request, id response) {

            success(response);
            
        } failure:^(SSRequest *request, NSString *errorMsg) {
            SSMBToast(errorMsg, MainWindow);
            failure(errorMsg);
        }];
        
    }else {  //POST
        [[SSRequest request]POST:url parameters:params ? params.mutableCopy : nil success:^(SSRequest *request, id response) {
            
            success(response);
            
        } failure:^(SSRequest *request, NSString *errorMsg) {
            SSMBToast(errorMsg, MainWindow);
            failure(errorMsg);
        }];
    }
}

/*通知推送 (未读消息数加减)
 *  点击推送 对应类型 -1
 *  返回总未读消息数, 根据这个设置BadgeNumber
 */
- (NSInteger)notiPushNumberWithType:(NotiType)type isAdd:(BOOL)isAdd {
    switch (type) {
        case NotiType_System:
        {
            if ([USERDEFAULTS objectForKey:@"NotiType_System"]) {
                NSInteger num = [[USERDEFAULTS objectForKey:@"NotiType_System"] integerValue];
                num = isAdd ? (num+1) : (num-1);
                if (num<0) { num = 0; }
                [USERDEFAULTS setObject:[NSNumber numberWithInteger:num] forKey:@"NotiType_System"];
            }else {
                [USERDEFAULTS setObject:[NSNumber numberWithInteger:1] forKey:@"NotiType_System"];
            }
        }
            break;
        case NotiType_SignOrActivity:
        {
            if ([USERDEFAULTS objectForKey:@"NotiType_SignOrActivity"]) {
                NSInteger num = [[USERDEFAULTS objectForKey:@"NotiType_SignOrActivity"] integerValue];
                num = isAdd ? (num+1) : (num-1);
                if (num<0) { num = 0; }
                [USERDEFAULTS setObject:[NSNumber numberWithInteger:num] forKey:@"NotiType_SignOrActivity"];
            }else {
                [USERDEFAULTS setObject:[NSNumber numberWithInteger:1] forKey:@"NotiType_SignOrActivity"];
            }
        }
            break;
        case NotiType_Video:
        {
            if ([USERDEFAULTS objectForKey:@"NotiType_Video"]) {
                NSInteger num = [[USERDEFAULTS objectForKey:@"NotiType_Video"] integerValue];
                num = isAdd ? (num+1) : (num-1);
                if (num<0) { num = 0; }
                [USERDEFAULTS setObject:[NSNumber numberWithInteger:num] forKey:@"NotiType_Video"];
            }else {
                [USERDEFAULTS setObject:[NSNumber numberWithInteger:1] forKey:@"NotiType_Video"];
            }
        }
            break;
        case NotiType_Like:
        {
            if ([USERDEFAULTS objectForKey:@"NotiType_Like"]) {
                NSInteger num = [[USERDEFAULTS objectForKey:@"NotiType_Like"] integerValue];
                num = isAdd ? (num+1) : (num-1);
                if (num<0) { num = 0; }
                [USERDEFAULTS setObject:[NSNumber numberWithInteger:num] forKey:@"NotiType_Like"];
            }else {
                [USERDEFAULTS setObject:[NSNumber numberWithInteger:1] forKey:@"NotiType_Like"];
            }
        }
            break;
        case NotiType_Comment:
        {
            if ([USERDEFAULTS objectForKey:@"NotiType_Comment"]) {
                NSInteger num = [[USERDEFAULTS objectForKey:@"NotiType_Comment"] integerValue];
                num = isAdd ? (num+1) : (num-1);
                if (num<0) { num = 0; }
                [USERDEFAULTS setObject:[NSNumber numberWithInteger:num] forKey:@"NotiType_Comment"];
            }else {
                [USERDEFAULTS setObject:[NSNumber numberWithInteger:1] forKey:@"NotiType_Comment"];
            }
        }
            break;
        default:
            break;
    }
    [USERDEFAULTS synchronize];
    return [self notiPushNumberWithType:NotiType_All];
}

//未读消息数, 某个类型的消息
- (NSInteger)notiPushNumberWithType:(NotiType)type {
    switch (type) {
        case NotiType_System:
        {
            if ([USERDEFAULTS objectForKey:@"NotiType_System"]) {
                NSInteger num = [[USERDEFAULTS objectForKey:@"NotiType_System"] integerValue];
                if (num<0) { num = 0; }
                return num;
            }else {
                return 0;
            }
        }
            break;
        case NotiType_SignOrActivity:
        {
            if ([USERDEFAULTS objectForKey:@"NotiType_SignOrActivity"]) {
                NSInteger num = [[USERDEFAULTS objectForKey:@"NotiType_SignOrActivity"] integerValue];
                if (num<0) { num = 0; }
                return num;
            }else {
                return 0;
            }
        }
            break;
        case NotiType_Video:
        {
            if ([USERDEFAULTS objectForKey:@"NotiType_Video"]) {
                NSInteger num = [[USERDEFAULTS objectForKey:@"NotiType_Video"] integerValue];
                if (num<0) { num = 0; }
                return num;
            }else {
                return 0;
            }
        }
            break;
        case NotiType_Like:
        {
            if ([USERDEFAULTS objectForKey:@"NotiType_Like"]) {
                NSInteger num = [[USERDEFAULTS objectForKey:@"NotiType_Like"] integerValue];
                if (num<0) { num = 0; }
                return num;
            }else {
                return 0;
            }
        }
            break;
        case NotiType_Comment:
        {
            if ([USERDEFAULTS objectForKey:@"NotiType_Comment"]) {
                NSInteger num = [[USERDEFAULTS objectForKey:@"NotiType_Comment"] integerValue];
                if (num<0) { num = 0; }
                return num;
            }else {
                return 0;
            }
        }
            break;
            case NotiType_All:
        {
            __block NSInteger sum = 0;
            NSArray *arr = @[@"NotiType_System",@"NotiType_SignOrActivity",@"NotiType_Video",@"NotiType_Like",@"NotiType_Comment"];
            [arr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([USERDEFAULTS objectForKey:obj]) {
                    NSInteger num = [[USERDEFAULTS objectForKey:obj] integerValue];
                    sum += num;
                }
            }];
            return sum;
        }
        default:
            return 0;
            break;
    }
}

//登录, 退出登录, 清空未读消息数
- (void)notiPushNumberClearWithType:(NotiType)type {
    switch (type) {
        case NotiType_System:
        {
            [USERDEFAULTS setObject:[NSNumber numberWithInteger:0] forKey:@"NotiType_System"];
        }
            break;
        case NotiType_SignOrActivity:
        {
            [USERDEFAULTS setObject:[NSNumber numberWithInteger:0] forKey:@"NotiType_SignOrActivity"];
        }
            break;
        case NotiType_Video:
        {
            [USERDEFAULTS setObject:[NSNumber numberWithInteger:0] forKey:@"NotiType_Video"];
        }
            break;
        case NotiType_Like:
        {
            [USERDEFAULTS setObject:[NSNumber numberWithInteger:0] forKey:@"NotiType_Like"];
        }
            break;
        case NotiType_Comment:
        {
            [USERDEFAULTS setObject:[NSNumber numberWithInteger:0] forKey:@"NotiType_Comment"];
        }
            break;
        case NotiType_All:
        {
            NSArray *arr = @[@"NotiType_System",@"NotiType_SignOrActivity",@"NotiType_Video",@"NotiType_Like",@"NotiType_Comment"];
            [arr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([USERDEFAULTS objectForKey:obj]) {
                    [USERDEFAULTS setObject:[NSNumber numberWithInteger:0] forKey:obj];
                }
            }];
        }
            break;
        default:
            break;
    }
    [USERDEFAULTS synchronize];
    
    //操作之后, 根据总未读消息数, 刷新App角标 和 Tabbar
    [self refreshAllBadge];
}

//设置App角标, MineTab角标, 个人中心我的消息角标
- (void)refreshAllBadge {
    NSInteger sum = [self notiPushNumberWithType:NotiType_All];
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:sum];
    
    if (sum>0) {
        [g_App.tabBarVC.tabBar showBadgeOnItemIndex:4];
    }else {
        [g_App.tabBarVC.tabBar hideBadgeOnItemIndex:4];
    }
    
    if (g_App.tabBarVC.selectedIndex == 3) { //在 "我的" 模块
        KSBaseNavViewController *nav = SelectVC;
        [nav.viewControllers enumerateObjectsUsingBlock:^(__kindof UIViewController * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj isMemberOfClass:[MineViewController class]]) {
                MineViewController *vc = (MineViewController *)obj;
                [vc refreshMsgCenterRedPoint];
            }
        }];
    }else {
        //这里不操作 我的模块willAppear里, 刷新 个人中心我的消息角标
    }
}

//每日弹框记录, 当天第一次启动请求弹框并记录
//YES:今天启动过了  NO:今天未启动
- (BOOL)haveShowDailyPopOut {
    NSString *todayDate = [Tool dateStringForAdvClickCacheKey];

    if([USERDEFAULTS objectForKey:DailyPopOutKey]) {
        NSArray *arr = [USERDEFAULTS objectForKey:DailyPopOutKey];
        if (arr.count>0) {
            if ([arr containsObject:todayDate]) {
                return YES;
            }else {
                return NO;
            }
        }else {
            NSArray *arr = @[todayDate];
            [USERDEFAULTS setObject:arr forKey:DailyPopOutKey];
            [USERDEFAULTS synchronize];
            return NO;
        }
    }else {
        NSArray *arr = @[todayDate];
        [USERDEFAULTS setObject:arr forKey:DailyPopOutKey];
        [USERDEFAULTS synchronize];
        return NO;
    }
}

@end
