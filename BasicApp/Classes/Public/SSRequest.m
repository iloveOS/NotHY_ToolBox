//
//  SSRequest.m
//  SmallStuff
//
//  Created by Hy on 2017/3/29.
//  Copyright © 2017年 yuhuimin. All rights reserved.
//

#import "SSRequest.h"
#import "Tool.h"
#import "LEEAlert.h"
#import "RSAUtil.h"

@interface SSRequest ()
@end

@implementation SSRequest

static AFHTTPSessionManager * extracted(SSRequest *object) {
    return object.sessionManager;
}

-(NSString *)URLEncodedString:(NSString *)str {
    NSString *encodedString = (NSString *)
    CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                              (CFStringRef)str,
                                                              NULL,
                                                              (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                              kCFStringEncodingUTF8));
    return encodedString;
}

-(NSString *)URLDecodedString:(NSString *)str {
    NSString *decodedString=(__bridge_transfer NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL, (__bridge CFStringRef)str, CFSTR(""), CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
    return decodedString;
}

static SSRequest *ssrequest = nil;

+ (instancetype)request {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ssrequest = [[SSRequest alloc]init];
    });
    return ssrequest;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (ssrequest == nil) {
            ssrequest = [super allocWithZone:zone];
        }
    });
    return ssrequest;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSString *cerPath = [[NSBundle mainBundle] pathForResource:@"iOS_KS_trust_hosts" ofType:@"cer"];
        NSData * certData =[NSData dataWithContentsOfFile:cerPath];
        
        AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
        // allowInvalidCertificates 是否允许无效证书（也就是自建的证书），默认为NO
        // 如果是需要验证自建证书，需要设置为YES
        //是否允许不信任的证书（证书无效、证书时间过期）通过验证 ，默认为NO.
        //发布APP的话，尽量不要设置allowInvalidCertificates = YES;
        //不要问为什么，这是允许无效证书，只是调试测试的时候使用，很可能无法通过审核
        securityPolicy.allowInvalidCertificates = YES; //[USER_MANAGER isDevStatus];
        //validatesDomainName 是否需要验证域名，默认为YES;
        //假如证书的域名与你请求的域名不一致，需把该项设置为NO；如设成NO的话，即服务器使用其他可信任机构颁发的证书，也可以建立连接，这个非常危险，建议打开。
        //置为NO，主要用于这种情况：客户端请求的是子域名，而证书上的是另外一个域名。因为SSL证书上的域名是独立的，假如证书上注册的域名是www.google.com，那么mail.google.com是无法验证通过的；当然，有钱可以注册通配符的域名*.google.com，但这个还是比较贵的。
        //如置为NO，建议自己添加对应域名的校验逻辑。
        securityPolicy.validatesDomainName =NO;    //是否需要验证域名，默认YES
        securityPolicy.pinnedCertificates = [NSSet setWithObject:certData];
        
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        manager.securityPolicy = securityPolicy;
        self.sessionManager = manager;
    }
    return self;
}

