/*
     File: IRCConnection.m
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

#import "IRCConnection.h"
#import "IRCServicePlugIn.h"

@interface IRCConnection (Internal)
    - (void) handleIncomingPRIVMSG:(NSArray *)params;

    - (void) _sendOutgoingNickServRegistration;
    - (BOOL) _handleIncomingNickServMessage:(NSData *)message;
@end

@implementation IRCConnection

- (id) initWithDelegate:(id<IRCConnectionDelegate>)delegate
{
    if ((self = [super init])) {
        [self setDelegate:delegate];
        _namesDictionary = [[NSMutableDictionary alloc] init];
        _multiLineMessages = [[NSMutableDictionary alloc] init];
        _connectionState = IRCConnectionDisconnectedState;
    }

    return self;
}

- (void) dealloc
{
    [self disconnect];

    [_channelKeys release];
    [_namesDictionary release];
    [_multiLineMessages release];
    [_originalNickname release];
    [_host release];
    
    [self setNickname:nil];
    [self setNickServPassword:nil];
    [self setNickServEmailAddress:nil];
    [self setUserName:nil];
    [self setRealName:nil];
    [self setLastErrorMessage:nil];

    [super dealloc];
}

#pragma mark -
#pragma mark LineStream Delegate

- (void) lineReceived:(NSData *)line
{
    const char *bytes = [line bytes];
    NSUInteger length = [line length];
    NSUInteger i = 0;
        
    NSMutableString *commandString  = [[NSMutableString alloc] initWithCapacity:10]; 
    NSMutableArray  *params         = [[NSMutableArray alloc]  initWithCapacity:10];
    
    // We have a prefix, store it
    if (length > 0 && bytes[0] == ':') {
        for (i = 1; i < length; i++) {
            if (bytes[i] == ' ') {
                NSData *param = [[NSData alloc] initWithBytes:(void *)(bytes + 1) length:(i - 1)];
                [params addObject:param];
                [param release];

                i++; 
                break;
            }
        }
    }
    
    // Parse commandString
    for ( ; i < length; i++) {
        const char c = bytes[i];

        if (isalnum(c)) {
            [commandString appendFormat:@"%c", c];
        } else if (bytes[i] == ' ') {
            i++; 
            break;
        }
    }
    
    
    // Parse remaining params
    BOOL isTrailingParam = NO;
    NSUInteger paramStart = i;

    for ( ; i < length; i++) {
        BOOL atEnd = (i == (length - 1));

        if (bytes[i] == ':' && !isTrailingParam) {
            isTrailingParam = YES;
            paramStart = i + 1;

        } else if ((bytes[i] == ' ' && !isTrailingParam) || atEnd) {
            if (atEnd) i++;

            NSData *param = [[NSData alloc] initWithBytes:(void *)(bytes + paramStart) length:(i - paramStart)];
            [params addObject:param];
            [param release];
            
            paramStart = i + 1;
        }
    }

    // Decide what selector to perform
    NSString *selectorAsString = [NSString stringWithFormat:@"handleIncoming%@:", commandString];
    SEL selector = NSSelectorFromString(selectorAsString);
        
    BOOL forceLog = NO;
    if ([self respondsToSelector:selector]) {
        [self performSelector:selector withObject:params];
    } else {
        forceLog = YES;
    }
    
    [_delegate connection:self logIncomingLine:line force:forceLog];

    [commandString release];
    [params release];
}

- (void) disconnected
{
    if (_connectionState != IRCConnectionDisconnectedState) {
        _connectionState = IRCConnectionDisconnectedState;
        [_delegate connection:self connectionStateDidChange:IRCConnectionDisconnectedState];
    }
}

#pragma mark -
#pragma mark Private Methods

- (NSString *) _newUserHostFromIndex:(NSUInteger)index ofParameters:(NSArray *)parameters
{
    return [[NSString alloc] initWithData:[parameters objectAtIndex:index] encoding:NSASCIIStringEncoding];
}


- (NSString *) _newNicknameFromIndex:(NSUInteger)index ofParameters:(NSArray *)parameters
{
    NSString *userHost = [self _newUserHostFromIndex:index ofParameters:parameters];
    NSString *nickname = nil;

    NSRange rangeOfBang = [userHost rangeOfString:@"!"];
    if (rangeOfBang.location != NSNotFound) {
        nickname = [[userHost substringToIndex:rangeOfBang.location] retain];
        [userHost release];
    } else {
        nickname = userHost;
    }

    return nickname;
}

- (NSString *) _newChannelFromIndex:(NSUInteger)index ofParameters:(NSArray *)parameters
{
    NSData *data = [parameters objectAtIndex:index];
    const char *bytes = [data bytes];
    
    if ([data length] > 0 && (bytes[0] == '#' || bytes[0] == '&')) {
        return [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    } 

    return nil;
}

- (NSString *) _newStringFromIndex:(NSUInteger)index ofParameters:(NSArray *)parameters
{
    return [[NSString alloc] initWithData:[parameters objectAtIndex:index] encoding:NSASCIIStringEncoding];
}

- (NSData *) _newDataFromIndex:(NSUInteger)index ofParameters:(NSArray *)parameters
{
    return [[parameters objectAtIndex:index] retain];
}

- (void) _addValue:(NSString *)value toSetOfKey:(NSString *)key inDictionary:(NSMutableDictionary *)dictionary
{
    NSMutableSet *set = [dictionary objectForKey:key];

    if (!set) {
        set = [[NSMutableSet alloc] init];
        [dictionary setObject:set forKey:key];
        [set release];
    }

    [set addObject:value];
}

#pragma mark -
#pragma mark Numeric Replies

- (void) _handleIncomingMultiLineStart:(NSString *)contentNumber withParams:(NSArray *)params
{
    [_multiLineMessages setObject:[NSMutableArray arrayWithCapacity:1] forKey:contentNumber];
}

- (void) _handleIncomingMultiLineContent:(NSString *)contentNumber atIndex:(int)index withParams:(NSArray *)params
{
    if ([params count] < index) return;
    
    NSData   *message = [self _newDataFromIndex:index ofParameters:params];
    NSMutableArray* dataArray = [_multiLineMessages objectForKey:contentNumber];
    if (!dataArray)
        [_multiLineMessages setObject:[NSMutableArray arrayWithCapacity:1] forKey:contentNumber];
    
    [dataArray addObject:message];
    [message release];
}

- (void) _handleIncomingMultiLineEnd:(NSString *)contentNumber withParams:(NSArray *)params
{
    [_delegate connection:self postedMultiLineConsoleMessage:[_multiLineMessages objectForKey:contentNumber]];
    [_multiLineMessages removeObjectForKey:contentNumber];
}

- (void) handleIncoming001:(NSArray *)params // Welcome message
{
    if (_connectionState == IRCConnectionConnectingState) {
        _connectionState = IRCConnectionConnectedState;
        [_delegate connection:self connectionStateDidChange:IRCConnectionConnectedState];
    }

    if (_useNickServ) {
        [self _sendOutgoingNickServRegistration];
    }
    
    if ([params count] > 2)
        [self setNickname:[[self _newNicknameFromIndex:1 ofParameters:params] autorelease]];
}

- (void) handleIncoming002:(NSArray *)params { } // eat this
- (void) handleIncoming003:(NSArray *)params { } // eat this
- (void) handleIncoming004:(NSArray *)params { } // eat this
- (void) handleIncoming005:(NSArray *)params { } // eat this

- (void) handleIncoming250:(NSArray *)params { } // eat this
- (void) handleIncoming251:(NSArray *)params { } // eat this
- (void) handleIncoming252:(NSArray *)params { } // eat this
- (void) handleIncoming253:(NSArray *)params { } // eat this
- (void) handleIncoming254:(NSArray *)params { } // eat this
- (void) handleIncoming255:(NSArray *)params { } // eat this
- (void) handleIncoming265:(NSArray *)params { } // eat this
- (void) handleIncoming266:(NSArray *)params { } // eat this

- (void) handleIncoming305:(NSArray *)params { } // eat this
- (void) handleIncoming306:(NSArray *)params { } // eat this

- (void) handleIncoming321:(NSArray *)params
{
    [self _handleIncomingMultiLineStart:@"322" withParams:params];
}

- (void) handleIncoming322:(NSArray *)params
{
    [self _handleIncomingMultiLineContent:@"322" atIndex:2 withParams:params];
}

- (void) handleIncoming323:(NSArray *)params
{
    [self _handleIncomingMultiLineEnd:@"322" withParams:params];
}

- (void) handleIncoming332:(NSArray *)params // RPL_TOPIC
{
    if ([params count] < 4) return;

    NSString *channel  = [self _newChannelFromIndex:2 ofParameters:params];
    NSData   *topic    = [self _newDataFromIndex:3 ofParameters:params];

    NSDictionary *channelProperties = [[NSDictionary alloc] initWithObjectsAndKeys:topic, IRCChannelTopicKey, nil];

    [_delegate connection:self channel:channel initialProperties:channelProperties];
    
    [channelProperties release];
    [topic release];
    [channel release];
}

- (void) handleIncoming353:(NSArray *)params // RPL_NAMREPLY
{
    if ([params count] < 5) return;

    NSString *channel  = [self _newChannelFromIndex:3 ofParameters:params];
    NSString *nickList = [self _newStringFromIndex:4  ofParameters:params];

    NSMutableDictionary *channelInformation = [_namesDictionary objectForKey:channel];
    
    if (!channelInformation) {
        channelInformation = [[NSMutableDictionary alloc] init];
        [_namesDictionary setObject:channelInformation forKey:channel];
        [channelInformation release];
    }
    
    NSArray *nicks = [nickList componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    for (NSString *nick in nicks) {
        if ([nick length]) {
            unichar firstCharacter = [nick characterAtIndex:0];

            if (![[NSCharacterSet letterCharacterSet] characterIsMember:firstCharacter]) {
                nick = [nick substringFromIndex:1];
                
                if (firstCharacter == IRCOperatorPrefixCharacter) {
                    [self _addValue:nick toSetOfKey:IRCChannelOperatorsKey inDictionary:channelInformation];
                } else if (firstCharacter == IRCHalfOperatorPrefixCharacter) {
                    [self _addValue:nick toSetOfKey:IRCChannelHalfOperatorsKey inDictionary:channelInformation];
                } else if (firstCharacter == IRCVoicedMemberPrefixCharacter) {
                    [self _addValue:nick toSetOfKey:IRCChannelVoicedMembersKey inDictionary:channelInformation];
                }
            }
            
            [self _addValue:nick toSetOfKey:IRCChannelAllMembersKey inDictionary:channelInformation];
        }
    }
    
    [channel release];
    [nickList release];
}

- (void) handleIncoming366:(NSArray *)params // RPL_ENDOFNAMES
{
    if ([params count] < 3) return;

    NSString *channel = [self _newChannelFromIndex:2 ofParameters:params];

    NSMutableDictionary *channelInformation = [_namesDictionary objectForKey:channel];

    if (channelInformation) {
        [_delegate connection:self channel:channel initialProperties:channelInformation];
        [_namesDictionary removeObjectForKey:channel];
    }
    
    [channel release];
}

- (void) handleIncoming375:(NSArray *)params
{
    [self _handleIncomingMultiLineStart:@"372" withParams:params];
}

- (void) handleIncoming372:(NSArray *)params
{
    [self _handleIncomingMultiLineContent:@"372" atIndex:2 withParams:params];
}

- (void) handleIncoming376:(NSArray *)params
{
    [self _handleIncomingMultiLineEnd:@"372" withParams:params];
}

- (void) handleIncoming403:(NSArray *)params // ERR_NOSUCHCHANNEL
{
    if ([params count] < 3) return;
    
    NSString *channel = [self _newStringFromIndex:2 ofParameters:params];
    [_delegate connection:self couldNotJoinChannel:channel error:IRCInvalidNameError];
    [channel release];
}

- (void) handleIncoming431:(NSArray *)params // ERR_NONICKNAMEGIVEN
{
    if (_connectionState == IRCConnectionConnectingState) {
        NSString *message = NSLocalizedStringFromTableInBundle(@"Your nickname contains invalid characters or is too long.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when an invalid nick name is specifed.");
        [self setLastErrorMessage:message];
        [self disconnect];
    }
}

- (void) handleIncoming432:(NSArray *)params // ERR_ERRONEUSNICKNAME
{
    // Treat as ERR_NONICKNAMEGIVEN
    [self handleIncoming431:params];
}

- (void) handleIncoming433:(NSArray *)params // ERR_NICKNAMEINUSE
{
    if ([params count] < 3) return;

    NSString *nick = [self _newChannelFromIndex:2 ofParameters:params];

    if (_connectionState == IRCConnectionConnectingState) {
        // Move _nickname to _originalNickname
        if (!_originalNickname) {
            _originalNickname = [_nickname retain];
        }

        [self setNickname:[[self nickname] stringByAppendingString:@"_"]];
        [self sendNICK:[self nickname]];
    }

    [nick release];
}

- (void) handleIncoming465:(NSArray *)params // ERR_YOUREBANNEDCREEP
{
    if (_connectionState == IRCConnectionConnectingState) {
        NSString *message = NSLocalizedStringFromTableInBundle(@"You are banned from this server.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when a user is banned from the server.");
        [self setLastErrorMessage:message];
        [self disconnect];
    }
}

- (void) handleIncoming471:(NSArray *)params // ERR_CHANNELISFULL
{
    if ([params count] < 3) return;

    NSString *channel = [self _newChannelFromIndex:2 ofParameters:params];
    [_delegate connection:self couldNotJoinChannel:channel error:IRCIsFullError];
    [channel release];
}

- (void) handleIncoming473:(NSArray *)params // ERR_INVITEONLYCHAN
{
    if ([params count] < 3) return;

    NSString *channel = [self _newChannelFromIndex:2 ofParameters:params];
    [_delegate connection:self couldNotJoinChannel:channel error:IRCInviteOnlyError];
    [channel release];
}

- (void) handleIncoming474:(NSArray *)params // ERR_BANNEDFROMCHAN
{
    if ([params count] < 3) return;

    NSString *channel = [self _newChannelFromIndex:2 ofParameters:params];
    [_delegate connection:self couldNotJoinChannel:channel error:IRCBannedError];
    [channel release];
}

- (void) handleIncoming475:(NSArray *)params // ERR_BADCHANNELKEY
{
    if ([params count] < 3) return;

    NSString *channel = [self _newChannelFromIndex:2 ofParameters:params];
    [_delegate connection:self couldNotJoinChannel:channel error:IRCInvalidPasswordError];
    [channel release];
}

- (void) handleIncoming479:(NSArray *)params // ERR_BADCHANNAME
{
    if ([params count] < 3) return;
    
    NSString *channel = [self _newStringFromIndex:2 ofParameters:params];
    [_delegate connection:self couldNotJoinChannel:channel error:IRCInvalidNameError];
    [channel release];
}

- (void) handleIncoming704:(NSArray *)params
{
    [self _handleIncomingMultiLineStart:@"705" withParams:params];
}

- (void) handleIncoming705:(NSArray *)params
{
    [self _handleIncomingMultiLineContent:@"705" atIndex:3 withParams:params];
}

- (void) handleIncoming706:(NSArray *)params
{
    [self _handleIncomingMultiLineEnd:@"705" withParams:params];
}

#pragma mark -
#pragma mark Command Replies

- (void) handleIncomingERROR:(NSArray *)params
{
    if ([params count] < 1)
        return;
    
    NSString *lastErrorMessage = [self _newStringFromIndex:0 ofParameters:params];
    [self setLastErrorMessage:lastErrorMessage];
    [lastErrorMessage release];
}

- (void) handleIncomingINVITE:(NSArray *)params
{
    NSString *nickname = [self _newNicknameFromIndex:0 ofParameters:params];
    NSString *target   = [self _newNicknameFromIndex:1 ofParameters:params];
    NSString *channel  = [self _newChannelFromIndex:2  ofParameters:params];

    [_delegate connection:self nick:nickname invited:target toChannel:channel];

    [channel release];
    [target release];
    [nickname release];
}

- (void) handleIncomingJOIN:(NSArray *)params
{
    if ([params count] < 2) return;

    NSString *nickname = [self _newNicknameFromIndex:0 ofParameters:params];
    NSString *channel  = [self _newChannelFromIndex:1  ofParameters:params];
    
    [_delegate connection:self nick:nickname joinedChannel:channel];

    [channel release];
    [nickname release];
}

- (void) handleIncomingKICK:(NSArray *)params
{
    if ([params count] < 3) return;

    NSString *nickname = [self _newNicknameFromIndex:0 ofParameters:params];
    NSString *channel  = [self _newChannelFromIndex:1  ofParameters:params];
    NSString *target   = [self _newNicknameFromIndex:2 ofParameters:params];
    NSData   *reason     = ([params count] >= 4 ? [self _newDataFromIndex:3 ofParameters:params] : nil);
    
    [_delegate connection:self nick:nickname kicked:target fromChannel:channel withMessage:reason];

    [reason release];
    [target release];
    [channel release];
    [nickname release];
}

- (void) handleIncomingMODE:(NSArray *)params
{
    if ([params count] < 3) return;

    NSString *nickname = [self _newNicknameFromIndex:0 ofParameters:params];
    if (!nickname) return;

    NSString *channel = [self _newChannelFromIndex:1  ofParameters:params];
    if (!channel) {
        [nickname release];
        return;
    }

    NSString *modeString = [self _newStringFromIndex:2   ofParameters:params];

    NSMutableDictionary *channelProperties = [[NSMutableDictionary alloc] init];
    NSMutableString *channelFlags    = [[NSMutableString alloc] init];
    NSMutableArray  *stringArguments = [[NSMutableArray alloc] init];

    BOOL isRemove = NO;
    BOOL isLimit  = NO;
    NSInteger limit = 0;
    NSString *keyForStringArguments = nil;
    
    for (NSUInteger i = 0; i < [modeString length]; i++) {
        unichar c = [modeString characterAtIndex:i];
    
        if (c == '-')       isRemove = YES;
        else if (c == 'l')  isLimit = YES;
        else if (c == 'b')  keyForStringArguments = IRCChannelBanMasksKey;
        else if (c == 'o')  keyForStringArguments = IRCChannelOperatorsKey;
        else if (c == 'h')  keyForStringArguments = IRCChannelHalfOperatorsKey;
        else if (c == 'v')  keyForStringArguments = IRCChannelVoicedMembersKey;
        
        else if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) {
            [channelFlags appendFormat:@"%C", c];
        }
    }
    
    for (NSUInteger i = 3; i < [params count]; i++) {
        NSString *stringArgument = [self _newStringFromIndex:i ofParameters:params];
        unichar   firstCharacter = [stringArgument length] > 0 ? [stringArgument characterAtIndex:0] : 0;
        
        // This works since IRC nicknames cannot start with a number
        if (firstCharacter >= '0' && firstCharacter <= '9') {
            limit = [stringArgument integerValue];
        } else {
            [stringArguments addObject:stringArgument];
        }
        
        [stringArgument release];
    }

    if ([channelFlags length]) {
        [channelProperties setObject:channelFlags forKey:IRCChannelFlagsKey];
    }
    
    if (isLimit) {
        [channelProperties setObject:[NSNumber numberWithInteger:limit] forKey:IRCChannelLimitKey];
    }

    if (keyForStringArguments) {
        [channelProperties setObject:stringArguments forKey:keyForStringArguments];
    }

    if (!isRemove) {
        [_delegate connection:self nick:nickname addedProperties:channelProperties toChannel:channel];
    } else {
        [_delegate connection:self nick:nickname removedProperties:channelProperties fromChannel:channel];
    }

    [channelFlags release];
    [stringArguments release];
    [channelProperties release];

    [modeString release];
    [channel release];
    [nickname release];
}

- (void) handleIncomingNOTICE:(NSArray *)params
{
    [self handleIncomingPRIVMSG:params];
}

- (void) handleIncomingNICK:(NSArray *)params
{
    if ([params count] < 2) return;

    NSString *oldNick = [self _newNicknameFromIndex:0 ofParameters:params];
    NSString *newNick = [self _newNicknameFromIndex:1 ofParameters:params];

    [_delegate connection:self nick:oldNick changedNickTo:newNick];
    [self setNickname:newNick];
    
    [newNick release];
    [oldNick release];
}

- (void) handleIncomingPART:(NSArray *)params
{
    if ([params count] < 2) return;

    NSString *nickname = [self _newNicknameFromIndex:0 ofParameters:params];
    NSString *channel  = [self _newChannelFromIndex:1  ofParameters:params];

    [_delegate connection:self nick:nickname partedChannel:channel];
    
    [channel release];
    [nickname release];
}

- (void) handleIncomingPING:(NSArray *)params
{
    if ([params count] < 1) return;

    NSMutableData *pong = [[NSMutableData alloc] init];
    [pong appendBytes:"PONG " length: 5];
    [pong appendData:[params objectAtIndex:0]];

    [self sendLine:pong];
    
    [pong release];
}

- (void) handleIncomingPRIVMSG:(NSArray *)params
{
    if ([params count] < 3) return;
    
    NSString *nick    = [self _newNicknameFromIndex:0 ofParameters:params];
    NSString *to      = [self _newStringFromIndex:1   ofParameters:params];
    NSData   *message = [self _newDataFromIndex:2     ofParameters:params];

    NSUInteger length = [message length];
    const char *b = [message bytes];

    // NickServ
    if (_suppressNickServMessages && [_nickServPassword length] && [nick rangeOfString:@"nickserv" options:(NSAnchoredSearch | NSCaseInsensitiveSearch)].location != NSNotFound) {
        // Do nothing

    // CTCP / ACTION
    } else if (length > 1 && b[0] == 1 && b[length - 1] == 1) {
        if (b[1] == 'A' && b[2] == 'C' && b[3] == 'T' && b[4] == 'I' && b[5] == 'O' && b[6] == 'N' && b[length - 1] == 1) {
            [_delegate connection:self nick:nick sentMessage:[message subdataWithRange:NSMakeRange(7, length - 8)] to:to isAction:YES];
        } else {
            // CTCP REQUEST Handler would go here.  Implementing CTCP would expose us to flooding concerns, so just
            // leave it blank for now.
            // 
            // NSString *request = [[NSString alloc] initWithBytes:(b + 1) length:(length - 2) encoding:NSASCIIStringEncoding];
            // NSLog(@"CTCP REQUEST: %@", request);
            // [request release];
        }
        
    // Normal Messages
    } else {
        [_delegate connection:self nick:nick sentMessage:message to:to isAction:NO];
    }
    
    [message release];
    [to release];
    [nick release];
}

- (void) handleIncomingTOPIC:(NSArray *)params
{
    NSString *nick    = [self _newNicknameFromIndex:0 ofParameters:params];
    NSString *channel = [self _newChannelFromIndex:1  ofParameters:params];
    NSData   *topic   = [self _newDataFromIndex:2     ofParameters:params];

    NSDictionary *channelProperties = [[NSDictionary alloc] initWithObjectsAndKeys:topic, IRCChannelTopicKey, nil];

    [_delegate connection:self nick:nick addedProperties:channelProperties toChannel:channel];

    [channelProperties release];

    [topic release];
    [channel release];
    [nick release];
}

#pragma mark -
#pragma mark Outgoing Commands

- (void) sendUserTypedCommand:(NSString *)userTypedCommand encoding:(NSStringEncoding)encoding context:(NSString *)nicknameOrChannel
{
    NSData *data = [userTypedCommand dataUsingEncoding:encoding];
    data = [data subdataWithRange:NSMakeRange(1, [data length] - 1)];
    [self sendLine:data];
}

- (void) sendAWAY:(NSString *)awayMessageOrNil
{
    if ([awayMessageOrNil length]) {
        [self sendLine:[[NSString stringWithFormat:@"AWAY :%@", awayMessageOrNil] dataUsingEncoding:[self commandEncoding]]];
    } else {
        [self sendLine:[@"AWAY" dataUsingEncoding:[self commandEncoding]]];
    }
}

- (void) sendINVITE:(NSString *)channel to:(NSString *)nickname
{
    [self sendLine:[[NSString stringWithFormat:@"INVITE %@ %@", nickname, channel] dataUsingEncoding:[self commandEncoding]]];
}

- (void) _addKey:(NSString *)key forChannel:(NSString *)channel
{
    if (!_channelKeys)
        _channelKeys = [[NSMutableDictionary alloc] initWithCapacity:1];
    
    NSMutableDictionary *keysForHost = [_channelKeys objectForKey:_host];
    if (!keysForHost)
        keysForHost = [[[NSMutableDictionary alloc] initWithCapacity:1] autorelease];
    
    [keysForHost setObject:key forKey:channel];
    [_channelKeys setObject:keysForHost forKey:_host];
    
    [[NSUserDefaults standardUserDefaults] setObject:_channelKeys forKey:@"ChannelKeys"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *) _keyForChannel:(NSString *)channel
{
    if (!_channelKeys)
        _channelKeys = [[NSUserDefaults standardUserDefaults] objectForKey:@"ChannelKeys"];
        
    return [[_channelKeys objectForKey:_host] objectForKey:channel];
}

- (void) sendJOIN:(NSString *)channel
{
    NSArray *items = [channel componentsSeparatedByString:@" "];
    if ([items count] > 1) {
        channel = [items objectAtIndex:0];
        [self _addKey:[items objectAtIndex:0] forChannel:channel];
        [_delegate connection:self postedConsoleMessage:[NSString stringWithFormat:@"Saving token for channel %@.", channel]];
    }
    
    NSString *password = [self _keyForChannel:channel];
    NSString *joinLine = [NSString stringWithFormat:@"JOIN %@", channel];
    if (password) {
        joinLine = [NSString stringWithFormat:@"%@ %@", joinLine, password];
        [_delegate connection:self postedConsoleMessage:[NSString stringWithFormat:@"Using stored token for channel %@.", channel]];
    }
    
    [self sendLine:[joinLine dataUsingEncoding:[self commandEncoding]]];
}

- (void) sendNICK:(NSString *)nickname
{
    [self sendLine:[[NSString stringWithFormat:@"NICK %@", nickname] dataUsingEncoding:[self commandEncoding]]];
}

- (void) sendPART:(NSString *)channel
{
    [self sendLine:[[NSString stringWithFormat:@"PART %@", channel] dataUsingEncoding:[self commandEncoding]]];
}

- (void) sendPRIVMSG:(NSData *)message to:(NSString *)channelOrNickname isAction:(BOOL)isAction
{ 
    NSMutableData *data = [[NSMutableData alloc] init];

    if ([channelOrNickname caseInsensitiveCompare:@"nickserv"] == NSOrderedSame) {
        _suppressNickServMessages = NO;
    }

    [data appendData:[[NSString stringWithFormat:@"PRIVMSG %@ :", channelOrNickname] dataUsingEncoding:[self commandEncoding]]];

    if (isAction) {
        [data appendBytes:"\001ACTION " length:8];
        [data appendData:message];
        [data appendBytes:"\001" length:1];
    } else {
        [data appendData:message];
    }

    [self sendLine:data];
    
    [data release];
}

- (void) sendQUIT:(NSData *)quitMessage
{
    NSMutableData *data = [[NSMutableData alloc] init];

    [data appendData:[@"QUIT :" dataUsingEncoding:[self commandEncoding]]];
    [data appendData:quitMessage];
    
    [self sendLine:data];
    
    [data release];
}

#pragma mark -
#pragma mark NickServ Support

- (void) _sendNickServCommand:(NSString *)messageFormat, ...
{
    va_list argList;
    va_start(argList, messageFormat);

    NSMutableString *lineAsString = [[NSMutableString alloc] initWithString:@"PRIVMSG NickServ :"];
    NSString *message = [[NSString alloc] initWithFormat:messageFormat arguments:argList];

    [lineAsString appendString:message];
    [self sendLine:[message dataUsingEncoding:[self commandEncoding]]];
    
    [message release];
    [lineAsString release];
     
    va_end(argList);
}

- (void) _allowNickServMessages
{
    _suppressNickServMessages = NO;
}

- (void) _sendOutgoingNickServRegistration
{
    // If we have _originalNickname, our nickname was in use
    if ([_originalNickname length]) {
        [self _sendNickServCommand:@"RECOVER %@ %@", _originalNickname, _nickServPassword];
        [self _sendNickServCommand:@"RELEASE %@ %@", _originalNickname, _nickServPassword];

        [self setNickname:_originalNickname];
        [self sendNICK:[self nickname]];

    } else {
        [self _sendNickServCommand:@"IDENTIFY %@ %@", _originalNickname, _nickServPassword];
        [self _sendNickServCommand:@"REGISTER %@ %@", _nickServPassword, _nickServEmailAddress];
    }

    [self performSelector:@selector(_allowNickServMessages) withObject:nil afterDelay:2.0];
}

#pragma mark -
#pragma mark Public Methods

- (void) connectToHost: (NSString *) host
                  port: (UInt16) port
              password: (NSString *) serverPassword
{
    [self disconnect];
    
    _lineStream = [[IRCLineStream alloc] init];
    
    [_lineStream setDelegate:self];
    [_lineStream connectToHost:host port:port security:nil];
   
    [_host release];
    _host = [host retain];

    [_originalNickname release];
    _originalNickname = nil;
    
    _suppressNickServMessages = YES;

    if ([serverPassword length]) {
        NSString *passString = [NSString stringWithFormat:@"PASS %@", serverPassword];
        [self sendLine:[passString dataUsingEncoding:[self commandEncoding]]];
    }

    [self sendNICK:[self nickname]];

    NSString *userString = [NSString stringWithFormat:@"USER %@ 0 * :%@", [self userName], [self realName]];
    [self sendLine:[userString dataUsingEncoding:[self commandEncoding]]];

    if (_connectionState != IRCConnectionConnectingState) {
        _connectionState = IRCConnectionConnectingState;
        [_delegate connection:self connectionStateDidChange:IRCConnectionConnectingState];
    }
}

- (void) disconnect
{
    [_lineStream close];
    [_lineStream release];
    _lineStream = nil;

    if (_connectionState != IRCConnectionDisconnectedState) {
        _connectionState = IRCConnectionDisconnectedState;
        [_delegate connection:self connectionStateDidChange:IRCConnectionDisconnectedState];
    }
}

- (void) sendLine:(NSData *)line
{
    [_delegate connection:self logOutgoingLine:line];
    [_lineStream sendLine:line];
}

#pragma mark -
#pragma mark Accessors

- (NSStringEncoding) commandEncoding
{
    return NSUTF8StringEncoding;
}

- (IRCConnectionState) connectionState
{
    return _connectionState;
}

- (void) setNickname:(NSString *)nickname
{
    if (nickname != _nickname) {
        [_nickname release];
        _nickname = [nickname retain];
    }
}

- (NSString *)nickname
{
    return _nickname;
}

- (void) setUseNickServ:(BOOL)yn
{
    _useNickServ = yn;
}

- (BOOL) useNickServ
{
    return _useNickServ;
}

- (void) setNickServPassword:(NSString *)nickServPassword
{
    if (nickServPassword != _nickServPassword) {
        [_nickServPassword release];
        _nickServPassword = [nickServPassword retain];
    }
}

- (NSString *) nickServPassword
{
    return _nickServPassword;
}

- (void) setNickServEmailAddress:(NSString *)nickServEmailAddress
{
    if (nickServEmailAddress != _nickServEmailAddress) {
        [_nickServEmailAddress release];
        _nickServEmailAddress = [nickServEmailAddress retain];
    }
}

- (NSString *) nickServEmailAddress
{
    return _nickServEmailAddress;
}

- (void) setUserName:(NSString *)userName
{
    if (userName != _userName) {
        [_userName release];
        _userName = [userName retain];
    }
}

- (NSString *) userName
{
    return _userName;
}

- (void) setRealName:(NSString *)realName
{
    if (realName != _realName) {
        [_realName release];
        _realName = [realName retain];
    }
}

- (NSString *) realName
{
    return _realName;
}

- (void) setLastErrorMessage:(NSString *)lastErrorMessage
{
    if (lastErrorMessage != _lastErrorMessage) {
        [_lastErrorMessage release];
        _lastErrorMessage = [lastErrorMessage retain];
    }
}

- (NSString *) lastErrorMessage
{
    return _lastErrorMessage;
}

- (void) setDelegate:(id<IRCConnectionDelegate>)delegate
{
    _delegate = delegate;
}

- (id<IRCConnectionDelegate>) delegate
{
    return _delegate;
}

@end
