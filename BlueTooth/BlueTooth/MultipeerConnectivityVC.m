//
//  MultipeerConnectivityVC.m
//  BlueTooth
//
//  Created by DayHR on 2017/4/18.
//  Copyright © 2017年 haiqinghua. All rights reserved.
//

#import "MultipeerConnectivityVC.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>
@interface MultipeerConnectivityVC ()<MCSessionDelegate,MCAdvertiserAssistantDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate,NSStreamDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property(nonatomic,strong)MCSession * session;//会话
@property(nonatomic,strong)MCAdvertiserAssistant * advertiserAssistant;//广播助手
@property(nonatomic,strong)UIImagePickerController * imagePickerController;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property(nonatomic,strong)NSOutputStream * outputStream;//输出流
@property(nonatomic,strong)NSInputStream * inputStream;//输入流
@property(nonatomic,assign)NSInteger byteIndex;//字节下标
@property(nonatomic,strong)NSMutableData * streamData;//二进制流数据
//@property(nonatomic,strong)NSProgress * imageProcess;//图片文件传输的进度
@end

@implementation MultipeerConnectivityVC

- (void)viewDidLoad {
    [super viewDidLoad];
    //创建ID
    MCPeerID * peerID = [[MCPeerID alloc] initWithDisplayName:@"蓝牙设备1"];
    //根据ID创建会话对象
    self.session = [[MCSession alloc] initWithPeer:peerID];
    self.session.delegate =self;
    //创建广播
    //ServiceType的值可以自定义，但是一定要和发现的相同
    _advertiserAssistant = [[MCAdvertiserAssistant alloc] initWithServiceType:@"connect" discoveryInfo:nil session:self.session];
    _advertiserAssistant.delegate = self;
}
#pragma mark -- MCAdvertiserAssistantDelegate
// An invitation will be presented to the user.
- (void)advertiserAssistantWillPresentInvitation:(MCAdvertiserAssistant *)advertiserAssistant{
    NSLog(@"一个邀请将出现时");
}

