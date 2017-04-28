//
//  CoreBluetoothVC.m
//  BlueTooth
//
//  Created by DayHR on 2017/4/18.
//  Copyright © 2017年 haiqinghua. All rights reserved.
//

#import "CoreBluetoothVC.h"
#import <CoreBluetooth/CoreBluetooth.h>
#define kPeripheralName @"xiangzuhua Device" //外围设备名称
#define kServiceUUID @"C4FB2349-72FE-4CA2-94D6-1F3CB16331EE" //服务的UUID
#define kCharacteristicUUID @"6A3E4B28-522D-4B3B-82A9-D5E2004534FC" //特征的UUID
@interface CoreBluetoothVC ()<CBPeripheralManagerDelegate>
@property (weak, nonatomic) IBOutlet UITextView *logTextView;
@property(nonatomic,strong)CBPeripheralManager * peripheralManager;//外围设备管理器
@property(strong,nonatomic)NSMutableArray * centralM;//订阅此外围设备特征的中心设备
@property(nonatomic,strong)CBMutableCharacteristic * characterristicM;//特征

@end

@implementation CoreBluetoothVC

- (void)viewDidLoad {
    [super viewDidLoad];
}
//启动按钮
- (IBAction)startAction:(UIBarButtonItem *)sender {
    //创建外围设备
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
}
//更新特征
- (IBAction)updata:(UIBarButtonItem *)sender {
    [self updateCharacteristicValue];
}
#pragma mark - CBPeripheralManager代理方法
//外围设备状态发生变化后调用
-(void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral{
    switch (peripheral.state) {
        case CBPeripheralManagerStatePoweredOn:
            NSLog(@"BLE已打开.");
            [self writeToLog:@"BLE已打开."];
            //添加服务
            [self setupService];
            break;
        default:
            NSLog(@"此设备不支持BLE或未打开蓝牙功能，无法作为外围设备.");
            [self writeToLog:@"此设备不支持BLE或未打开蓝牙功能，无法作为外围设备."];
            break;
    }
}
//外围设备添加服务后调用
-(void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error{
    if (error) {
        NSLog(@"向外围设备添加服务失败，错误详情：%@",error.localizedDescription);
        [self writeToLog:[NSString stringWithFormat:@"向外围设备添加服务失败，错误详情：%@",error.localizedDescription]];
        return;
    }
    //添加服务后开始广播
    NSDictionary *dic=@{CBAdvertisementDataLocalNameKey:kPeripheralName};//广播设置
    [self.peripheralManager startAdvertising:dic];//开始广播
    NSLog(@"向外围设备添加了服务并开始广播...");
    [self writeToLog:@"向外围设备添加了服务并开始广播..."];
}
//启动广播的结果
-(void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error{
    if (error) {
        NSLog(@"启动广播过程中发生错误，错误信息：%@",error.localizedDescription);
        [self writeToLog:[NSString stringWithFormat:@"启动广播过程中发生错误，错误信息：%@",error.localizedDescription]];
        return;
    }
    NSLog(@"启动广播...");
    [self writeToLog:@"启动广播..."];
}
//有中心设备订阅特征
-(void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic{
    NSLog(@"中心设备：%@ 已订阅特征：%@.",central,characteristic);
    [self writeToLog:[NSString stringWithFormat:@"中心设备：%@ 已订阅特征：%@.",central.identifier.UUIDString,characteristic.UUID]];
    //发现中心设备并存储
    if (![self.centralM containsObject:central]) {
        [self.centralM addObject:central];
    }
    /*中心设备订阅成功后外围设备可以更新特征值发送到中心设备,一旦更新特征值将会触发中心设备的代理方法：
     -(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
     */
}
//中心设备取消订阅特征
-(void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic{
    NSLog(@"didUnsubscribeFromCharacteristic");
}

//接受写请求
-(void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(CBATTRequest *)request{
    NSLog(@"didReceiveWriteRequests");
}
//将恢复状态
-(void)peripheralManager:(CBPeripheralManager *)peripheral willRestoreState:(NSDictionary *)dict{
    NSLog(@"willRestoreState");
}

#pragma mark -- 私有方法
//更新特征值
-(void)updateCharacteristicValue{
    //特征值
    NSString *valueStr=[NSString stringWithFormat:@"%@ --%@",kPeripheralName,[NSDate   date]];
    NSData *value=[valueStr dataUsingEncoding:NSUTF8StringEncoding];
    //更新特征值
    [self.peripheralManager updateValue:value forCharacteristic:self.characterristicM onSubscribedCentrals:nil];
    [self writeToLog:[NSString stringWithFormat:@"更新特征值：%@",valueStr]];
}
//创建特征、服务并添加服务到外围设备
-(void)setupService{
    /*1.创建特征*/
    //创建特征的UUID对象
    CBUUID *characteristicUUID=[CBUUID UUIDWithString:kCharacteristicUUID];
    //特征值
    NSString *valueStr=kPeripheralName;
    NSData *value=[valueStr dataUsingEncoding:NSUTF8StringEncoding];
    //创建特征
    /** 参数
     * uuid:特征标识
     * properties:特征的属性，例如：可通知、可写、可读等
     * value:特征值
     * permissions:特征的权限
     */
    CBMutableCharacteristic *characteristicM=[[CBMutableCharacteristic alloc]initWithType:characteristicUUID properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
    self.characterristicM=characteristicM;
    //characteristicM.value=value;
    
    /*2.创建服务并且设置特征*/
    //创建服务UUID对象
    CBUUID *serviceUUID=[CBUUID UUIDWithString:kServiceUUID];
    //创建服务
    CBMutableService *serviceM=[[CBMutableService alloc]initWithType:serviceUUID primary:YES];
    //设置服务的特征
    [serviceM setCharacteristics:@[characteristicM]];
    /*3.将服务添加到外围设备*/
    [self.peripheralManager addService:serviceM];
}
//记录日志
-(void)writeToLog:(NSString *)info{
    self.logTextView.text=[NSString stringWithFormat:@"%@\r\n%@",self.logTextView.text,info];
}

#pragma mark -懒加载
-(NSMutableArray *)centralM{
    if (!_centralM) {
        _centralM=[NSMutableArray array];
    }
    return _centralM;
}

@end
