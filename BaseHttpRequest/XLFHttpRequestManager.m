
//
//  XLFHttpRequestManager.m
//  NSURLSessionTaskKit
//
//  Created by Marike Jave on 14-8-25.
//  Copyright (c) 2014年 Marike Jave. All rights reserved.
//

#import <objc/runtime.h>

#import "XLFHttpRequestManager.h"
#import "MBProgressHUDPrivate.h"
#import "XLFLog.h"

#pragma mark 类型转换

/**
 *  格式化字符串
 */
#define fmts(fmt,...)                                       [NSString stringWithFormat:fmt, ##__VA_ARGS__]

/**
 *  BOOL 转换成NSNumber
 */
#define bton(bool)                                          [NSNumber numberWithBool:bool]

/**
 *  BOOL 转换成NSString
 */
#define btos(bool)                                          [NSString stringWithFormat:@"%d", bool]

/**
 *  NSInteger 转换成NSString
 */

#if __LP64__ || (TARGET_OS_EMBEDDED && !TARGET_OS_IPHONE) || TARGET_OS_WIN32 || NS_BUILD_32_LIKE_64
#define itos(integer)                                       [NSString stringWithFormat:@"%ld", (long)integer]
#define uitos(integer)                                       [NSString stringWithFormat:@"%lu", (unsigned long)integer]
#else
#define itos(integer)                                       [NSString stringWithFormat:@"%d", integer]
#define uitos(integer)                                       [NSString stringWithFormat:@"%u", integer]
#endif

/**
 *  NSInteger 转换成NSNumber
 */
#define iton(integer)                                       [NSNumber numberWithInteger:integer]

/**
 *  CGFloat 转换成NSString
 */
#define ftos(float)                                         [NSString stringWithFormat:@"%f", float]

/**
 *  NSObject 转换成NSString
 */
#define otos(object)                                        [NSString stringWithFormat:@"%@", object]

/**
 *  NULL 转换成 空NSString
 */
#define ntoe(string)                                        ([string length]?string:@"")

/**
 *  NULL 转换成 NSNull
 */
#define ntonull(obj)                                        (obj?obj:[NSNull null])

/**
 *  格式化字符串
 */
#define ntodefault(obj , deft)                              (obj?obj:deft)

/**
 *  Cache 路径
 */
#define SDCacheDirectory                                    [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask,   YES) objectAtIndex:0]

/**
 *  Cache 路径 folderName 文件夹
 */
#define SDCacheFolder(folderName)                           [SDCacheDirectory    stringByAppendingPathComponent:folderName]

#ifndef weakself
#if DEBUG
#if __has_feature(objc_arc)
#define weakself(object) autoreleasepool{} __weak __typeof(self) object = self;
#else
#define weakself(object) autoreleasepool{} __block __typeof(self) object = self;
#endif
#else
#if __has_feature(objc_arc)
#define weakself(object) try{} @finally{} {} __weak __typeof__(self) object = self;
#else
#define weakself(object) try{} @finally{} {} __block __typeof__(self) object = self;
#endif
#endif
#endif

#ifndef weakify
#if DEBUG
#if __has_feature(objc_arc)
#define weakify(object) autoreleasepool{} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) autoreleasepool{} __block __typeof__(object) block##_##object = object;
#endif
#else
#if __has_feature(objc_arc)
#define weakify(object) try{} @finally{} {} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) try{} @finally{} {} __block __typeof__(object) block##_##object = object;
#endif
#endif
#endif

#ifndef strongify
#if DEBUG
#if __has_feature(objc_arc)
#define strongify(object) autoreleasepool{} __typeof__(object) object = weak##_##object;
#else
#define strongify(object) autoreleasepool{} __typeof__(object) object = block##_##object;
#endif
#else
#if __has_feature(objc_arc)
#define strongify(object) try{} @finally{} __typeof__(object) object = weak##_##object;
#else
#define strongify(object) try{} @finally{} __typeof__(object) object = block##_##object;
#endif
#endif
#endif

NSInteger const XLFHttpRquestNormalTag   = 0;

NSString const *XLFHttpRquestMethodGet = @"GET";

NSString const *XLFHttpRquestMethodPost = @"POST";

NSString const *XLFHttpRquestMethodPut = @"PUT";

NSString const *XLFHttpRquestMethodDelete = @"DELETE";

NSString const *XLFHttpRquestMethodHead = @"HEAD";

NSString *const XLFCachePathFolder       = @"WebCache";

XLFVisibleViewControllerBlock   XLFGloableVisibleVCBlock = nil;
XLFListeningErrorBlock          XLFGloableListeningErrorBlock = nil;

FOUNDATION_EXPORT NSString * const AFURLResponseSerializationErrorDomain;

static NSError * XLFErrorWithUnderlyingError(NSError *error, NSError *underlyingError) {
    if (!error) {
        return underlyingError;
    }
    
    if (!underlyingError || error.userInfo[NSUnderlyingErrorKey]) {
        return error;
    }
    
    NSMutableDictionary *mutableUserInfo = [error.userInfo mutableCopy];
    mutableUserInfo[NSUnderlyingErrorKey] = underlyingError;
    
    return [[NSError alloc] initWithDomain:error.domain code:error.code userInfo:mutableUserInfo];
}

