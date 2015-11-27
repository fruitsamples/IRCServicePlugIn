/*
     File: Notice.h
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

#import <Cocoa/Cocoa.h>


@interface Notices : NSObject

+ (NSAttributedString *) invitationMessage;

+ (NSString *) chatRoomTopic:(NSString *)topic;
+ (NSString *) chatRoomOperators:(NSArray *)members;
+ (NSString *) chatRoomHalfOperators:(NSArray *)members;
+ (NSString *) chatRoomVoicedMembers:(NSArray *)members;

+ (NSString *) nick:(NSString *)nick changeNickTo:(NSString *)newNick;
+ (NSString *) nick:(NSString *)nick quitChatRoomWithMessage:(NSString *)message;

+ (NSString *) nick:(NSString *)kicker kickedNick:(NSString *)target;

+ (NSString *) nick:(NSString *)nick addedChannelFlags:(NSString *)channelFlags;
+ (NSString *) nick:(NSString *)nick promotedMembersToOperator:(NSArray *)members;
+ (NSString *) nick:(NSString *)nick promotedMembersToHalfOperator:(NSArray *)members;
+ (NSString *) nick:(NSString *)nick grantedVoiceToMembers:(NSArray *)members;
+ (NSString *) nick:(NSString *)nick setChannelMemberLimit:(NSNumber *)limit;
+ (NSString *) nick:(NSString *)nick setChannelTopic:(NSString *)topic;

+ (NSString *) nick:(NSString *)nick removedChannelFlags:(NSString *)channelFlags;
+ (NSString *) nick:(NSString *)nick demotedMembersFromOperator:(NSArray *)members;
+ (NSString *) nick:(NSString *)nick demotedMembersFromHalfOperator:(NSArray *)members;
+ (NSString *) nick:(NSString *)nick revokedVoiceFromMembers:(NSArray *)members;
+ (NSString *) nickRemovedChannelMemberLimit:(NSString *)nick;

@end

@interface Errors : NSObject
+ (NSError *) errorWithMessage:(NSString *)message;
+ (NSError *) kickedFromChatRoomBy:(NSString *)kicker;

+ (NSError *) channelIsFull;
+ (NSError *) channelIsInviteOnly;
+ (NSError *) bannedFromChannel;
+ (NSError *) invalidChannelName;
+ (NSError *) invalidPassword;
+ (NSError *) couldNotJoinChannel;

@end
