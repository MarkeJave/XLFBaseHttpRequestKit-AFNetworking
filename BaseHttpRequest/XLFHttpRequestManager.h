//
//  XLFHttpRequestManager.h
//  XLFBaseHttpRequestKit
//
//  Created by Marike Jave on 14-8-25.
//  Copyright (c) 2014年 Marike Jave. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AFNetWorking.h"

#import "XLFProgressViewDelegate.h"

@class XLFBaseHttpRequest;

typedef  UIViewController* (^VisibleViewControllerBlock)(UIView *loadingView,BOOL isHiddenLoadingView);

typedef void (^XLFCompleteBlock)();
typedef void (^XLFSuccessedBlock)(id request, id result) ;
typedef void (^XLFProgressBlock)(id request, CGFloat progress, NSData *responseData ) ;
typedef void (^XLFFailedBlock)(id request, NSError *error) ;

typedef void (^XLFNoneResultSuccessedBlock)(id request) ;
typedef void (^XLFBytesSuccessedBlock)(id request, NSData *bytes) ;

typedef void (^XLFOnlyStringResponseSuccessedBlock)(id request, id result, NSString *response);
typedef void (^XLFOnlyIntegerResponseSuccessedBlock)(id request, id result, NSInteger response);
typedef void (^XLFOnlyFloatResponseSuccessedBlock)(id request, id result, CGFloat response);
typedef void (^XLFOnlyArrayResponseSuccessedBlock)(id request, id result, NSArray *multipierResponses);
typedef void (^XLFOnlyDictionaryResponseSuccessedBlock)(id request, id result, NSDictionary *multipierResponses);


typedef NS_ENUM(NSInteger, XLFHttpRquestDataType) {

    XLFHttpRquestDataTypeJson,
    XLFHttpRquestDataTypeByte
};

extern NSInteger const XLFHttpRquestNormalTag;
extern NSString *const XLFHttpRquestModeGet;
extern NSString *const XLFHttpRquestModePost;
extern NSString *const XLFHttpRquestModePut;
extern NSString *const XLFHttpRquestModeDelete;

@interface NSObject(FilterNull)
- (id)filterNull;
@end

@protocol XLFHttpRequestDelegate <NSObject>
@optional
- (void)didFailWithError:(NSError *)err request:(XLFBaseHttpRequest *)baseRequest;

#pragma HttpRquestDataTypeJson
- (void)didFinishReuqestWithJSONValue:(id)json request:(XLFBaseHttpRequest *)baseRequest;
- (void)didLoadProgress:(CGFloat)progress request:(XLFBaseHttpRequest *)baseRequest;

#pragma HttpRquestDataTypeByte
- (void)didFinishReuqestWithData:(NSData*)responseData request:(XLFBaseHttpRequest *)baseRequest;
- (void)didLoadProgress:(CGFloat)progress data:(NSData*)responseData request:(XLFBaseHttpRequest *)baseRequest;

@end

//  文件类型（0：未知文件，1：office file[office文件] , 2：rar/zip[压缩文件]，3：MP4/avi[视频文件]，4：jpg/png[图片文件]）
typedef NS_ENUM(NSInteger ,XLFFileType){
    
    XLFFileTypeUnknown,
    XLFFileTypeOffice,
    XLFFileTypeCompression,
    XLFFileTypeVideo,
    XLFFileTypeImage
};

@interface XLFUploadFile : NSObject

@property(nonatomic, strong) NSData *data;

@property(nonatomic, copy  ) NSString *contentType;

@property(nonatomic, copy  ) NSString *fileName;

@property(nonatomic, assign) XLFFileType type;

+ (id)uploadFileWithFileData:(NSData *)fileData fileName:(NSString *)fileName contentType:(NSString *)contentType type:(XLFFileType)type;

- (id)initWithFileData:(NSData *)fileData fileName:(NSString *)fileName contentType:(NSString *)contentType type:(XLFFileType)type;

@end

@interface XLFHttpParameter : NSObject

/**
 *  请求操作
 */
@property(nonatomic, copy  ) NSString     *handle;

