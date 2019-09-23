# 热更新之入门篇

## 背景

作为iOS开发者都知道，在千辛万苦作出一个app以后，上架App Store之前是需要苹果爸爸审核的。App审核不但规则苛责，还周期漫长（不过现在有所改善啦）所以每发一次版本实属不易。

但是如果线上出现了严重的生产BUG（说到BUG，想必这是程序猿最不想听到的一个词，但是这又是在所难免的事），这个时候通过发版来解决就不现实了。

热更新（Hot fix）此时应运而生。



## 现状

下面列举一下行业内比较常见的几种热更新方案。

|          | [JSPatch](https://github.com/bang590/JSPatch)                | React Native                                                 | Dynamic Framework                                            | WaxPatch                                             |
| -------- | :----------------------------------------------------------- | ------------------------------------------------------------ | :----------------------------------------------------------- | :--------------------------------------------------- |
| 维护团队 | Tencent                                                      | Facebook                                                     | 滴滴                                                         | Alibaba                                              |
| 内容     | JS                                                           | JS                                                           | Objective-C                                                  | Lua                                                  |
| 原理     | JS 传递字符串给 OC，OC 通过 Runtime 接口调用和替换 OC 方法   | 因为RN本来就是通过JS来写原生，所以可以通过修改JS达到Hot fix的目的。 | 是一个动态库，通过更新App所依赖的Framework方式，来实现对于Bug的HotFix | 利用Objective-C动态性，调用接口和替换Objective-C方法 |
| 优缺点   | JSPatch曾经一度被苹果爸爸封杀，如有兴趣请见[详情](http://blog.cnbang.net/internet/3374/)，但是经过腾讯和苹果公司层面的沟通后，苹果作出了让步，请见[详情](https://jspatch.com/Docs/appleFAQ)，也就是只能通过JSPatch平台下发JS脚本。 | 只适合用于使用了React Native这种方案的应用或者模块。         | 它不符合Apple3.2.2的审核规则，所以不能上架App Store          | 需要Lua脚本的解析引擎，并且常年未维护更新            |



## 热更新原理

### 基础原理

上面列举的其他几种热更新方式基本上是建立在Objective-C的动态性的基础上。众所周知，Objective-C在类的生成/方法的调用都是在运行时进行的。我们可以在运行时，通过反射生成某个类的对象，调用对应的方法。

```objective-c
Class class = NSClassFromString("UIViewController");
id viewController = [[class alloc] init];
SEL selector = NSSelectorFromString("viewDidLoad");
[viewController performSelector:selector];
```

当然，替换方法也不在话下

```objective-c
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
```



### 语言选型

相信在开发过程中，我们也运用了很多Objective-C的动态性，但是要想实现动态更新，这往往不能提前预置在代码里，而需要通过**动态下发**。那动态下发可执行代码，然后再通过Objective-C的动态性，岂不美哉？

不好意思，苹果爸爸早就想到你们坏人想图谋不轨了，所以早在**iOS Developer Program License Agreement**里3.3.2提到不可动态下发可执行代码，但通过苹果**JavaScriptCore.framework**或**WebKit**执行的代码除外。

So，JS有天然的沃土。在iOS 7之后，JSCore作为一个系统级Framework被苹果提供给开发者。JSCore作为苹果的浏览器引擎WebKit中重要组成部分，这个JS引擎已经存在多年。

**WebKit**由多个重要模块组成，通过下图我们可以对WebKit有个整体的了解：

![webkit](/Users/haiguanghuang/Documents/Document/热更新/webkit.jpeg)

简单点讲，WebKit就是一个**页面渲染**以及**逻辑处理**引擎，前端工程师把HTML、JavaScript、CSS作为输入，经过WebKit的处理，就输出成了我们能看到以及操作的Web页面。

其中**JSCore**是WebKit默认内嵌的JS引擎，即用来解释执行JS脚本的。

![jscore](/Users/haiguanghuang/Documents/Document/热更新/jscore.jpeg)



### JS和OC交互

> iOS7之后，苹果对WebKit中的JSCore进行了Objective-C的封装，并提供给所有的iOS开发者。JSCore框架给Swift、OC以及C语言编写的App提供了调用JS程序的能力。同时我们也可以使用JSCore往JS环境中去插入一些自定义对象。

下面就简单地看看JS和Objective-C是如何相互调用的。

**JSContext**

> JSContext表示了一次JS的执行环境。

JSContext是对JS环境的一种OC封装。在这个Context里面，资源是在同一个上下文。

OC可以直接通过context声明变量，方法。当然也可以直接通过context获取js的变量，返回的是一个JSValue。

**Talk is Cheap. Show me the code!**

```objective-c
//创建JSContext
JSContext *context = [[JSContext alloc] init];
//声明一个js变量a, 并赋值
context[@"a"] = @"Hello ";
//还可以通过js的方式来声明变量
[context evaluateScript:@"var b = 'JS';"];
//声明一个js方法fun，在OC中则是一个匿名函数block
context[@"fun"] = ^() {
    //获取方法入参
    NSArray *args = [JSContext currentArguments];
    for (JSValue *value in args) {
        NSLog(@"%@", [value toObject]);
    }
};
//执行js方法fun
[context evaluateScript:@"fun(a, b)"];

//获取js的变量，并转成OC对象
JSValue *value = context[@"a"];
NSLog(@"%@",[value toObject]);
```

**JSValue**

> JSValue实例是一个指向JS值的引用指针。

我们可以使用JSValue类，在OC和JS的基础数据类型之间相互转换。同时我们也可以使用这个类，去创建包装了Native自定义类的JS对象，或者是那些由Native方法或者Block提供实现JS方法的JS对象。支持以下转换:

```objective-c
   Objective-C type  |   JavaScript type
 --------------------+---------------------
         nil         |     undefined
        NSNull       |        null
       NSString      |       string
       NSNumber      |   number, boolean
     NSDictionary    |   Object object
       NSArray       |    Array object
        NSDate       |     Date object
       NSBlock (1)   |   Function object (1)
          id (2)     |   Wrapper object (2)
        Class (3)    | Constructor object (3)
```

至此，我们已经知道在OC里面如何调用JS了，我们还需要知道JS是如何调用OC的。这时候JSExport就要粉墨登场了。

**JSExport**

> JSExport是一个协议，对象实现JSExport协议可以开放OC类和它们的实例方法，类方法，以及属性给JS调用。

```objective-c
@protocol AnimalProtocol <JSExport>

@property (nonatomic, strong) NSString *name;

- (void)sayWithExport;

@end

@interface Animal : NSObject <AnimalProtocol>

@property (nonatomic, strong) NSString *name;

- (void)sayWithoutExport;

@end
  
@implementation Animal

- (void)sayWithoutExport {
    NSLog(@"my name is %@", self.name);
}

- (void)sayWithExport {
    NSLog(@"say in js");
}

@end
```

上面声明了一个类Animal，并实现AnimalProtocol。

```objective-c
Animal *animal = [[Animal alloc] init];
animal.name = @"bird";

//创建JSContext
JSContext *context = [[JSContext alloc] init];
//传递OC对象到当前Context中
context[@"animal"] = animal;
//因为AnimalProtocol并未声明sayWithoutExport方法，所以JS是无法调用该方法的。
[context evaluateScript:@"animal.sayWithoutExport()"];
//work，控制台打印say in js
[context evaluateScript:@"animal.sayWithExport()"];
    
context.exceptionHandler = ^(JSContext *context, JSValue *exception) {
    NSLog(@"%@", [exception toObject]);
};
```

达到这一步还是不能达到热更新的目的的。我们还需要利用runtime的机制，动态替换OC的方法。

下面我们通过一个简单的例子看看一个简单的热更新整体是如何运作的。



### Demo

大家可以看到，Animal有个test方法，这个方法如果没有做任何处理，是会数组越界导致crash的。下面我们就利用热更新修复这个问题。

```objective-c
@implementation Animal
- (void)test {
    NSArray *array = [NSArray array];
    array[0];	//数组越界
}
@end
```

**Step 1 **我们需要编写一个JS文件，假设为test.js

```javascript
var global = this

;(function() {
  
  //这就是替换原生test方法的function
  var test = function() {
    _OC_log("say in demo")
  }
  
  __JSCallOCMethod('Animal', {'test':test})		//调用OC预置的方法，将要热更新的Class名字，方法名，以及对应的function传给OC
  
})()
```

**Step 2** 预置一些OC方法，起到Bridge的作用

```objective-c
- (void)startEngine
{
  //创建JS上下文
    self.context = [[JSContext alloc] init];
  
  //预置_OC_log，供JS调用
    self.context[@"_OC_log"] = ^(NSString *msg) {
        NSLog(@"%@", msg);
    };
    
  //预置__JSCallOCMethod，供JS调用
    self.context[@"__JSCallOCMethod"] = ^(NSString *className, JSValue *jsValue) {
      //JS通过__JSCallOCMethod，将类名，还有替换的方法传给OC
        NSDictionary *methodDic = [jsValue toDictionary];
        for (NSString *method in methodDic.allKeys) {
            JSValue *function = [jsValue valueForProperty:method];
          //OC接收到以后，利用runtime机制替换原生方法。
            overrideMethod(className, method, function, NULL);
        }
    };
  
    //加载test.js，在实际应用中，需要通过下发的方式，这里先读取本地的作为测试。
    NSString *path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"js"];
    NSString *jsScript = [[NSString alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] encoding:NSUTF8StringEncoding error:nil];
    [self.context evaluateScript:jsScript];
}

```

**Step3** 替换方法

```objective-c
//替换方法
static void overrideMethod(NSString *className, NSString *selectName, JSValue *function, const char *typeDescription) {
  //一个全局的字典，存储从JS传递过来的信息
    NSMutableDictionary *methods = overideMethodsDic[className];
    if (!methods) {
        methods = [NSMutableDictionary dictionary];
    }
    [methods setValue:function forKey:selectName];
    
    [overideMethodsDic setValue:methods forKey:className];
    
    Class clazz = NSClassFromString(className);

  //替换forwardInvocation方法
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
  
  //将要替换的方法替换成_objc_msgForward，也就是当调用其他的时候，最终会调用forwardInvocation
  //而forwardInvocation刚刚又被替换成JPForwardInvocation了，从而达到捕获方法的目的
    class_replaceMethod(clazz, selector, msgForwardIMP, typeDescription);
}

//JPForwardInvocation替换最终会调用forwardInvocation方法，
static void JPForwardInvocation(__unsafe_unretained id assignSlf, SEL selector, NSInvocation *invocation)
{
    NSString *className = NSStringFromClass([assignSlf class]);
  //从overideMethodsDic取出对应方法名的JS的function
    NSDictionary *methods = overideMethodsDic[className];
    NSString *methodName = NSStringFromSelector(invocation.selector);
    JSValue *function = methods[methodName];
  //最终调用js的function，从而达到热更新的目的。
    [function callWithArguments:nil];
}

```

这是一个最最最最最简单的热更新的例子，只是阐述了热更新的整体流程的，如果要做到能够实用，还有很多其他问题需要攻克。

路漫漫其修远兮，吾将上下而求索

