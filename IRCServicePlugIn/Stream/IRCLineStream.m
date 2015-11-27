/*
     File: IRCLineStream.m
 Abstract: Handles lines received from and sent to IRC connections.
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

#import "IRCLineStream.h"

@implementation IRCLineStream

- (void) dealloc
{
    [_buffer release];
    [super dealloc];
}


- (void) sendLine:(NSData *)line
{
    static NSData *sCRLF = nil;
    
    NSMutableData *outData = [[NSMutableData alloc] initWithCapacity:[line length] + 2];
    
    if (!sCRLF) {
        sCRLF = [[NSData alloc] initWithBytes:"\015\012" length:2];
    }
    
    [outData appendData:line];
    [outData appendData:sCRLF];
    
    [self writeData:outData];
    
    [outData release];
}


- (void) EOFReached
{
    [[self delegate] disconnected];
}


- (void) dataReceived:(NSData *)data
{
    if (!_buffer) {
        _buffer = [[NSMutableData alloc] init];
    }

    [_buffer appendData:data];
    
    const char *bytes = [_buffer bytes];
    NSUInteger length = [_buffer length];
    NSUInteger i = 0;
    NSUInteger lineStart = 0;
    
    for (i = 0; i < (length - 1); i++) {
        if (bytes[i]     == 0x0d &&
            bytes[i + 1] == 0x0a)
        {
            [[self delegate] lineReceived:[_buffer subdataWithRange:NSMakeRange(lineStart, i - lineStart)]];
            lineStart = (i + 2);
        }
    }
    
    if (lineStart > 0) {
        [_buffer replaceBytesInRange:NSMakeRange(0, lineStart) withBytes:NULL length:0];
    }
}


- (void) setDelegate:(id<IRCLineStreamDelegate>)delegate
{
    _delegate = delegate;
}


- (id<IRCLineStreamDelegate>) delegate
{
    return _delegate;
}



@end
