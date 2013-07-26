//
//  BLESerialPort.m
//  HelloBTSmart
//
//  Created by Shawn Chain on 13-7-25.
//
//

#import "BLESerialService.h"

typedef enum {
    DISCONNECTED = 0,
    CONNECTING = 1,
    CONNECTED = 2,
}BLESerialServiceState;

@interface BLESerialService()<CBCentralManagerDelegate, CBPeripheralDelegate>{
    BLESerialServiceState _state;
    int _timeout;
}
@property(strong,nonatomic,readwrite) CBUUID *serviceUUID;
@property(strong,nonatomic,readwrite) CBUUID *readWriteCharacteristicUUID;
@property(strong,nonatomic,readwrite) CBUUID *notifyCharacteristicUUID;

@property(strong,nonatomic) CBCentralManager *cbCentralManager;
@property(strong,nonatomic) CBPeripheral *cbPeripheral;
@property(strong,nonatomic) CBService *cbService;
@property(strong,nonatomic) CBCharacteristic *cbReadWriteCharacteristic;
@property(strong,nonatomic) CBCharacteristic *cbNotifyCharacteristic;

@property(strong,nonatomic) NSTimer *connectTimer;
@property(strong,nonatomic) NSTimer *disconnectTimer;
@property(strong,nonatomic) NSError *disconnectCause;

/*
 * connect complete block
 */
@property(strong,nonatomic,readwrite) BLESerialConnectCompleteBlock connectCompleteBlock;
/*
 * disconnected block
 */
@property(strong,nonatomic,readwrite) BLESerialDisconnectCompleteBlock disconnectCompleteBlock;
/*
 * data send complete block
 */
@property(strong,nonatomic,readwrite) BLESerialDataSendCompleteBlock dataSendCompleteBlock;

@end

#define DEFAULT_SERVICE_UUID @"FFC0"
#define DEFAULT_READWRITE_CHARACTERISTIC_UUID @"FFC1"
#define DEFAULT_NOTIFY_CHARACTERISTIC_UUID @"FFC2"

NSString *kBLESerialServiceErrorDomain = @"BLESerialServiceError";
const int kBLESerialServiceErrorCodeScanTimeout = 1;
const int kBLESerialServiceErrorCodeUserCancled = 2;
const int kBLESerialServiceErrorCodeNotFound = 3;
const int kBLESerialServiceErrorCodePoweredOff = 4;

@implementation BLESerialService

-(id)init{
    return [self initWithServiceUUIDString:nil readWriteCharacteristicUUIDString:nil notifyCharacteristicUUIDString:nil];
}

-(id)initWithServiceUUIDString:(NSString*)suuid readWriteCharacteristicUUIDString:cuuid notifyCharacteristicUUIDString:(NSString*)nuuid;{
    self = [super init];
    if(self){
        if(!suuid)suuid = DEFAULT_SERVICE_UUID;
        if(!cuuid)cuuid = DEFAULT_READWRITE_CHARACTERISTIC_UUID;
        if(!nuuid)nuuid = DEFAULT_NOTIFY_CHARACTERISTIC_UUID;
        self.serviceUUID = [CBUUID UUIDWithString:suuid];
        self.readWriteCharacteristicUUID = [CBUUID UUIDWithString:cuuid];
        self.notifyCharacteristicUUID = [CBUUID UUIDWithString:nuuid];
        
        // initialize the bluetooth manager instances, using main dispatch queue
        self.cbCentralManager = [[[CBCentralManager alloc] initWithDelegate:self queue:nil] autorelease];
        
        _timeout = 15;
    }
    return self;
}