/** 非登录相关的GET请求 */
- (void)GET:(NSString *)URLString
 parameters:(id)parameters
    success:(void (^)(SSRequest *request, NSDictionary *response))success
    failure:(void (^)(SSRequest *request, NSString *errorMsg))failure {
    
    self.operationQueue = self.sessionManager.operationQueue;
    AFJSONResponseSerializer *JsonSerializer = [AFJSONResponseSerializer serializer];
    JsonSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript",@"text/html", nil];
    JsonSerializer.removesKeysWithNullValues=YES;
    self.sessionManager.responseSerializer = JsonSerializer;
    
    NSString *requestUrlString = SSStr([USER_MANAGER serverAddress], URLString);
    //local
//    requestUrlString = SSStr(@"http://10.0.0.19:8082/", URLString);

    self.sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
    self.sessionManager.requestSerializer.timeoutInterval = 10.f;
    [self.sessionManager.requestSerializer setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [self.sessionManager.requestSerializer setValue:[self getUserAgentStrWithUrlStr:URLString IsLogin:NO] forHTTPHeaderField:@"User-Agent"];
    
    if ([URLString isEqualToString:HomeHotChannelUrl] || [URLString isEqualToString:DiscoverShortVideoUrl]) {
        NSDictionary *advDic = [USER_MANAGER getAdvParamDicWithPositionID:kGDTPositionId_DiscoverAdvCell slotWidth:ScreenWidth slotHeight:self.sizeH(320)];
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:advDic options:NSJSONWritingPrettyPrinted error:nil];
        NSString *receiptStr = [jsonData base64EncodedStringWithOptions:0];
        [self.sessionManager.requestSerializer setValue:receiptStr forHTTPHeaderField:@"Ads-Agent"];
      
    }else if ([URLString isEqualToString:SearchLinkingOrResultUrl]) {
        NSDictionary *advDic = [USER_MANAGER getAdvParamDicWithPositionID:kGDTPositionId_SearchResultAdvCell slotWidth:ScreenWidth slotHeight:self.sizeH(80)];
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:advDic options:NSJSONWritingPrettyPrinted error:nil];
        NSString *receiptStr = [jsonData base64EncodedStringWithOptions:0];
        [self.sessionManager.requestSerializer setValue:receiptStr forHTTPHeaderField:@"Ads-Agent"];
    
    }else if ([URLString isEqualToString:ShortVideoRecomListUrl]) {
        NSDictionary *advDic = [USER_MANAGER getAdvParamDicWithPositionID:TTPositionId_ShortVideoPlayListFeed slotWidth:ScreenWidth slotHeight:self.sizeH(320)];
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:advDic options:NSJSONWritingPrettyPrinted error:nil];
        NSString *receiptStr = [jsonData base64EncodedStringWithOptions:0];
        [self.sessionManager.requestSerializer setValue:receiptStr forHTTPHeaderField:@"Ads-Agent"];
    }
    
    [self.sessionManager GET:requestUrlString parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        long long endTime = [Tool getCurrentTimeMillsNum];
        long long startTime = [responseObject[@"requestStartTime"] longLongValue];
        long long durationTime = startTime - endTime;
        [USERDEFAULTS setObject:[NSNumber numberWithLong:durationTime] forKey:LastRequestDurTime];
        [USERDEFAULTS synchronize];

        if([responseObject[@"code"] integerValue] == 10000) {
            success(self,responseObject);
        }else {
            failure(self,responseObject[@"message"]);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if(error.code == -1009) {
            failure(self,@"网络连接中断,请检查网络");
        }else {
            failure(self,error.localizedDescription);
        }
    }];
}

/** 登录相关的GET请求 */
- (void)GETAboutLogin:(NSString *)URLString
           parameters:(NSDictionary *)parameters
              success:(void (^)(SSRequest *request, NSDictionary *response))success
              failure:(void (^)(SSRequest *request, NSString *errorMsg))failure {
    
    self.operationQueue = self.sessionManager.operationQueue;
    AFJSONResponseSerializer *JsonSerializer = [AFJSONResponseSerializer serializer];
    JsonSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript",@"text/html", nil];
    JsonSerializer.removesKeysWithNullValues=YES;
    self.sessionManager.responseSerializer = JsonSerializer;
    
    NSString *requestUrlString = SSStr([USER_MANAGER serverAddressWithLogin], URLString);
    //local
    //    requestUrlString = SSStr(@"http://10.0.0.19:8082/", URLString);

    self.sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
    self.sessionManager.requestSerializer.timeoutInterval = 10.f;
    [self.sessionManager.requestSerializer setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [self.sessionManager.requestSerializer setValue:[self getUserAgentStrWithUrlStr:URLString IsLogin:YES] forHTTPHeaderField:@"User-Agent"];
    
    [self.sessionManager GET:requestUrlString parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        long long endTime = [Tool getCurrentTimeMillsNum];
        long long startTime = [responseObject[@"requestStartTime"] longLongValue];
        long long durationTime = startTime - endTime;

        [USERDEFAULTS setObject:[NSNumber numberWithLong:durationTime] forKey:LastRequestDurTime];
        [USERDEFAULTS synchronize];
        
        if([responseObject[@"code"] integerValue] == 10000) {
            success(self,responseObject);
        }else {
            failure(self,responseObject[@"message"]);
        }
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if(error.code == -1009) {
            failure(self,@"网络连接中断,请检查网络");
        }else {
            failure(self,error.localizedDescription);
        }
    }];
}