/**
 *  查询参数
 */
@property(nonatomic, strong) NSDictionary *queryParams;

/**
 *  表单参数
 */
@property(nonatomic, strong) NSDictionary *formParams;

/**
 *  文件参数
 */
//@property(nonatomic, strong) NSDictionary<NSString *, XLFUploadFile *> *fileParams;

/**
 *  请求头部参数
 */
@property(nonatomic, strong) NSDictionary *headParams;

/**
 *  路径参数
 */
@property(nonatomic, strong) NSArray      *pathParams;

/**
 *  请求体
 */
@property(nonatomic, strong) id            postBody;

@end

@interface XLFBaseHttpRequest : NSObject

@property (nonatomic, strong, readonly) NSURLSessionTask *URLSessionTask;
@property (nonatomic, strong, readonly) NSURLCache *cache;


@property (nonatomic, strong) id evUserInfo;
@property (nonatomic, copy  ) NSString *evUserTag;

@property (nonatomic, strong) XLFHttpParameter        *parameter;
@property (nonatomic, assign) NSInteger               requestSubTag;
@property (nonatomic, assign) BOOL                    needCache;
@property (nonatomic, copy  ) NSString                *cachePath;
@property (nonatomic, copy  ) NSString                *loadingHintsText;
@property (nonatomic, strong) Class<XLFProgressViewDelegate> progressViewClass;

@property (nonatomic, assign, getter = isHiddenLoadingView) BOOL  hiddenLoadingView;

@property (nonatomic, assign, readonly) XLFHttpRquestDataType dataType;

@property (nonatomic, assign, readonly) NSInteger             requestTag;
@property (nonatomic, copy  , readonly) NSDictionary          *descInfo;
@property (nonatomic, strong, readonly) NSError               *userError;
@property (nonatomic, copy  , readonly) id                    result;

@property (nonatomic, copy  ) NSArray<NSString *>           *listeningErrorInfos;

@property (nonatomic, copy  , readonly) void (^listeningErrorBlock)(id httpRequest, NSError *error);

/**
 *  请求的生命周期依赖对象，当该对象被释放后，便停止该请求
 */
@property(nonatomic, assign) id            relationObject;

/**
 *  三种回调方式
 *
 *  第一种：通过代理回调  优先级最高  默认为 XLFHttpRequestDelegate
 */
@property (nonatomic, assign) id evDelegate;
/**
 *  第三种：通过Selector回调 当XLFHttpRequestDelegate没有被实现时有效
 *
 *  类型一： [delegate performSelector:successSelector]
 *
 *  类型二： [delegate performSelector:successSelector withObject:(id)json]
 *
 *  类型三： [delegate performSelector:successSelector withObject:(id)json withObject:(id)request]
 */
@property (nonatomic, assign) SEL didSuccessSelector ;
/**
 *  类型一： [delegate performSelector:failureSelector]
 *
 *  类型二： [delegate performSelector:failureSelector withObject:(id)error]
 *
 *  类型三： [delegate performSelector:successSelector withObject:(id)error withObject:(id)request]
 */
@property (nonatomic, assign) SEL didFailureSelector ;
/**
 *  类型一： [delegate performSelector:didProgressSelector]
 *
 *  类型二： [delegate performSelector:didProgressSelector withObject:(NSNumble*)progress]
 *
 *  类型三： [delegate performSelector:didProgressSelector withObject:(NSNumble*)progress withObject:(id)request]
 */
@property (nonatomic, assign) SEL didProgressSelector ;

#if NS_BLOCKS_AVAILABLE
/**
 *  第二种：通过block回调 优先级最低
 */
@property (atomic, copy ) XLFSuccessedBlock successedBlock ;
@property (atomic, copy ) XLFFailedBlock    failedBlock    ;
@property (atomic, copy ) XLFProgressBlock  progressBlock  ;
@property (atomic, copy ) XLFCompleteBlock  completeBlock  ;

