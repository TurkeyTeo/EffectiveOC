####1. 理解objc_msgSend

objc_msgSend函数会依据接受者与选择子的类型来调用适当的方法。为了完成次操作，改方法需要在接受者所属的类中搜寻起“方法列表”（list of methods），如果能找到与选择子名称相符的方法，就调到其实现代码。若是找不到，那就沿着继承体系继续向上查找，等找到合适的方法之后再跳转。如果最终还是找不到相符的方法，那就执行“消息转发”（message forwarding）操作。



- objc_msgSend_stret：如果待发送的消息要返回结构体，那么可交由此函数处理。只有当CPU的寄存器能够容纳得下消息返回类型时，这个函数才能处理此消息。若是返回值无法容纳于CPU寄存器中（比如说返回的结构体太大了），那么就由另一个函数执行派发。此时，那个函数会通过分配在栈上的某个变量来处理消息所返回的结构体。
- objc_msgSend_fpret：如果消息返回的是浮点数，那么金额交由次函数处理。
- objc_msgSendSuper：如果要给超类发消息，例如[super message:parameter]，那么就交由次函数处理。也有另外两个于objc_msgSend_stret和objc_msgSend_fpret等效的函数，用于处理发送给super的相应消息。



####2. 消息转发

如果在控制台中看到下面这种提示信息，那就说明你曾向某个对象发送过一条其无法解读的消息，从而启动了消息转发机制，并将此消息转发给了NSObject的默认实现。

unrecognized selector sent to instance 0x87

上面这段异常信息是由NSObject的“doesNotRecognizeSelector：”方法所抛出的。

消息转发分为两大阶段。第一阶段先征询接收者，所属的类，看其是否能动态添加方法，以处理当前这个“未知的选择子”（unknown selector），这叫做“动态方法解析”（dynamic  method resolution）。第二阶段涉及“完整的消息转发机制”（full forwarding mechanism）。如果运行期系统以及把第一阶段执行完了，那边接收者自己就无法再以动态新增方法的手段来响应包含该选择子的消息了。此时，运行期系统会请求接收者以其他手段来处理与消息相关的方法调用。这又细分为2小步。首先，请接收者看看有没有其他对象能处理这条消息。若有，则运行期系统会把消息转给那个对象，于是消息转发过程结束，一切如常。若没有“被援的接收者”（replacement receiver），则启动完整的消息转发机制，运行期系统会把与消息有关的全部细节都封装到NSInvocation对象中，再给接收者最后一次机会，令其设法解决当前还未处理的这条消息。



##### 动态方法解析

对象在接收到无法解读的消息后，首先将调用其所属类的下列类方法：

```
+ (BOOL)resolveInstanceMethod:(SEL)selector
```



#####备援接收者

当前接收者还有第二次机会能处理位置的选择子，在这一步中，运行期系统会问它：能不能把这条消息转给其他接收者来处理。与该步骤对应的处理方法如下：

```
- (id)forwardingTargetForSelector:(SEL)selector
```



##### 完整的消息转发

如果转发算法已经来到这一步的话，那么唯一能做的就是启用完整的消息转发机制了。首先创建NSInvocation对象，把与尚未处理的那条消息有关的全部细节都封装在其中，此对象包括选择子，目标（target）及参数。在触发NSInvocation对象时，消息派发系统（message-dispatch-system）将亲自出马，把消息指派给目标对象。

此步骤会调用下列方法来转发消息：

```
-(void)forwardInvocation:(NSInvocation *)invovation
```

这个方法可以实现的很简单：只需改变调用目标，使消息在新目标上得以调用即可。然而这样实现出来的方法与“备援接收者”方案所实现的方法等效，所以很少有人采用这么简单的实现方式。比较有用的实现方式为：在触发消息前，先以某种方式改变消息内容，比如追加另外一个参数，或者改变选择子等。

![forwarding_flow](/Users/thinkive/Desktop/Study/MD/Effective Objective-C 2.0  学习笔记/forwarding_flow.png)



####3. 用“方法调配技术”调试“黑盒方法” 

类的方法列表会把选择子的名称映射到相关的方法实现上，使得“动态消息派发系统”能够据此找到应该调用的方法。这些方法均以函数指针的形式来表示，这种指针叫做IMP，其原型如下：

```
id (*IMP)(id, SEL, ...)
```

`isKindOfClass`和`isMemberOfClass`这样的类型信息查询方法原理是使用了isa指针获取对所属的类，然后通过super_class指针在继承体系中游走。



#### 4. 提供“全能初始化方法”

- 在类中提供一个全能初始化方法，并于文档里指明。其他初始化方法均应调用此方法。
- 若全能初始化方法与超类不同，则需覆写超类中的对应方法。
- 如果超类的初始化方法不适用于子类，那边应该覆写这个超类方法，并在其中抛出异常。



####5. 实现description方法 

我们有时需要更为有用的信息， 只需要覆写description方法并将描述次对象的信息返回即可。NSObject协议中还有个方法：debugDescription，此方法与description非常相似。二者的区别在于，debugDescription方法是开发者在调试器中以控制台命令打印对象时才调用的，即当运行到断点时，你使用LLDB的“po”命令打印输出的内容就是debugDescription。在NSObject类的默认实现中，此方法只是直接调用了description。



#### 6. 理解NSCopying协议

使用对象时经常需要拷贝它。在OC中，此操作通过copy方法完成。如果想令自己的类支持拷贝操作，那就要实现NSCopying协议，该协议只有一个方法：

```
- (id)copyWithZone:(NSZone *)zone
```

