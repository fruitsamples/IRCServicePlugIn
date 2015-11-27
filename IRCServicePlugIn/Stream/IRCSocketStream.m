/*
     File: IRCSocketStream.m
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

#import "IRCSocketStream.h"
#import <unistd.h>
#import <sys/time.h>
#import <netinet/in.h>

#define kMaxIncomingBufferSize 32672 // 32k

#define kSocketStreamReadEvents (  kCFStreamEventOpenCompleted \
                                   | kCFStreamEventHasBytesAvailable \
                                   | kCFStreamEventErrorOccurred \
                                   | kCFStreamEventEndEncountered )
#define kSocketStreamWriteEvents (  kCFStreamEventOpenCompleted \
                                    | kCFStreamEventCanAcceptBytes \
                                    | kCFStreamEventErrorOccurred )


@interface IRC_SocketStream (FwdRef)
- (NSError *) _finishConnecting: (BOOL)requireOut;
@end


@implementation IRC_SocketStream


static void streamCallback( void *stream, CFStreamEventType type, void *clientCallBackInfo );


- (id) init
{
    self = [super init];
    if( self ) {
    }
    return self;
}


- (void) dealloc
{
    [self disconnect];
    if( _httpResponse ) CFRelease(_httpResponse);
    [super dealloc];
} 


- (void) setConnectTimeout: (NSTimeInterval)timeout
{
    _connectTimeout = timeout;
}


- (NSError *) connectToNetService: (NSNetService *) service
{
	[service getInputStream:(NSInputStream **)&_in outputStream:(NSOutputStream **)&_out];
    return [self _finishConnecting: YES];
}

- (NSError *) connectToHost: (NSString*)host port: (UInt16)port socksSettings: (NSDictionary *) socksSettings
{
    CFStreamCreatePairWithSocketToHost( NULL, (CFStringRef)host, port, &_in, &_out );
    if( socksSettings ) {
        if( _in )  CFReadStreamSetProperty( _in, kCFStreamPropertySOCKSProxy,socksSettings);
        if( _out ) CFWriteStreamSetProperty(_out,kCFStreamPropertySOCKSProxy,socksSettings);
    }
	
    return [self _finishConnecting: YES];
}


- (NSError *) connectToSocketSignature: (CFSocketSignature *) signature securitySettings: (CFDictionaryRef) securitySettings
{
    CFStreamCreatePairWithPeerSocketSignature(NULL,signature,&_in, &_out);
    if (securitySettings) {
        if( _in )  CFReadStreamSetProperty( _in, kCFStreamPropertySSLSettings,securitySettings);
        if( _out ) CFWriteStreamSetProperty(_out,kCFStreamPropertySSLSettings,securitySettings);        
    }

    return [self _finishConnecting:YES];
}


- (NSError *) connectToHost: (NSString*)host port: (UInt16)port security: (CFStringRef) securityLevel
{
    CFStreamCreatePairWithSocketToHost( NULL, (CFStringRef)host, port, &_in, &_out );
    if( securityLevel ) {
        if( _in )  CFReadStreamSetProperty( _in, kCFStreamPropertySocketSecurityLevel,securityLevel);
        if( _out ) CFWriteStreamSetProperty(_out,kCFStreamPropertySocketSecurityLevel,securityLevel);
    }

    return [self _finishConnecting: YES];
}


- (void) negotiateSSLWithSecuritySettings:(NSDictionary *) securitySettings
{
    if( securitySettings ) {
        if( _in )  CFReadStreamSetProperty( _in, kCFStreamPropertySSLSettings,securitySettings);
        if( _out ) CFWriteStreamSetProperty(_out,kCFStreamPropertySSLSettings,securitySettings);
    }
}


- (NSError *) connectToHost: (NSString*)host port: (UInt16)port securitySettings: (CFDictionaryRef) securitySettings
{
    CFStreamCreatePairWithSocketToHost( NULL, (CFStringRef)host, port, &_in, &_out );
    if( securitySettings ) {
        if( _in )  CFReadStreamSetProperty( _in, kCFStreamPropertySSLSettings,securitySettings);
        if( _out ) CFWriteStreamSetProperty(_out,kCFStreamPropertySSLSettings,securitySettings);
    }
    
    return [self _finishConnecting: YES];
}

- (NSError *) connectToHTTPURL: (NSURL*)url method: (NSString*)method extraHeaders: (NSDictionary*)headers
{
    CFHTTPMessageRef msg = CFHTTPMessageCreateRequest(NULL,(CFStringRef)method,(CFURLRef)url,kCFHTTPVersion1_1);
    if( ! msg ) {
        return [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOTCONN userInfo:nil];
    }
    
    for (NSString *key in [headers allKeys] )
        CFHTTPMessageSetHeaderFieldValue(msg, (CFStringRef)key, (CFStringRef)[headers objectForKey: key]);

    _in = CFReadStreamCreateForHTTPRequest(NULL,msg);
    _out = NULL;
    CFRelease(msg);
    return [self _finishConnecting: NO];
}
    
    
- (NSError *) connectToSocket: (CFSocketNativeHandle)socket
{
    CFStreamCreatePairWithSocket(NULL,socket,&_in,&_out);
    CFReadStreamSetProperty(_in,kCFStreamPropertyShouldCloseNativeSocket,kCFBooleanTrue);

    return [self _finishConnecting: YES];
}

- (void) _stopConnectionTimer
{
    NSTimer *timer = _connectTimer;
    _connectTimer = nil;
    [timer invalidate];
    [timer release];
}

- (NSError *) _finishConnecting: (BOOL)requireOut
{
    if( !_in || (requireOut && !_out) ) {
        return [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOTCONN userInfo:nil];
    }
 
    memset(&_streamCallbackContext,0,sizeof(_streamCallbackContext));
    _streamCallbackContext.info = self;
    CFReadStreamSetClient(_in,
                            kSocketStreamReadEvents,
                            (CFReadStreamClientCallBack)&streamCallback,
                            &_streamCallbackContext);
    CFReadStreamScheduleWithRunLoop( _in,  CFRunLoopGetCurrent(), kCFRunLoopCommonModes);

    if( _out ) {
        CFWriteStreamSetClient(_out,
                            kSocketStreamWriteEvents,
                            (CFWriteStreamClientCallBack)&streamCallback,
                            &_streamCallbackContext);
        CFWriteStreamScheduleWithRunLoop(_out, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    }
    
    if( ! CFReadStreamOpen(_in) ) {
        NSError *error = [(NSError *)CFMakeCollectable(CFReadStreamCopyError(_in)) autorelease];
        [self disconnect];
        return error;
    }

    if( _out ) {
        if( ! CFWriteStreamOpen(_out) ) {
            NSError *error = [(NSError *)CFMakeCollectable(CFWriteStreamCopyError(_out)) autorelease];
            [self disconnect];
            return error;
        }
    }
    
    // Set a timer for detecting connection timeout:
    if( _connectTimeout > 0.0 ) {
        [self _stopConnectionTimer];
        
        _connectTimer = [[NSTimer scheduledTimerWithTimeInterval: _connectTimeout
                                                          target: self
                                                        selector: @selector(_connectTimedOut)
                                                        userInfo: NULL
                                                         repeats: NO] retain];
    }

    return nil;
}


- (void) _connectTimedOut
{
    [self retain]; // we might release ourselves when disconnect

    void *badStream = NULL;
    if( _in && !_inOpened )
        badStream = _in;
    else if( _out && !_outOpened )
        badStream = _out;
    if( badStream ) {
        NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ETIMEDOUT userInfo:nil];
        [self disconnect];
        [self errorOccurred: error onStream: _in];
    }
    
    [self _stopConnectionTimer];
    
    [self release];
}


- (void) disconnect
{
    if( _in ) {
        _inOpened = NO;
        CFReadStreamClose(_in);
        CFReadStreamSetClient(_in, kSocketStreamReadEvents, NULL,NULL);
        CFRelease(_in);
        _in = NULL;
    }
    if( _out ) {
        _outOpened = NO;
        CFWriteStreamClose(_out);
        CFWriteStreamSetClient(_out, kSocketStreamWriteEvents, NULL,NULL);
        CFRelease(_out);
        _out = NULL;
    }
    [_outBuffer release];
    _outBuffer = nil;

    if ( _readBuffer ) {
        free(_readBuffer);
        _readBuffer = NULL;
    }
    [self _stopConnectionTimer];
}


- (void) close
{
    if( [_outBuffer length] > 0 ) {
        if( ! _closing ) {
            _closing = YES;
            [self retain];
        }
    } else {
        [self disconnect];
    }
}


- (void) _finishClosing
{
    // Will be called when _closing is set and the last of the data was sent (or there was an error).
    [self disconnect];
    [self release];
}


- (CFReadStreamRef) inputStream		{return _in;}
- (CFWriteStreamRef) outputStream	{return _out;}

- (NSError *) inputError		{return [ (NSError *)CFMakeCollectable(CFReadStreamCopyError(_in))   autorelease]; }
- (NSError *) outputError		{return [ (NSError *)CFMakeCollectable(CFWriteStreamCopyError(_out)) autorelease]; }

- (BOOL) inputOpened			{return _inOpened;}
- (BOOL) outputOpened			{return _outOpened;}


- (NSString*) valueOfResponseHeader: (NSString*)headerName;	// for HTTP streams only
{
    if( ! _httpResponse )
    	_httpResponse = (CFHTTPMessageRef) CFReadStreamCopyProperty(_in,kCFStreamPropertyHTTPResponseHeader);
    if( _httpResponse ) {
        NSString *value = (id) CFHTTPMessageCopyHeaderFieldValue(_httpResponse,(CFStringRef)headerName);
        return [value autorelease];
    } else {
        return nil;
    }
}


#pragma mark -
#pragma mark HANDLING INPUT:


- (void) _errorOccurred: (void*)stream
{
    NSError *error = nil;

    if( stream == _in ) {
        error = [(NSError *)CFMakeCollectable(CFReadStreamCopyError(stream)) autorelease];
    } else {
        error = [(NSError *)CFMakeCollectable(CFWriteStreamCopyError(stream)) autorelease];
    }
        
    if( _closing )
        [self _finishClosing];
    else
        [self errorOccurred: error onStream: stream];
}

- (void) errorOccurred: (NSError *)error onStream: (void*)stream
{
}


int socketForStream(void *stream, BOOL isWriteStream) {
	if ( stream == NULL )
		return -1;
	
    unsigned int descriptor;
    CFDataRef ref;
    if (isWriteStream)
        ref = CFWriteStreamCopyProperty((CFWriteStreamRef)stream, kCFStreamPropertySocketNativeHandle);
    else 
        ref = CFReadStreamCopyProperty((CFReadStreamRef)stream, kCFStreamPropertySocketNativeHandle);        
    CFDataGetBytes (ref,CFRangeMake(0,sizeof(int)),(unsigned char *)&descriptor);
    CFRelease(ref);
    
    return descriptor;
    
}

- (void) _openCompleted: (void*)stream
{
    if( stream == _in )
        _inOpened = YES;
    else
        _outOpened = YES;
    if( _inOpened && (!_out || _outOpened) )
        [self _stopConnectionTimer];
        
    [self openCompleted: stream];
}


- (void) openCompleted: (void*)stream
{
}


- (void) dataReceived: (NSData*)data
{
}

- (void) receivedDataBytes:(NSData *)data
{
    [self receivedBytes: (unsigned char *)[data bytes] length: (unsigned int)[data length]];
    // alloced in [SocketStream dataReceived:]
    if ((--_fastReadCounter == 0) && _EOFReached) {
        [self EOFReached];
    }
}

- (void) receivedBytes: (unsigned char *) bytes length:(unsigned int) length {
}

- (void) EOFReached
{
}


- (void) _dataReceived
{
    CFIndex nBytes = 1;
    
    [self retain];	// In case subclass decides to shut down & release me in response to received data
    
    while( nBytes > 0 && _in && CFReadStreamHasBytesAvailable(_in) ) {
        UInt8* buffer = NULL;
        
        if (!_bufSz)
            _bufSz = [self incomingBufferSize];
        
        if (!_fastReadCallback) {
            if( !_readBuffer ) {
                // Try to use the stream's buffer:
                buffer = (UInt8*) CFReadStreamGetBuffer(_in,0,&nBytes);

                // Stream has no buffer, allocate one of my own.
                if( !buffer ) {
                    _bufSz = MIN(kMaxIncomingBufferSize, _bufSz);
                    _readBuffer = malloc(_bufSz);
                }
            }
            if( _readBuffer ) {
                // Stream has no buffer; read into my own:
                buffer = _readBuffer;
                nBytes = CFReadStreamRead(_in,buffer,_bufSz);
            }
        } else {
            buffer = malloc(_bufSz);
            nBytes = CFReadStreamRead(_in,buffer,_bufSz);
        }
        
        if( nBytes > 0 ) {
            // Data received:
            if (!_fastReadCallback) {
                NSData *dataReceived = [NSData dataWithBytesNoCopy: buffer length: nBytes freeWhenDone: NO];
                [self dataReceived: dataReceived];
            } else {
               	 // released in [SocketStream receivedDataBytes:]
				 NSData * data = [NSData dataWithBytesNoCopy: buffer length: nBytes freeWhenDone:YES];
                _fastReadCounter++;

                [self performSelector: @selector(receivedDataBytes:) withObject: data afterDelay: 0.0];
            }
            break;	//FIX: This should not be here, but without it we hit CFStream bug 2713341 --jpa 12/11/01
        } else if( nBytes < 0 ) {
            // Stream error!
            [self _errorOccurred: _in];
        }
    }
    
    [self release];	// Undoes the retain at the beginning
}


#pragma mark -
#pragma mark HANDLING OUTPUT:

- (int) outgoingMinimumBufferSize {
    if (_out) {
        int sz;
        unsigned int len = sizeof(sz);
        getsockopt(socketForStream(_out, YES),SOL_SOCKET,SO_SNDLOWAT,&sz,&len);
        return sz;
    }
    
    return 0;
}

- (int) incomingMinimumBufferSize {
    if (_in) {
        int sz;
        unsigned int len = sizeof(sz);
        getsockopt(socketForStream(_in, NO),SOL_SOCKET,SO_RCVLOWAT,&sz,&len);
        return sz;
    }
    
    return 0; 
}

- (int) outgoingBufferSize {
    if (_out) {
        int sz;
        unsigned int len = sizeof(sz);
        getsockopt(socketForStream(_out, YES),SOL_SOCKET,SO_SNDBUF,&sz,&len);
        return sz;
    }
    
    return 0;
}

- (int) incomingBufferSize {
    if (_in) {
        int sz;
        unsigned int len = sizeof(sz);
        getsockopt(socketForStream(_in, NO),SOL_SOCKET,SO_RCVBUF,&sz,&len);
        return sz;
    }
    
    return 0;
}

- (void) setFastReadCallback:(BOOL) set {
    _fastReadCallback = set;
}

- (void) setMinimumOutgoingBufferSize:(int) bufSz {
    if (_out) {
        unsigned int len = sizeof(bufSz);
        setsockopt(socketForStream(_out, YES),SOL_SOCKET,SO_SNDLOWAT,&bufSz,len);
    }
}

- (void) setMinimumIncomingBufferSize:(int) bufSz {
    if (_in) {
        unsigned int len = sizeof(bufSz);
        setsockopt(socketForStream(_in, NO),SOL_SOCKET,SO_RCVLOWAT,&bufSz,len);
    }
}



- (CFIndex) _writeFromBuffer
{
    CFIndex nWritten;
    NSUInteger nAvailable = [_outBuffer length];
    if( nAvailable > 0 ) {
        nWritten = CFWriteStreamWrite(_out,[_outBuffer bytes],nAvailable);
        if( nWritten == nAvailable ) {
            [_outBuffer release];
            _outBuffer = nil;
        } else if( nWritten > 0 ) {
            [_outBuffer replaceBytesInRange: NSMakeRange(0,nWritten)
                                  withBytes: NULL length: 0];
        }
    } else {
        nWritten = 0;
    }
    return nWritten;
}


- (CFIndex) writeBytes: (unsigned char *) bytes length:(CFIndex) length {
    return CFWriteStreamWrite(_out,bytes,length);
}

- (BOOL) writeData: (NSData*)data
{
    if (!_out) {
        return NO;
    }
    
    CFIndex nWritten = 0;
    NSUInteger nAvailable = [data length];
    if( nAvailable > 0 ) {
        BOOL ready = [self isReadyForData];
        BOOL buffered = [_outBuffer length] > 0;
        if( !ready || buffered ) {
            // Append data to existing buffer, or start new buffer if stream is not ready to write yet:
            if( _outBuffer )
                [_outBuffer appendData: data];
            else
                _outBuffer = [data mutableCopy];
        }
        
        if( ready ) {
            if( buffered ) {
                // Now send as much as we can of the existing buffer:
                do{
                    nWritten = [self _writeFromBuffer];
                }while( nWritten > 0 && [self isReadyForData] );
            } else {
                // or if there is no current buffer, send the data directly, and buffer whatever's left over:
                const void *bytes = [data bytes];
                nWritten = CFWriteStreamWrite(_out,bytes,nAvailable);

                if( nWritten >= 0 ) {
                    const void *bytesToAdd = (const char*)bytes + nWritten;
                    size_t length = nAvailable-nWritten;
                    if (length) {
                        if (_outBuffer) {
                            [_outBuffer appendBytes:bytesToAdd length:length];
                        } else {
                            _outBuffer = [[NSMutableData alloc] initWithBytes:bytesToAdd length:length];
                        }
                    }
                }
            }
        }
    }
    return (nWritten >= 0);
}


- (BOOL) isReadyForData
{
    return CFWriteStreamCanAcceptBytes(_out);
}

- (void) pleaseSendMoreData
{
    // subclasses can override this to provide data on demand -- should call writeData:.
}


- (void) _canAcceptBytes
{
    if( _outBuffer && [_outBuffer length] > 0 ) {
        if( [self _writeFromBuffer] < 0 )
            [self _errorOccurred: _out];
    } else if( _closing ) {
        [self _finishClosing];
    } else {
        [self pleaseSendMoreData];
    }
}

- (void) _setEOFReached:(BOOL) reached {
    _EOFReached = reached;
    if ((!_fastReadCallback || _fastReadCounter <= 0) && reached)
        [self EOFReached];
}

static void streamCallback( void *stream, CFStreamEventType type, void *clientCallBackInfo )
{
    // stream will be either a CFReadStreamRef or a CFWriteStream, either _in or _out.
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NS_DURING{
        IRC_SocketStream *self = (IRC_SocketStream*)clientCallBackInfo;
        switch( type ) {
            case kCFStreamEventOpenCompleted:
                [self _openCompleted: stream];
                break;
            case kCFStreamEventHasBytesAvailable:
                [self _dataReceived];
                break;
            case kCFStreamEventCanAcceptBytes:
                [self _canAcceptBytes];
                break;
            case kCFStreamEventErrorOccurred:
                [self _errorOccurred: stream];
                break;
            case kCFStreamEventEndEncountered:
                [self _setEOFReached:YES];
                break;
            default:
                break;
        }
    }NS_HANDLER{
    }NS_ENDHANDLER
    [pool release];
}


@end