-(void)dealloc{
    NSLog(@"dealloc %@",self);

#if 0
    NSAssert(_state == DISCONNECTED,@"dealloc a BLESerialSerice that state is CONNECTED, check code please!!!");
#else
    if(_state != DISCONNECTED){
        NSLog(@"WARNING - You're deallocing an CONNECTED BLESerialSerice instance, please disconnect before deallocing it");
    }
#endif

    // removing callbacks and delegates
    self.connectCompleteBlock = nil;
    self.disconnectCompleteBlock = nil;
    self.dataReceivedBlock = nil;
    self.dataSendCompleteBlock = nil;
    _cbPeripheral.delegate = nil;
    _cbCentralManager.delegate = nil;
    
    // Releasing the connected peripheral will cause the disconnect
    [self reset];
    self.cbCentralManager = nil;
    
    self.connectTimer = nil;
    self.disconnectCause = nil;
    
    self.serviceUUID =nil;
    self.readWriteCharacteristicUUID = nil;
    self.notifyCharacteristicUUID = nil;
    
    [super dealloc];
}

#pragma mark - Service APIs
-(void)connect:(BLESerialConnectCompleteBlock)completeBlock{
    if(_state != DISCONNECTED){
        // in state connecting or connected, bail out
        return;
    }
    
    _state = CONNECTING;
    self.disconnectCause = nil;
    self.connectCompleteBlock = completeBlock;
    
    //TODO timeout should to be configurable.
    self.connectTimer = [NSTimer scheduledTimerWithTimeInterval:(float)_timeout target:self selector:@selector(connectTimerRoutin:) userInfo:nil repeats:NO];
    
    [_cbCentralManager scanForPeripheralsWithServices:[NSArray arrayWithObjects:_serviceUUID, nil] options:0];
    NSLog(@"Scanning peripherals...");
}

-(void)disconnect:(BLESerialDisconnectCompleteBlock)completeBlock{
    // we assume all code runs in main thread then no race-conditions there
    self.disconnectCompleteBlock = completeBlock;
    // connecting... so just disconnect
    if(_connectTimer.isValid){
        [_connectTimer invalidate];
    }
    
    [self doDisconnect:nil];
}

-(void)send:(NSData*)data{
    if(_state != CONNECTED || data == nil || data.length == 0){
        //DISCUSS shall we invoke the callback here for the error?
        return;
    }
    
    // We're limited to send 16 bytes every time by the BLE Spec
    NSRange range =  NSMakeRange(0, 16);
    int i = 0;
    while(i < data.length){
        range.location = i;
        range.length =  data.length - i > 16?16:(data.length - i); // the actual packet length
        NSData *packet = [data subdataWithRange:range];
        [_cbPeripheral writeValue:packet forCharacteristic:_cbReadWriteCharacteristic type:CBCharacteristicWriteWithoutResponse];
        //FIXME - should be continue while send is succeed?
        i += range.length;
    }
}

#pragma mark - Internal methods
-(void) connectTimerRoutin:(NSTimer *)timer{
    NSError *cause = nil;
    if(_state != CONNECTED){
        cause = [NSError errorWithDomain:kBLESerialServiceErrorDomain code:kBLESerialServiceErrorCodeScanTimeout userInfo:nil];
    }
    NSLog(@"connect time out");
    [self doDisconnect:cause];
}

-(void) doDisconnect:(NSError*)error{
    // stop scanning if any
    [_cbCentralManager stopScan];
    
    // if not connected, just release the peripheral and bail out
    if(![_cbPeripheral isConnected]){
        [self reset];
        [self callAndClearConnectCompleteBlock:error];
    }else{
        // we're connected already!
        // disable notification if any
        if(true/*_cbNotifyCharacteristic*/){
            [_cbPeripheral setNotifyValue:NO forCharacteristic:_cbNotifyCharacteristic];
        }
        // perform disconnect
        if(error){
            self.disconnectCause = error;
        }
        [_cbCentralManager cancelPeripheralConnection:_cbPeripheral]; // will trigger the delegate method "didDisconnected"
    }
}

