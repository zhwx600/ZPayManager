//
//  ZPayManager.m
//  TinyShop
//
//  Created by zhwx on 15/12/9.
//  Copyright © 2015年 zhenwanxiang. All rights reserved.
//

#import "ZPayManager.h"
#import <AlipaySDK/AlipaySDK.h>
#import "APOrderInfo.h"
#import "APRSASigner.h"

#import <CommonCrypto/CommonDigest.h>
#import "WXApi.h"



//支付宝 错误码
#define ALI_SUCCESSFUL_STATUS @"9000"
#define ALI_ORDER_PAY_FALSE @"4000"
#define ALI_NET_ERROR @"6002"
#define ALI_USER_CANCEL @"6001"


//接入模式设定,两个值: @"00":代表接入生产环境(正式版 本需要); @"01":代表接入开发测试环境(测 试版本需要);
//#define kUnionpayMode               @"01"
//#define kPlublicKeyFile             @"public_test.key"
/*********正式环境***********/
#define kUnionpayMode               @"00"
#define kPlublicKeyFile             @"public_product.key"
#define UnionpayCode_Success                @"success"
#define UnionpayCode_Fail                   @"fail"
#define UnionpayCode_Cancel                 @"cancel"

//#define UPPay_AppScheme @"UPPayTinyShop"//银联
// extern NSString* kUPPayFinishedNotify;//银联支付结束通知
const NSString* kUPPayFinishedNotify = @"kUPPayFinishedNotify";



@interface ZPayManager()<WXApiDelegate>


@end



@implementation ZPayManager

+(instancetype) shareInstance
{
    static ZPayManager* __payManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __payManager = [[ZPayManager alloc] init];
    });
    return __payManager;
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        
//        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uppayFinishedNotify:) name:(NSString*)kUPPayFinishedNotify object:nil];
        
    }
    return self;
}

-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



-(void) configAlipayAppId:(NSString*)appid
                      pid:(NSString*)pid
                     rsa2:(NSString*)rsa2
                      rsa:(NSString*)rsa
                   scheme:(NSString*)scheme
                 sellerId:(NSString*)sellerId
{
    _o_aliAppId = appid;
    _o_aliPId = pid;
    _o_aliRsa2PrivateKey = rsa2;
    _o_aliRsaPrivateKey = rsa;
    _o_aliAppScheme = scheme;
    _o_aliSellerId = sellerId;
}
-(void) configWXAppId:(NSString*)appid
{
    _o_wxAppId = appid;
}



/**
 在 AppDelegate 接收到openurl 操作时，解析url (包含微信、支付宝)
 处理 payOrder: 的callback 不调用的情况
 @param url openurl 参数
 */
-(void) parsePayUrl:(NSURL*)url
{
    //只解析 支付宝 支付url
    if([url.host isEqualToString:@"safepay"]) {
        //跳转支付宝钱包进行支付，处理支付结果
        [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic) {
            NSLog(@"AlipaySDK processOrderWithPaymentResult:\n%@",resultDic);
            
            [self handleAlipayResult:resultDic];
            
        }];
        
    }else if([[url scheme] isEqualToString:_o_wxAppId]) {
        
        //wx320ce700000000://pay/?returnKey=(null)&ret=-2
        //wx320ce700000000://platformId=wechat
        //微信支付
        if ([url.host isEqualToString:@"pay"]) {
            [WXApi handleOpenURL:url delegate:self];
        }
    }
    
}


#pragma mark- 支付宝
/**
 *  支付宝支付
 *
 *  @param tradeNo     交易号
 *  @param productName 商品名称
 *  @param amount      金额
 *  @param callBackUrl 回调地址
 */