//非登录类的POST请求
- (void)POST:(NSString *)URLString
  parameters:(id)parameters
     success:(void (^)(SSRequest *request, id response))success
     failure:(void (^)(SSRequest *request, NSString *errorMsg))failure{
    
    self.operationQueue = self.sessionManager.operationQueue;
    AFJSONResponseSerializer *JsonSerializer = [AFJSONResponseSerializer serializer];
    JsonSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript",@"text/html", nil];
    JsonSerializer.removesKeysWithNullValues=YES;
    self.sessionManager.responseSerializer = JsonSerializer;
    
    NSString *requestUrlString = SSStr([USER_MANAGER serverAddress], URLString);

    self.sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
    self.sessionManager.requestSerializer.timeoutInterval = 10.f;
    if ([URLString isEqualToString:CheckInAppPurchaseUrl]) {
        self.sessionManager.requestSerializer.timeoutInterval = 20.f;
    }
    [self.sessionManager.requestSerializer setValue:@"application/json;charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [self.sessionManager.requestSerializer setValue:[self getUserAgentStrWithUrlStr:URLString IsLogin:NO] forHTTPHeaderField:@"User-Agent"];
    
    if ([URLString isEqualToString:ShortVideoRecomListUrl]) {
        NSDictionary *advDic = [USER_MANAGER getAdvParamDicWithPositionID:TTPositionId_ShortVideoPlayListFeed slotWidth:ScreenWidth slotHeight:self.sizeH(320)];
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:advDic options:NSJSONWritingPrettyPrinted error:nil];
        NSString *receiptStr = [jsonData base64EncodedStringWithOptions:0];
        [self.sessionManager.requestSerializer setValue:receiptStr forHTTPHeaderField:@"Ads-Agent"];
    }
    
    [self.sessionManager POST:requestUrlString parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        long long endTime = [Tool getCurrentTimeMillsNum];
        long long startTime = [responseObject[@"requestStartTime"] longLongValue];
        long long durationTime = startTime - endTime;

        [USERDEFAULTS setObject:[NSNumber numberWithLong:durationTime] forKey:LastRequestDurTime];
        [USERDEFAULTS synchronize];
        
        if([responseObject[@"code"] integerValue] == 10000) {
            success(self,responseObject);
        }else {
            failure(self,responseObject[@"message"]);
        }
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if(error.code == -1009) {
            failure(self,@"网络连接中断,请检查网络");
        }else {
            failure(self,error.localizedDescription);
        }
    }];
}

//登录类的POST请求
- (void)POSTAboutLogin:(NSString *)URLString
  parameters:(NSMutableDictionary*)parameters
     success:(void (^)(SSRequest *request, id response))success
     failure:(void (^)(SSRequest *request, NSString *errorMsg))failure{
    
    self.operationQueue = self.sessionManager.operationQueue;
    AFJSONResponseSerializer *JsonSerializer = [AFJSONResponseSerializer serializer];
    JsonSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript",@"text/html", nil];
    JsonSerializer.removesKeysWithNullValues=YES;
    self.sessionManager.responseSerializer = JsonSerializer;
    
    NSString *requestUrlString = SSStr([USER_MANAGER serverAddressWithLogin], URLString);
    //local
    //    requestUrlString = SSStr(@"http://10.0.0.19:8082/", URLString);

    self.sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
    self.sessionManager.requestSerializer.timeoutInterval = 10.f;
    [self.sessionManager.requestSerializer setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [self.sessionManager.requestSerializer setValue:[self getUserAgentStrWithUrlStr:URLString IsLogin:YES] forHTTPHeaderField:@"User-Agent"];
    
    [self.sessionManager POST:requestUrlString parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        long long endTime = [Tool getCurrentTimeMillsNum];
        long long startTime = [responseObject[@"requestStartTime"] longLongValue];
        long long durationTime = startTime - endTime;
        [USERDEFAULTS setObject:[NSNumber numberWithLong:durationTime] forKey:LastRequestDurTime];
        [USERDEFAULTS synchronize];

        if([responseObject[@"code"] integerValue] == 10000) {
            success(self,responseObject);
        }else {
            failure(self,responseObject[@"message"]);
        }
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        if(error.code == -1009) {
            failure(self,@"网络连接中断,请检查网络");
        }else {
            failure(self,error.localizedDescription);
        }
        
    }];
}