static BOOL XLFErrorOrUnderlyingErrorHasCodeInDomain(NSError *error, NSInteger code, NSString *domain) {
    if ([error.domain isEqualToString:domain] && error.code == code) {
        return YES;
    } else if (error.userInfo[NSUnderlyingErrorKey]) {
        return XLFErrorOrUnderlyingErrorHasCodeInDomain(error.userInfo[NSUnderlyingErrorKey], code, domain);
    }
    
    return NO;
}

@class XLFHttpRequestSetter;

@interface NSURLSessionTask(PrivateExtenssion)

@property(nonatomic, strong) UIView<XLFProgressViewDelegate>    *progressView;

@property(nonatomic, strong) XLFHttpParameter                   *httpParameter;

@property(nonatomic, strong) XLFHttpRequestSetter               *httpRequestSetter;

@property(nonatomic, strong) Class<XLFProgressViewDelegate> progressViewClass;

@property(nonatomic, assign) XLFHttpRequestManager              *container;

@property(nonatomic, assign) id relationObject;

@property(nonatomic, assign) NSInteger taskTag;

@end

@interface XLFHttpRequestSetter : NSObject

@property(nonatomic, strong) NSMutableSet<NSURLSessionTask *> *tasks;

@end

@implementation XLFHttpRequestSetter

- (NSMutableSet *)tasks{
    
    if (!_tasks) {
        
        _tasks = [NSMutableSet set];
    }
    
    return _tasks;
}

- (void)addHttpRequest:(NSURLSessionTask * _Nonnull)httpRequest{
    
    [[self tasks] addObject:httpRequest];
}

- (void)removeHttpRequest:(NSURLSessionTask * _Nonnull)httpRequest{
    
    [[self tasks] removeObject:httpRequest];
}

- (void)dealloc{
    
    for (NSURLSessionTask * task in [[self tasks] allObjects]) {
        
        if ([task state] != NSURLSessionTaskStateCompleted && ([task state] != NSURLSessionTaskStateCanceling || [task state] != NSURLSessionTaskStateSuspended)) {
            
            [task setRelationObject:nil];
            
            [task cancel];
        }
    }
    
    [[self tasks] removeAllObjects];
    
    [self setTasks:nil];
}

@end

@interface NSObject (HttpRequestSetter)

@property(nonatomic, strong, readonly) XLFHttpRequestSetter *httpRequestSetter;

@end

@implementation NSObject (HttpRequestSetter)

- (XLFHttpRequestSetter *)httpRequestSetter{
    
    XLFHttpRequestSetter *etHttpRequestSetter = objc_getAssociatedObject(self, @selector(httpRequestSetter));
    
    if (!etHttpRequestSetter) {
        
        etHttpRequestSetter = [XLFHttpRequestSetter new];
        
        objc_setAssociatedObject(self, @selector(httpRequestSetter), etHttpRequestSetter, OBJC_ASSOCIATION_RETAIN);
    }
    return etHttpRequestSetter;
}

@end

@implementation NSNull (Categories)

- (NSString *)description;{
    return @"";
}

@end

@implementation NSObject(FilterNull)

- (id)filterNull{
    
    if ([self isKindOfClass:[NSDictionary class]]) {
        
        return [self filterNullInDictionary:self];
    }
    else if ([self isKindOfClass:[NSArray class]]){
        
        return [self filterNullInArray:self];
    }
    else if ([self isKindOfClass:[NSNull class]]){
        
        return nil;
    }
    else{
        
        return self;
    }
}

- (NSDictionary *)filterNullInDictionary:(id)dictionary{
    
    NSMutableDictionary *etFilterDictionary = [NSMutableDictionary dictionary];
    
    for (NSString *etKey in [dictionary allKeys]) {
        
        id etValue = [dictionary objectForKey:etKey];
        
        if (![etValue isKindOfClass:[NSNull class]]) {
            
            if ([etValue isKindOfClass:[NSDictionary class]]) {
                
                etValue = [etValue filterNullInDictionary:etValue];
            }
            else if ([etValue isKindOfClass:[NSArray class]]){
                
                etValue = [etValue filterNullInArray:etValue];
            }
            
            [etFilterDictionary setObject:etValue forKey:etKey];
        }
    }
    return etFilterDictionary;
}

- (NSArray *)filterNullInArray:(id)array{
    
    NSMutableArray *etFilterArray = [NSMutableArray array];
    
    for (id etValue in array) {
        
        if (![etValue isKindOfClass:[NSNull class]]) {
            
            id etFilterValue = etValue;
            
            if ([etValue isKindOfClass:[NSDictionary class]]) {
                
                etFilterValue = [etValue filterNullInDictionary:etValue];
            }
            else if ([etValue isKindOfClass:[NSArray class]]){
                
                etFilterValue = [etValue filterNullInArray:etValue];
            }
            
            [etFilterArray addObject:etFilterValue];
        }
    }
    return etFilterArray;
}

@end

@interface XLFHttpRequestManager (Private)

@property(nonatomic, strong) NSMutableDictionary *referrence;

@end

@implementation XLFUploadFile