-(void) payOrderByAlixPayWithTradeNo:(NSString*)tradeNo
                         productName:(NSString*)productName
                              amount:(double)amount
                         callbackUrl:(NSString*)callBackUrl
{
    
    NSString *rsa2PrivateKey = _o_aliRsa2PrivateKey.length>0?_o_aliRsa2PrivateKey:@"";
    NSString *rsaPrivateKey = _o_aliRsaPrivateKey.length>0?_o_aliRsaPrivateKey:@"";
    
    
    /*
     *生成订单信息及签名
     */
    //将商品信息赋予AlixPayOrder的成员变量
    APOrderInfo* order = [APOrderInfo new];
    
    // NOTE: app_id设置
    order.app_id = _o_aliAppId;
    
    // NOTE: 支付接口名称
    order.method = @"alipay.trade.app.pay";
    
    // NOTE: 参数编码格式
    order.charset = @"utf-8";
    
    // NOTE: 当前时间点
    NSDateFormatter* formatter = [NSDateFormatter new];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    order.timestamp = [formatter stringFromDate:[NSDate date]];
    
    // NOTE: 支付版本
    order.version = @"1.0";
    
    // NOTE: sign_type 根据商户设置的私钥来决定
    order.sign_type = (rsa2PrivateKey.length > 1)?@"RSA2":@"RSA";
    
    // NOTE: 商品数据
    order.biz_content = [APBizContent new];
    order.biz_content.body = productName;//商品描述
    order.biz_content.subject = productName;//商品名字
    order.biz_content.out_trade_no = tradeNo; //订单ID（由商家自行制定）
    order.biz_content.timeout_express = @"30m"; //超时时间设置
    order.biz_content.total_amount = [NSString stringWithFormat:@"%.2f", amount]; //商品价格
    order.biz_content.seller_id = _o_aliSellerId;
    
    //将商品信息拼接成字符串
    NSString *orderInfo = [order orderInfoEncoded:NO];
    NSString *orderInfoEncoded = [order orderInfoEncoded:YES];
    NSLog(@"orderSpec = %@",orderInfo);
    
    // NOTE: 获取私钥并将商户信息签名，外部商户的加签过程请务必放在服务端，防止公私钥数据泄露；
    //       需要遵循RSA签名规范，并将签名字符串base64编码和UrlEncode
    NSString *signedString = nil;
    APRSASigner* signer = [[APRSASigner alloc] initWithPrivateKey:((rsa2PrivateKey.length > 1)?rsa2PrivateKey:rsaPrivateKey)];
    if ((rsa2PrivateKey.length > 1)) {
        signedString = [signer signString:orderInfo withRSA2:YES];
    } else {
        signedString = [signer signString:orderInfo withRSA2:NO];
    }
    
    // NOTE: 如果加签成功，则继续执行支付
    if (signedString != nil) {
        //应用注册scheme,在AliSDKDemo-Info.plist定义URL types
        NSString *appScheme = _o_aliAppScheme;
        
        // NOTE: 将签名成功字符串格式化为订单字符串,请严格按照该格式
        NSString *orderString = [NSString stringWithFormat:@"%@&sign=%@",
                                 orderInfoEncoded, signedString];
        
        // NOTE: 调用支付结果开始支付
        [[AlipaySDK defaultService] payOrder:orderString fromScheme:appScheme callback:^(NSDictionary *resultDic) {
            NSLog(@"AlipaySDK payOrder reslut:\n%@",resultDic);
            
            [self handleAlipayResult:resultDic];
            
        }];
    }else{
        NSLog(@"AlipaySDK 签名错误");
    }

}