#endif
/**
 *  过滤/解析 返回的数据
 *
 *  默认返回数据格式   { "statusCode":状态编码, "data":结果集 , "msg":"请求描述"}
 *
 *  正确返回状态编码：200
 *
 *  如果接口协议不匹配，需要重写该函数
 *
 *  @param responseObject返回数据
 *  @param result       从返回数据中提取结果集
 *  @param err          错误结果返回，正常情况错误代码为：statusCode , domian为：msg
 *
 *  @return 返回数据是否正常
 */
- (BOOL)filter:(id)responseObject result:/* json or xml */(id*)result error:(NSError **)err;
/**
 *  根据数据返回对应NSError对象
 *
 *  @param statusCode 状态码
 *
 *  @return NSError
 */
- (NSError*)filterError:(id)responseObject statusCode:(NSInteger)statusCode;
/**
 *  根据系统错误代码返回对应NSError对象，默认是从Localization.string中获取
 *
 *  @param errorCode 错误代码
 *
 *  @return NSError
 */
- (NSError*)systemErrorWithStatusCode:(NSInteger)statusCode errorCode:(NSInteger)errorCode;

/**
 *  是否监听这个错误
 *
 *  @param error NSError 错误对象
 *
 *  @return 是否监听
 */
- (BOOL)shouldListeningError:(NSError*)error;

/**
 *  注册block,此block能获取当前可视的ViewController
 *
 *  @param visibleVCBlock block
 *  @param isGlobal       是否全局
 */
- (void)registerVisibleViewControllerBlock:(VisibleViewControllerBlock)visibleVCBlock
                                  isGlobal:(BOOL)isGlobal;

+ (void)registerVisibleViewControllerBlockForGlobal:(VisibleViewControllerBlock)visibleVCBlock;

- (void)registerListeningErrorBlock:(void (^)(id httpRequest, NSError *error))listeningErrorBlock
                           isGlobal:(BOOL)isGlobal;

+ (void)registerListeningErrorBlockForGlobal:(void (^)(id httpRequest, NSError *error))listeningErrorBlock;

/**
 *  缓存器
 *
 *  @return 缓存实例
 */
+ (NSURLCache*)cacheShareInstance;

/**
 *  系统错误代码  单例
 *
 *  @return 系统错误代码
 */
+ (NSArray<NSNumber *> *)shareSystemErrorCodes;

- (void)cancel;
- (void)suspend;
- (void)resume;

@end

@interface XLFHttpRequestManager : NSObject

@property(nonatomic, strong) Class httpRequestClass;

+ (void)registerHttpRequestClass:(Class)cls;

/**
 *  HttpRequestManager 单例
 *
 *  @return HttpRequestManager 实例
 */
+ (instancetype)sharedInstance;

/**
 *  移除并取消相关代理的请求
 *
 *  @param delegate 代理
 */
+ (void)removeAndCancelAllRequestDelegate:(id<XLFHttpRequestDelegate>)delegate;

/**
 *  移除并取消相关代理的请求
 *
 *  @param userTag 用户标记
 */
+ (void)removeAndCancelAllRequestByUserTag:(id)userTag;

/**
 *  移除相关代理的请求
 *
 *  @param delegate 代理
 */
+ (void)removeAllRequestDelegate:(id<XLFHttpRequestDelegate>)delegate;

/**
 *  创建请求
 *
 *  @param params   参数
 *  @param method   请求方式
 *  @param request  当前请求对象
 *  @param tag      标签
 *  @param delegate 代理
 *
 *  @return 请求对象
 */
+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
                withTag:(NSInteger)tag
               delegate:(id<XLFHttpRequestDelegate>)delegate;
/**
 *  创建请求
 *
 *  @param params   参数
 *  @param method   请求方式
 *  @param request  当前请求对象
 *  @param tag      标签
 *  @param delegate 代理
 *  @param hiddenLoadingView 影藏加载视图
 *
 *  @return 请求对象
 */
+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
                withTag:(NSInteger)tag
      hiddenLoadingView:(BOOL)hiddenLoadingView
               delegate:(id<XLFHttpRequestDelegate>)delegate;
