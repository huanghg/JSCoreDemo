//
//  JSCoreEngine.h
//  JSCoreDemo
//
//  Created by HaiguangHuang on 2019/6/17.
//  Copyright © 2019 HaiguangHuang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JSCoreEngine : NSObject

+ (instancetype)sharedInstance;

- (void)startEngine;

@end

NS_ASSUME_NONNULL_END