-(void) handleAlipayResult:(NSDictionary*)resultDic
{
    NSString *status = [resultDic objectForKey:@"resultStatus"];
    if ([status isEqualToString:ALI_SUCCESSFUL_STATUS]) {
        //成功
        if ([_o_delegate respondsToSelector:@selector(payFinishedWithResult:payType:error:)]) {
            [_o_delegate payFinishedWithResult:ZPayResultType_Success payType:ZPayType_Alipay error:nil];
        }
        
    } else if ([status isEqualToString:ALI_ORDER_PAY_FALSE]) {
        //失败
        if ([_o_delegate respondsToSelector:@selector(payFinishedWithResult:payType:error:)]) {
            [_o_delegate payFinishedWithResult:ZPayResultType_Failed payType:ZPayType_Alipay error:nil];
        }
    } else if ([status isEqualToString:ALI_USER_CANCEL]) {
        //取消
        if ([_o_delegate respondsToSelector:@selector(payFinishedWithResult:payType:error:)]) {
            [_o_delegate payFinishedWithResult:ZPayResultType_Cancel payType:ZPayType_Alipay error:nil];
        }
    } else if ([status isEqualToString:ALI_NET_ERROR]) {
        //网络错误
        if ([_o_delegate respondsToSelector:@selector(payFinishedWithResult:payType:error:)]) {
            [_o_delegate payFinishedWithResult:ZPayResultType_NetError payType:ZPayType_Alipay error:nil];
        }
    }else{
        if ([_o_delegate respondsToSelector:@selector(payFinishedWithResult:payType:error:)]) {
            [_o_delegate payFinishedWithResult:ZPayResultType_Failed payType:ZPayType_Alipay error:nil];
        }
    }
    
}


#pragma mark- 微信

/**
 *  微信支付
 *
 *  @param partnerId 商家向财付通申请的商家id
 *  @param prepayId  预支付订单
 *  @param nonceStr  随机串，防重发
 *  @param timeStamp 时间戳，防重发
 *  @param package   商家根据财付通文档填写的数据和签名
 *  @param sign      商家根据微信开放平台文档对数据做的签名
 */
-(void) payOrderByWeiXinWithPartnerId:(NSString*)partnerId
                             prepayId:(NSString*)prepayId
                             nonceStr:(NSString*)nonceStr
                            timeStamp:(NSTimeInterval)timeStamp
                              package:(NSString*)package
                                 sign:(NSString*)sign
{
    if (![self isValidateWeiXinApp]) {
        return;
    }
    
    //调起微信支付
    PayReq* req             = [[PayReq alloc] init];
    req.partnerId           = partnerId;
    req.prepayId            = prepayId;
    req.nonceStr            = nonceStr;
    req.timeStamp           = (UInt32)timeStamp;
    req.package             = package;
    req.sign                = sign;
    
    //    req.partnerId           = @"10000100";
    //    req.prepayId            = @"wx201601061632260a08785e440987115400";
    //    req.nonceStr            = @"590b09afb16979332598afa20ca75c22";
    //    req.timeStamp           = (UInt32)1452069146;
    //    req.package             = @"Sign=WXPay";
    //    req.sign                = @"CA9BADFAEEAA431DC7485AC7BB4EC743";
    
    
    [WXApi sendReq:req];
}

-(BOOL) isValidateWeiXinApp
{
    BOOL isInstalled = [WXApi isWXAppInstalled];
    if (!isInstalled) {
        //未安装微信
        if ([_o_delegate respondsToSelector:@selector(payFinishedWithResult:payType:error:)]) {
            [_o_delegate payFinishedWithResult:ZPayResultType_UnInstall payType:ZPayType_WeiXin error:nil];
        }
        
        return NO;
    }
    
    BOOL isSupport = [WXApi isWXAppSupportApi];
    if (!isSupport) {
        
        //不支持
        if ([_o_delegate respondsToSelector:@selector(payFinishedWithResult:payType:error:)]) {
            [_o_delegate payFinishedWithResult:ZPayResultType_UnSupport payType:ZPayType_WeiXin error:nil];
        }
        return NO;
    }
    
    return YES;
}


#pragma mark- WXApiDelegate
/*! @brief 收到一个来自微信的请求，处理完后调用sendResp
 *
 * 收到一个来自微信的请求，异步处理完成后必须调用sendResp发送处理结果给微信。
 * 可能收到的请求有GetMessageFromWXReq、ShowMessageFromWXReq等。
 * @param req 具体请求内容，是自动释放的
 */