+ (id)uploadFileWithFileData:(NSData *)fileData fileName:(NSString *)fileName contentType:(NSString *)contentType type:(XLFFileType)type;{
    
    return [[[self class] alloc] initWithFileData:fileData fileName:fileName contentType:contentType type:type];
}

- (id)initWithFileData:(NSData *)fileData fileName:(NSString *)fileName contentType:(NSString *)contentType type:(XLFFileType)type;{
    self = [super init];
    if (self) {
        
        [self setData:fileData];
        [self setFileName:fileName];
        [self setContentType:contentType];
        [self setType:type];
    }
    return self;
}

@end

@implementation XLFHttpParameter

- (id)init{
    self = [super init];
    if (self ) {
        
    }
    return self;
}

- (void)dealloc{
    
    [self setHandle:nil];
    [self setPathParameters:nil];
    [self setQueryParameters:nil];
    [self setPostBody:nil];
    [self setFormParameters:nil];
    [self setHeadParameters:nil];
}

- (NSString *)description{
    
    return [@{@"url":ntoe([[self requestURL] absoluteString]),
              @"method":ntoe([self method]),
              @"handle":ntoe([self handle]),
              @"queryParameters":ntodefault([self queryParameters], @{}),
              @"formParameters":ntodefault([self formParameters], @{}),
              @"postBody":ntodefault([self postBody], @{}),
              @"headParameters":ntodefault([self headParameters], @{}),
              @"pathParameters":ntodefault([self pathParameters], @[])} description];
}

@end

@implementation NSURLSessionTask (PrivateExtenssion)

- (void)clearProperties{
    
    @synchronized ([self container]) {
        if ([self container] && [[self container] referrence]) {
            [[[self container] referrence] removeObjectForKey:[NSNumber numberWithInteger:[self taskTag]]];
        }
    }
    if ([self relationObject]) {
        [[[self relationObject] httpRequestSetter] removeHttpRequest:self];
    }
    
    [self removeLoadingView];
}

- (NSDictionary*)descriptionInfo{
    
    return @{@"url":ntoe([[[self httpParameter] requestURL] absoluteString]),
             @"handle":ntoe([[self httpParameter] handle]),
             @"method":ntoe([[self httpParameter] method]),
             @"queryParameters":ntodefault([[self httpParameter] queryParameters], @{}),
             @"formParameters":ntodefault([[self httpParameter] formParameters], @{}),
             @"postBody":ntodefault([[self httpParameter] postBody], @{}),
             @"headParameters":ntodefault([[self httpParameter] headParameters], @{}),
             @"pathParameters":ntodefault([[self httpParameter] pathParameters], @[]),
             @"taskTag":[NSNumber numberWithInteger:[self taskTag]]};
}

