//
//  MultipeerConVC.m
//  BlueTooth
//
//  Created by DayHR on 2017/4/19.
//  Copyright © 2017年 haiqinghua. All rights reserved.
//

#import "MultipeerConVC.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>
@interface MultipeerConVC ()<MCSessionDelegate,MCBrowserViewControllerDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate,NSStreamDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property(nonatomic,strong)MCSession * session;
@property(nonatomic,strong)MCBrowserViewController * browserController;
@property(nonatomic,strong)UIImagePickerController * imagePickerController;
@property (weak, nonatomic) IBOutlet UITextField *textField;//文字传输的文本
@property(nonatomic,strong)NSOutputStream * outputStream;//输出流
@property(nonatomic,strong)NSInputStream * inputStream;//输入流
@property(nonatomic,assign)NSInteger byteIndex;//字节下标
@property(nonatomic,strong)NSMutableData * streamData;//二进制流数据
@end

@implementation MultipeerConVC

- (void)viewDidLoad {
    [super viewDidLoad];
    //创建标识
    MCPeerID * peerID = [[MCPeerID alloc] initWithDisplayName:@"蓝牙设备2"];
    //创建会话对象
    self.session = [[MCSession alloc] initWithPeer:peerID];
    self.session.delegate = self;
}
#pragma mark - MCSession代理方法
-(void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state{
    NSLog(@"didChangeState");
    switch (state) {
        case MCSessionStateConnected:
            NSLog(@"连接成功.");
            [self.browserController dismissViewControllerAnimated:YES completion:nil];
            break;
        case MCSessionStateConnecting:
            NSLog(@"正在连接...");
            break;
        default:
            NSLog(@"连接失败.");
            break;
    }
}
//接收数据
-(void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID{
    NSLog(@"接收到数据...");
    if ([UIImage imageWithData:data]) {
        UIImage *image=[UIImage imageWithData:data];
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.imageView setImage:image];
        });
        //保存到相册
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    }
    if([[NSString alloc] initWithData:data encoding:(NSUTF8StringEncoding)]){
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.textField.text = [[NSString alloc] initWithData:data encoding:(NSUTF8StringEncoding)];
        });
    }
}
//开始接收Resource数据
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress{
    NSLog(@"开始获取文件数据");
    NSLog(@"进度：%lld",progress.completedUnitCount);
}
//完成Resource数据的接收
- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(nullable NSError *)error{
    NSLog(@"获取文件数据结束");
    NSURL *destinationURL = [NSURL fileURLWithPath:[self imagePath]];
    //判断文件是否存在，存在则删除
    if ([[NSFileManager defaultManager] isDeletableFileAtPath:[self imagePath]]) {
        [[NSFileManager defaultManager] removeItemAtPath:[self imagePath] error:nil];
    }
    //转移文件
    NSError *error1 = nil;
    if (![[NSFileManager defaultManager] moveItemAtURL:localURL toURL:destinationURL error:&error1]) {
        NSLog(@"[Error] %@", error1);
    }
    //转移成功展示数据
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSData * data = [NSData dataWithContentsOfURL:destinationURL];
        UIImage * image = [[UIImage alloc] initWithData:data];
        self.imageView.image = image;
    });
}
//接收到Stream数据流
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID{
    NSLog(@"获取流数据");
    //输入流实例化---既然有流通道伸过来了，那我也得有可以对接的通道
    self.inputStream = stream;
    self.inputStream.delegate = self;
    //有了载体，要将这个通道流通起来，就需要添加动力，即放到runloop上
    [self.inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [self.inputStream open];//打开输入流通道
}
#pragma mark - MCBrowserViewController代理方法
-(void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController{
    NSLog(@"已选择");
    [self.browserController dismissViewControllerAnimated:YES completion:nil];
}
-(void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController{
    NSLog(@"取消浏览.");
    [self.browserController dismissViewControllerAnimated:YES completion:nil];
}
- (BOOL)browserViewController:(MCBrowserViewController *)browserViewController
      shouldPresentNearbyPeer:(MCPeerID *)peerID
            withDiscoveryInfo:(nullable NSDictionary<NSString *, NSString *> *)info{
    NSLog(@"发现附近的广播");
    return YES;
}
#pragma mark -- NSStreamDelegate
/**
 *  流数据操作
 *
 *  @param aStream   流数据
 *  @param eventCode 流数据获取事件
 */
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode{
    switch (eventCode) {
        case NSStreamEventOpenCompleted:{
            NSLog(@"数据流开始");
            self.byteIndex = 0;
            self.streamData = [[NSMutableData alloc]init];
        }
            break;
        case NSStreamEventHasBytesAvailable:{
            //有数据可用
            NSInputStream *input = (NSInputStream *)aStream;
            uint8_t buffer[1024];
            NSInteger length = [input read:buffer maxLength:1024];
            NSLog(@"%ld", length);
            [self.streamData appendBytes:(const void *)buffer length:(NSUInteger)length];
            // 记住这边的数据陆陆续续的
        }
            break;
        case NSStreamEventHasSpaceAvailable:{
            //有空间可以存放
            NSData *data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:[self recordPath]]];
            NSOutputStream *output = (NSOutputStream *)aStream;
            NSUInteger len = ((data.length - self.byteIndex >= 1024) ? 1024 : (data.length-self.byteIndex));
            NSData *data1 = [data subdataWithRange:NSMakeRange(self.byteIndex, len)];
            [output write:data1.bytes maxLength:len];
            self.byteIndex += len;
        }
            break;
        case NSStreamEventEndEncountered:{
            //结束
            [aStream close];
            //操作结束后，清除流对象
            [aStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
            if([aStream isKindOfClass:[NSInputStream class]]){
//                NSFileManager *fileManager = [[NSFileManager alloc]init];
                self.imageView.image = [[UIImage alloc] initWithData:self.streamData];
//                NSLog(@"%@",[[UIImage alloc] initWithData:self.streamData]);
//                [fileManager createFileAtPath:[self recordPath] contents:self.streamData attributes:nil];
            }
            self.byteIndex = 0;
        }
            break;
        case NSStreamEventErrorOccurred:{
            //发生错误
            NSLog(@"error");
        }
            break;
        default:
            break;
    }
}
#pragma mark - UIImagePickerController代理方法
-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    UIImage *image=[info objectForKey:UIImagePickerControllerOriginalImage];
    [self.imageView setImage:image];
    //发送数据给所有已连接设备
    NSError *error=nil;
    [self.session sendData:UIImagePNGRepresentation(image) toPeers:[self.session connectedPeers] withMode:MCSessionSendDataUnreliable error:&error];
    NSLog(@"开始发送数据...");
    if (error) {
        NSLog(@"发送数据过程中发生错误，错误信息：%@",error.localizedDescription);
    }
    [self.imagePickerController dismissViewControllerAnimated:YES completion:nil];
}
-(void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [self.imagePickerController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -- 点击事件
//搜索广播
- (IBAction)searchBroadcast:(UIBarButtonItem *)sender {
    //ServiceType的值可以自定义，但是一定要和广播的相同
    _browserController = [[MCBrowserViewController alloc] initWithServiceType:@"connect" session:self.session];
    _browserController.delegate = self;
    [self presentViewController:_browserController animated:YES completion:nil];
}
//选择照片
- (IBAction)selectedPhoto:(UIBarButtonItem *)sender {
    _imagePickerController = [[UIImagePickerController alloc] init];
    _imagePickerController.delegate = self;
    [self presentViewController:_imagePickerController animated:YES completion:nil];
}
//文字传输
- (IBAction)textButtonAction:(UIButton *)sender {
    NSString * string = @"白云山上白云边，善男信女饰能仁，而我独饰九龙泉";
    NSData * data = [string dataUsingEncoding:(NSUTF8StringEncoding)];
    NSError * error = nil;
    [self.session sendData:data toPeers:[self.session connectedPeers] withMode:MCSessionSendDataUnreliable error:&error];
    NSLog(@"开始发送文字数据...");
    if (error) {
        NSLog(@"发送数据过程中发生错误，错误信息：%@",error.localizedDescription);
    }
}
//resource传输
- (IBAction)resourceButtonAction:(UIButton *)sender {
    //获取导数据的路径
    NSURL *fileURL = [NSURL fileURLWithPath:[self imagePath]];
    //发送数据给匹配的蓝牙设备，Name随意取
    [self.session sendResourceAtURL:fileURL withName:@"image_" toPeer:[self.session.connectedPeers firstObject] withCompletionHandler:^(NSError *error) {\
        if (error) {
            NSLog(@"发送源数据发生错误：%@", error);
        }
    }];
}
//stream传输
- (IBAction)streamButtonAction:(UIButton *)sender {
    NSError *error;
    self.outputStream = [self.session startStreamWithName:@"super_Stream" toPeer:[self.session.connectedPeers firstObject] error:&error];
    self.outputStream.delegate = self;
    [self.outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    if(error || !self.outputStream) {
        NSLog(@"%@", error);
    }
    else{
        [self.outputStream open];
    }
}

#pragma mark -- 私有方法
-(NSString*)recordPath{
    NSString * path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    NSString * newPath = [path stringByAppendingPathComponent:@"nothing.PNG"];
    UIImage * image = [UIImage imageNamed:@"WechatIMG2.PNG"];
    NSData * data = UIImageJPEGRepresentation(image, 0.1);
    [data writeToFile:newPath atomically:YES];
    return newPath;
}

-(NSString *)imagePath{
    NSString * path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    NSString * newPath = [path stringByAppendingPathComponent:@"nothing.PNG"];
    UIImage * image = [UIImage imageNamed:@"WechatIMG2.PNG"];
    NSData * data = UIImageJPEGRepresentation(image, 0.1);
    [data writeToFile:newPath atomically:YES];
    return newPath;
}

#pragma mark -- 懒加载





- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
