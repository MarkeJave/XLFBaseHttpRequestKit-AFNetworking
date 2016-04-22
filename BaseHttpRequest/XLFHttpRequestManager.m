
//
//  XLFHttpRequestManager.m
//  XLFBaseHttpRequestKit
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
NSString *const XLFHttpRquestModeGet     = @"GET";
NSString *const XLFHttpRquestModePost    = @"POST";
NSString *const XLFHttpRquestModePut     = @"PUT";
NSString *const XLFHttpRquestModeDelete  = @"DELETE";

NSString *const XLFCachePathFolder       = @"WebCache";

VisibleViewControllerBlock XLFVisibleVCBlock = nil;

void (^XLFListeningErrorBlock)(id httpRequest, NSError *error);

@interface XLFHttpRequestSetter : NSObject

@property(nonatomic, strong) NSMutableSet<XLFBaseHttpRequest *> *httpRequests;

@end

@implementation XLFHttpRequestSetter

- (NSMutableSet *)httpRequests{
    
    if (!_httpRequests) {
        
        _httpRequests = [NSMutableSet set];
    }
    
    return _httpRequests;
}

- (void)addHttpRequest:(XLFBaseHttpRequest * _Nonnull)httpRequest{
    
    [[self httpRequests] addObject:httpRequest];
}

- (void)removeHttpRequest:(XLFBaseHttpRequest * _Nonnull)httpRequest{
    
    [[self httpRequests] removeObject:httpRequest];
}

- (void)dealloc{
    
    for (XLFBaseHttpRequest * httpRequest in [[self httpRequests] allObjects]) {
        
        if ([[httpRequest URLSessionTask] state] != NSURLSessionTaskStateCompleted && ([[httpRequest URLSessionTask] state] != NSURLSessionTaskStateCanceling || [[httpRequest URLSessionTask] state] != NSURLSessionTaskStateSuspended)) {
            
            [httpRequest setRelationObject:nil];
            
            [[httpRequest URLSessionTask] cancel];
        }
    }
    
    [[self httpRequests] removeAllObjects];
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

@property (nonatomic, strong) NSMutableDictionary *evreqReferrence;

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
    [self setPathParams:nil];
    [self setQueryParams:nil];
    [self setPostBody:nil];
    [self setFormParams:nil];
    [self setHeadParams:nil];
}

- (NSString *)description{
    
    return [@{@"handle":ntoe([self handle]),
              @"queryParams":ntodefault([self queryParams], @{}),
              @"formParams":ntodefault([self formParams], @{}),
              @"postBody":ntodefault([self postBody], @{}),
              @"headParams":ntodefault([self headParams], @{}),
              @"pathParams":ntodefault([self pathParams], @[])} description];
}

@end

@interface XLFBaseHttpRequest ()

@property(nonatomic, strong) NSURLSessionTask *URLSessionTask;

@property(nonatomic, strong) NSURLCache *cache;

@property (nonatomic, assign) NSInteger                         requestTag;
@property (nonatomic, assign) XLFHttpRquestDataType             dataType;
@property (nonatomic, copy  ) VisibleViewControllerBlock        visibleVCBlock;

@property (nonatomic, strong) UIView<XLFProgressViewDelegate>   *progressView;
@property (nonatomic, strong) NSError                           *userError;
@property (nonatomic, copy  ) id                                result;

@property (nonatomic, assign) XLFHttpRequestManager             *container;

@property (nonatomic, copy  ) void (^listeningErrorBlock)(id httpRequest, NSError *error);

@end

@implementation XLFBaseHttpRequest

+ (NSURLCache*)cacheShareInstance;{
    
    static NSURLCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        cache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024
                                              diskCapacity:20 * 1024 * 1024
                                                  diskPath:SDCacheFolder(XLFCachePathFolder)];
    });
    return cache;
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

- (instancetype)init{
    self = [super init];
    
    if ( self ) {
        
        if (XLFVisibleVCBlock) {
            [self setVisibleVCBlock:XLFVisibleVCBlock];
        }
        if (XLFListeningErrorBlock) {
            [self setListeningErrorBlock:XLFListeningErrorBlock];
        }
        [self setLoadingHintsText:@"加载中..."];
    }
    
    return self;
}

- (void)dealloc{
    
    [self clearProperties];
}

- (void)cancel{
    
    [self clearProperties];
    
    [[self URLSessionTask] cancel];
}

- (void)suspend;{
    
    [[self URLSessionTask] suspend];
}

- (void)resume;{
    
    [[self URLSessionTask] resume];
}

