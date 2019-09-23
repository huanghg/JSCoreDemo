//
//  JSCoreEngine.m
//  JSCoreDemo
//
//  Created by HaiguangHuang on 2019/6/17.
//  Copyright © 2019 HaiguangHuang. All rights reserved.
//

#import "JSCoreEngine.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <JavaScriptCore/JavaScriptCore.h>

static NSMutableDictionary *overideMethodsDic;

@interface JSCoreEngine ()

@property (nonatomic, strong) JSContext *context;

@end

@implementation JSCoreEngine

+ (instancetype)sharedInstance
{
    static JSCoreEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[JSCoreEngine alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        overideMethodsDic = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (void)swizzleSelector:(SEL)originalSelector ofClass:(Class)class withSelector:(SEL)swizzledSelector
{
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(self, swizzledSelector);
    
    BOOL didAddMethod =
    class_addMethod(class,
                    originalSelector,
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(class,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

- (void)startEngine
{
    self.context = [[JSContext alloc] init];
    
    self.context[@"_OC_log"] = ^(NSString *msg) {
        NSLog(@"%@", msg);
    };
    
    self.context[@"__JSCallOCMethod"] = ^(NSString *className, JSValue *jsValue) {
        NSDictionary *methodDic = [jsValue toDictionary];
        for (NSString *method in methodDic.allKeys) {
            JSValue *function = [jsValue valueForProperty:method];
            overrideMethod(className, method, function, NULL);
        }
    };
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"demo" ofType:@"js"];
    NSString *jsScript = [[NSString alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] encoding:NSUTF8StringEncoding error:nil];
    [self.context evaluateScript:jsScript];
}

static void overrideMethod(NSString *className, NSString *selectName, JSValue *function, const char *typeDescription) {
    NSMutableDictionary *methods = overideMethodsDic[className];
    if (!methods) {
        methods = [NSMutableDictionary dictionary];
    }
    [methods setValue:function forKey:selectName];
    
    [overideMethodsDic setValue:methods forKey:className];
    
    Class clazz = NSClassFromString(className);

    if (class_getMethodImplementation(clazz, @selector(forwardInvocation:)) != (IMP)JPForwardInvocation) {
        IMP originalForwardImp = class_replaceMethod(clazz, @selector(forwardInvocation:), (IMP)JPForwardInvocation, "v@:@");
        if (originalForwardImp) {
            class_addMethod(clazz, @selector(ORIGforwardInvocation:), (IMP)JPForwardInvocation, "v@:@");
        }
    }
    
    SEL selector = NSSelectorFromString(selectName);
    
    if (!typeDescription) {
        Method method = class_getInstanceMethod(clazz, selector);
        typeDescription = (char *)method_getTypeEncoding(method);
    }
    
    IMP msgForwardIMP = _objc_msgForward;
    class_replaceMethod(clazz, selector, msgForwardIMP, typeDescription);
}

static void JPForwardInvocation(__unsafe_unretained id assignSlf, SEL selector, NSInvocation *invocation)
{
    NSString *className = NSStringFromClass([assignSlf class]);
    NSDictionary *methods = overideMethodsDic[className];
    NSString *methodName = NSStringFromSelector(invocation.selector);
    JSValue *function = methods[methodName];
    [function callWithArguments:nil];
}
@end