-(void) callAndClearConnectCompleteBlock:(NSError*)error{
    if(!_connectCompleteBlock){
        return;
    }
    //dispatch_async(dispatch_get_main_queue(),^{_connectCompleteBlock(self,error);});
    _connectCompleteBlock(self,error);
    [[_connectCompleteBlock retain] autorelease];
    self.connectCompleteBlock = nil;
}

-(void) callAndClearDisConnectCompleteBlock:(NSError*)error{
    if(!_disconnectCompleteBlock){
        return;
    }
//    dispatch_async(dispatch_get_main_queue(),^{_disconnectCompleteBlock(self,error);});
    _disconnectCompleteBlock(self,error);
    [[_disconnectCompleteBlock retain] autorelease];
    self.disconnectCompleteBlock = nil;
}

- (void) discoveryStatePoweredOff
{
    NSString *title     = @"Bluetooth Power";
    NSString *message   = @"You must turn on Bluetooth in Settings in order to use LE";
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
    [alertView release];
}

-(void) reset{
    self.cbNotifyCharacteristic = nil;
    self.cbReadWriteCharacteristic = nil;
    self.cbService = nil;
    self.cbPeripheral.delegate = nil;
    self.cbPeripheral = nil;
    _state = DISCONNECTED;
}

#pragma mark - CBCentralManager Delegates

// BT State Handler
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    static CBCentralManagerState previousState = -1;
    
	switch (_cbCentralManager.state) {
		case CBCentralManagerStatePoweredOff:
		{
            // BT is not powered on
            // connecting... so just disconnect
            if(_connectTimer.isValid){
                [_connectTimer invalidate];
            }
            NSError *error = [NSError errorWithDomain:kBLESerialServiceErrorDomain code:kBLESerialServiceErrorCodePoweredOff userInfo:nil];
            [self doDisconnect:error];
            
			// Tell user to power ON BT for functionality, but not on first run - the Framework will alert in that instance.
            if (previousState != -1) {
                [self discoveryStatePoweredOff];
            }
			break;
		}
            
		case CBCentralManagerStateUnauthorized:
		{
			/* Tell user the app is not allowed. */
			break;
		}
            
        case CBCentralManagerStateUnsupported:
		case CBCentralManagerStateUnknown:
		{
			/* Bad news, let's wait for another event. */
			break;
		}
            
		case CBCentralManagerStatePoweredOn:
		{
            //TODO - start discovery
            /*
			pendingInit = NO;
			[self loadSavedDevices];
			[centralManager retrieveConnectedPeripherals];
			[discoveryDelegate discoveryDidRefresh];
             */
            NSLog(@"Bluetooth is powered on");
			break;
		}
            
		case CBCentralManagerStateResetting:
		{
            /*
			[self clearDevices];
            [discoveryDelegate discoveryDidRefresh];
            [peripheralDelegate alarmServiceDidReset];
            
			pendingInit = YES;
             */
			break;
		}
	}
    
    previousState = _cbCentralManager.state;
}

// Peripherals found
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI{
    
    //TODO might be more peripherals that providing the serial service with same UUID?
    [_cbCentralManager stopScan];
    
    // stop scan and try to connecto
    NSLog(@"Found peripheral %@, RSSI:%@ connecting...",peripheral,RSSI);
    self.cbPeripheral = peripheral;
    
    [_cbCentralManager connectPeripheral:peripheral options:nil];
}

// Device connected
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connected to peripheral %@, discovering services",peripheral);
    
    // we're connected
    peripheral.delegate = self;
    [peripheral discoverServices: [NSArray arrayWithObjects:_serviceUUID,nil]];
}

// Device disconnected
-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"disconnected from peripheral %@, error:%@",peripheral,error);
    
    if(_state == CONNECTED){
        [self reset];
        // we're connected and service/characteristic found already
        // notify user with "disconnected" message
        //FIXME - wrap error with kBLESerialServiceError
        [self callAndClearDisConnectCompleteBlock:error];
    }else{
        [self reset];
        // not connected yet
        // notify user with "connectCompleted" message;
        //FIXME - wrap error with kBLESerialServiceError
        [self callAndClearConnectCompleteBlock:_disconnectCause?_disconnectCause:error];
    }
}

