//
//  ZPayManager.h
//  TinyShop
//
//  Created by zhwx on 15/12/9.
//  Copyright © 2015年 zhenwanxiang. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 支付类型
 */
typedef enum : NSUInteger {
    ZPayType_Alipay = 0,//支付宝
    ZPayType_WeiXin,//微信
    ZPayType_Union,//银联
} ZPayType;


/**
 支付结果类型
 */
typedef enum : NSUInteger {
    ZPayResultType_Success = 0,//成功
    ZPayResultType_Cancel,//取消
    ZPayResultType_NetError,//网络错误
    ZPayResultType_Failed,//失败
    ZPayResultType_SignError,//签名数据异常（银联特有错误类型）
    ZPayResultType_DataException,//获取支付信息异常(微信特有错误类型)
    ZPayResultType_UnInstall,//未安装 (微信特有错误类型)
    ZPayResultType_UnSupport,//版本不支持 (微信特有错误类型)
} ZPayResultType;


/**
 *  支付结果代理
 */
@protocol PayResultDelegate <NSObject>

//app可以根据需求，是否显示 error信息。
//如: [NSString stringWithFormat:@"支付失败:%@",error]
-(void) payFinishedWithResult:(ZPayResultType)resultType payType:(ZPayType)payType error:(NSString*)error;

@end


/**
 *  所有支付方式管理类 (暂时只支持 常用的 支付宝、微信)
 *
 *  AlipaySDK version:15.5.0
 *  WeChatSDK version:1.8.1
 *
 */
@interface ZPayManager : NSObject

@property (nonatomic,weak) id<PayResultDelegate> o_delegate;//代理(一般为当前页面 UIViewController)


//支付宝 基本支付信息设置
@property (nonatomic,copy) NSString* o_aliAppId;//支付宝APPID(必填)
@property (nonatomic,copy) NSString* o_aliPId;//支付宝商户id（必填）
@property (nonatomic,copy) NSString* o_aliRsa2PrivateKey;//支付宝商RSA2私钥（必填2选1）
@property (nonatomic,copy) NSString* o_aliRsaPrivateKey;//支付宝商RSA1私钥（必填2选1）
@property (nonatomic,copy) NSString* o_aliAppScheme;//支付宝App 跳转Scheme(必填)

@property (nonatomic,copy) NSString* o_aliSellerId;//支付宝商户账号 （选填）

//微信 基本支付信息设置
@property (nonatomic,copy) NSString* o_wxAppId;//微信APPID(必填)


#pragma mark-

+(instancetype) shareInstance;

//(rsa2、rsa 二选一)，sellerId 选填
-(void) configAlipayAppId:(NSString*)appid
                      pid:(NSString*)pid
                     rsa2:(NSString*)rsa2
                      rsa:(NSString*)rsa
                   scheme:(NSString*)scheme
                 sellerId:(NSString*)sellerId;
-(void) configWXAppId:(NSString*)appid;


/**
 在 AppDelegate 接收到openurl 操作时，解析url (包含微信、支付宝) 如:
 
 [[ZPayManager shareInstance] parsePayUrl:url]
 
 处理 payOrder: 的callback 不调用的情况
 @param url openurl 参数
 */
-(void) parsePayUrl:(NSURL*)url;

#pragma mark- 支付宝、微信、银联
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
                         callbackUrl:(NSString*)callBackUrl;


/**
 *  微信支付 (微信支付前必须 [WXApi registerApp:WX_APP_ID])
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
                                 sign:(NSString*)sign;

///**
// *  银联支付
// *
// *  @param tn 银联支付tn值
// */
//-(void) payOrderByUnionPayWithTN:(NSString*)tn;


#pragma mark- 代理方法 示例（可以直接copy 过去使用）:

//-(void) payFinishedWithResult:(ZPayResultType)resultType payType:(ZPayType)payType error:(NSString *)error
//{
//    if (resultType == ZPayResultType_Success) {
//        [JoProgressHUD makeToast:@"支付成功"];
//
//        [self beginRefreshing];
//
//        return;
//    }else if (resultType == ZPayResultType_Cancel) {
//        [JoProgressHUD makeToast:@"取消支付"];
//    }else if (resultType == ZPayResultType_Failed) {
//        [JoProgressHUD makeToast:@"支付失败"];
//    }else if (resultType == ZPayResultType_NetError) {
//        [JoProgressHUD makeToast:@"支付失败,网络异常"];
//    }else if (resultType == ZPayResultType_SignError) {
//        [JoProgressHUD makeToast:@"支付失败,签名异常"];
//    }else if (resultType == ZPayResultType_DataException) {
//        [JoProgressHUD makeToast:@"获取支付信息异常"];
//    }else if (resultType == ZPayResultType_UnSupport) {
//
//        [JoProgressHUD makeToast:@"您的微信版本不支持支付，请切换支付方式或安装最新版微信"];
//
//    }else if (resultType == ZPayResultType_UnInstall) {
//
//        [JoProgressHUD makeToast:@"您没有安装微信，请切换支付方式或安装最新版微信"];
//
//    }
//
//}



@end
