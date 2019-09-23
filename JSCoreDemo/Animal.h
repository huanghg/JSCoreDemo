//
//  Animal.h
//  JSCoreDemo
//
//  Created by HaiguangHuang on 2019/6/17.
//  Copyright © 2019 HaiguangHuang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AnimalProtocol <JSExport>

@property (nonatomic, strong) NSString *name;

- (void)sayWithExport;

@end

@interface Animal : NSObject <AnimalProtocol>

@property (nonatomic, strong) NSString *name;

- (void)sayWithoutExport;

- (void)test;

@end

NS_ASSUME_NONNULL_END