//code != 10000时  也需要返回的情况
- (void)POSTWithAllReturn:(NSString *)URLString
               parameters:(NSMutableDictionary*)parameters
                  success:(void (^)(SSRequest *request, id response))success
                  failure:(void (^)(SSRequest *request, NSString *errorMsg))failure{
    
    self.operationQueue = self.sessionManager.operationQueue;
    AFJSONResponseSerializer *JsonSerializer = [AFJSONResponseSerializer serializer];
    JsonSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript",@"text/html", nil];
    JsonSerializer.removesKeysWithNullValues=YES;
    self.sessionManager.responseSerializer = JsonSerializer;
    
    self.sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
    NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] requestWithMethod:@"POST" URLString:URLString parameters:parameters error:nil];
    request.timeoutInterval= 10.f;
    [parameters enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [request setValue:obj forHTTPHeaderField:key];
    }];
    [request setHTTPBody: [NSData data]];
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    //底层请求
    [[self.sessionManager dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        if(error!=nil)
        {
            failure(self,error.localizedDescription);
        }else
        {
            success(self,responseObject);
            if([responseObject[@"ret"] integerValue] == 306)
            {
                [[NSNotificationCenter defaultCenter]postNotificationName:OverDateToken object:nil];
            }
        }
    }]resume];
}

- (void)getWithURL:(NSString *)URLString {
    
//    [self GET:URLString parameters:nil success:^(SSRequest *request, NSDictionary *response) {
//        if ([self.delegate respondsToSelector:@selector(SSRequest:finished:)]) {
//            [self.delegate SSRequest:request finished:response];
//        }
//    } failure:^(SSRequest *request, NSError *error) {
//        if ([self.delegate respondsToSelector:@selector(SSRequest:Error:)]) {
//            [self.delegate SSRequest:request Error:error.description];
//        }
//    }];
}

- (NSString  *)sortedDictionary:(NSDictionary *)dict{
    
    //将所有的key放进数组
    NSArray *allKeyArray = [dict allKeys];
//    //序列化器对数组进行排序的block 返回值为排序后的数组
//    NSArray *afterSortKeyArray =  [allKeyArray sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
//        //排序操作
//        NSComparisonResult resuest = [obj1 compare:obj2];
//        return resuest;
//    }];
    //通过排列的key值获取value
    NSString * aesNormalStr = @"";
    for (NSString *sortsing in allKeyArray) {
        NSString *valueString = [dict objectForKey:sortsing];
        if(aesNormalStr.length == 0)
        {
            aesNormalStr = [NSString stringWithFormat:@"%@=%@",sortsing,[self URLEncodedString:[NSString stringWithFormat:@"%@",valueString]]];
        }else
        {
            aesNormalStr = [NSString stringWithFormat:@"%@&%@=%@",aesNormalStr,sortsing,[self URLEncodedString:[NSString stringWithFormat:@"%@",valueString]]];
        }
    }
    return aesNormalStr;
}