// An invitation was dismissed from screen.
- (void)advertiserAssistantDidDismissInvitation:(MCAdvertiserAssistant *)advertiserAssistant{
    NSLog(@"一个邀请将从屏幕消失");
}
#pragma mark -- MCSessionDelegate
//会话对象链接状态改变
-(void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state{
    switch (state) {
        case MCSessionStateConnected:
            NSLog(@"连接成功.");
            break;
        case MCSessionStateConnecting:
            NSLog(@"正在连接...");
            break;
        default:
            NSLog(@"连接失败.");
            break;
    }
}
-(void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID{
    NSLog(@"开始接收数据...");
    if ([UIImage imageWithData:data]) {
        UIImage *image=[UIImage imageWithData:data];
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.imageView setImage:image];
        });
        //保存到相册
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    }
    if ([[NSString alloc] initWithData:data encoding:(NSUTF8StringEncoding)]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.textField.text = [[NSString alloc] initWithData:data encoding:(NSUTF8StringEncoding)];
        });
    }
}
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress{
    NSLog(@"开始获取文件数据");
    NSLog(@"进度：%lld",progress.completedUnitCount);
}
- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(nullable NSError *)error{
    NSLog(@"接收数据完成");
    NSLog(@"获取文件数据结束");
    NSURL *destinationURL = [NSURL fileURLWithPath:[self imagePath]];
    //判断文件是否存在，存在则删除
    if ([[NSFileManager defaultManager] isDeletableFileAtPath:[self imagePath]]) {
        [[NSFileManager defaultManager] removeItemAtPath:[self imagePath] error:nil];
    }
    //转移文件
    NSError *error1 = nil;
    if (![[NSFileManager defaultManager] moveItemAtURL:localURL toURL:destinationURL                            error:&error1]) {
        NSLog(@"[Error] %@", error1);
    }
    //转移成功展示数据
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSData * data = [NSData dataWithContentsOfURL:destinationURL];
        UIImage * image = [[UIImage alloc] initWithData:data];
        self.imageView.image = image;
    });
}
-(void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID{
    NSLog(@"数据流");
    self.inputStream = stream;
    self.inputStream.delegate = self;
    [self.inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [self.inputStream open];
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
        case NSStreamEventOpenCompleted:{//打开输出数据流通道或者打开输入数据流通道就会走到这一步
            NSLog(@"数据流开始");
            self.byteIndex = 0;
            self.streamData = [[NSMutableData alloc]init];
        }
            break;
        case NSStreamEventHasBytesAvailable:{//监测到输入流通道中有数据流，就把数据一点一点的拼接起来
            NSInputStream *input = (NSInputStream *)aStream;
            uint8_t buffer[1024];
            NSInteger length = [input read:buffer maxLength:1024];
            NSLog(@"%ld", length);
            [self.streamData appendBytes:(const void *)buffer length:(NSUInteger)length];
            // 记住这边的数据陆陆续续的
        }
            break;
        case NSStreamEventHasSpaceAvailable:{//监测到有内存空间可用，就把输出流通道中的流写入到内存空间
            NSData *data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:[self recordPath]]];
            NSOutputStream *output = (NSOutputStream *)aStream;
            NSUInteger len = ((data.length - self.byteIndex >= 1024) ? 1024 : (data.length-self.byteIndex));
            NSData *data1 = [data subdataWithRange:NSMakeRange(self.byteIndex, len)];
            [output write:data1.bytes maxLength:len];
            self.byteIndex += len;
        }
            break;
        case NSStreamEventEndEncountered:{//监测到输出流通道中的流数据写入内存空间完成或者输入流通道中的流数据获取完成
            [aStream close];//关闭输出流
            [aStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];//将输出流从runloop中清除
            //输入流数据拼接完成，可以直接获取数据
            if([aStream isKindOfClass:[NSInputStream class]]){
                self.imageView.image = [[UIImage alloc] initWithData:self.streamData];
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
    //获取照片并展示
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
//开始广播
- (IBAction)beginBroadcast:(UIBarButtonItem *)sender {
    [self.advertiserAssistant start];
}

//选择照片
- (IBAction)selectedPhoto:(UIBarButtonItem *)sender {
    _imagePickerController = [[UIImagePickerController alloc] init];
    _imagePickerController.delegate = self;
    [self presentViewController:_imagePickerController animated:YES completion:nil];
}
//文字传输
- (IBAction)textButtonAction:(UIButton *)sender {
    NSString * string = @"住进布达拉宫，你是雪域的王；走在拉萨街头，你是世上最美的情郎";
    NSData * data = [string dataUsingEncoding:(NSUTF8StringEncoding)];
    NSError * error = nil;
    [self.session sendData:data toPeers:[self.session connectedPeers] withMode:MCSessionSendDataUnreliable error:&error];
    NSLog(@"开始发送文字数据...");
    if (error) {
        NSLog(@"发送数据过程中发生错误，错误信息：%@",error.localizedDescription);
    }
}
//Stream数据传输
- (IBAction)streamButtonAction:(UIButton *)sender {
    NSError *error;
    //将输出流初始化，即与连接上会话的蓝牙设备进行关联----我是输出数据流通道，我要流给谁
    self.outputStream = [self.session startStreamWithName:@"superStream" toPeer:[self.session.connectedPeers firstObject] error:&error];
    self.outputStream.delegate = self;
    //将输出流放到runloop上，这一步可以理解为，输出流通道需要动力，才能动，那刚好runloop可以提供动力，
    [self.outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    if(error || !self.outputStream) {
        NSLog(@"%@", error);
    }
    else{
        //打开输出流通道
        [self.outputStream open];
    }
}
//Resource数据传输
- (IBAction)resourceButtonAction:(UIButton *)sender {
    NSURL *fileURL = [NSURL fileURLWithPath:[self imagePath]];
    [self.session sendResourceAtURL:fileURL withName:@"image" toPeer:[self.session.connectedPeers firstObject] withCompletionHandler:^(NSError *error) {\
        if (error) {
            NSLog(@"发送源数据发生错误：%@", error);
        }
    }];
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