-(void) onReq:(BaseReq*)req
{
    NSLog(@"req = %@",req);
}

/*! @brief 发送一个sendReq后，收到微信的回应
 *
 * 收到一个来自微信的处理结果。调用一次sendReq后会收到onResp。
 * 可能收到的处理结果有SendMessageToWXResp、SendAuthResp等。
 * resp具体的回应内容，是自动释放的
 */
-(void) onResp:(BaseResp*)resp
{
    NSLog(@"resp = %@",NSStringFromClass([resp class]));
        //支付返回的结果
    if ([resp isKindOfClass:[PayResp class]]){
        
        PayResp *response = (PayResp *)resp;
        switch (response.errCode) {
            case WXSuccess: {
                if ([self respondsToSelector:@selector(weixinPaySuccess:)]) {
                    [self weixinPaySuccess:response];
                }
            }
                break;
            default: {
                if ([self respondsToSelector:@selector(weixinPayFail:)]) {
                    [self weixinPayFail:response];
                }
            }
                break;
        }
    }
    
    
}




-(void) weixinPaySuccess:(PayResp*) resp
{
    if ([_o_delegate respondsToSelector:@selector(payFinishedWithResult:payType:error:)]) {
        [_o_delegate payFinishedWithResult:ZPayResultType_Success payType:ZPayType_WeiXin error:nil];
    }
}

-(void) weixinPayFail:(PayResp*) resp
{
    //可能的原因：签名错误、未注册APPID、项目设置APPID不正确、注册的APPID与设置的不匹配、其他异常等。
    if (resp.errCode == -1) {
        if ([_o_delegate respondsToSelector:@selector(payFinishedWithResult:payType:error:)]) {
            [_o_delegate payFinishedWithResult:ZPayResultType_Failed payType:ZPayType_WeiXin error:resp.errStr];
        }
        //无需处理。发生场景：用户不支付了，点击取消，返回APP。
    }else if (resp.errCode == -2){
        if ([_o_delegate respondsToSelector:@selector(payFinishedWithResult:payType:error:)]) {
            [_o_delegate payFinishedWithResult:ZPayResultType_Cancel payType:ZPayType_WeiXin error:nil];
        }
    }
    
}



#pragma mark- 银联