- (void)clearProperties{
    
    if ([self container] && [[self container] evreqReferrence]) {
        [[[self container] evreqReferrence] removeObjectForKey:[NSNumber numberWithInteger:[self requestTag]]];
    }
    
    if ([self relationObject]) {
        [[[self relationObject] httpRequestSetter] removeHttpRequest:self];
    }
    
    [self removeLoadingView];
    
    [self setRelationObject:nil];
    [self setEvUserTag:nil];
    [self setEvUserInfo:nil];
    [self setEvDelegate:nil];
    [self setProgressView:nil];
    [self setProgressViewClass:nil];
    [self setVisibleVCBlock:nil];
    [self setCachePath:nil];
    [self setLoadingHintsText:nil];
    [self setFailedBlock:nil];
    [self setProgressBlock:nil];
    [self setSuccessedBlock:nil];
    [self setDidFailureSelector: nil];
    [self setDidSuccessSelector: nil];
}

- (NSDictionary*)descriptionInfo{
    
    return @{@"url":ntoe([[[self URLSessionTask] currentRequest] description]),
             @"handle":ntoe([[self parameter] handle]),
             @"queryParams":ntodefault([[self parameter] queryParams], @{}),
             @"formParams":ntodefault([[self parameter] formParams], @{}),
             @"postBody":ntodefault([[self parameter] postBody], @{}),
             @"headParams":ntodefault([[self parameter] headParams], @{}),
             @"pathParams":ntodefault([[self parameter] pathParams], @[]),
             @"requestTag":[NSNumber numberWithInteger:[self requestTag]],
             @"needCache":[NSNumber numberWithBool:[self needCache]]};
}

- (void)setNeedCache:(BOOL)needCache{
    
    _needCache = needCache;
    if (needCache) {
        
        NSURLCache *cache = nil;
        // 设置缓存
        if ([[self cachePath] length]){
            
            cache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024
                                                  diskCapacity:20 * 1024 * 1024
                                                      diskPath:[self cachePath]];
        }
        else if ([XLFCachePathFolder length]){
            
            cache = [[self class] cacheShareInstance];
        }
        else{
            cache = [NSURLCache sharedURLCache];
        }
        [self setCache:cache];
    }
}

- (void)setRelationObject:(id)relationObject{
    
    if (_relationObject != relationObject) {
        _relationObject = relationObject;
    }
    
    if (relationObject) {
        [[relationObject httpRequestSetter] addHttpRequest:self];
    }
}

- (BOOL)filter:(id)responseObject result:/* json or xml */(id*)result error:(NSError **)err;{
    
    NSInteger statusCode = [[responseObject objectForKey:@"status"] integerValue];
    
    if (statusCode == 200) {
        
        *result = [responseObject objectForKey:@"data"];
        
        if (![*result isKindOfClass:[NSDictionary class]] && ![*result isKindOfClass:[NSArray class]]) {
            
            *result = nil;
        }
        
        return YES;
    }
    
    NSString *msg = ntoe([responseObject objectForKey:@"msg"]);
    
    if (![msg length]) {
        
        msg = NSLocalizedString(itos(statusCode),nil);
    }
    
    if (err) {
        
        *err = [[NSError alloc] initWithDomain:msg code:statusCode userInfo:[self descInfo]];
    }
    
    return NO;
}

