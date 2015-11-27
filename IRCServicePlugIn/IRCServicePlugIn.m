/*
     File: IRCServicePlugIn.m
 Abstract: Implementation of the IRC IMServicePlugIn.
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

#import "IRCServicePlugIn.h"

#import "IRCConnection.h"
#import "MessageConverter.h"
#import "Notice.h"

#define IRCServiceDefaultsRealNameKey          @"IRCServiceDefaultsRealNameKey"
#define IRCServiceDefaultsServerPasswordKey    @"IRCServiceDefaultsServerPasswordKey"
#define IRCServiceDefaultsUseNickServ          @"IRCServiceDefaultsUseNickServ"
#define IRCServiceDefaultsDefaultEncodingKey   @"IRCServiceDefaultsDefaultEncodingKey"
#define IRCServiceDefaultsEnableConsoleKey     @"IRCServiceDefaultsDefaultEnableConsole"
#define IRCServiceDefaultsNickServEmailAddress @"IRCServiceDefaultsNickServEmailAddress"
#define IRCServiceDefaultsEnableLoggingKey     @"IRCServiceDefaultsDefaultEnableLogging"

#define IRCLOG(A, ...) { if (_isLoggingEnabled) NSLog(A, ##__VA_ARGS__); }

#pragma mark -

@implementation IRCServicePlugIn

- (id) initWithServiceApplication:(id<IMServiceApplication>)serviceApplication 
{
    if ((self = [super init])) {
        _application = [serviceApplication retain];
        
        _connection = [[IRCConnection alloc] initWithDelegate:self];

        _channelToNicksMap = [[NSMutableDictionary alloc] init];
        _nickToChannelsMap = [[NSMutableDictionary alloc] init];
        _isConsoleEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:IRCServiceDefaultsEnableConsoleKey];
        _isLoggingEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:IRCServiceDefaultsEnableLoggingKey];
    }

    return self;
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_connection setDelegate:nil];
    [_connection release];

    [_channelToNicksMap release];
    [_nickToChannelsMap release];
    
    [_consoleHandle release];

    [super dealloc];
}


#pragma mark -
#pragma mark Nickname Registry

- (void) _addItem:(id)item toSetWithKey:(id)key inMap:(NSMutableDictionary *)inMap
{
    NSMutableSet *set = [inMap objectForKey:key];

    if (!set) {
        set = [[NSMutableSet alloc] init];
        [inMap setObject:set forKey:key];
        [set release];
    }

    [set addObject:item];
}


- (void) _removeItem:(id)item fromSetWithKey:(id)key inMap:(NSMutableDictionary *)inMap isSetEmpty:(BOOL *)isSetEmpty
{
    NSMutableSet *set = [inMap objectForKey:key];

    [set removeObject:item];

    if (isSetEmpty) {
        *isSetEmpty = ([set count] == 0);
    }
}


- (void) _learnNickname:(NSString *)nickname inChannel:(NSString *)channel
{
    [self _addItem:nickname toSetWithKey:channel  inMap:_channelToNicksMap];
    [self _addItem:channel  toSetWithKey:nickname inMap:_nickToChannelsMap];
    
    NSDictionary *properties = [[NSDictionary alloc] initWithObjectsAndKeys:
        [NSNumber numberWithInt:IMHandleAvailabilityAvailable], IMHandlePropertyAvailability,
        nil];

    [_application plugInDidUpdateProperties:properties ofHandle:nickname];
        
    [properties release];
}


- (void) _forgetNickname:(NSString *)nickname inChannel:(NSString *)channel
{
    BOOL isSetEmpty = NO;
    
    [self _removeItem:nickname fromSetWithKey:channel  inMap:_channelToNicksMap isSetEmpty:NULL];
    [self _removeItem:channel  fromSetWithKey:nickname inMap:_nickToChannelsMap isSetEmpty:&isSetEmpty];

    if (isSetEmpty) {
        NSDictionary *properties = [[NSDictionary alloc] initWithObjectsAndKeys:
            [NSNumber numberWithInt:IMHandleAvailabilityUnknown], IMHandlePropertyAvailability,
            nil];

        [_application plugInDidUpdateProperties:properties ofHandle:nickname];
        
        [properties release];
    }
}


- (void) _forgetAllNicknamesInChannel:(NSString *)channel
{
    NSSet *allNicknamesInChannel = [[_channelToNicksMap objectForKey:channel] mutableCopy];
    
    for (NSString *nick in allNicknamesInChannel) {
        [self _forgetNickname:nick inChannel:channel];
    }
    
    [allNicknamesInChannel release];
}


#pragma mark -
#pragma mark Private Methods

- (void) _postConsoleMessage:(NSAttributedString *)content
{
    IMServicePlugInMessage *message = [[IMServicePlugInMessage alloc] init];
    [message setContent:content];    
    IRCLOG(@"plugInDidReceiveMessage: %@ fromHandle: %@", content, _consoleHandle);
    [_application plugInDidReceiveMessage:message fromHandle:_consoleHandle];
    [message release];
}


- (void) _toggleConsoleEnabled
{
    NSString *message = nil;

    if (_isConsoleEnabled) {
        message = NSLocalizedStringFromTableInBundle(@"Console has been disabled.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when user enables the IRC console.");
        _isConsoleEnabled = NO;

    } else {
        message = NSLocalizedStringFromTableInBundle(@"Console has been enabled.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when user enables the IRC console.");
        _isConsoleEnabled = YES;
    }
    
    [[NSUserDefaults standardUserDefaults] setBool:_isConsoleEnabled forKey:IRCServiceDefaultsEnableConsoleKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:message];
    [self _postConsoleMessage:attributedString];
    [attributedString release];
}

- (void) _toggleLoggingEnabled
{
    NSString *message = nil;
    
    if (_isLoggingEnabled) {
        message = NSLocalizedStringFromTableInBundle(@"Logging has been disabled.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when user enables the IRC console.");
        _isLoggingEnabled = NO;
        
    } else {
        message = NSLocalizedStringFromTableInBundle(@"Logging has been enabled.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when user enables the IRC console.");
        _isLoggingEnabled = YES;
    }
    
    [[NSUserDefaults standardUserDefaults] setBool:_isLoggingEnabled forKey:IRCServiceDefaultsEnableLoggingKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:message];
    [self _postConsoleMessage:attributedString];
    [attributedString release];    
}

- (void) _sendMessage:(IMServicePlugInMessage *)message toHandleOrChatRoom:(NSString *)handleOrChatRoom
{
    NSMutableAttributedString *content = [[[message content] mutableCopy] autorelease];
    NSString *contentAsString = [content string];

    if (![contentAsString length]) return;

    BOOL isAction = NO;
    BOOL isSlashCommand = NO;

    // Intercept slash commands
    //
    if ([contentAsString characterAtIndex:0] == '/') {
        isSlashCommand = YES;
        if ([contentAsString rangeOfString:@"/me " options:(NSCaseInsensitiveSearch | NSAnchoredSearch)].location == 0) {
            [content deleteCharactersInRange:NSMakeRange(0, 4)];
            isAction = YES;

        } else if ([contentAsString rangeOfString:@"/em " options:(NSCaseInsensitiveSearch | NSAnchoredSearch)].location == 0) {
            [content deleteCharactersInRange:NSMakeRange(0, 4)];
            isAction = YES;
        
        } else if ([contentAsString rangeOfString:@"/emote " options:(NSCaseInsensitiveSearch | NSAnchoredSearch)].location == 0) {
            [content deleteCharactersInRange:NSMakeRange(0, 7)];
            isAction = YES;
        
        } else if ([contentAsString rangeOfString:@"/console" options:(NSCaseInsensitiveSearch | NSAnchoredSearch)].location == 0) {
            [self _toggleConsoleEnabled];

        } else if ([contentAsString rangeOfString:@"/logging" options:(NSCaseInsensitiveSearch | NSAnchoredSearch)].location == 0) {
            [self _toggleLoggingEnabled];
            
        } else if ([[contentAsString lowercaseString] hasPrefix:@"/join "]) {
            [content deleteCharactersInRange:NSMakeRange(0, 6)];
            [_connection sendJOIN:[content string]];
        } else {
            [_connection sendUserTypedCommand:contentAsString encoding:NSUTF8StringEncoding context:nil];
        }
    } 
    
    if (!isSlashCommand || isAction) {
        // Handle normal messages
        //
        for (NSData *line in [[MessageConverter sharedInstance] linesForContent:content]) {
            if (![line length]) continue;
            [_connection sendPRIVMSG:line to:handleOrChatRoom isAction:isAction];
        }
    }
}


- (void) _sendBuddyList
{
    // IRC has no real concept of a buddy list.  We could implement one locally, and then try to use
    // ISON polling to detect when members came online/went offline.  However, this might spam the 
    // server for large buddy lists and ban the client.
    //
    // Fake a buddy list with one user, our Console.
    //
    NSArray  *handles     = [[NSArray alloc] initWithObjects:_consoleHandle, nil];
    NSNumber *permissions = [[NSNumber alloc] initWithInt:IMGroupListCanReorderGroup];
    
    NSDictionary *defaultGroup = [[NSDictionary alloc] initWithObjectsAndKeys: 
        IMGroupListDefaultGroup, IMGroupListNameKey,
        handles, IMGroupListHandlesKey, 
        permissions, IMGroupListPermissionsKey,
        nil];

    NSArray *groups = [[NSArray alloc] initWithObjects:defaultGroup, nil];
    [_application plugInDidUpdateGroupList:groups error:nil];
    [groups release];
    
    [defaultGroup release];
    [permissions release];
    [handles release];
    
    
    // Now update the Console to give it a friendlier name, picture, and a green gem.
    //
    NSMutableDictionary *consoleProperties = [[NSMutableDictionary alloc] init];

    [consoleProperties setObject:[NSNumber numberWithInt:IMHandleAvailabilityAvailable] forKey:IMHandlePropertyAvailability];
    [consoleProperties setObject:[_accountSettings objectForKey:IMAccountSettingServerHost] forKey:IMHandlePropertyAlias];
    [consoleProperties setObject:[NSArray arrayWithObject:IMHandleCapabilityMessaging] forKey:IMHandlePropertyCapabilities];
    [consoleProperties setObject:_consoleHandle forKey:IMHandlePropertyPictureIdentifier];

    IRCLOG(@"plugInDidUpdateProperties: %@", consoleProperties);
    [_application plugInDidUpdateProperties:consoleProperties ofHandle:_consoleHandle];
    
    [consoleProperties release];
}


#pragma mark -
#pragma mark IMServicePlugIn Delegate


#pragma mark -
#pragma mark IMServicePlugIn

- (oneway void) login
{
    IRCLOG(@"login");
    IRCConnectionState connectionState = [_connection connectionState];
    
    if (connectionState == IRCConnectionConnectedState) {
        return;
    }

    [_channelToNicksMap removeAllObjects];
    [_nickToChannelsMap removeAllObjects];

    NSString *serverHost = [_accountSettings objectForKey:IMAccountSettingServerHost];

    // Clear console state
    [_consoleHandle release];
    _consoleHandle = [[NSString alloc] initWithFormat:@"+console@%@", [serverHost lowercaseString]];

    // Set up Nickname, User Name, and Real Name
    [_connection setNickname:[_accountSettings objectForKey:IMAccountSettingLoginHandle]];
    [_connection setUserName:@"irc"];
    [_connection setRealName:@"irc"];

    // Set up NickServ options
    [_connection connectToHost: serverHost
                          port: [[_accountSettings objectForKey:IMAccountSettingServerPort] unsignedShortValue]
                      password: nil];
}


- (oneway void) logout
{
    IRCLOG(@"logout");
    NSString *quitMessage = NSLocalizedStringFromTableInBundle(@"Disconnecting", @"IRCLocalizable", [NSBundle mainBundle], @"Message sent when disconnecting from IRC.");

    [_connection setLastErrorMessage:nil];
    [_connection sendQUIT:[quitMessage dataUsingEncoding:NSUTF8StringEncoding]];
    [_connection disconnect];
}


- (oneway void) updateAccountSettings:(NSDictionary *)accountSettings
{
    IRCLOG(@"updateAccountSettings: %@", accountSettings);
    [_accountSettings release];
    _accountSettings = [accountSettings retain];
}


#pragma mark -
#pragma mark IMServiceApplicationGroupListSupport

- (oneway void) updateSessionProperties:(NSDictionary *)properties
{
    IRCLOG(@"updateSessionProperties: %@", properties);
    IMSessionAvailability availability = [[properties objectForKey:IMSessionPropertyAvailability] intValue];
    NSString *awayMessage = [properties objectForKey:IMSessionPropertyStatusMessage];
    
    if (availability == IMSessionAvailabilityAvailable) {
        [_connection sendAWAY:nil];
    } else if (availability == IMSessionAvailabilityAway) {
        [_connection sendAWAY:([awayMessage length] ? awayMessage : @"Away")];
    }
}


- (oneway void) requestGroupList
{
    IRCLOG(@"requestGroupList")
    // No real buddy list support, just send back the list containing the console user
    [self _sendBuddyList];
}


#pragma mark -
#pragma mark IMServicePlugInInstantMessagingSupport

- (oneway void) userDidStartTypingToHandle:(NSString *)handle
{
    // No way to represent this on IRC
}


- (oneway void) userDidStopTypingToHandle:(NSString *)handle
{
    // No way to represent this on IRC
}


- (oneway void) sendMessage:(IMServicePlugInMessage *)message toHandle:(NSString *)handle
{
    IRCLOG(@"sendMessage: %@ toHandle: %@", message, handle);
    [self _sendMessage:message toHandleOrChatRoom:handle];
    [_application plugInDidSendMessage:message toHandle:handle error:nil];
}


#pragma mark -
#pragma mark IMServicePlugInChatRoomSupport

- (oneway void) joinChatRoom:(NSString *)roomName
{
    IRCLOG(@"joinChatRoom: %@", roomName);
    // If we think we're already in the chat room, tell the app we joined it.
    if ([_channelToNicksMap objectForKey:roomName]) {
        IRCLOG(@"found %@ in _channelToNicksMap: %@", roomName, _channelToNicksMap);
        [_application plugInDidJoinChatRoom:roomName];
    } else {
        [_connection sendJOIN:roomName];
    }
}


- (oneway void) leaveChatRoom:(NSString *)roomName
{
    IRCLOG(@"leaveChatRoom: %@", roomName);
    [self _forgetAllNicknamesInChannel:roomName];
    [_channelToNicksMap removeObjectForKey:roomName];
    [_connection sendPART:roomName];
}


- (oneway void) inviteHandles:(NSArray *)handles toChatRoom:(NSString *)roomName withMessage:(IMServicePlugInMessage *)message 
{ 
    for (NSString *handle in handles) {
        [_connection sendINVITE:roomName to:handle];
    }
}


- (oneway void) sendMessage:(IMServicePlugInMessage *)message toChatRoom:(NSString *)roomName
{
    [self _sendMessage:message toHandleOrChatRoom:roomName];
    IRCLOG(@"sendMessage: %@ toHandleOrChatRoom: %@", [message content], roomName);
    [_application plugInDidReceiveMessage:message forChatRoom:roomName fromHandle:[_connection nickname]];
}


- (oneway void) declineChatRoomInvitation:(NSString *)roomName
{
    // There is no decline reply to an IRC INVITE
}


#pragma mark -
#pragma mark IRCConnection -> IMServiceApplication

- (void) connection:(IRCConnection *)connection connectionStateDidChange:(IRCConnectionState)state
{
    if (state == IRCConnectionConnectingState) {

    } else if (state == IRCConnectionConnectedState) {
        [_application plugInDidLogIn];
        [self _sendBuddyList];

    } else if (state == IRCConnectionDisconnectedState) {
        NSError *error = nil;
        NSString *lastErrorMessage = [_connection lastErrorMessage];
        if (lastErrorMessage)
            error = [Errors errorWithMessage:lastErrorMessage];
        [_application plugInDidLogOutWithError:error reconnect:NO];
    }
}


- (void) connection:(IRCConnection *)connection couldNotJoinChannel:(NSString *)channel error:(IRCError)ircError
{
    IRCLOG(@"couldNotJoinChannel: %@", channel);
    NSError *error = nil;
    
    if (ircError == IRCIsFullError) {
        error = [Errors channelIsFull];
    } else if (ircError == IRCInviteOnlyError) {
        error = [Errors channelIsInviteOnly];
    } else if (ircError == IRCBannedError) {
        error = [Errors bannedFromChannel];
    } else if (ircError == IRCInvalidNameError) {
        error = [Errors invalidChannelName];
    } else if (ircError == IRCInvalidPasswordError) {
        error = [Errors invalidPassword];
    } else {
        error = [Errors couldNotJoinChannel];
    }

    [_application plugInDidLeaveChatRoom:channel error:error];
    [self _forgetAllNicknamesInChannel:channel];
    [_channelToNicksMap removeObjectForKey:channel];
}


- (void) connection:(IRCConnection *)connection logIncomingLine:(NSData *)line force:(BOOL)force
{
    if (_isConsoleEnabled || force) {
        NSAttributedString *content = [[MessageConverter sharedInstance] contentForIncomingConsoleMessage:line];
        [self _postConsoleMessage:content];
    }
}


- (void) connection:(IRCConnection *)connection logOutgoingLine:(NSData *)line
{
    if (_isConsoleEnabled) {
        NSAttributedString *content = [[MessageConverter sharedInstance] contentForOutgoingConsoleMessage:line];
        [self _postConsoleMessage:content];
    }
}


- (void) connection:(IRCConnection *)connection nick:(NSString *)nick sentMessage:(NSData *)messageAsData to:(NSString *)channelOrNickname isAction:(BOOL)isAction
{
    IMServicePlugInMessage *message = [[IMServicePlugInMessage alloc] init];
    NSAttributedString *content = [[MessageConverter sharedInstance] contentForLine:messageAsData];
    
    // If the message came from the server, make it show up as from console
    if ([nick isEqualToString:[_accountSettings objectForKey:IMAccountSettingServerHost]])
        nick = _consoleHandle;
        
    [message setContent:content];

    if ([channelOrNickname isEqualToString:[_connection nickname]] || ![channelOrNickname hasPrefix:@"#"]) {
        IRCLOG(@"plugInDidReceiveMessage: %@ fromHandle: %@", content, nick);
        [_application plugInDidReceiveMessage:message fromHandle:nick];
    } else {
        IRCLOG(@"plugInDidReceiveMessage: %@ forChatRoom: %@ fromHandle: %@", content, channelOrNickname, nick);
        [_application plugInDidReceiveMessage:message forChatRoom:channelOrNickname fromHandle:nick];
    }

    [message release];
}


- (void) connection:(IRCConnection *)connection nick:(NSString *)nick joinedChannel:(NSString *)channel
{
    if ([nick isEqualToString:[_connection nickname]]) {
        IRCLOG(@"plugInDidJoinChatRoom: %@", channel);
        [_application plugInDidJoinChatRoom:channel];
    } else {
        IRCLOG(@"handle: %@ didJoinChatRoom: %@", nick, channel);
        [_application handles:[NSArray arrayWithObject:nick] didJoinChatRoom:channel];
        [self _learnNickname:nick inChannel:channel];
    }
}


- (void) connection:(IRCConnection *)connection nick:(NSString *)nick partedChannel:(NSString *)channel
{
    IRCLOG(@"partedChannel: %@ nick: %@", channel, nick);
    if ([nick isEqualToString:[_connection nickname]]) {
        [_application plugInDidLeaveChatRoom:channel error:nil];
        [self _forgetAllNicknamesInChannel:channel];
        [_channelToNicksMap removeObjectForKey:channel];
    } else {
        [_application handles:[NSArray arrayWithObject:nick] didLeaveChatRoom:channel];
        [self _forgetNickname:nick inChannel:channel];
    }
}


- (void) connection:(IRCConnection *)connection nick:(NSString *)nick quitChannel:(NSString *)channel withMessage:(NSData *)messageAsData
{
    NSAttributedString *message = [[MessageConverter sharedInstance] contentForLine:messageAsData];

    IRCLOG(@"quitChannel: %@ nick: %@ withMessage: %@", channel, nick, message);

    if ([message length]) {
        [_application plugInDidReceiveNotice:[Notices nick:nick quitChatRoomWithMessage:[message string]] forChatRoom:channel];
    }

    [_application handles:[NSArray arrayWithObject:nick] didLeaveChatRoom:channel];
    [self _forgetNickname:nick inChannel:channel];
}


- (void) connection:(IRCConnection *)connection nick:(NSString *)nick kicked:(NSString *)target fromChannel:(NSString *)channel withMessage:(NSData *)messageAsData
{
    IRCLOG(@"kicked: %@ fromChannel: %@ nick: %@ withMessage: %@", target, channel, nick, messageAsData);
    if ([target isEqualToString:[_connection nickname]]) {
        NSError *error = [Errors kickedFromChatRoomBy:nick];
        [_application plugInDidLeaveChatRoom:channel error:error];
        [self _forgetAllNicknamesInChannel:channel];
        [_channelToNicksMap removeObjectForKey:channel];
    } else {
        [_application plugInDidReceiveNotice:[Notices nick:nick kickedNick:target] forChatRoom:channel];
        [_application handles:[NSArray arrayWithObject:nick] didLeaveChatRoom:channel];
        [self _forgetNickname:nick inChannel:channel];
    }
}


- (void) connection:(IRCConnection *)connection nick:(NSString *)nick invited:(NSString *)target toChannel:(NSString *)channel;
{
    if ([target isEqualToString:[_connection nickname]]) {
        IMServicePlugInMessage *message = [[IMServicePlugInMessage alloc] init];
        [message setContent:[Notices invitationMessage]];
        IRCLOG(@"plugInDidReceiveInvitation: forChatRoom: %@ fromHandle: %@", channel, nick);
        [_application plugInDidReceiveInvitation:message forChatRoom:channel fromHandle:nick];
        [message release];
    }
}


- (void) connection:(IRCConnection *)connection nick:(NSString *)nick changedNickTo:(NSString *)newNick
{
    for (NSString *channel in [_nickToChannelsMap objectForKey:nick]) {
		[_application handles:[NSArray arrayWithObject:nick] didLeaveChatRoom:channel];
		[_application plugInDidReceiveNotice:[Notices nick:nick changeNickTo:newNick] forChatRoom:channel];
		[_application handles:[NSArray arrayWithObject:newNick] didJoinChatRoom:channel];
    }
}


- (void) connection:(IRCConnection *)connection channel:(NSString *)channel initialProperties:(NSDictionary *)channelProperties;
{
    IRCLOG(@"channel: %@ initialProperties: %@", channel, channelProperties);
    NSSet *allMembers = [channelProperties objectForKey:IRCChannelAllMembersKey];
    if ([allMembers count]) {
        [_application handles:[allMembers allObjects] didJoinChatRoom:channel];
        
        for (NSString *member in allMembers) {
            [self _learnNickname:member inChannel:channel];
        }
    }

    NSData *topicData = [channelProperties objectForKey:IRCChannelTopicKey];
    NSString *topic = [[[MessageConverter sharedInstance] contentForLine:topicData] string];
    if ([topic length]) [_application plugInDidReceiveNotice:[Notices chatRoomTopic:topic] forChatRoom:channel];

    NSArray *operators = [[channelProperties objectForKey:IRCChannelOperatorsKey] allObjects];
    if ([operators count]) [_application plugInDidReceiveNotice:[Notices chatRoomOperators:operators] forChatRoom:channel];

    NSArray *halfOperators = [[channelProperties objectForKey:IRCChannelHalfOperatorsKey] allObjects];
    if ([halfOperators count]) [_application plugInDidReceiveNotice:[Notices chatRoomHalfOperators:halfOperators] forChatRoom:channel];

    NSArray *voicedMembers = [[channelProperties objectForKey:IRCChannelVoicedMembersKey] allObjects];
    if ([voicedMembers count]) [_application plugInDidReceiveNotice:[Notices chatRoomVoicedMembers:voicedMembers] forChatRoom:channel];
}


- (void) connection:(IRCConnection *)connection nick:(NSString *)nick addedProperties:(NSDictionary *)channelProperties toChannel:(NSString *)channel
{
    IRCLOG(@"nick: %@ addedProperties: %@ toChannel: %@", nick, channelProperties, channel);
    NSString *channelFlags = [channelProperties objectForKey:IRCChannelFlagsKey];

    if ([channelFlags length]) {
        [_application plugInDidReceiveNotice:[Notices nick:nick addedChannelFlags:channelFlags] forChatRoom:channel];
    }

    // Post operator additions
    NSArray *operators = [channelProperties objectForKey:IRCChannelOperatorsKey];
    
    if ([operators count]) {
        [_application plugInDidReceiveNotice:[Notices nick:nick promotedMembersToOperator:operators] forChatRoom:channel];
    }

    // Post half-operator additions
    NSArray *halfOperators = [channelProperties objectForKey:IRCChannelHalfOperatorsKey];

    if ([halfOperators count]) {
        [_application plugInDidReceiveNotice:[Notices nick:nick promotedMembersToHalfOperator:halfOperators] forChatRoom:channel];
    }

    // Post voice additions
    NSArray *voicedMembers = [channelProperties objectForKey:IRCChannelVoicedMembersKey];

    if ([voicedMembers count]) {
        [_application plugInDidReceiveNotice:[Notices nick:nick grantedVoiceToMembers:voicedMembers] forChatRoom:channel];
    }


    // Post limit addition
    //
    NSNumber *limit = [channelProperties objectForKey:IRCChannelLimitKey];

    if (limit) {
        [_application plugInDidReceiveNotice:[Notices nick:nick setChannelMemberLimit:limit] forChatRoom:channel];
    }

    // Post topic changes
    NSData   *topicData = [channelProperties objectForKey:IRCChannelTopicKey];
    NSString *topic     = [[[MessageConverter sharedInstance] contentForLine:topicData] string];

    if ([topic length]) {
        [_application plugInDidReceiveNotice:[Notices nick:nick setChannelTopic:topic] forChatRoom:channel];
    }
}


- (void) connection:(IRCConnection *)connection nick:(NSString *)nick removedProperties:(NSDictionary *)channelProperties fromChannel:(NSString *)channel
{
    // Post channel flag removals
    NSString *channelFlags = [channelProperties objectForKey:IRCChannelFlagsKey];

    if ([channelFlags length]) {
        [_application plugInDidReceiveNotice:[Notices nick:nick removedChannelFlags:channelFlags] forChatRoom:channel];
    }
    
    // Post operator removals
    NSArray *operators = [channelProperties objectForKey:IRCChannelOperatorsKey];
    
    if ([operators count]) {
        [_application  plugInDidReceiveNotice:[Notices nick:nick demotedMembersFromOperator:operators] forChatRoom:channel];
    }
    
    // Post half-operator removals
    NSArray *halfOperators = [channelProperties objectForKey:IRCChannelHalfOperatorsKey];
    
    if ([halfOperators count]) {
        [_application plugInDidReceiveNotice:[Notices nick:nick demotedMembersFromHalfOperator:halfOperators] forChatRoom:channel];
    }

    // Post voice removals
    NSArray *voicedMembers = [channelProperties objectForKey:IRCChannelVoicedMembersKey];

    if ([voicedMembers count]) {
        [_application plugInDidReceiveNotice:[Notices nick:nick revokedVoiceFromMembers:voicedMembers] forChatRoom:channel];
    }

    // Post limit removal
    NSNumber *limit = [channelProperties objectForKey:IRCChannelLimitKey];
    
    if (limit) {
        [_application plugInDidReceiveNotice:[Notices nickRemovedChannelMemberLimit:nick] forChatRoom:channel];
    }
}

- (void) connection:(IRCConnection *)connection postedConsoleData:(NSData *)content;
{
    NSAttributedString *messageContent = [[MessageConverter sharedInstance] contentForLine:content];
    [self _postConsoleMessage:messageContent];
}

- (void) connection:(IRCConnection *)connection postedConsoleMessage:(NSString *)content;
{
    NSAttributedString *messageContent = [[NSAttributedString alloc] initWithString:content];
    [self _postConsoleMessage:messageContent];
    [messageContent release];
}

- (void) connection:(IRCConnection *)connection postedMultiLineConsoleMessage:(NSArray *)messages
{
    static NSAttributedString *sNewLineString = nil;
    if (!sNewLineString)
        sNewLineString = [[NSAttributedString alloc] initWithString:@"\n"];
    NSMutableAttributedString *messageContent = [[NSMutableAttributedString alloc] init];
    BOOL firstMessage = YES;
    for (NSData *message in messages) {
        if (!firstMessage)
            [messageContent appendAttributedString:sNewLineString];
        
        [messageContent appendAttributedString:[[MessageConverter sharedInstance] contentForLine:message]];
        firstMessage = NO;
    }
    [self _postConsoleMessage:messageContent];
    [messageContent release];
}

- (oneway void) requestPictureForHandle:(NSString *)handle withIdentifier:(NSString *)identifier
{
    IRCLOG(@"requestPictureForHandle: %@ withIdentifier: %@", handle, identifier);
    if ([handle isEqualToString:_consoleHandle]) {
        NSMutableDictionary *consoleProperties = [[NSMutableDictionary alloc] init];
        NSString *consoleIconPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Console" ofType:@"tiff"];
        NSData   *consoleIconData = [[NSData alloc] initWithContentsOfFile:consoleIconPath];
        [consoleProperties setObject:consoleIconData forKey:IMHandlePropertyPictureData];
        [consoleProperties setObject:identifier forKey:IMHandlePropertyPictureIdentifier];
        
        [_application plugInDidUpdateProperties:consoleProperties ofHandle:_consoleHandle];
        [consoleIconData release];
        [consoleProperties release];
    }
    
}

@end