为何会出现NSZone呢？因为在以前开发程序时，会据此吧内存分成不同的“区”（zone），而对象会创建在某个区里面。现在不用了，每个程序只有一个区：“默认区”（default zone）。所以说，尽管必须实现这个方法，但是你不必担心其中的zone参数。

若想使某个类支持拷贝功能，只需声明该类遵从NSCopying协议，并实现其中的该方法。

- 若想令自己所写的对象具有拷贝功能，则需实现NSCopying协议。
- 如果自定义的对象分为可变版本与不可变版本，那么就要同时实现NSCopying和NSMutableCopying协议。
- 复制对象时需决定采用浅拷贝还是深拷贝，一般情况下应该尽量执行浅拷贝。
- 如果你缩写的对象需要深拷贝，那么可考虑新增一个专门执行深拷贝的方法。




#### 7. 内存管理

**ARC如何清理实例变量:**

ARC会借用Objective-C++的一项特性来生成清理例程（cleanup routine）。回收Objective-C++对象时，待回收的对象会调用所有C++对象的析构函数（destructor）。编译器如果发现某个对象里含有C++对象，就会生成名为.cxx_destruct的方法。而ARC则借助此特性，在该方法中生成清理内存的代码。

不过如果有非Objective-C的对象，比如CoreFoundation中的对象或是由malloc()分配在堆中的内存，那么仍然需要清理。然而不需要像原来那样调用超类的dealloc方法。ARC会自动在.cxx_destruct方法中生成代码并运行此方法，而在生成的代码中会自动调用超类的dealloc方法。ARC环境下，dealloc方法可以如下写：

```objective-c
- (void)dealloc{
  CFRelease(_coreFoundationObject);
  free(_heapAllocatedMemoryBlob);
}
```



**以autoreleasepool降低内存峰值：**

通常，系统会自动创建一些线程，比如主线程或者GCD中的线程，默认都有自动释放池，每次执行“事件循环”（event loop）时，就会将其清空。

```objective-c
NSArray *databaseRecords = /*...*/;
NSMutableArray *people = [NSMutableArray new];
for (NSDictionary *record in databseRecords) {
  	@autoreleasepool {
      	TTPerson *person = [[TTPerson alloc] initWithRecord:record];
      	[people addObject:person];
  	}
}
```



#### 8.GCD

**block的内部结构**

每个OC对象都占据着某个内存区域，因为实例变量的个数及对象所包含的关联数据互不相同，所以每个对象所占的内存区域也有大有小。block本身也是对象，在存放块对象的内存区域中，首个变量是指向Class对象的指针，该指针叫做isa。其余内存中含有块对象正常运转所需的各种信息。![block](/Users/thinkive/Desktop/Study/MD/Effective Objective-C 2.0  学习笔记/block.png)

在内存布局中，最重要的就是invoke变量，这是个函数指针，指向块的实现代码。函数原型至少要接收一个void*型的参数，此参数代表block（block其实就是一种代替函数指针的语法结构），原来使用函数指针时，需要用“不透明的void指针”来传递状态。而改用block之后，则可以把原来用标准C语言特性所编写的代码封装成简明易用的接口。

descriptor变量是指向结构体的指针，每个block中都含有此结构体，其中声明了block对象的总体大小，还声明了copy与dispose这两个辅助函数所对应的函数指针。辅助函数在拷贝及丢弃block对象时运行，其中会执行一些操作，比如，前者要保留捕获的对象，而后者则将之释放。

block还会把它所捕获的所有变量都拷贝一份。这些拷贝放在descriptor变量后面，捕获了多少个变量，就要占据多少内存空间。注意：**拷贝的并不是对象本身，而是指向这些对象的指针变量**。invoke函数为何需要把block对象作为参数传进来呢？原因在于，执行block时要从内存中把这些捕获到的变量读出来。



**全局块，栈块及堆块**

定义block时，起占有的内存区域是分配在栈中的。这就是说，block只在定义他的那个范围内有效。

例如，如下代码就是危险的：

```objective-c
  void (^block)(void);
    if (XXX) {
        block = ^{
            NSLog(@"block A");
        };
    }else{
        block = ^{
            NSLog(@"block B");
        };
    }
    block();
```

因为定义在if及else语句中的两个块都分配在栈内存中。编译器会给每个block分配好栈内存，然而等离开了想要的范围之后，编译器有可能会把分配给快的内存覆盖掉。于是，这两个block只能保证在对应的if或else语句范围内有效，这样写的代码可以编译，但是运行起来若编译器覆写了待执行的block则程序会崩溃。

为解决此问题，可给block对象发送copy消息拷贝之。这样就可以把block从栈复制到堆了。拷贝后的block可以在定义他的那个范围之外使用，而且一旦复制到堆上，块就成了带引用计数的对象了，后续的复制操作都不会真的执行复制，二十递增block对象的引用计数。

```objective-c
   void (^block)(void);
    if (1) {
        block = [^{
            NSLog(@"block A");
        } copy];
    }else{
        block = [^{
            NSLog(@"block B");
        } copy];
    }
    block();
```



全局块（global block）：这种块不会捕捉任何状态（比如外围的变量等），运行时也无需有状态来参与。块所使用的整个内存区域，在编译期就已经完全确定了，因此，全局块可以生命在全局内存中，而不需要在每次用到的时候在栈中创建，另外，全局块的拷贝操作是个空操作，因为全局块不可能被系统回收，这种块相当于单例，如下：

```objective-c
    //全局block
    void (^globalBlock)() = ^{
        NSLog(@"globalBlock");
    };
```



