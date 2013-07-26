//
//  BLESerialPort.h
//
//  A simple wrapper class that simplify the BlueTooth/Serial Operations
//
//  Created by Shawn Chain on 13-7-25.
//
//  Copyright shawn.chain@gmail.com 2013
//
//  Released under GPL license
//  www.gnu.org/licenses/gpl.html‎
//
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

/*
 * error code
 */
extern NSString *kBLESerialServiceErrorDomain;
extern int const kBLESerialServiceErrorCodeTimeout;
extern int const kBLESerialServiceErrorCodeUserCancled;
extern int const kBLESerialServiceErrorCodeNotFound;
extern int const kBLESerialServiceErrorCodePoweredOff;


@class BLESerialService;

/*
 * callback block definitions
 */
typedef void (^BLESerialConnectCompleteBlock)(BLESerialService *service, NSError *error);
typedef void (^BLESerialDataSendCompleteBlock)(BLESerialService *service, NSError *error);
typedef void (^BLESerialDisconnectCompleteBlock)(BLESerialService *service, NSError *error);
typedef void (^BLESerialDataReceivedBlock)(BLESerialService *service, NSData *data);


#pragma mark - BLESerialService
@interface BLESerialService : NSObject

/*
 * data received block
 */
@property(strong,nonatomic,readwrite) BLESerialDataReceivedBlock dataReceivedBlock;

/*
 * init service instance with specific UUIDs
 */
-(id)initWithServiceUUIDString:(NSString*)suuid readWriteCharacteristicUUIDString:(NSString*)cuuid notifyCharacteristicUUIDString:(NSString*)nuuid;

/*
 * connect to the bt/serial pass-through service
 */
-(void)connect:(BLESerialConnectCompleteBlock)completeBlock;

/*
 * disconnect from the bt/serial pass-through service
 */
-(void)disconnect:(BLESerialDisconnectCompleteBlock)completeBlock;

/*
 * send data to the end
 */
-(void)send:(NSData*)data;
@end