///**
// *  银联支付
// *
// *  @param tn 银联支付tn值
// */
//-(void) payOrderByUnionPayWithTN:(NSString*)tn
//{
//    [[UPPaymentControl defaultControl] startPay:tn fromScheme:UPPay_AppScheme mode:kUnionpayMode viewController:_o_payVC];
//    
//}
//
////银联支付完成通知
//-(void) uppayFinishedNotify:(NSNotification*)notify
//{
//    [self handleResult:notify.object data:notify.userInfo];
//}
//
//
//-(void) handleResult:(NSString*)code data:(NSDictionary*)data
//{
//    
//    //结果code为成功时，先校验签名，校验成功后做后续处理
//    if([code isEqualToString:UnionpayCode_Success]) {
//        
//        //支付成功且验签成功，展示支付成功提示
//        if ([_o_delegate respondsToSelector:@selector(payFinishedWithResult:payType:error:)]) {
//            [_o_delegate payFinishedWithResult:ZPayResultType_Success payType:ZPayType_Union error:nil];
//        }
//    }
//    else if([code isEqualToString:UnionpayCode_Fail]) {
//        //交易失败
//        if ([_o_delegate respondsToSelector:@selector(payFinishedWithResult:payType:error:)]) {
//            [_o_delegate payFinishedWithResult:ZPayResultType_Failed payType:ZPayType_Union error:nil];
//        }
//    }
//    else if([code isEqualToString:UnionpayCode_Cancel]) {
//        //交易取消
//        if ([_o_delegate respondsToSelector:@selector(payFinishedWithResult:payType:error:)]) {
//            [_o_delegate payFinishedWithResult:ZPayResultType_Cancel payType:ZPayType_Union error:nil];
//        }
//    }
//}
//
//
//- (NSString *) readPublicKey:(NSString *) keyName
//{
//    if (keyName == nil || [keyName isEqualToString:@""]) return nil;
//    
//    NSMutableArray *filenameChunks = [[keyName componentsSeparatedByString:@"."] mutableCopy];
//    NSString *extension = filenameChunks[[filenameChunks count] - 1];
//    [filenameChunks removeLastObject]; // remove the extension
//    NSString *filename = [filenameChunks componentsJoinedByString:@"."]; // reconstruct the filename with no extension
//    
//    NSString *keyPath = [[NSBundle mainBundle] pathForResource:filename ofType:extension];
//    
//    NSString *keyStr = [NSString stringWithContentsOfFile:keyPath encoding:NSUTF8StringEncoding error:nil];
//    
//    return keyStr;
//}
//
//-(BOOL) verify:(NSString *) resultStr {
//    
//    //从NSString转化为NSDictionary
//    NSData *resultData = [resultStr dataUsingEncoding:NSUTF8StringEncoding];
//    NSDictionary *data = [NSJSONSerialization JSONObjectWithData:resultData options:0 error:nil];
//    
//    //获取生成签名的数据
//    NSString *sign = data[@"sign"];
//    NSString *signElements = data[@"data"];
//    //NSString *pay_result = signElements[@"pay_result"];
//    //NSString *tn = signElements[@"tn"];
//    //转换服务器签名数据
//    NSData *nsdataFromBase64String = [[NSData alloc]
//                                      initWithBase64EncodedString:sign options:0];
//    //生成本地签名数据，并生成摘要
//    //    NSString *mySignBlock = [NSString stringWithFormat:@"pay_result=%@tn=%@",pay_result,tn];
//    //    NSData *dataOriginal = [[self sha1:signElements] dataUsingEncoding:NSUTF8StringEncoding];
//    NSData *dataOriginal = [[self sha1:signElements] dataUsingEncoding:NSUTF8StringEncoding];
//    //验证签名
//    //TODO：此处如果是正式环境需要换成public_product.key
//    NSString *pubkey =[self readPublicKey:kPlublicKeyFile];
//    OSStatus result=[URSA verifyData:dataOriginal sig:nsdataFromBase64String publicKey:pubkey];
//    
//    
//    
//    //签名验证成功，商户app做后续处理
//    if(result == 0) {
//        //支付成功且验签成功，展示支付成功提示
//        return YES;
//    }
//    else {
//        //验签失败，交易结果数据被篡改，商户app后台查询交易结果
//        return NO;
//    }
//    
//    return NO;
//}

- (NSString*)sha1:(NSString *)string
{
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1_CTX context;
    NSString *description;
    
    CC_SHA1_Init(&context);
    
    memset(digest, 0, sizeof(digest));
    
    description = @"";
    
    
    if (string == nil)
    {
        return nil;
    }
    
    // Convert the given 'NSString *' to 'const char *'.
    const char *str = [string cStringUsingEncoding:NSUTF8StringEncoding];
    
    // Check if the conversion has succeeded.
    if (str == NULL)
    {
        return nil;
    }
    
    // Get the length of the C-string.
    int len = (int)strlen(str);
    
    if (len == 0)
    {
        return nil;
    }
    
    
    if (str == NULL)
    {
        return nil;
    }
    
    CC_SHA1_Update(&context, str, len);
    
    CC_SHA1_Final(digest, &context);
    
    description = [NSString stringWithFormat:
                   @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                   digest[ 0], digest[ 1], digest[ 2], digest[ 3],
                   digest[ 4], digest[ 5], digest[ 6], digest[ 7],
                   digest[ 8], digest[ 9], digest[10], digest[11],
                   digest[12], digest[13], digest[14], digest[15],
                   digest[16], digest[17], digest[18], digest[19]];
    
    return description;
}

@end