- (NSError*)filterError:(id)responseObject statusCode:(NSInteger)statusCode;{
    
    NIF_INFO(@"%@", responseObject);
    
    NSString *msg = ntoe([responseObject objectForKey:@"msg"]);
    
    if (![msg length]) {
        
        msg = NSLocalizedString(itos(statusCode),nil);
    }
    return [[NSError alloc] initWithDomain:msg code:statusCode userInfo:[self descInfo]];
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

- (BOOL)shouldListeningError:(NSError *)err;{
    
    if ([[self listeningErrorInfos] containsObject:itos([err code])]) {
        
        return YES;
    }
    
    return NO;
}

#pragma mark - request delegate

- (nullable void (^)(NSURLSessionDataTask *task, id _Nullable responseObject))requestSuccess{
    
    @weakify(self);
    return ^(NSURLSessionDataTask *task, id _Nullable responseObject){
        @strongify(self);
        
        [self removeLoadingView];
        
        if ([self dataType] == XLFHttpRquestDataTypeJson) {
            
            id result = nil;
            NSError *err = nil;
            
            NIF_INFO(@"http string receive:\n%@", responseObject);
            
            if ([self filter:responseObject result:&result error:&err]) {
                
                NIF_INFO(@"Http Request Response: %@", result);
                
                [self setResult:result];
                [self setUserError:err];
                
                if ([self evDelegate]) {
                    
                    if ([[self evDelegate] respondsToSelector:@selector(didFinishReuqestWithJSONValue:request:)]) {
                        
                        [[self evDelegate] didFinishReuqestWithJSONValue:result request:self];
                    }
                    else if ([[self evDelegate] respondsToSelector:[self didSuccessSelector]]){
                        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        [[self evDelegate] performSelector:[self didSuccessSelector] withObject:result withObject:self];
#pragma clang diagnostic pop
                    }
                }
#if NS_BLOCKS_AVAILABLE
                else if ([self successedBlock]) {
                    self.successedBlock(self , result);
                }
#endif
            }
            else{
                
                [self request:self error:err];
            }
        }
        else if ([self dataType] == XLFHttpRquestDataTypeByte){
            
            if ([self evDelegate]) {
                
                if ([[self evDelegate] respondsToSelector:@selector(didFinishReuqestWithData:request:)]) {
                    
                    [[self evDelegate] didFinishReuqestWithData:responseObject request:self];
                }
                else if ([[self evDelegate] respondsToSelector:[self didSuccessSelector]]){
                    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [[self evDelegate] performSelector:[self didSuccessSelector] withObject:responseObject withObject:self];
#pragma clang diagnostic pop
                }
            }
#if NS_BLOCKS_AVAILABLE
            else if ([self successedBlock]) {
                
                self.successedBlock(self , responseObject);
            }
#endif
        }
        
        [self clearProperties];
    };
}

- (IBAction)requestFailed:(XLFBaseHttpRequest *)baseRequest{
    
    NIF_ERROR(@"%@",[[baseRequest URLSessionTask] error]);
    
    NSError *etError = [self systemErrorWithStatusCode:[(NSHTTPURLResponse *)[[baseRequest URLSessionTask] response] statusCode]
                                             errorCode:[[[baseRequest URLSessionTask] error] code]];
    
    if ([[baseRequest responseData] length]) {
        
        etError = [self filterError:[baseRequest responseData]
                         statusCode:[baseRequest responseStatusCode]];
    }
    
    [self removeLoadingView];
    
    [self request:baseRequest error:etError];
    
    [self clearProperties];
}

- (void)request:(id)baseRequest error:(NSError*)err{
    
    NIF_ERROR(@"request : %@ \n error : %@", [baseRequest descriptionInfo], err);
    
    [self setUserError:err];
    
    if ([self shouldListeningError:err] &&
        [self listeningErrorBlock]) {
        
        self.listeningErrorBlock(self, err);
        return;
    }
    
    if ([self evDelegate]){
        
        if ([[self evDelegate] respondsToSelector:@selector(didFailWithError:request:)]) {
            
            [[self evDelegate] didFailWithError:err request:baseRequest];
            return ;
        }
        else if ([[self evDelegate] respondsToSelector:[self didFailureSelector]]){
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [[self evDelegate] performSelector:[self didFailureSelector] withObject:err withObject:baseRequest];
#pragma clang diagnostic pop
            return ;
        }
    }
    
#if NS_BLOCKS_AVAILABLE
    else if ([self failedBlock]){
        
        self.failedBlock(baseRequest , err);
        return ;
    }
#endif
    
    UIView *etvVisibleContent = [self visibleContentView];
    if (etvVisibleContent) {
        
        [[self progressViewClass] showErrorString:[err domain] inContentView:etvVisibleContent duration:2];
    }
}

- (void)setProgress:(float)newProgress;{
    
    if ([self progressView] && [[self progressView] respondsToSelector:@selector(setProgress:)]) {
        
        [[self progressView] setProgress:newProgress];
    }
    
    if ([self dataType] == XLFHttpRquestDataTypeJson) {
        
        if ([self evDelegate]) {
            
            if ([[self evDelegate] respondsToSelector:@selector(didLoadProgress:request:)]) {
                
                [[self evDelegate] didLoadProgress:newProgress request:self];
            }
            else if ([[self evDelegate] respondsToSelector:[self didProgressSelector]]){
                
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [[self evDelegate] performSelector:[self didProgressSelector] withObject:[NSNumber numberWithFloat:newProgress] withObject:self];
#pragma clang diagnostic pop
            }
        }
        
#if NS_BLOCKS_AVAILABLE
        else if ([self progressBlock]){
            
            self.progressBlock(self , newProgress , [self responseData]);
        }
#endif
    }
    else if ([self dataType] == XLFHttpRquestDataTypeByte){
        
        if ([self evDelegate]) {
            
            if ([[self evDelegate] respondsToSelector:@selector(didLoadProgress:data:request:)]) {
                
                [[self evDelegate] didLoadProgress:newProgress data:[self responseData] request:self];
            }
            else if ([[self evDelegate] respondsToSelector:[self didProgressSelector]]){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [[self evDelegate] performSelector:[self didProgressSelector] withObject:[NSNumber numberWithFloat:newProgress] withObject:self];
#pragma clang diagnostic pop
            }
        }
        
#if NS_BLOCKS_AVAILABLE
        else if ([self progressBlock]){
            
            self.progressBlock(self , newProgress , [self responseData]);
        }
#endif
    }
}

- (void)startAsynchronous{
    
    NIF_INFO(@"Request will start with description:\n%@",[self descInfo]);
    
    if ([Reachability  isHaveNetWork] ) {
        
        [self showLoadingView];
        
        [super startAsynchronous];
    }
    else {
        
        [self removeLoadingView];
        
        NSError *err = [NSError errorWithDomain:@"网络无连接" code:ASIConnectionFailureErrorType userInfo:[self descInfo]];
        
        [self request:self error:err];
    }
}

- (void)startSynchronous{
    
    if ([Reachability  isHaveNetWork] ) {
        
        [self showLoadingView];
        
        [super startSynchronous];
    }
    else {
        
        NSError *err = [NSError errorWithDomain:@"网络无连接" code:ASIConnectionFailureErrorType userInfo:[self descInfo]];
        
        [self request:self error:err];
    }
    [self removeLoadingView];
}

- (void)showLoadingView{
    
    [self removeLoadingView];
    
    UIView *etvVisibleContent = [self visibleContentView];
    
    if (![self isHiddenLoadingView] && etvVisibleContent) {
        
        [etvVisibleContent setUserInteractionEnabled:NO];
        
        if (![self progressViewClass]) {
            [self setProgressViewClass:[MBProgressHUDPrivate class]];
        }
        
        NIF_DEBUG(@"添加loading视图");
        [self setProgressView:[[self progressViewClass] showProgressString:[self loadingHintsText] inContentView:etvVisibleContent]];
    }
}

- (void)removeLoadingView{
    
    if ([self progressView]) {
        
        NIF_DEBUG(@"移除loading视图");
        [[[self progressView] superview] setUserInteractionEnabled:YES];
        [[self progressView] removeFromSuperview];
    }
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

#pragma mark - 网络加载状态
- (void)registerVisibleViewControllerBlock:(VisibleViewControllerBlock)visibleVCBlock
                                  isGlobal:(BOOL)isGlobal{
    
    if (isGlobal) {
        
        [[self class] registerVisibleViewControllerBlockForGlobal:visibleVCBlock];
    }
    [self setVisibleVCBlock:visibleVCBlock];
    
}

+ (void)registerVisibleViewControllerBlockForGlobal:(VisibleViewControllerBlock)visibleVCBlock{
    
    XLFVisibleVCBlock = visibleVCBlock;
}

- (void)registerListeningErrorBlock:(void (^)(id httpRequest, NSError *error))listeningErrorBlock
                           isGlobal:(BOOL)isGlobal;{
    
    if (isGlobal) {
        
        [[self class] registerListeningErrorBlockForGlobal:listeningErrorBlock];
    }
    [self setListeningErrorBlock:listeningErrorBlock];
}

+ (void)registerListeningErrorBlockForGlobal:(void (^)(id httpRequest, NSError *error))listeningErrorBlock;{
    
    XLFListeningErrorBlock = listeningErrorBlock;
}

- (UIView*)visibleContentView;{
    
    UIView *contentView = [[[UIApplication sharedApplication] windows] firstObject];
    if (![self visibleVCBlock]) {
        
        NIF_DEBUG(@"请注册可见视图 efRegisterVisibleViewControllerBlock");
    }
    else{
        
        UIViewController *visibleVC = self.visibleVCBlock(nil,[self isHiddenLoadingView]);
        if (visibleVC && [visibleVC isKindOfClass:[UIViewController class]]) {
            contentView = [visibleVC view];
        }
        else{
            
            NIF_DEBUG(@"注册可见视图（efRegisterVisibleViewControllerBlock）不是一个有效视图，请检查");
        }
    }
    return contentView;
}

@end

@interface XLFHttpRequestManager ()

@property(nonatomic, strong) NSMutableDictionary *evreqReferrence;

@end

@implementation XLFHttpRequestManager

+ (void)load{
    [super load];
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:SDCacheDirectory]){
        [[NSFileManager defaultManager] createDirectoryAtPath:SDCacheDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

+ (instancetype)sharedInstance{
    
    static id httpRequestManager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        httpRequestManager =  [[[self class] alloc] init];
    });
    
    return httpRequestManager;
}

+ (void)registerHttpRequestClass:(Class)cls;{
    
    if ([cls isSubclassOfClass:[XLFBaseHttpRequest class]]) {
        
        [[self sharedInstance] setHttpRequestClass:cls];
    }
    else{
        
        NIF_ERROR(@"register http request class isn't subclass of XLFBaseHttpRequest");
    }
}

- (NSMutableDictionary *)evreqReferrence{
    
    if (!_evreqReferrence) {
        
        _evreqReferrence = [NSMutableDictionary dictionary];
    }
    return _evreqReferrence;
}

/**
 *  移除并取消相关代理的请求
 *
 *  @param delegate 代理
 */
+ (void)removeAndCancelAllRequestDelegate:(id<XLFHttpRequestDelegate>)delegate;{
    
    NSOperationQueue *queue = [ASIHTTPRequest sharedQueue];
    
    for (id request in [queue operations]) {
        
        if ([request isKindOfClass:[XLFBaseHttpRequest class]] && [request evDelegate] == delegate) {
            
            [request clearDelegatesAndCancel];
        }
    }
}

/**
 *  移除并取消相关代理的请求
 *
 *  @param userTag 用户标记
 */
+ (void)removeAndCancelAllRequestByUserTag:(id)userTag;{
    
    NSOperationQueue *queue = [ASIHTTPRequest sharedQueue];
    
    for (id request in [queue operations]) {
        
        if ([request isKindOfClass:[XLFBaseHttpRequest class]] && [[request evUserTag] isEqual:userTag]) {
            
            [request clearDelegatesAndCancel];
        }
    }
}

/**
 *  移除相关代理的请求
 *
 *  @param delegate 代理
 */
+ (void)removeAllRequestDelegate:(id<XLFHttpRequestDelegate>)delegate;{
    
    NSOperationQueue *queue = [ASIHTTPRequest sharedQueue];
    
    for (id request in [queue operations]) {
        
        if ([request isKindOfClass:[XLFBaseHttpRequest class]] && [request evDelegate] == delegate) {
            
            [request setEvDelegate:nil];
        }
    }
}

+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
                withTag:(NSInteger)tag
               delegate:(id<XLFHttpRequestDelegate>)delegate{
    
    return [self requestWithParams:params
                        httpMethod:method
                           withTag:tag
                 hiddenLoadingView:YES
                          delegate:delegate];
}

+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
                withTag:(NSInteger)tag
      hiddenLoadingView:(BOOL)hiddenLoadingView
               delegate:(id<XLFHttpRequestDelegate>)delegate{
    
    return [self requestWithParams:params
                        httpMethod:method
                          dataType:XLFHttpRquestDataTypeJson
                           withTag:tag
                 hiddenLoadingView:hiddenLoadingView
                          delegate:delegate];
}

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
               delegate:(id<XLFHttpRequestDelegate>)delegate;{
    
    XLFBaseHttpRequest *request = [[[self sharedInstance] evreqReferrence] objectForKey:@(tag)];
    
    if (request) {
        [request clearDelegatesAndCancel];
    }
    
    request = [self requestWithParams:params method:method];
    
    if (request) {
        
        [request setEvDelegate:delegate];
        
        [self setupRequest:request
                httpMethod:method
                  dataType:dataType
                   withTag:tag
         hiddenLoadingView:hiddenLoadingView
            relationObject:delegate];
        [request setContainer:[self sharedInstance]];
        [[[self sharedInstance] evreqReferrence] setObject:request forKey:@(tag)];
    }
    return request;
}

+ (id)fileRequestWithUrl:(NSString*)fileUrl
                 withTag:(NSInteger)tag
       hiddenLoadingView:(BOOL)hiddenLoadingView
                delegate:(id<XLFHttpRequestDelegate>)delegate;{
    
    XLFBaseHttpRequest *request = [[[self sharedInstance] evreqReferrence] objectForKey:@(tag)];
    
    if (request) {
        [request clearDelegatesAndCancel];
    }
    
    request = [self fileRequestWithUrl:fileUrl
                     hiddenLoadingView:hiddenLoadingView
                              delegate:delegate];
    
    if (request) {
        
        [request setRequestTag:tag];
        [request setContainer:[self sharedInstance]];
        [[[self sharedInstance] evreqReferrence] setObject:request forKey:@(tag)];
    }
    
    return request;
    
}

+ (id)fileRequestWithUrl:(NSString*)fileUrl
       hiddenLoadingView:(BOOL)hiddenLoadingView
                delegate:(id<XLFHttpRequestDelegate>)delegate;{
    
    XLFBaseHttpRequest *request = [self modelFileRequestWithUrl:fileUrl];
    
    [request setEvDelegate:delegate];
    
    [self setupRequest:request
            httpMethod:XLFHttpRquestModeGet
              dataType:XLFHttpRquestDataTypeByte
               withTag:XLFHttpRquestNormalTag
     hiddenLoadingView:hiddenLoadingView
        relationObject:delegate];
    
    return request;
}

/**
 *  Selector
 */
+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
                withTag:(NSInteger)tag
               delegate:(id)delegate
                success:(SEL)successSelector
                failure:(SEL)failureSelector;{
    
    return [self requestWithParams:params
                        httpMethod:method
                           withTag:tag
                 hiddenLoadingView:YES
                          delegate:delegate
                           success:successSelector
                           failure:failureSelector];
}
/**
 *  Selector
 */
+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
                withTag:(NSInteger)tag
      hiddenLoadingView:(BOOL)hiddenLoadingView
               delegate:(id)delegate
                success:(SEL)successSelector
                failure:(SEL)failureSelector;{
    
    return [self requestWithParams:params
                        httpMethod:method
                          dataType:XLFHttpRquestDataTypeJson
                           withTag:tag
                 hiddenLoadingView:hiddenLoadingView
                          delegate:delegate
                           success:successSelector
                           failure:failureSelector];
}

+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
               dataType:(XLFHttpRquestDataType)dataType
                withTag:(NSInteger)tag
      hiddenLoadingView:(BOOL)hiddenLoadingView
               delegate:(id)delegate
                success:(SEL)successSelector
                failure:(SEL)failureSelector;{
    
    XLFBaseHttpRequest *request = [[[self sharedInstance] evreqReferrence] objectForKey:@(tag)];
    
    if (request) {
        [request clearDelegatesAndCancel];
    }
    
    request = [self requestWithParams:params method:method];
    
    if (request) {
        
        [request setEvDelegate:delegate];
        [request setDidSuccessSelector:successSelector];
        [request setDidFailureSelector:failureSelector];
        
        [self setupRequest:request
                httpMethod:method
                  dataType:dataType
                   withTag:tag
         hiddenLoadingView:hiddenLoadingView
            relationObject:delegate];
        [request setContainer:[self sharedInstance]];
        [[[self sharedInstance] evreqReferrence] setObject:request forKey:@(tag)];
    }
    
    return request;
}

+ (id)fileRequestWithUrl:(NSString*)fileUrl
                 withTag:(NSInteger)tag
       hiddenLoadingView:(BOOL)hiddenLoadingView
                delegate:(id)delegate
                 success:(SEL)successSelector
                 failure:(SEL)failureSelector;{
    
    XLFBaseHttpRequest *request = [[[self sharedInstance] evreqReferrence] objectForKey:@(tag)];
    
    if (request) {
        [request clearDelegatesAndCancel];
    }
    
    request = [self fileRequestWithUrl:fileUrl
                     hiddenLoadingView:hiddenLoadingView
                              delegate:delegate
                               success:successSelector
                               failure:failureSelector];
    
    if (request) {
        
        [request setRequestTag:tag];
        [request setContainer:[self sharedInstance]];
        [[[self sharedInstance] evreqReferrence] setObject:request forKey:@(tag)];
    }
    
    return request;
}

+ (id)fileRequestWithUrl:(NSString*)fileUrl
       hiddenLoadingView:(BOOL)hiddenLoadingView
                delegate:(id)delegate
                 success:(SEL)successSelector
                 failure:(SEL)failureSelector;{
    
    XLFBaseHttpRequest* request = [self modelFileRequestWithUrl:fileUrl];
    
    [request setEvDelegate:delegate];
    [request setDidSuccessSelector:successSelector];
    [request setDidFailureSelector:failureSelector];
    
    [self setupRequest:request
            httpMethod:XLFHttpRquestModeGet
              dataType:XLFHttpRquestDataTypeByte
               withTag:XLFHttpRquestNormalTag
     hiddenLoadingView:hiddenLoadingView
        relationObject:delegate];
    
    return request;
}

#if NS_BLOCKS_AVAILABLE
/**
 *  block
 */
+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
                withTag:(NSInteger)tag
                success:(XLFSuccessedBlock)successedBlock
                failure:(XLFFailedBlock)failedBlock;{
    
    return [self requestWithParams:params
                        httpMethod:method
                           withTag:tag
                 hiddenLoadingView:YES
                    relationObject:nil
                           success:successedBlock
                           failure:failedBlock];
}
/**
 *  block
 */
+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
                withTag:(NSInteger)tag
      hiddenLoadingView:(BOOL)hiddenLoadingView
         relationObject:(id)relationObject
                success:(XLFSuccessedBlock)successedBlock
                failure:(XLFFailedBlock)failedBlock;{
    
    return [self requestWithParams:params
                        httpMethod:method
                          dataType:XLFHttpRquestDataTypeJson
                           withTag:tag
                 hiddenLoadingView:hiddenLoadingView
                    relationObject:relationObject
                           success:successedBlock
                           failure:failedBlock];
}

+ (id)requestWithParams:(XLFHttpParameter *)params
             httpMethod:(NSString*)method
               dataType:(XLFHttpRquestDataType)dataType
                withTag:(NSInteger)tag
      hiddenLoadingView:(BOOL)hiddenLoadingView
         relationObject:relationObject
                success:(XLFSuccessedBlock)successedBlock
                failure:(XLFFailedBlock)failedBlock;{
    
    XLFBaseHttpRequest *request = [[[self sharedInstance] evreqReferrence] objectForKey:@(tag)];
    
    if (request) {
        [request clearDelegatesAndCancel];
    }
    
    request = [self requestWithParams:params method:method];
    
    if (request) {
        
        [request setSuccessedBlock:successedBlock];
        [request setFailedBlock:failedBlock];
        
        [self setupRequest:request
                httpMethod:method
                  dataType:dataType
                   withTag:tag
         hiddenLoadingView:hiddenLoadingView
            relationObject:relationObject];
        
        [request setContainer:[self sharedInstance]];
        [[[self sharedInstance] evreqReferrence] setObject:request forKey:@(tag)];
    }
    
    return request;
}

+ (id)fileRequestWithUrl:(NSString*)fileUrl
                 withTag:(NSInteger)tag
       hiddenLoadingView:(BOOL)hiddenLoadingView
          relationObject:relationObject
                 success:(XLFSuccessedBlock)successedBlock
                 failure:(XLFFailedBlock)failedBlock;{
    
    XLFBaseHttpRequest *request = [[[self sharedInstance] evreqReferrence] objectForKey:@(tag)];
    
    if (request) {
        [request clearDelegatesAndCancel];
    }
    
    request = [self fileRequestWithUrl:fileUrl
                     hiddenLoadingView:hiddenLoadingView
                        relationObject:relationObject
                               success:successedBlock
                               failure:failedBlock];
    if (request) {
        
        [request setRequestTag:tag];
        [request setContainer:[self sharedInstance]];
        [[[self sharedInstance] evreqReferrence] setObject:request forKey:@(tag)];
    }
    
    return request;
}

+ (id)fileRequestWithUrl:(NSString*)fileUrl
       hiddenLoadingView:(BOOL)hiddenLoadingView
          relationObject:(id)relationObject
                 success:(XLFSuccessedBlock)successedBlock
                 failure:(XLFFailedBlock)failedBlock;{
    
    XLFBaseHttpRequest* request = [self modelFileRequestWithUrl:fileUrl];
    
    [request setSuccessedBlock:successedBlock];
    [request setFailedBlock:failedBlock];
    
    [self setupRequest:request
            httpMethod:XLFHttpRquestModeGet
              dataType:XLFHttpRquestDataTypeByte
               withTag:XLFHttpRquestNormalTag
     hiddenLoadingView:hiddenLoadingView
        relationObject:relationObject];
    
    return request;
}

#endif

+ (void)setupRequest:(id)request
          httpMethod:(NSString*)method
            dataType:(XLFHttpRquestDataType)dataType
             withTag:(NSInteger)tag
   hiddenLoadingView:(BOOL)hiddenLoadingView
      relationObject:(id)relationObject{
    
    [request setRelationObject:relationObject];
    [request setRequestTag:tag];
    [request setHiddenLoadingView:hiddenLoadingView];
    [request setRequestMethod:method];
    [request setDataType:dataType];
    [request setDelegate:request];
    [request setTimeOutSeconds:150];
    [request setDownloadProgressDelegate:request];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDidFinishSelector:@selector(requestFinished:)];
}