/**
 *  创建请求
 *
 *  @param params   参数
 *  @param method   请求方式
 *  @param dataType 接收数据类型
 *  @param request  当前请求对象
 *  @param tag      标签
 *  @param delegate 代理
 *  @param hiddenLoadingView 影藏加载视图
 *
 *  @return 请求对象
 */
+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
               dataType:(XLFHttpRquestDataType)dataType
                withTag:(NSInteger)tag
      hiddenLoadingView:(BOOL)hiddenLoadingView
               delegate:(id<XLFHttpRequestDelegate>)delegate;

+ (id)fileRequestWithUrl:(NSString*)fileUrl
                 withTag:(NSInteger)tag
       hiddenLoadingView:(BOOL)hiddenLoadingView
                delegate:(id<XLFHttpRequestDelegate>)delegate;


+ (id)fileRequestWithUrl:(NSString*)fileUrl
       hiddenLoadingView:(BOOL)hiddenLoadingView
                delegate:(id<XLFHttpRequestDelegate>)delegate;

/**
 *  Selector
 */
+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
                withTag:(NSInteger)tag
               delegate:(id)delegate
                success:(SEL)successSelector
                failure:(SEL)failureSelector;

+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
                withTag:(NSInteger)tag
      hiddenLoadingView:(BOOL)hiddenLoadingView
               delegate:(id)delegate
                success:(SEL)successSelector
                failure:(SEL)failureSelector;

+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
               dataType:(XLFHttpRquestDataType)dataType
                withTag:(NSInteger)tag
      hiddenLoadingView:(BOOL)hiddenLoadingView
               delegate:(id)delegate
                success:(SEL)successSelector
                failure:(SEL)failureSelector;

+ (id)fileRequestWithUrl:(NSString*)fileUrl
                 withTag:(NSInteger)tag
       hiddenLoadingView:(BOOL)hiddenLoadingView
                delegate:(id)delegate
                 success:(SEL)successSelector
                 failure:(SEL)failureSelector;

+ (id)fileRequestWithUrl:(NSString*)fileUrl
       hiddenLoadingView:(BOOL)hiddenLoadingView
                delegate:(id)delegate
                 success:(SEL)successSelector
                 failure:(SEL)failureSelector;

#if NS_BLOCKS_AVAILABLE
/**
 *  block
 */
+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
                withTag:(NSInteger)tag
                success:(XLFSuccessedBlock)successedBlock
                failure:(XLFFailedBlock)failedBlock;

/**
 *  block
 */
+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
                withTag:(NSInteger)tag
      hiddenLoadingView:(BOOL)hiddenLoadingView
         relationObject:(id)relationObject
                success:(XLFSuccessedBlock)successedBlock
                failure:(XLFFailedBlock)failedBlock;

+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
               dataType:(XLFHttpRquestDataType)dataType
                withTag:(NSInteger)tag
      hiddenLoadingView:(BOOL)hiddenLoadingView
         relationObject:(id)relationObject
                success:(XLFSuccessedBlock)successedBlock
                failure:(XLFFailedBlock)failedBlock;

+ (id)fileRequestWithUrl:(NSString*)fileUrl
                 withTag:(NSInteger)tag
       hiddenLoadingView:(BOOL)hiddenLoadingView
          relationObject:(id)relationObject
                 success:(XLFSuccessedBlock)successedBlock
                 failure:(XLFFailedBlock)failedBlock;

+ (id)fileRequestWithUrl:(NSString*)fileUrl
       hiddenLoadingView:(BOOL)hiddenLoadingView
          relationObject:(id)relationObject
                 success:(XLFSuccessedBlock)successedBlock
                 failure:(XLFFailedBlock)failedBlock;

#endif
//warning 需要重载实现具体部分，包括URL的构造，表单数据等等
/**
 *  根据参数创建请求
 *  默认为
 *
 *  @param url 接口地址
 *  @param params 参数
 *  @param method 请求类型
 *
 *  @return 请求对象
 */
+ (id)requestWithParams:(XLFHttpParameter *)params
                 method:(NSString*)method;

@end

