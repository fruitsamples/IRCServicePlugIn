/*
     File: MessageConverter.m
 Abstract: Converts line data into NSAttributedString content.
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

#import "MessageConverter.h"

static struct { double r; double g; double b; } sIRCColors[16] = {
    { 1.0, 1.0, 1.0  },    // 0 - White
    { 0.0, 0.0, 0.0  },    // 1 - Black
    { 0.0, 0.0, 0.5  },    // 2 - Blue
    { 0.0, 0.5, 0.0  },    // 3 - Green
    { 1.0, 0.0, 0.0  },    // 4 - Red
    { 0.5, 0.0, 0.25 },    // 5 - Maroon
    { 0.5, 0.0, 0.5  },    // 6 - Purple
    { 1.0, 0.5, 0.25 },    // 7 - Orange
    { 1.0, 1.0, 0.0  },    // 8 - Bright Yellow
    { 0.5, 1.0, 0.0  },    // 9 - Bright Green
    { 0.0, 0.5, 0.5  },    // 10 - Cyan
    { 0.0, 1.0, 1.0  },    // 11 - Bright Cyan
    { 0.0, 0.0, 1.0  },    // 12 - Bright Blue
    { 1.0, 0.0, 1.0  },    // 13 - Bright Purple
    { 0.5, 0.5, 0.5  },    // 14 - 50% Grey
    { 0.75,0.75,0.75 },    // 15 - 75% Grey
};
typedef NSInteger IRCColor;


@implementation MessageConverter

+ (id) sharedInstance
{
    static id sharedInstance = nil;
    if (!sharedInstance) sharedInstance = [[MessageConverter alloc] init];
    return sharedInstance;
}


#pragma mark -
#pragma mark Color Conversion

- (NSString *) componentsForColor:(IRCColor)color
{
    if (color >= 0 && color < 16) {
        int r = sIRCColors[color].r * 255;
        int g = sIRCColors[color].g * 255;
        int b = sIRCColors[color].b * 255;
        
        return [NSString stringWithFormat:@"#%2.2X%2.2X%2.2X",r,g,b];
    }
    
    return nil;
}



static BOOL sParseHTMLColor(NSString *aString, double *red, double *green, double *blue)
{
    NSUInteger length = [aString lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
    char *buffer = (char *)alloca(length);    
	
    if (buffer) {
        unsigned int r, g, b;
        float a;
        double divisor = 0.0;
		
        [aString getCString:buffer maxLength:length encoding:NSUTF8StringEncoding];
		
        if (sscanf(buffer," #%2x%2x%2x", &r, &g, &b) == 3) {
            divisor = 255.0;
			
        } else if (sscanf(buffer," %2x%2x%2x", &r, &g, &b) == 3) {
            divisor = 255.0;
			
        } else if (sscanf(buffer," #%1x%1x%1x", &r, &g, &b) == 3) {
            divisor = 15.0;
			
        } else if (sscanf(buffer," %1x%1x%1x", &r, &g, &b) == 3) {
            divisor = 15.0;
			
        } else if (sscanf(buffer, " rgb ( %d , %d , %d )", &r, &g, &b) == 3) {
            divisor = 255.0;
			
        } else if (sscanf(buffer, " rgba ( %d , %d , %d , %f )", &r, &g, &b, &a) == 4) {
            divisor = 255.0;
        }
        
        if (divisor > 0.0) {
            *red   = ((double)r / divisor);
            *green = ((double)g / divisor);
            *blue  = ((double)b / divisor);
            
            return YES;
        }
    }
    
    return NO;
}


- (IRCColor) colorForComponents:(NSString *)components
{
    if (!components) return -1;

	IRCColor result = 0;
	double r, g, b;
	
	if( sParseHTMLColor(components, &r, &g, &b) )
    {
		double shortestDistance = DBL_MAX;

		for (NSInteger i = 0; i < 16; i++) {
			double distance = sqrt(pow(r - sIRCColors[i].r, 2) + pow(g - sIRCColors[i].g, 2) + pow(b - sIRCColors[i].b, 2));
			if (distance < shortestDistance) {
				shortestDistance = distance;
				result = i;
			}
		}
	}
	
    return result;
}


#pragma mark -
#pragma mark Message Conversion

- (NSAttributedString *) contentForLine:(NSData *)line
{
    if (!line) return nil;

    const UInt8 *bytes = (const UInt8 *)[line bytes];
    __block NSUInteger index = 0;
    UInt8 c;

    NSMutableAttributedString *content    = [[NSMutableAttributedString alloc] init];
    NSMutableDictionary       *attributes = [[NSMutableDictionary alloc] init];
    NSMutableString           *buffer     = [[NSMutableString alloc] init];

    void (^Flush)() = ^{
        NSRange range = NSMakeRange([content length], [buffer length]);

        [content replaceCharactersInRange:NSMakeRange([content length], 0) withString:buffer];
        [content setAttributes:attributes range:range];

        [buffer deleteCharactersInRange:NSMakeRange(0, [buffer length])];
    };

    UInt8 (^Peek)() = ^{
        return bytes[index];
    };
    
    UInt8 (^Shift)() = ^{
        return bytes[index++]; 
    };

    while ((c = Shift())) {
        if (c == 002) {         // Go Bold
            Flush();

            [attributes setObject:[NSNumber numberWithBool:YES] forKey:IMAttributeBold];

        } else if (c == 026) {  // Go Italic
            Flush();

            [attributes setObject:[NSNumber numberWithBool:YES] forKey:IMAttributeItalic];

        } else if (c == 037) {  // Go Underline
            Flush();

            [attributes setObject:[NSNumber numberWithBool:YES] forKey:IMAttributeUnderline];

        } else if (c == 017) {  // Reset bold/italic/underline state
            Flush();

            [attributes removeObjectForKey:IMAttributeBold];
            [attributes removeObjectForKey:IMAttributeItalic];
            [attributes removeObjectForKey:IMAttributeUnderline];
            [attributes removeObjectForKey:IMAttributeForegroundColor];
            [attributes removeObjectForKey:IMAttributeBackgroundColor];

        } else if (c == 003) {  // Incoming color
            Flush();

            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

            char foregroundBuffer[3];
            char backgroundBuffer[3];
            
            long foreground = 0;
            long background = 0;
            
            foregroundBuffer[0] = (char)Shift();
            
            if ((foregroundBuffer[0] == '0' || foregroundBuffer[0] == '1') && isnumber(Peek())) {
                foregroundBuffer[1] = (char)Shift();
                foregroundBuffer[2] = 0;
            } else {
                foregroundBuffer[1] = 0;
            }            
            
            foreground = strtol(foregroundBuffer, NULL, 10);

            [attributes setObject:[self componentsForColor:foreground] forKey:IMAttributeForegroundColor];
            
            if (Peek() == ',') {
                Shift(); // Get rid of ','

                backgroundBuffer[0] = (char)Shift();

                if ((backgroundBuffer[0] == '1' || backgroundBuffer[0] == '0')  && isnumber(Peek())) {
                    backgroundBuffer[1] = (char)Shift();
                    backgroundBuffer[2] = 0;
                } else {
                    backgroundBuffer[1] = 0;
                }            
                
                background = strtol(backgroundBuffer, NULL, 10);
                [attributes setObject:[self componentsForColor:background] forKey:IMAttributeBackgroundColor];
                
            } else {
                [attributes removeObjectForKey:IMAttributeBackgroundColor];
            }

            [pool release];

        } else {
            [buffer appendFormat:@"%C", c];
        }
    }

    Flush();

    [buffer release];
    [attributes release];

    return [content autorelease];
}


- (NSArray *) linesForContent:(NSAttributedString *)content
{
    if (!content) return nil;

    __block BOOL wasBold      = NO;
    __block BOOL wasItalic    = NO;
    __block BOOL wasUnderline = NO;
    __block BOOL wasColored   = NO;

    __block NSMutableData  *outputLine  = [NSMutableData data];
    __block NSMutableArray *outputLines = [NSMutableArray arrayWithObject:outputLine];

    [content enumerateAttributesInRange: NSMakeRange(0, [content length])
                                options: NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                             usingBlock: ^(NSDictionary *attributes, NSRange range, BOOL *stop)
    {
        NSString *substring = [[content string] substringWithRange:range];

        NSString *foregroundComponents = [attributes objectForKey:IMAttributeForegroundColor];
        NSString *backgroundComponents = [attributes objectForKey:IMAttributeBackgroundColor];

        NSInteger background = [self colorForComponents:backgroundComponents];
        NSInteger foreground = [self colorForComponents:foregroundComponents];

        if (background < 0) background = 0; // Default colors, 0 (black) for background
        if (foreground < 0) foreground = 1; // and 1 (white) for foreground

        BOOL isItalic    = [[attributes objectForKey:IMAttributeItalic]    boolValue];
        BOOL isBold      = [[attributes objectForKey:IMAttributeBold]      boolValue];
        BOOL isUnderline = [[attributes objectForKey:IMAttributeUnderline] boolValue];
        BOOL isColored   = (background || foreground);

        BOOL isAdditionalLine = NO;
        for (NSString *inputLine in [substring componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {    

            if (isAdditionalLine) {
                wasBold = wasItalic = wasUnderline = wasColored = NO;
            }

            if ((wasBold      && !isBold)      ||
                (wasItalic    && !isItalic)    ||
                (wasUnderline && !isUnderline) ||
                (wasColored   && !isColored))
            {
                [outputLine appendBytes:"\017" length:1];
                wasBold = wasItalic = wasUnderline = wasColored = NO;
            }
            
            if (isBold && !wasBold) {
                [outputLine appendBytes:"\002" length:1];
            }
            
            if (isItalic && !wasItalic) {
                [outputLine appendBytes:"\026" length:1];
            } 
            
            if (isUnderline && !wasUnderline) {
                [outputLine appendBytes:"\037" length:1];
            }
            
            if (isColored) {
                char outBuffer[10];
                if (background) {
                    snprintf(outBuffer, 10, "\003%02d,%02d", (int)foreground, (int)background);
                } else {
                    snprintf(outBuffer, 10, "\003%02d", (int)foreground);
                }

                [outputLine appendBytes:outBuffer length:strlen(outBuffer)];
            }
            
            [outputLine appendData:[inputLine dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES]];

            if (isAdditionalLine) {
                outputLine = [NSMutableData data];
                [outputLines addObject:outputLine];
            } else {
                isAdditionalLine = YES;
            }
        }
        
        wasBold      = isBold;
        wasItalic    = isItalic;
        wasUnderline = isUnderline;
        wasColored   = isColored;
    }];


    return outputLines;
}


- (NSAttributedString *) _contentForConsoleMessage:(NSData *)consoleMessage fontFamily:(NSString *)fontFamily fontSize:(double)fontSize isBold:(BOOL)isBold
{
    NSMutableAttributedString *result = [[self contentForLine:consoleMessage] mutableCopy];
    
    NSString *whiteBackgroundComponents = @"#ffffff";
            
    NSNumber *fontSizeAsNumber = [[NSNumber alloc] initWithDouble:fontSize];
    NSNumber *isBoldAsNumber   = [[NSNumber alloc] initWithBool:isBold];

    NSRange entireString = NSMakeRange(0, [result length]);

    [result addAttribute:IMAttributeMessageBackgroundColor value:whiteBackgroundComponents range:entireString];    
    [result addAttribute:IMAttributeFontFamily value:fontFamily       range:entireString];
    [result addAttribute:IMAttributeFontSize   value:fontSizeAsNumber range:entireString];

    [isBoldAsNumber   release];
    [fontSizeAsNumber release];
    [whiteBackgroundComponents release];
    
    return [result autorelease];
}


- (NSAttributedString *) contentForIncomingConsoleMessage:(NSData *)consoleMessage
{
    return [self _contentForConsoleMessage:consoleMessage fontFamily:@"Monaco" fontSize:10.0 isBold:NO];
}


- (NSAttributedString *) contentForOutgoingConsoleMessage:(NSData *)consoleMessage
{
    return [self _contentForConsoleMessage:consoleMessage fontFamily:@"Helvetica" fontSize:11.0 isBold:YES];
}


@end


