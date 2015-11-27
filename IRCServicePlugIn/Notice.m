/*
     File: Notice.m
 Abstract: Handles friendly display of notices.
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

#import "Notice.h"
#import "IRCConnection.h"


@implementation Notices


#pragma mark -
#pragma mark Private Methods

+ (NSString *) _localizedNameOfChannelFlag:(unichar)channelFlag
{
    if (channelFlag == IRCChannelFlagPrivateCharacter) {
        return NSLocalizedStringFromTableInBundle(@"Private", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Title of chat room setting +p (private channel flag)");
    } else if (channelFlag == IRCChannelFlagSecretCharacter) {
        return NSLocalizedStringFromTableInBundle(@"Secret", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Title of chat room setting +s (secret channel flag)");
    } else if (channelFlag == IRCChannelFlagInviteOnlyCharacter) {
        return NSLocalizedStringFromTableInBundle(@"Invite only", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Title of chat room setting +i (invite-only channel flag)");
    } else if (channelFlag == IRCChannelFlagLockedTopicCharacter) {
        return NSLocalizedStringFromTableInBundle(@"Locked topic", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Title of chat room setting +t (topic settable by channel operator only flag)");
    } else if (channelFlag == IRCChannelFlagNoExternalMessagesCharacter) {
        return NSLocalizedStringFromTableInBundle(@"No External Messages", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Title of chat room setting +n (no messages to channel from clients on the outside)");
    } else if (channelFlag == IRCChannelFlagModeratedCharacter) {
        return NSLocalizedStringFromTableInBundle(@"Moderated", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Title of chat room setting +m (moderated channel)");
    }

    return nil;
}


+ (NSArray *) _localizedNameArrayOfChannelFlags:(NSString *)channelFlagString
{
    NSUInteger length = [channelFlagString length];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:length];

    for (NSUInteger i = 0; i < length; i++) {
        unichar c = [channelFlagString characterAtIndex:i];
        NSString *localizedName = [self _localizedNameOfChannelFlag:c];
        if (localizedName) [array addObject:localizedName];
    }

    return array;
}


+ (NSString *) _stringForMembersArray:(NSArray *)members
{
    return [members componentsJoinedByString:@", "];
}


#pragma mark -
#pragma mark Localized Strings

+ (NSAttributedString *) invitationMessage
{
    NSString *string = NSLocalizedStringFromTableInBundle(@"Please join me in this chat room.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Invitation message when invited to a chat room.");
    return [[[NSAttributedString alloc] initWithString:string] autorelease];
}


+ (NSString *) chatRoomTopic:(NSString *)topic
{
    NSString *noticeFormat = NSLocalizedStringFromTableInBundle(@"Chat room topic: \"%@\"", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message for initial topic.");
    return [NSString stringWithFormat:noticeFormat, topic];
}


+ (NSString *) chatRoomOperators:(NSArray *)members
{
    NSString *membersString = [self _stringForMembersArray:members];
    NSString *noticeFormat = NSLocalizedStringFromTableInBundle(@"Chat room operators: %@", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message for initial operators.");
    return [NSString stringWithFormat:noticeFormat, membersString];
}


+ (NSString *) chatRoomHalfOperators:(NSArray *)members
{
    NSString *membersString = [self _stringForMembersArray:members];
    NSString *noticeFormat = NSLocalizedStringFromTableInBundle(@"Chat room half-operators: %@", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message for initial half-operators.");
    return [NSString stringWithFormat:noticeFormat, membersString];
}


+ (NSString *) chatRoomVoicedMembers:(NSArray *)members
{
    NSString *membersString = [self _stringForMembersArray:members];
    NSString *noticeFormat = NSLocalizedStringFromTableInBundle(@"Chat room voiced members: %@", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message for initial voiced members.");
    return [NSString stringWithFormat:noticeFormat, membersString];
}


+ (NSString *) nick:(NSString *)nick changeNickTo:(NSString *)newNick
{
	NSString *noticeFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has changed nickname to %2$@.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom changes nickname.");
    return [NSString stringWithFormat:noticeFormat, nick, newNick];
}


+ (NSString *) nick:(NSString *)nick quitChatRoomWithMessage:(NSString *)message
{
    NSString *noticeFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has quit the chat room (%2$@).", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom quits the chat server.");
    return [NSString stringWithFormat:noticeFormat, nick, message];
}


+ (NSString *) nick:(NSString *)kicker kickedNick:(NSString *)target
{
    NSString *noticeFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has kicked %2$@ from the chat room.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom removes another member from the chat room.");
    return [NSString stringWithFormat:noticeFormat, kicker, target];
}


+ (NSString *) nick:(NSString *)nick addedChannelFlags:(NSString *)channelFlags
{
    NSArray *localizedNames = [self _localizedNameArrayOfChannelFlags:channelFlags];
    NSString *noticeFormat = nil;

    if ([localizedNames count] > 1) { 
        noticeFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has added the chat room settings: %2$@", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom adds multiple channel settings.");
    } else if ([localizedNames count] == 1) {
        noticeFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has added the chat room setting: %2$@", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom adds a channel setting.");
    }

    return [NSString stringWithFormat:noticeFormat, nick, [localizedNames componentsJoinedByString:@", "]];
}


+ (NSString *) nick:(NSString *)nick promotedMembersToOperator:(NSArray *)members
{
    NSString *membersString = [self _stringForMembersArray:members];
    NSString *noticeFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has promoted %2$@ to a chat room operator", @"IRCLocalizable.", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom promotes another member to +o (operator).");
    return [NSString stringWithFormat:noticeFormat, nick, membersString];
}


+ (NSString *) nick:(NSString *)nick promotedMembersToHalfOperator:(NSArray *)members
{
    NSString *membersString = [self _stringForMembersArray:members];
    NSString *noticeFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has promoted %2$@ to a chat room half-operator", @"IRCLocalizable.", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom promotes another member to +h (half-operator).");
    return [NSString stringWithFormat:noticeFormat, nick, membersString];
}

+ (NSString *) nick:(NSString *)nick grantedVoiceToMembers:(NSArray *)members
{
    NSString *membersString = [self _stringForMembersArray:members];
    NSString *noticeFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has granted voice to %2$@", @"IRCLocalizable.", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom promotes another member to +v (voiced).");
    return [NSString stringWithFormat:noticeFormat, nick, membersString];
}


+ (NSString *) nick:(NSString *)nick setChannelMemberLimit:(NSNumber *)limit;
{
    NSString *noticeFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has set the chat room member limit to %2$@.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom removes the channel member limit.");
    return [NSString stringWithFormat:noticeFormat, nick, limit];
}


+ (NSString *) nick:(NSString *)nick setChannelTopic:(NSString *)topic
{
    NSString *noticeFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has changed the chat room topic to \"%2$@\".", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom changes the chat room topic.");
    return [NSString stringWithFormat:noticeFormat, nick, topic];
}



+ (NSString *) nick:(NSString *)nick removedChannelFlags:(NSString *)channelFlags
{
    NSArray *localizedNames = [self _localizedNameArrayOfChannelFlags:channelFlags];
    NSString *noticeFormat = nil;

    if ([localizedNames count] > 1) { 
        noticeFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has removed the chat room settings: %2$@", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom removes multiple channel settings.");
    } else if ([localizedNames count] == 1) {
        noticeFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has removed the chat room setting: %2$@", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom removes a channel setting.");
    }

    return [NSString stringWithFormat:noticeFormat, nick, [localizedNames componentsJoinedByString:@", "]];
}


+ (NSString *) nick:(NSString *)nick demotedMembersFromOperator:(NSArray *)members
{
    NSString *membersString = [self _stringForMembersArray:members];
    NSString *noticeFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has demoted %2$@ as a chat room operator.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom demotes another member to -o (no longer operator).");
    return [NSString stringWithFormat:noticeFormat, nick, membersString];
}


+ (NSString *) nick:(NSString *)nick demotedMembersFromHalfOperator:(NSArray *)members
{
    NSString *membersString = [self _stringForMembersArray:members];
    NSString *noticeFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has demoted %2$@ as a chat room half-operator.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom demotes another member to -h (no longer half-operator).");
    return [NSString stringWithFormat:noticeFormat, nick, membersString];
}


+ (NSString *) nick:(NSString *)nick revokedVoiceFromMembers:(NSArray *)members
{
    NSString *membersString = [self _stringForMembersArray:members];
    NSString *noticeFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has revoked voice from %2$@.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom demotes another member to -v (no longer voiced).");
    return [NSString stringWithFormat:noticeFormat, nick, membersString];
}


+ (NSString *) nickRemovedChannelMemberLimit:(NSString *)nick
{
    NSString *noticeFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has removed the chat room member limit.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom removes the channel member limit.");
    return [NSString stringWithFormat:noticeFormat, nick];
}


@end


@implementation Errors

#pragma mark -
#pragma mark Localized Errors

+ (NSError *) errorWithMessage:(NSString *)localizedDescription
{
    NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
        localizedDescription, NSLocalizedDescriptionKey,
        nil];

    NSError *error = [NSError errorWithDomain:@"IRCServicePlugInErrorDomain" code:-1 userInfo:userInfo];
    
    [userInfo release];
    
    return error;
}


+ (NSError *) kickedFromChatRoomBy:(NSString *)kicker
{
    NSString *stringFormat = NSLocalizedStringFromTableInBundle(@"%1$@ has kicked you from the chat room.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Message when a member of a chatroom removes you.");
    NSString *string = [NSString stringWithFormat:stringFormat, kicker];
    return [self errorWithMessage:string];
}


+ (NSError *) channelIsFull
{
    NSString *string = NSLocalizedStringFromTableInBundle(@"Could not join the chat room because it is full.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Join error - the chat room is full.");
    return [self errorWithMessage:string];
}


+ (NSError *) channelIsInviteOnly
{
    NSString *string = NSLocalizedStringFromTableInBundle(@"Could not join the chat room because an invitation is required.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Join error - the chat room requires an invitation.");
    return [self errorWithMessage:string];
}


+ (NSError *) bannedFromChannel
{
    NSString *string = NSLocalizedStringFromTableInBundle(@"Could not join the chat room because you are banned.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Join error - user is banned.");
    return [self errorWithMessage:string];
}


+ (NSError *) invalidChannelName
{
    NSString *string = NSLocalizedStringFromTableInBundle(@"Could not join the chat room because the room name is invalid.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Join error - invalid name.");
    return [self errorWithMessage:string];
}


+ (NSError *) invalidPassword
{
    NSString *string = NSLocalizedStringFromTableInBundle(@"Could not join the chat room because the password is invalid.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Join error - invalid password.");
    return [self errorWithMessage:string];
}


+ (NSError *) couldNotJoinChannel
{
    NSString *string = NSLocalizedStringFromTableInBundle(@"Could not join the chat room.", @"IRCLocalizable", [NSBundle bundleForClass: [self class]], @"Join error - generic error.");
    return [self errorWithMessage:string];
}


@end





