//
//  XLFProgressViewDelegate.h
//  XLFBaseHttpRequestKit
//
//  Created by Marike Jave on 15/7/5.
//  Copyright (c) 2015年 Marike Jave. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol XLFProgressViewDelegate <NSObject>

@property(nonatomic, assign) CGFloat progress;

+ (id)alloc;

+ (id)showProgressString:(NSString*)string;
+ (id)showProgressString:(NSString*)string inContentView:(UIView *)contentView;


+ (id)showErrorString:(NSString*)string;
+ (id)showErrorString:(NSString*)string inContentView:(UIView *)contentView;
+ (id)showErrorString:(NSString*)string inContentView:(UIView *)contentView duration:(NSTimeInterval)duration;


+ (id)showSuccessString:(NSString*)string;
+ (id)showSuccessString:(NSString*)string inContentView:(UIView *)contentView;
+ (id)showSuccessString:(NSString*)string inContentView:(UIView *)contentView duration:(NSTimeInterval)duration;

@end