/**
 *  根据参数创建请求
 *  默认为
 *
 *  @param params 参数
 *  @param method 请求类型
 *
 *  @return 请求对象
 */
+ (id)requestWithParams:(XLFHttpParameter *)parameter
                 method:(NSString *)method;{
    
    NSString *etUrl = [parameter handle];
    
    XLFBaseHttpRequest *etRequest = nil;
    
    for (id etPathParameter in [parameter pathParams]) {
        
        etUrl = [etUrl stringByAppendingFormat:@"/%@",etPathParameter];
    }
    
    if ([parameter queryParams] && [[parameter queryParams] count]) {
        
        etUrl = [etUrl stringByAppendingString:@"?"];
    }
    
    if ([parameter queryParams] && [[parameter queryParams] count]) {
        
        NSInteger nIndex = 0;
        
        for (id etKey in [[parameter queryParams] allKeys]) {
            
            id etValue = [[parameter queryParams] objectForKey:etKey];
            
            if (([etValue isKindOfClass:[NSString class]] && [etValue length]) ||
                ([etValue isKindOfClass:[NSNumber class]] && etValue)) {
                
                etUrl = [etUrl stringByAppendingFormat:@"%@%@=%@", nIndex ? @"&" : @"", etKey, etValue];
            }
            else if ([etValue isKindOfClass:[NSArray class]] || [etValue isKindOfClass:[NSSet class]]) {
                
                for (NSString *etSubValue in etValue) {
                    
                    etUrl = [etUrl stringByAppendingFormat:@"%@%@=%@", nIndex ? @"&" : @"", etKey, etSubValue];
                }
            }
            else if ([etValue isKindOfClass:[NSDictionary class]]){
                
                etUrl = [etUrl stringByAppendingFormat:@"%@%@=%@",nIndex ? @"&" : @"", etKey, [etValue JSONPrivateString]];
            }
            
            nIndex++;
        }
    }
    
    etUrl = [etUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    etRequest = [[[[self sharedInstance] httpRequestClass] alloc] initWithURL:[NSURL URLWithString:etUrl]];
    
    if ([parameter formParams] && [[parameter formParams] count]) {
        
        for (id etKey in [[parameter formParams] allKeys]) {
            
            id etValue = [[parameter formParams] objectForKey:etKey];
            
            if ([etValue isKindOfClass:[NSData class]] ) {
                
                [etRequest addData:etValue forKey:etKey];
            }
            else if([etValue isKindOfClass:[XLFUploadFile class]]){
                
                [etRequest addData:[etValue data] withFileName:[etValue fileName] andContentType:[etValue contentType] forKey:etKey];
            }
            else if ([etValue isKindOfClass:[NSString class]] || [etValue isKindOfClass:[NSNumber class]]) {
                
                [etRequest addPostValue:etValue forKey:etKey];
            }
            else if ([etValue isKindOfClass:[NSArray class]] || [etValue isKindOfClass:[NSDictionary class]]){
                
                [etRequest addPostValue:[etValue JSONPrivateString] forKey:etKey];
            }
            else {
                NIF_WARN(@"Unknown type of post value");
            }
        }
    }
    
    if ([parameter postBody]) {
        
        if ([[parameter postBody] isKindOfClass:[NSData class]]) {
            
            [etRequest setPostBody:[NSMutableData dataWithData:[parameter postBody]]];
        }
        else{
            
            NIF_DEBUG(@"%@",[[parameter postBody] JSONPrivateString]);
            
            [etRequest setPostBody:[NSMutableData dataWithData:[[parameter postBody] JSONPrivateData]]];
        }
        [etRequest addRequestHeader:@"Content-Type" value:@"application/json"];
    }
    
    if ([parameter headParams] && [[parameter headParams] count]) {
        
        for (id etKey in [[parameter headParams] allKeys]) {
            
            id etValue = [[parameter headParams] objectForKey:etKey];
            
            if ([etValue isKindOfClass:[NSString class]]) {
                
                [etRequest addRequestHeader:etKey value:etValue];
            }
            else{
                NIF_WARN(@"Unknown type of post value ");
            }
        }
    }
    
    [etRequest setParameter:parameter];
    
    NIF_DEBUG(@"request url:%@ \n httpMethod:%@\n params:\n%@", etUrl, method, parameter);
    
    return etRequest;
}

+ (id)modelFileRequestWithUrl:(NSString *)url{
    
    return nil;
}

@end