//广告反馈用的GET请求
- (void)AdvReportGET:(NSString *)URLString success:(void (^)(SSRequest *request, NSDictionary *response))success failure:(void (^)(SSRequest *request, NSString *errorMsg))failure {
    
    self.operationQueue = self.sessionManager.operationQueue;
    AFJSONResponseSerializer *JsonSerializer = [AFJSONResponseSerializer serializer];
    JsonSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript",@"text/html", nil];
    JsonSerializer.removesKeysWithNullValues=YES;
    self.sessionManager.responseSerializer = JsonSerializer;
    self.sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
    self.sessionManager.requestSerializer.timeoutInterval = 10.f;
    [self.sessionManager.requestSerializer setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [self.sessionManager.requestSerializer setValue:[self getUserAgentStrWithUrlStr:URLString IsLogin:NO] forHTTPHeaderField:@"User-Agent"];
    
    [self.sessionManager GET:URLString parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        long long endTime = [Tool getCurrentTimeMillsNum];
        long long startTime = [responseObject[@"requestStartTime"] longLongValue];
        long long durationTime = startTime - endTime;
        [USERDEFAULTS setObject:[NSNumber numberWithLong:durationTime] forKey:LastRequestDurTime];
        [USERDEFAULTS synchronize];
        
        if([responseObject[@"code"] integerValue] == 10000) {
            success(self,responseObject);
        }else {
            failure(self,responseObject[@"message"]);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if(error.code == -1009) {
            failure(self,@"网络连接中断,请检查网络");
        }else {
            failure(self,error.localizedDescription);
        }
    }];
}

- (void)cancelAllOperations{
    [self.operationQueue cancelAllOperations];
}

+(void)SSNetType:(NetType)netType URLString:(NSString *)URLString parameters:(NSDictionary *)parameters animationHud:(BOOL)isAnimation animationView:(UIView *)view MJRefreshScroll:(UIScrollView *)scroll refreshType:(SSRefreshType)refreshType success:(void (^)(BaseModel *, BOOL))success failure:(void (^)(NSString *))failure
{
    if(isAnimation)
    {
        SSGifShow(view, @"加载中...");
    }
    if(netType == GET)
    {
        [[SSRequest request] GET:URLString parameters:parameters success:^(SSRequest *request, NSDictionary *response) {
            if(isAnimation)
            {
                SSDissMissMBHud(view, YES);
            }
            if(scroll)
            {
                [[SSRequest request] MJRefreshStop:scroll refreshType:refreshType];
            }
            BaseModel * model = [BaseModel mj_objectWithKeyValues:response];
            if(success)
            {
                success(model,model.succeed);
            }
        } failure:^(SSRequest *request, NSString *errorMsg)
         {
             if(isAnimation)
             {
                 SSDissMissMBHud(view, YES);
             }
             if(scroll)
             {
                 [[SSRequest request] MJRefreshStop:scroll refreshType:refreshType];
             }
             if(failure)
             {
                 failure(errorMsg);
             }
         }];
    }
    else
    {
        [[SSRequest request] POST:URLString parameters:[parameters mutableCopy] success:^(SSRequest *request, id response) {
            
            if(isAnimation)
            {
                SSDissMissMBHud(view, YES);
            }
            if(scroll)
            {
                [[SSRequest request] MJRefreshStop:scroll refreshType:refreshType];
            }
            BaseModel * model = [BaseModel mj_objectWithKeyValues:response];
            if(success)
            {
                success(model,model.succeed);
            }
            
        } failure:^(SSRequest *request, NSString *errorMsg) {
            
            if(isAnimation)
            {
                SSDissMissMBHud(view, YES);
            }
            if(scroll)
            {
                [[SSRequest request] MJRefreshStop:scroll refreshType:refreshType];
            }
            if(failure)
            {
                failure(errorMsg);
            }
        }];
    }
}

- (NSString *)getUserAgentStrWithUrlStr:(NSString *)urlStr IsLogin:(BOOL)isLogin {
    
//    __block NSString *webUA = @"";
//    dispatch_async(dispatch_get_main_queue(), ^{
//        webUA = [USER_MANAGER getUserAgent];
//    });
    
    NSDictionary *infoDic = [[NSBundle mainBundle] infoDictionary];
    NSString *ver = [infoDic objectForKey:@"CFBundleShortVersionString"];
    //正确的: osTypeId:01
    //改成osTypeId:02试试
    NSString *ua = [NSString stringWithFormat:@"%@ ks2/%@ (agent:s;channel:%@;credential:%@;deviceId:%@;osTypeId:01;detailInfo:iOS;simTypeId:%@;netTypeId:%@;deviceTypeId:02;osVersion:%@;token:%@)",[USER_MANAGER getUserAgent],[USER_MANAGER getVersionStr],[USER_MANAGER getAppPubChannel],[USER_MANAGER getCredential],[USER_MANAGER getUUID],[USER_MANAGER getSimType],[USER_MANAGER getNetWorkType],ver,[self getTokenWithUrlStr:urlStr IsLogin:isLogin]];
    return ua;
}

- (NSString *)getTokenWithUrlStr:(NSString *)urlStr IsLogin:(BOOL)isLogin {
    NSString *userID = [USER_MANAGER getUserID];
    if (userID && userID.length>8) {
        userID = [NSString stringWithFormat:@"%@*%@#%@!%@$%@",[userID substringWithRange:NSMakeRange(0, 1)],[userID substringWithRange:NSMakeRange(1, 1)],[userID substringWithRange:NSMakeRange(2, 1)],[userID substringWithRange:NSMakeRange(4, 1)],[userID substringWithRange:NSMakeRange(7, 1)]];
    }
    
    NSString *app_Version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *token = [NSString stringWithFormat:@"/%@-%@-%@-",urlStr,[USER_MANAGER getTimeForToken],app_Version];
    NSString * md5Str = [Tool md5:SSStr(token, userID)];
    NSString *rsaStr = [RSAUtil encryptString:SSStr(token, md5Str) publicKey: isLogin ? [USER_MANAGER publicKeyWithLogin] : [USER_MANAGER publicKey]];
    return rsaStr;
}

-(void)MJRefreshStop:(UIScrollView*)scroll refreshType:(SSRefreshType)type
{
    if(type == SSHeaderRefreshType)
    {
        [scroll.mj_header endRefreshing];
    }else if (type == SSFooterRefreshType)
    {
        [scroll.mj_footer endRefreshing];
    }else
    {
        [scroll.mj_header endRefreshing];
        [scroll.mj_footer endRefreshing];
    }
}

@end


@implementation BaseModel
@end

@implementation CheckVersionModel
@end