- (void)setProgressView:(UIView<XLFProgressViewDelegate> *)progressView{
    
    if ([self progressView] != progressView) {
        
        objc_setAssociatedObject(self, @selector(progressView), progressView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (UIView<XLFProgressViewDelegate> *)progressView{
    
    return objc_getAssociatedObject(self, @selector(progressView));
}

- (void)setHttpParameter:(XLFHttpParameter *)httpParameter{
    
    if ([self httpParameter] != httpParameter) {
        
        objc_setAssociatedObject(self, @selector(httpParameter), httpParameter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (XLFHttpParameter *)httpParameter{
    
    return objc_getAssociatedObject(self, @selector(httpParameter));
}

- (void)setContainer:(XLFHttpRequestManager *)container{
    
    if ([self container] != container) {
        
        objc_setAssociatedObject(self, @selector(container), container, OBJC_ASSOCIATION_ASSIGN);
    }
}

- (XLFHttpRequestManager *)container{
    
    return objc_getAssociatedObject(self, @selector(container));
}

- (void)setRelationObject:(id)relationObject{
    
    if ([self relationObject] != relationObject) {
        
        objc_setAssociatedObject(self, @selector(relationObject), relationObject, OBJC_ASSOCIATION_ASSIGN);
    }
    
    if (relationObject) {
        [[relationObject httpRequestSetter] addHttpRequest:self];
    }
}

- (id)relationObject{
    
    return objc_getAssociatedObject(self, @selector(relationObject));
}

- (void)setTaskTag:(NSInteger)taskTag{
    
    if ([self taskTag] != taskTag) {
        
        objc_setAssociatedObject(self, @selector(taskTag), @(taskTag), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (NSInteger)taskTag{
    
    return [objc_getAssociatedObject(self, @selector(taskTag)) integerValue];
}

- (void)setHiddenLoadingView:(BOOL)hiddenLoadingView{
    
    if ([self hiddenLoadingView] != hiddenLoadingView) {
        
        objc_setAssociatedObject(self, @selector(hiddenLoadingView), @(hiddenLoadingView), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (BOOL)hiddenLoadingView{
    
    return [objc_getAssociatedObject(self, @selector(hiddenLoadingView)) boolValue];
}

- (void)setHttpRequestSetter:(XLFHttpRequestSetter *)httpRequestSetter{
    
    if ([self httpRequestSetter] != httpRequestSetter) {
        
        objc_setAssociatedObject(self, @selector(httpRequestSetter), httpRequestSetter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (XLFHttpRequestSetter *)httpRequestSetter{
    
    return objc_getAssociatedObject(self, @selector(httpRequestSetter));
}

- (void)setProgressViewClass:(Class)progressViewClass{
    
    if ([self progressViewClass] != progressViewClass) {
        
        objc_setAssociatedObject(self, @selector(progressViewClass), progressViewClass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (Class)progressViewClass{
    
    return objc_getAssociatedObject(self, @selector(progressViewClass));
}

- (void)setLoadingText:(NSString *)loadingText{
    
    if ([self loadingText] != loadingText) {
        
        objc_setAssociatedObject(self, @selector(loadingText), loadingText, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
}

- (NSString *)loadingText{
    
    NSString *loadingText = objc_getAssociatedObject(self, @selector(loadingText));
    if (!loadingText) {
        loadingText = @"加载中...";
        objc_setAssociatedObject(self, @selector(loadingText), loadingText, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    return loadingText;
}

- (void)showLoadingView{
    
    [self removeLoadingView];
    
    UIView *etvVisibleContent = [self visibleContentView];
    
    if (![self hiddenLoadingView] && etvVisibleContent) {
        
        [etvVisibleContent setUserInteractionEnabled:NO];
        
        if (![self progressViewClass]) {
            [self setProgressViewClass:[MBProgressHUDPrivate class]];
        }
        
        NIF_DEBUG(@"添加loading视图");
        [self setProgressView:[[self progressViewClass] showProgressString:[self loadingText] inContentView:etvVisibleContent]];
    }
}

- (void)removeLoadingView{
    
    if ([self progressView]) {
        
        NIF_DEBUG(@"移除loading视图");
        [[[self progressView] superview] setUserInteractionEnabled:YES];
        [[self progressView] removeFromSuperview];
    }
}

- (UIView*)visibleContentView;{
    
    UIView *contentView = [[[UIApplication sharedApplication] windows] firstObject];
    if (![[self container] visibleVCBlock]) {
        
        NIF_DEBUG(@"请注册可见视图 efRegisterVisibleViewControllerBlock");
    }
    else{
        
        UIViewController *visibleVC = [self container].visibleVCBlock(nil,[self hiddenLoadingView]);
        if (visibleVC && [visibleVC isKindOfClass:[UIViewController class]]) {
            contentView = [visibleVC view];
        }
        else{
            
            NIF_DEBUG(@"注册可见视图（efRegisterVisibleViewControllerBlock）不是一个有效视图，请检查");
        }
    }
    return contentView;
}

- (void)startAsynchronous;{
    
    NIF_INFO(@"Request will start with description:\n%@",[self descriptionInfo]);
    
    if ([[AFNetworkReachabilityManager sharedManager] isReachable]) {
        
        [self showLoadingView];
        
        [self resume];
    }
    else {
        
        [self removeLoadingView];
        
        NSError *error = [NSError errorWithDomain:@"网络无连接" code:kCFURLErrorNotConnectedToInternet userInfo:[self descriptionInfo]];
        
        [self failedWithError:error failure:nil];
    }
}

- (BOOL)filter:(id)responseObject result:(id*)result error:(NSError **)err;{
    
    NSInteger statusCode = [[self response] isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)[self response] statusCode] : 0;
    
    NSString *message = nil;
    
    if (statusCode == 200) {
        
        XLFResponseContentType responseContentType = [[self httpParameter] responseContentType];
        
        if (responseContentType & XLFResponseContentTypeJSON) {
            
            if ([responseObject isKindOfClass:[NSArray class]]) {
                responseObject = [responseObject firstObject];
            }
            if ([responseObject isKindOfClass:[NSDictionary class]]) {
                
                if ([[responseObject allKeys] containsObject:@"status"]) {
                    statusCode = [[responseObject objectForKey:@"status"] integerValue];
                }
                if ([[responseObject allKeys] containsObject:@"msg"]) {
                    message = ntoe([responseObject objectForKey:@"msg"]);
                }
                
                id data = [responseObject objectForKey:@"data"];
                
                if ([data isKindOfClass:[NSDictionary class]] || [data isKindOfClass:[NSArray class]]) {
                    
                    *result = data;
                    return YES;
                }
                else{
                    goto error_content_type_unsupport;
                }
            }
        }
        else if (responseContentType & XLFResponseContentTypeString){
            
            if ([responseObject isKindOfClass:[NSString class]]) {
                *result =  responseObject;
                return YES;
            }
            else{
                goto error_content_type_unsupport;
            }
        }
        else if (responseContentType & XLFResponseContentTypeImage){
            if ([responseObject isKindOfClass:[UIImage class]]) {
                *result = responseObject;
                return YES;
            }
            else{
                goto error_content_type_unsupport;
            }
        }
        else if (responseContentType & XLFResponseContentTypeData){
            
            if ([responseObject isKindOfClass:[NSData class]]) {
                *result =  [responseObject description];
                return YES;
            }
            else{
                goto error_content_type_unsupport;
            }
        }
        else if (responseContentType & XLFResponseContentTypeXML){
            
            if ([responseObject isKindOfClass:[NSXMLParser class]]) {
                *result =  responseObject;
                return YES;
            }
            else{
                goto error_content_type_unsupport;
            }
        }
        else if (responseContentType & XLFResponseContentTypeXML){
            
            if ([responseObject isKindOfClass:[NSPropertyListSerialization class]]) {
                *result =  responseObject;
                return YES;
            }
            else{
                goto error_content_type_unsupport;
            }
        }
    }
    goto error_happen;
    
error_content_type_unsupport:
    statusCode = kCFURLErrorDataNotAllowed;
    message = @"返回数据类型异常";
    
error_happen:
    
    if (![message length]) {
        message = NSLocalizedString(itos(statusCode),nil);
    }
    
    if (err) {
        *err = [[NSError alloc] initWithDomain:message code:statusCode userInfo:nil];
    }
    
    return NO;
}

- (NSError*)filterError:(id)responseObject statusCode:(NSInteger)statusCode;{
    
    NIF_INFO(@"%@", responseObject);
    
    NSString *msg = ntoe([responseObject objectForKey:@"msg"]);
    
    if (![msg length]) {
        
        msg = NSLocalizedString(itos(statusCode),nil);
    }
    return [[NSError alloc] initWithDomain:msg code:statusCode userInfo:nil];
}

- (NSError*)systemErrorWithStatusCode:(NSInteger)statusCode errorCode:(NSInteger)errorCode;{
    
    NSString *msg = nil;
    
    if (statusCode) {
        msg = NSLocalizedString(itos(statusCode), nil);
    }
    if ([msg length]) {
        return [[NSError alloc] initWithDomain:([msg length] ? msg : @"系统异常") code:statusCode userInfo:nil];
    }
    else{
        msg = NSLocalizedString(itos(errorCode), nil);
        return [[NSError alloc] initWithDomain:([msg length] ? msg : @"系统异常") code:errorCode userInfo:nil];
    }
}

#pragma mark - task delegate

- (nullable void (^)(id _Nullable responseObject, XLFSuccessedBlock success, XLFFailedBlock failure))taskSuccess{
    
    @weakify(self);
    return ^(id _Nullable responseObject, XLFSuccessedBlock success, XLFFailedBlock failure){
        @strongify(self);
        
        [self removeLoadingView];
        
        id result = nil;
        NSError *error = nil;
        
        if ([self filter:responseObject result:&result error:&error]) {
            
            NIF_INFO(@"Http Request Response: %@", result);
            
            if (success) {
                success(self, result);
            }
        }
        else{
            
            [self failedWithError:error failure:failure];
        }
        
        [self clearProperties];
    };
}

- (nullable void (^)(NSError *error, XLFFailedBlock failure))taskFailed{
    
    @weakify(self);
    return ^(NSError *error,  XLFFailedBlock failure){
        @strongify(self);
        
        NIF_ERROR(@"%@", error);
        
        NSError *newError = [self systemErrorWithStatusCode:[(NSHTTPURLResponse *)[self response] statusCode]
                                                  errorCode:[error code]];
        
        [self removeLoadingView];
        
        [self failedWithError:newError failure:failure];
        
        [self clearProperties];
    };
}

- (void)failedWithError:(NSError*)error failure:(XLFFailedBlock)failure{
    
    NIF_ERROR(@"task : %@ \n error : %@", [self descriptionInfo], error);
    
    @synchronized ([self container]) {
        
        if ([[self container] shouldListeningError:error] &&
            [[self container] listeningErrorBlock]) {
            
            [self container].listeningErrorBlock(self, error);
            return;
        }
    }
    if (failure){
        failure(self, error);
        return ;
    }
    
    UIView *etvVisibleContent = [self visibleContentView];
    if (etvVisibleContent) {
        
        [[self progressViewClass] showErrorString:[error domain] inContentView:etvVisibleContent duration:2];
    }
}

- (void (^)(NSProgress *uploadProgress, NSData *data, XLFProgressBlock progress))taskProgressUpdate{
    
    @weakify(self);
    return ^(NSProgress *uploadProgress, NSData *data, XLFProgressBlock progress){
        @strongify(self);
        
        CGFloat newProgress = [uploadProgress fractionCompleted] / (CGFloat)[uploadProgress totalUnitCount];
        
        if ([self progressView] && [[self progressView] respondsToSelector:@selector(setProgress:)]) {
            
            [[self progressView] setProgress:newProgress];
        }
        
        if (progress){
            
            progress(self , newProgress , data);
        }
    };
}

@end

@class AFURLSessionManagerTaskDelegate;
@interface AFHTTPSessionManager (Private)

- (AFURLSessionManagerTaskDelegate *)delegateForTask:(NSURLSessionTask *)task;

- (NSProgress *)uploadProgressForTask:(NSURLSessionTask *)task;

- (NSProgress *)downloadProgressForTask:(NSURLSessionTask *)task;


@end

@implementation XLFStringResponseSerializer

- (BOOL)validateResponse:(NSHTTPURLResponse *)response
                    data:(NSData *)data
                   error:(NSError * __autoreleasing *)error{
    
    BOOL responseIsValid = YES;
    NSError *validationError = nil;
    
    if (response && [response isKindOfClass:[NSHTTPURLResponse class]]) {
        if (![[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] length] &&
            !([response MIMEType] == nil && [data length] == 0)) {
            
            if ([data length] > 0 && [response URL]) {
                NSMutableDictionary *mutableUserInfo = [@{
                                                          NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedStringFromTable(@"Request failed: unacceptable content-type: %@", @"AFNetworking", nil), [response MIMEType]],
                                                          NSURLErrorFailingURLErrorKey:[response URL],
                                                          AFNetworkingOperationFailingURLResponseErrorKey: response,
                                                          } mutableCopy];
                if (data) {
                    mutableUserInfo[AFNetworkingOperationFailingURLResponseDataErrorKey] = data;
                }
                
                validationError = XLFErrorWithUnderlyingError([NSError errorWithDomain:AFURLResponseSerializationErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:mutableUserInfo], validationError);
            }
            
            responseIsValid = NO;
        }
        
        if (self.acceptableStatusCodes && ![self.acceptableStatusCodes containsIndex:(NSUInteger)response.statusCode] && [response URL]) {
            NSMutableDictionary *mutableUserInfo = [@{
                                                      NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedStringFromTable(@"Request failed: %@ (%ld)", @"AFNetworking", nil), [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], (long)response.statusCode],
                                                      NSURLErrorFailingURLErrorKey:[response URL],
                                                      AFNetworkingOperationFailingURLResponseErrorKey: response,
                                                      } mutableCopy];
            
            if (data) {
                mutableUserInfo[AFNetworkingOperationFailingURLResponseDataErrorKey] = data;
            }
            
            validationError = XLFErrorWithUnderlyingError([NSError errorWithDomain:AFURLResponseSerializationErrorDomain code:NSURLErrorBadServerResponse userInfo:mutableUserInfo], validationError);
            
            responseIsValid = NO;
        }
    }
    
    if (error && !responseIsValid) {
        *error = validationError;
    }
    
    return responseIsValid;
}

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing *)error
{
    if (![self validateResponse:(NSHTTPURLResponse *)response data:data error:error]) {
        if (!error || XLFErrorOrUnderlyingErrorHasCodeInDomain(*error, NSURLErrorCannotDecodeContentData, AFURLResponseSerializationErrorDomain)) {
            return nil;
        }
    }
    
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end

@interface XLFCompoundResponseSerializer : AFCompoundResponseSerializer

@end

@implementation XLFCompoundResponseSerializer

+ (instancetype)serializer{
    
    return [self compoundSerializerWithResponseSerializers:@[[AFImageResponseSerializer serializer], [AFJSONResponseSerializer serializer], [AFXMLParserResponseSerializer serializer], [AFPropertyListResponseSerializer serializer], [XLFStringResponseSerializer serializer]]];
}

@end

@interface XLFHttpRequestManager ()

@property(nonatomic, strong) NSMutableDictionary *referrence;

@property(nonatomic, copy  ) XLFVisibleViewControllerBlock      visibleVCBlock;

@property(nonatomic, copy  ) XLFListeningErrorBlock             listeningErrorBlock;

@property(nonatomic, strong) NSMutableArray                     *listeningErrorInfos;

@end

@implementation XLFHttpRequestManager

+ (void)load{
    [super load];
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:SDCacheDirectory]){
        [[NSFileManager defaultManager] createDirectoryAtPath:SDCacheDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

+ (NSArray<NSNumber *> *)shareSystemErrorCodes;{
    
    static NSArray<NSNumber *> *systemErrorCodes = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        systemErrorCodes =  @[@(kCFHostErrorUnknown ),
                              @(kCFURLErrorCannotConnectToHost),
                              @(kCFURLErrorTimedOut),
                              @(kCFErrorHTTPAuthenticationTypeUnsupported),
                              @(kCFURLErrorCancelled),
                              @(kCFURLErrorBadURL),
                              @(kCFURLErrorNetworkConnectionLost),
                              @(kCFErrorHTTPBadCredentials),
                              @(kCFURLErrorHTTPTooManyRedirects),
                              @(kCFURLErrorBadServerResponse)];
    });
    
    return systemErrorCodes;
}

+ (instancetype)shareManager;{
    
    static id shareManager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareManager = [[[self class] alloc] initWithBaseURL:nil sessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        
        AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
        
        [securityPolicy setAllowInvalidCertificates:YES];
        [securityPolicy setValidatesDomainName:NO];
        
        [shareManager setSecurityPolicy:securityPolicy];
    });
    return shareManager;
}

- (instancetype)initWithBaseURL:(NSURL *)url
           sessionConfiguration:(NSURLSessionConfiguration *)configuration
{
    self = [super initWithBaseURL:url sessionConfiguration:configuration];
    if (self) {
        
        if (XLFGloableVisibleVCBlock) {
            [self setVisibleVCBlock:XLFGloableVisibleVCBlock];
        }
        if (XLFGloableListeningErrorBlock) {
            [self setListeningErrorBlock:XLFGloableListeningErrorBlock];
        }
        
        [self setResponseSerializer:[XLFCompoundResponseSerializer serializer]];
        
        [[self requestSerializer] setHTTPMethodsEncodingParametersInURI:[NSSet setWithObjects:@"GET", @"POST", @"PUT", @"HEAD", @"DELETE", nil]];
    }
    
    return self;
}

- (NSMutableDictionary *)referrence{
    
    if (!_referrence) {
        
        _referrence = [NSMutableDictionary dictionary];
    }
    return _referrence;
}

- (NSMutableArray *)listeningErrorInfos{
    
    if (!_listeningErrorInfos) {
        
        _listeningErrorInfos = [NSMutableArray array];
    }
    return _listeningErrorInfos;
}

/**
 *  移除并取消相关代理的请求
 *
 *  @param userTag 用户标记
 */
- (void)removeAndCancelAllRequestByTaskTag:(NSInteger)taskTag;{
    
    NSArray *tasks = [self tasks];
    
    for (NSURLSessionTask *task in tasks) {
        
        if ([task isKindOfClass:[NSURLSessionTask class]] && [task taskTag] == taskTag) {
            
            [task cancel];
        }
    }
}

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;{
    
    return [self taskWithParameters:parameters
                                tag:XLFHttpRquestNormalTag
                            success:successedBlock
                            failure:failedBlock];
}

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;{
    
    return [self taskWithParameters:parameters
                                tag:tag
                  hiddenLoadingView:YES
                        loadingText:nil
                     relationObject:nil
                           progress:nil
                            success:successedBlock
                            failure:failedBlock];
}


- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                             loadingText:(NSString *)loadingText
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;{
    
    return [self taskWithParameters:parameters
                                tag:tag
                  hiddenLoadingView:NO
                        loadingText:loadingText
                     relationObject:nil
                           progress:nil
                            success:successedBlock
                            failure:failedBlock];
}

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                          relationObject:(id)relationObject
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;{
    
    return [self taskWithParameters:parameters
                                tag:tag
                  hiddenLoadingView:YES
                        loadingText:nil
                     relationObject:relationObject
                           progress:nil
                            success:successedBlock
                            failure:failedBlock];
}

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                             loadingText:(NSString *)loadingText
                          relationObject:(id)relationObject
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;{
    
    return [self taskWithParameters:parameters
                                tag:tag
                  hiddenLoadingView:NO
                        loadingText:loadingText
                     relationObject:relationObject
                           progress:nil
                            success:successedBlock
                            failure:failedBlock];
}

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                                progress:(XLFProgressBlock)progress
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;{
    
    return [self taskWithParameters:parameters
                                tag:tag
                  hiddenLoadingView:YES
                        loadingText:nil
                     relationObject:nil
                           progress:progress
                            success:successedBlock
                            failure:failedBlock];
}

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                          relationObject:(id)relationObject
                                progress:(XLFProgressBlock)progress
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;{
    
    return [self taskWithParameters:parameters
                                tag:tag
                  hiddenLoadingView:YES
                        loadingText:nil
                     relationObject:relationObject
                           progress:progress
                            success:successedBlock
                            failure:failedBlock];
}

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                             loadingText:(NSString *)loadingText
                                progress:(XLFProgressBlock)progress
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;{
    
    return [self taskWithParameters:parameters
                                tag:tag
                  hiddenLoadingView:NO
                        loadingText:loadingText
                     relationObject:nil
                           progress:progress
                            success:successedBlock
                            failure:failedBlock];
    
}

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                             loadingText:(NSString *)loadingText
                          relationObject:(id)relationObject
                                progress:(XLFProgressBlock)progress
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;{
    
    return [self taskWithParameters:parameters
                                tag:tag
                  hiddenLoadingView:NO
                        loadingText:loadingText
                     relationObject:relationObject
                           progress:progress
                            success:successedBlock
                            failure:failedBlock];
    
}

- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                     tag:(NSInteger)tag
                       hiddenLoadingView:(BOOL)hiddenLoadingView
                             loadingText:(NSString *)loadingText
                          relationObject:(id)relationObject
                                progress:(XLFProgressBlock)progress
                                 success:(XLFSuccessedBlock)successedBlock
                                 failure:(XLFFailedBlock)failedBlock;{
    
    NSURLSessionTask *task = [[self referrence] objectForKey:@(tag)];
    
    if (task) {
        [task cancel];
    }
    
    task = [self taskWithParameters:parameters progress:progress success:successedBlock failure:failedBlock];
    if (task) {
        
        [task setTaskTag:tag];
        [task setContainer:self];
        [task setLoadingText:loadingText];
        [task setHttpParameter:parameters];
        [task setRelationObject:relationObject];
        [task setHiddenLoadingView:hiddenLoadingView];
        
        [[self referrence] setObject:task forKey:@(tag)];
    }
    
    return task;
}

/**
 *  根据参数创建请求
 *  默认为
 *
 *  @param parameters 参数
 *
 *  @return 请求对象
 */
- (NSURLSessionTask *)taskWithParameters:(XLFHttpParameter *)parameters
                                progress:(XLFProgressBlock)progress
                                 success:(XLFSuccessedBlock)success
                                 failure:(XLFFailedBlock)failure;{
    
    @weakify(self);
    [[parameters headParameters] enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        @strongify(self);
        
        [[self requestSerializer] setValue:fmts(@"%@", obj) forHTTPHeaderField:key];
    }];
    
    NSError *serializationError = nil;
    
    NSURL *httpRequestURL = [self baseURL];
    
    if ([parameters requestURL]) {
        httpRequestURL = [parameters requestURL];
    }
    
    [parameters setRequestURL:httpRequestURL];
    if ([parameters handle]){
        if(httpRequestURL) {
            httpRequestURL = [NSURL URLWithString:[parameters handle] relativeToURL:httpRequestURL];
        }
        else{
            httpRequestURL = [NSURL URLWithString:[parameters handle]];
        }
    }
    
    if ([parameters pathParameters] && [[parameters pathParameters] count]) {
        httpRequestURL = [NSURL URLWithString:[[parameters pathParameters] componentsJoinedByString:@"/"] relativeToURL:httpRequestURL];
    }
    
    NSMutableURLRequest *httpRequest = nil;
    
    if ([[parameters method] isEqualToString:@"POST"]) {
        
        httpRequest = [[self requestSerializer] multipartFormRequestWithMethod:[parameters method]
                                                                     URLString:[httpRequestURL absoluteString]
                                                                    parameters:[parameters formParameters]
                                                     constructingBodyWithBlock:^(id <AFMultipartFormData> formData){
                                                         
                                                         [[parameters fileParameters] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, XLFUploadFile * _Nonnull uploadFile, BOOL * _Nonnull stop) {
                                                             
                                                             [formData appendPartWithFileData:[uploadFile data] name:key fileName:[uploadFile fileName] mimeType:[uploadFile contentType]];
                                                         }];
                                                     } error:&serializationError];
    }
    else{
        httpRequest = [[self requestSerializer] requestWithMethod:[parameters method]
                                                        URLString:[httpRequestURL absoluteString]
                                                       parameters:[parameters queryParameters]
                                                            error:&serializationError];
    }
    
    if (serializationError) {
        if (failure) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
            dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
                failure(nil, serializationError);
            });
#pragma clang diagnostic pop
        }
        
        return nil;
    }
    
    if ([[parameters method] isEqualToString:@"PUT"] && [parameters postBody]) {
        
        NSData *postBodyData = nil;
        
        if ([[parameters postBody] isKindOfClass:[NSArray class]] || [[parameters postBody] isKindOfClass:[NSDictionary class]]) {
            
            postBodyData = [NSJSONSerialization dataWithJSONObject:[parameters postBody] options:NSJSONWritingPrettyPrinted error:&serializationError];
            
            if (serializationError) {
                if (failure) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
                    dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
                        failure(nil, serializationError);
                    });
#pragma clang diagnostic pop
                }
                
                return nil;
            }
        }
        else if ([[parameters postBody] isKindOfClass:[NSData class]]){
            
            postBodyData = [parameters postBody];
        }
        else if ([[parameters postBody] isKindOfClass:[NSString class]] || [[parameters postBody] isKindOfClass:[NSValue class]]){
            
            postBodyData = [[[parameters postBody] description] dataUsingEncoding:NSUTF8StringEncoding];
        }
        else {
#if DEBUG
            NSLog(@"unable post body with type : %@", [[parameters postBody] class]);
#endif
            return nil;
        }
        
        [httpRequest setHTTPBody:postBodyData];
    }
    
    __block NSURLSessionDataTask *task = [self dataTaskWithRequest:httpRequest uploadProgress:^(NSProgress *uploadProgress){
        
        id taskDelegate = [self delegateForTask:task];
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        task.taskProgressUpdate(uploadProgress, [taskDelegate performSelector:@selector(mutableData)], progress);
#pragma clang diagnostic pop
        
    } downloadProgress:^(NSProgress *downloadProgress){
        
        id taskDelegate = [self delegateForTask:task];
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        task.taskProgressUpdate(downloadProgress, [taskDelegate performSelector:@selector(mutableData)], progress);
#pragma clang diagnostic pop
        
    } completionHandler:^(NSURLResponse * __unused response, id responseObject, NSError *error) {
        
        if (error) {
            task.taskFailed(error, failure);
        }
        else {
            
            task.taskSuccess(responseObject, success, failure);
        }
    }];
    
    return task;
}

- (BOOL)shouldListeningError:(NSError *)error;{
    
    if ([[self listeningErrorInfos] containsObject:itos([error code])]) {
        
        return YES;
    }
    return NO;
}

#pragma mark - 网络加载状态
- (void)registerVisibleViewControllerBlock:(XLFVisibleViewControllerBlock)visibleVCBlock
                                  isGlobal:(BOOL)isGlobal{
    
    if (isGlobal) {
        
        [[self class] registerVisibleViewControllerBlockForGlobal:visibleVCBlock];
    }
    [self setVisibleVCBlock:visibleVCBlock];
    
}

+ (void)registerVisibleViewControllerBlockForGlobal:(XLFVisibleViewControllerBlock)visibleVCBlock{
    
    XLFGloableVisibleVCBlock = visibleVCBlock;
}

- (void)registerListeningErrorBlock:(XLFListeningErrorBlock)listeningErrorBlock
                           isGlobal:(BOOL)isGlobal;{
    
    if (isGlobal) {
        
        [[self class] registerListeningErrorBlockForGlobal:listeningErrorBlock];
    }
    [self setListeningErrorBlock:listeningErrorBlock];
}

+ (void)registerListeningErrorBlockForGlobal:(XLFListeningErrorBlock)listeningErrorBlock;{
    
    XLFGloableListeningErrorBlock = listeningErrorBlock;
}

@end