-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"failed to connect to peripheral %@: %@", peripheral, error);
    [self reset];
    //FIXME - wrap error with kBLESerialServiceError
    [self callAndClearConnectCompleteBlock:_disconnectCause?_disconnectCause:error];    
}

#pragma mark - CBPeripheral delegates
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if(error){
        // discover failed, so disconnect and bail out
        [self doDisconnect:error];
        return;
    }
    
    // find serial service
    BOOL serviceFound = NO;
    for(CBService *c in peripheral.services){
        if([c.UUID.data isEqual:_serviceUUID.data]){
            // we're hit!
            self.cbService = c;
            serviceFound = YES;
            break;
        }
    }
    if(!serviceFound){
        // no service found, disconnect and bail out
         NSError *notfoundError = [NSError errorWithDomain:kBLESerialServiceErrorDomain code:kBLESerialServiceErrorCodeNotFound userInfo:nil];
        [self doDisconnect:notfoundError];
        return;
    }
    
    // service found, discovering the chars
    [_cbPeripheral discoverCharacteristics:[NSArray arrayWithObjects:_readWriteCharacteristicUUID,_notifyCharacteristicUUID, nil] forService:_cbService];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if(error){
        // no characteristic found, disconnect and bail out
        [self doDisconnect:error];
        return;
    }
    
    // find the characters
    BOOL found1 = NO, found2 = NO;
    for(CBCharacteristic *c in service.characteristics){
        NSData *uuidData = c.UUID.data;
        if([uuidData isEqual:_readWriteCharacteristicUUID.data]){
            self.cbReadWriteCharacteristic = c;
            NSLog(@"Found characteristic for read/write: %@",c);
            found1 = YES;
            continue;
        }
        if([uuidData isEqual:_notifyCharacteristicUUID.data]){
            self.cbNotifyCharacteristic = c;
            NSLog(@"Found characteristic for data notification: %@",c);
            found2 = YES;
            continue;
        }
    }
    
    if(found1 && found2){
        // BINGO! we're connected
        _state = CONNECTED;
        // enable notify
        if(_connectTimer.isValid){
            [_connectTimer invalidate];
        }
        NSLog(@"Connected");
        [self callAndClearConnectCompleteBlock:nil];
        
        // enable data notification anyway
        if(true/*_dataReceivedBlock*/){
            [_cbPeripheral setNotifyValue:YES forCharacteristic:_cbNotifyCharacteristic];
        }
    }else{
         NSError *notfoundError = [NSError errorWithDomain:kBLESerialServiceErrorDomain code:kBLESerialServiceErrorCodeNotFound userInfo:nil];
        [self doDisconnect:notfoundError];
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"didUpdateValueForCharacteristic failed, %@",error);
        return;
    }
    
    if([characteristic.UUID.data isEqualToData:_notifyCharacteristicUUID.data]){
        // call the notification
        if(_dataReceivedBlock){
            //dispatch_async(dispatch_get_main_queue(),^{_dataReceivedBlock(self,characteristic.value);});
            _dataReceivedBlock(self,characteristic.value);
        }
    }else{
        NSLog(@"Unknow characteristic value update, %@, %@",characteristic,characteristic.value);
    }
}

// write complete callback
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"write data completed");
    if(_dataSendCompleteBlock){
        //dispatch_async(dispatch_get_main_queue(),^{_dataSendCompleteBlock(self,error);});
        _dataSendCompleteBlock(self,error);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error {
    
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error {

}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if(error){
        NSLog(@"notification state updated for characteristic %@ with error: %@",characteristic,error);
    }else{
        NSLog(@"notification state updated for characteristic %@",characteristic);
    }
}

@end
