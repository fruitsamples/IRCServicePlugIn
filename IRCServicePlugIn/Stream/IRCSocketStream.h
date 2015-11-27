/*
     File: IRCSocketStream.h
 Abstract: Handles data sent and received from a socket.
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

#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>

@interface IRC_SocketStream : NSObject
{
    @private
    CFReadStreamRef _in;
    CFWriteStreamRef _out;
    CFStreamClientContext _streamCallbackContext;
    unsigned char *_readBuffer;
    NSMutableData *_outBuffer;
    BOOL _inOpened, _outOpened;
    BOOL _closing;			// close has been called; waiting to send rest of data before actual close/dealloc
    CFHTTPMessageRef _httpResponse;
    NSTimeInterval _connectTimeout;
    NSTimer *_connectTimer;
    int _bufSz;
    BOOL _fastReadCallback;
    
    BOOL _EOFReached;
    int _fastReadCounter;
}

- (id) init;				// normal initializer

- (void) setConnectTimeout: (NSTimeInterval)timeout;

- (NSError *) connectToHost: (NSString*)host
                       port: (UInt16)port
                   security: (CFStringRef)securityLevel;	// nil, kCFStreamSocketSecurityLevelSSLv2, etc.
- (NSError *) connectToHost: (NSString*)host
                       port: (UInt16)port
           securitySettings: (CFDictionaryRef) securitySettings; // nil, kCFStreamPropertySSLSettings dictionary
- (NSError *) connectToHost: (NSString*)host
                       port: (UInt16)port
              socksSettings: (NSDictionary *) socksSettings;
- (NSError *) connectToHTTPURL: (NSURL*)url
                        method: (NSString*)method
                  extraHeaders: (NSDictionary*)headers;
- (NSError *) connectToSocket: (CFSocketNativeHandle)socket;
- (NSError *) connectToNetService: (NSNetService *) service;
- (NSError *) connectToSocketSignature: (CFSocketSignature *) signature
                      securitySettings: (CFDictionaryRef) securitySettings;

- (void) close;		// Polite close; will send rest of buffered output data before disconnecting
- (void) disconnect;	// Abrupt, immediate disconnect

- (int) outgoingBufferSize;
- (int) incomingBufferSize;
- (int) outgoingMinimumBufferSize;
- (int) incomingMinimumBufferSize;
- (void) setMinimumOutgoingBufferSize:(int) bufSz;
- (void) setMinimumIncomingBufferSize:(int) bufSz;
- (void) setFastReadCallback:(BOOL) set; // if this is set to YES, data callbacks are sent through -[SocketStream receivedBytes:length:]

- (CFReadStreamRef) inputStream;
- (CFWriteStreamRef) outputStream;
- (void) negotiateSSLWithSecuritySettings:(NSDictionary *) settings;

- (NSString*) valueOfResponseHeader: (NSString*)headerName;	// for HTTP streams only

- (BOOL) inputOpened;
- (BOOL) outputOpened;

- (NSError *) inputError;
- (NSError *) outputError;


/** Called when an error occurs asynchronously on either the input or the output stream.
    It is NOT called in response to an error that occurs during a writeData: call that you make; check the return value instead. */
- (void) errorOccurred: (NSError *)err onStream: (void*)stream;	// stream == inputStream or outputStream

- (void) openCompleted: (void*)stream;
- (void) EOFReached;

- (void) dataReceived: (NSData*)data;
- (void) receivedBytes:(unsigned char *) bytes length:(unsigned int) length; // used if fastReadCallback is set to yes -- doesn't create NSData buffers


/** The high-level method to write data to the output stream. 
    Guaranteed not to block: any data that can't currently be written to the stream will go into a queue to be written later.
    If you use this method, you shouldn't use immediateWriteBytes.
    Returns NO if there was an error writing the data. */
- (BOOL) writeData: (NSData*)data;

// this method does not buffer and returns the amount that was written
- (CFIndex) writeBytes: (unsigned char *) bytes length:(CFIndex) length;

/** Returns YES if the output stream is ready to send data without blocking. */
- (BOOL) isReadyForData;

/** Called when the output stream indicates it's ready to send more data without blocking,
    and there is no more previously buffered data to send.
    You can override this and call writeData: to provide data on demand. */
- (void) pleaseSendMoreData;

@end
