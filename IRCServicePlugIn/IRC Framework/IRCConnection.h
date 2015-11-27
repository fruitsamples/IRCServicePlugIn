/*
     File: IRCConnection.h
 Abstract: Handles the IRC connection
  Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 
 */

#import <Cocoa/Cocoa.h>
#import "IRCLineStream.h"

@protocol IRCConnectionDelegate;


@interface IRCConnection : NSObject <IRCLineStreamDelegate> {
    id<IRCConnectionDelegate> _delegate;
    IRCLineStream *_lineStream;

    NSMutableDictionary *_namesDictionary;
    NSMutableDictionary *_multiLineMessages;
    NSMutableDictionary *_channelKeys;
    NSString *_originalNickname;

    IRCConnectionState _connectionState;

    NSString *_nickname;
    NSString *_userName;
    NSString *_realName;
    NSString *_lastErrorMessage;
    NSString *_host;

    BOOL _useNickServ;
    BOOL _suppressNickServMessages;
    NSString *_nickServPassword;
    NSString *_nickServEmailAddress;
}

- (id) initWithDelegate:(id<IRCConnectionDelegate>)delegate;

- (void) connectToHost: (NSString *)host
                  port: (UInt16)port
              password: (NSString *)serverPassword;

- (void) disconnect;

- (void) sendUserTypedCommand:(NSString *)userTypedCommand encoding:(NSStringEncoding)encoding context:(NSString *)nicknameOrChannel;

- (void) sendAWAY:(NSString *)awayMessageOrNil;
- (void) sendINVITE:(NSString *)channel to:(NSString *)nickname;
- (void) sendJOIN:(NSString *)channel;
- (void) sendNICK:(NSString *)nickname;
- (void) sendPART:(NSString *)channel;
- (void) sendPRIVMSG:(NSData *)message to:(NSString *)channelOrNickname isAction:(BOOL)isAction;
- (void) sendQUIT:(NSData *)quitMessage;

- (NSStringEncoding) commandEncoding;
- (IRCConnectionState) connectionState;

- (void) setUseNickServ:(BOOL)yn;
- (BOOL) useNickServ;

- (void) setNickname:(NSString *)nick;
- (NSString *) nickname;

- (void) setNickServPassword:(NSString *)nickServPassword;
- (NSString *) nickServPassword;

- (void) setNickServEmailAddress:(NSString *)nickServEmailAddress;
- (NSString *) nickServEmailAddress;

- (void) setUserName:(NSString *)userName;
- (NSString *) userName;

- (void) setRealName:(NSString *)realName;
- (NSString *) realName;

- (void) setLastErrorMessage:(NSString *)lastErrorMessage;
- (NSString *) lastErrorMessage;

- (void) setDelegate:(id<IRCConnectionDelegate>)delegate;
- (id<IRCConnectionDelegate>) delegate;

@end


@interface IRCConnection (ForUseByIRCCommand)
- (void) sendLine:(NSData *)line;

- (void) clearInformationForChannel:(NSString *)channel;
- (void) addInformation:(NSMutableDictionary *)information forChannel:(NSString *)channel;

@end


@protocol IRCConnectionDelegate

// Console Log
- (void) connection:(IRCConnection *)connection logIncomingLine:(NSData *)line force:(BOOL)force;
- (void) connection:(IRCConnection *)connection logOutgoingLine:(NSData *)line;

- (void) connection:(IRCConnection *)connection connectionStateDidChange:(IRCConnectionState)state;

- (void) connection:(IRCConnection *)connection couldNotJoinChannel:(NSString *)channel error:(IRCError)error;

- (void) connection:(IRCConnection *)connection nick:(NSString *)nick sentMessage:(NSData *)message to:(NSString *)channelOrNickname isAction:(BOOL)isAction;
- (void) connection:(IRCConnection *)connection nick:(NSString *)nick joinedChannel:(NSString *)channel;
- (void) connection:(IRCConnection *)connection nick:(NSString *)nick partedChannel:(NSString *)channel;
- (void) connection:(IRCConnection *)connection nick:(NSString *)nick quitChannel:(NSString *)channel withMessage:(NSData *)message;
- (void) connection:(IRCConnection *)connection nick:(NSString *)nick kicked:(NSString *)target fromChannel:(NSString *)channel withMessage:(NSData *)message;
- (void) connection:(IRCConnection *)connection nick:(NSString *)nick invited:(NSString *)target toChannel:(NSString *)channel;
- (void) connection:(IRCConnection *)connection nick:(NSString *)nick changedNickTo:(NSString *)newNick;
- (void) connection:(IRCConnection *)connection postedConsoleMessage:(NSString *)content;
- (void) connection:(IRCConnection *)connection postedConsoleData:(NSData *)content;
- (void) connection:(IRCConnection *)connection postedMultiLineConsoleMessage:(NSArray *)messages;

// Channel properties
- (void) connection:(IRCConnection *)connection channel:(NSString *)channel initialProperties:(NSDictionary *)channelProperties;
- (void) connection:(IRCConnection *)connection nick:(NSString *)nick addedProperties:(NSDictionary *)channelProperties toChannel:(NSString *)channel;
- (void) connection:(IRCConnection *)connection nick:(NSString *)nick removedProperties:(NSDictionary *)channelProperties fromChannel:(NSString *)channel;


@end
