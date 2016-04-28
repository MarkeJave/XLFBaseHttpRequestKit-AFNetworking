//
//  XLFHttpRequestManager.h
//  NSURLSessionDataTaskKit
//
//  Created by Marike Jave on 14-8-25.
//  Copyright (c) 2014年 Marike Jave. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AFNetWorking/AFHTTPSessionManager.h>

#import "XLFProgressViewDelegate.h"

typedef  UIViewController* (^XLFVisibleViewControllerBlock)(UIView *loadingView,BOOL isHiddenLoadingView);
typedef  UIViewController* (^XLFListeningErrorBlock)(NSURLSessionTask *task, NSError *error);

typedef void (^XLFCompleteBlock)();
typedef void (^XLFSuccessedBlock)(id task, id result) ;
typedef void (^XLFProgressBlock)(id task, CGFloat progress, NSData *responseData ) ;
typedef void (^XLFFailedBlock)(id task, NSError *error) ;

typedef void (^XLFNoneResultSuccessedBlock)(id task) ;
typedef void (^XLFBytesSuccessedBlock)(id task, NSData *bytes) ;

typedef void (^XLFOnlyStringResponseSuccessedBlock)(id task, id result, NSString *response);
typedef void (^XLFOnlyIntegerResponseSuccessedBlock)(id task, id result, NSInteger response);
typedef void (^XLFOnlyFloatResponseSuccessedBlock)(id task, id result, CGFloat response);
typedef void (^XLFOnlyArrayResponseSuccessedBlock)(id task, id result, NSArray *multipierResponses);
typedef void (^XLFOnlyDictionaryResponseSuccessedBlock)(id task, id result, NSDictionary *multipierResponses);

extern NSInteger const XLFHttpRquestNormalTag;

extern NSString const *XLFHttpRquestMethodGet;

extern NSString const *XLFHttpRquestMethodPost;

extern NSString const *XLFHttpRquestMethodPut;

extern NSString const *XLFHttpRquestMethodDelete;

extern NSString const *XLFHttpRquestMethodHead;

@interface NSObject(FilterNull)
- (id)filterNull;
@end

@protocol XLFURLSessionDataTaskDelegate <NSObject>
@optional
- (void)didFailWithError:(NSError *)err task:(id)task;

#pragma HttpRquestDataTypeJson
- (void)didFinishReuqestWithJSONValue:(id)json task:(NSURLSessionDataTask *)task;
- (void)didLoadProgress:(CGFloat)progress task:(NSURLSessionDataTask *)task;

#pragma HttpRquestDataTypeByte
- (void)didFinishReuqestWithData:(NSData*)responseData task:(NSURLSessionDataTask *)task;
- (void)didLoadProgress:(CGFloat)progress data:(NSData*)responseData task:(NSURLSessionDataTask *)task;

@end

//  文件类型（0：未知文件，1：office file[office文件] , 2：rar/zip[压缩文件]，3：MP4/avi[视频文件]，4：jpg/png[图片文件]）
typedef NS_ENUM(NSInteger ,XLFFileType){
    
    XLFFileTypeUnknown,
    XLFFileTypeOffice,
    XLFFileTypeCompression,
    XLFFileTypeVideo,
    XLFFileTypeImage
};

typedef NS_ENUM(NSInteger ,XLFResponseContentType){
    
    XLFResponseContentTypeJSON      = 1 << 0,
    XLFResponseContentTypeXML       = 1 << 1,
    XLFResponseContentTypeData      = 1 << 2,
    XLFResponseContentTypeString    = 1 << 3,
    XLFResponseContentTypePropertyList = 1 << 4,
    XLFResponseContentTypeImage     = 1 << 5,
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
 *  请求类型
 */
@property(nonatomic, copy  ) NSString       *method;

/**
 *  请求根域名
 */
@property(nonatomic, strong) NSURL          *requestURL;

/**
 *  请求操作
 */
@property(nonatomic, copy  ) NSString       *handle;

/**
 *  查询参数
 */
@property(nonatomic, strong) NSDictionary   *queryParameters;

/**
 *  表单参数
 */
@property(nonatomic, strong) NSDictionary   *formParameters;

/**
 *  文件参数
 */
@property(nonatomic, strong) NSDictionary<NSString *, XLFUploadFile *> *fileParameters;

/**
 *  请求头部参数
 */
@property(nonatomic, strong) NSDictionary   *headParameters;

/**
 *  路径参数
 */
@property(nonatomic, strong) NSArray      *pathParameters;

/**
 *  请求体
 */
@property(nonatomic, strong) id            postBody;

/**
 *  返回类型
 */
@property(nonatomic, assign) XLFResponseContentType responseContentType;

@end

@interface NSURLSessionTask(Extenssion)

@property(nonatomic, strong, readonly) UIView<XLFProgressViewDelegate>    *progressView;

@property(nonatomic, strong, readonly) XLFHttpParameter                   *httpParameter;

@property(nonatomic, assign, readonly) NSInteger taskTag;

@property(nonatomic, assign) BOOL hiddenLoadingView;

@property(nonatomic, copy  ) NSString *loadingText;

- (void)startAsynchronous;

@end

@interface XLFStringResponseSerializer : AFHTTPResponseSerializer

@end

@interface XLFHttpRequestManager : AFHTTPSessionManager

@property(nonatomic, copy  , readonly) XLFVisibleViewControllerBlock      visibleVCBlock;

@property(nonatomic, copy  , readonly) XLFListeningErrorBlock             listeningErrorBlock;

@property(nonatomic, strong, readonly) NSMutableArray                     *listeningErrorInfos;

+ (instancetype)shareManager;

/**
 *  移除并取消相关代理的请求
 *
 *  @param userTag 用户标记
 */
- (void)removeAndCancelAllRequestByTaskTag:(NSInteger)taskTag;

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;


- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                             loadingText:(NSString *)loadingText
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                          relationObject:(id)relationObject
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                             loadingText:(NSString *)loadingText
                          relationObject:(id)relationObject
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                                progress:(XLFProgressBlock)progress
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                          relationObject:(id)relationObject
                                progress:(XLFProgressBlock)progress
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                             loadingText:(NSString *)loadingText
                                progress:(XLFProgressBlock)progress
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                             loadingText:(NSString *)loadingText
                          relationObject:(id)relationObject
                                progress:(XLFProgressBlock)progress
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                       hiddenLoadingView:(BOOL)hiddenLoadingView
                             loadingText:(NSString *)loadingText
                          relationObject:(id)relationObject
                                progress:(XLFProgressBlock)progress
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;

- (BOOL)shouldListeningError:(NSError *)error;

- (void)registerVisibleViewControllerBlock:(XLFVisibleViewControllerBlock)visibleVCBlock
                                  isGlobal:(BOOL)isGlobal;

+ (void)registerVisibleViewControllerBlockForGlobal:(XLFVisibleViewControllerBlock)visibleVCBlock;

- (void)registerListeningErrorBlock:(XLFListeningErrorBlock)listeningErrorBlock
                           isGlobal:(BOOL)isGlobal;

+ (void)registerListeningErrorBlockForGlobal:(XLFListeningErrorBlock)listeningErrorBlock;

@end

