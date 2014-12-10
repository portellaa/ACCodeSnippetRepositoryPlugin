//
//  ACCodeSnippetSerialization.m
//  ACCodeSnippetRepository
//
//  Created by Arnaud Coomans on 11/02/14.
//  Copyright (c) 2014 Arnaud Coomans. All rights reserved.
//

#import "ACCodeSnippetSerialization.h"

NSString * const ACCodeSnippetIdentifierKey = @"IDECodeSnippetIdentifier";
NSString * const ACCodeSnippetTitleKey = @"IDECodeSnippetTitle";
NSString * const ACCodeSnippetSummaryKey = @"IDECodeSnippetSummary";
NSString * const ACCodeSnippetContentsKey = @"IDECodeSnippetContents";
NSString * const ACCodeSnippetUserSnippetKey = @"IDECodeSnippetUserSnippet";
NSString * const ACCodeSnippetLanguageKey = @"IDECodeSnippetLanguage";
NSString * const ACCodeSnippetCompletionScopeKey = @"IDECodeSnippetCompletionScopes";
NSString * const ACCodeSnippetCompletionShortcutKey = @"IDECodeSnippetCompletionPrefix";

NSString * const ACCodeSnippetLanguageObjectiveC = @"Xcode.SourceCodeLanguage.Objective-C";

static NSString *const kACCodeSnippetIdentifierKey = @"Identifier";
static NSString *const kACCodeSnippetLanguageKey = @"Language";
static NSString *const kACCodeSnippetPlatformKey = @"Platform";
static NSString *const kACCodeSnippetScopeKey = @"Scopes";
static NSString *const kACCodeSnippetShortcutKey = @"Shortcuts";
static NSString *const kACCodeSnippetSummaryKey = @"Summary";
static NSString *const kACCodeSnippetTitleKey = @"Title";
static NSString *const kACCodeSnippetUserSnippetKey = @"UserSnippet";

@interface ACCodeSnippetSerialization ()

+ (NSArray *)allowedScopes;

+ (NSDictionary *)relationKeysDictionary;

@end

@implementation ACCodeSnippetSerialization


+ (NSData *)dataWithDictionary:(NSDictionary*)dict
                        format:(ACCodeSnippetSerializationFormat)format
                       options:(ACCodeSnippetSerializationWriteOptions)opt
                         error:(NSError**)error {
    
    NSString *title = dict[ACCodeSnippetTitleKey];
    NSString *summary = dict[ACCodeSnippetSummaryKey];
    NSString *contents = dict[ACCodeSnippetContentsKey];
    
    NSMutableDictionary *mutableDictionary = [dict mutableCopy];
    [mutableDictionary removeObjectsForKeys:@[ACCodeSnippetTitleKey, ACCodeSnippetSummaryKey, ACCodeSnippetContentsKey]];
    dict = mutableDictionary;
    
    NSMutableString *string = [@"" mutableCopy];
    
    [string appendFormat:@"// %@\n", (title?:@"")];
    [string appendFormat:@"// %@\n", (summary?:@"")];
    [string appendString:@"//\n"];
    
    NSDictionary *mappingKeys = [self relationKeysDictionary];
    
    [mutableDictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, __unused BOOL *stop) {
        if ([value isKindOfClass:[NSArray class]]) {
            [string appendFormat:@"// %@: [%@]\n", mappingKeys[key], [value componentsJoinedByString:@","]];
        } else {
            [string appendFormat:@"// %@: %@\n", mappingKeys[key], value];
        }
    }];
    
    [string appendFormat:@"\n%@", contents ?: @""];
    
    return [string dataUsingEncoding:NSUTF8StringEncoding];
}


+ (id)dictionaryWithData:(NSData*)data
                 options:(ACCodeSnippetSerializationReadOptions)opt
                  format:(ACCodeSnippetSerializationFormat)format
                   error:(NSError**)error {
    
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSMutableDictionary *dict = [@{} mutableCopy];

    __block BOOL isParsingHeader = YES;
    __block NSString *contents = @"";
    
    NSString *pattern = @"//\\s*(\\w*)\\s*:\\s*(.*)";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:error];
    __block int i = 0;
    [string enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        
        if (![line hasPrefix:@"//"]) {
            isParsingHeader = NO;
        }
        
        if (isParsingHeader) {
            __block NSString *key = nil;
            __block id value = nil;
            [regex enumerateMatchesInString:line
                                    options:0
                                      range:NSMakeRange(0, line.length)
                                 usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                                     
                                     key = [line substringWithRange:[result rangeAtIndex:1]];
                                     value = [[line substringWithRange:[result rangeAtIndex:2]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                     
                                     NSLog(@"Snippet attribute -> Analyzing key %@ with value %@", key, value);
                                     
                                     if ([value hasPrefix:@"["] && [value hasSuffix:@"]"]) {
                                         value = [[value substringWithRange:NSMakeRange(1, [value length]-2)] componentsSeparatedByString:@","];
                                     }
                                     
                                     if ([kACCodeSnippetTitleKey rangeOfString:[key lowercaseString]].location != NSNotFound) {
                                         key = ACCodeSnippetTitleKey;
                                     }
                                     
                                     if ([kACCodeSnippetSummaryKey rangeOfString:[key lowercaseString]].location != NSNotFound) {
                                         key = ACCodeSnippetSummaryKey;
                                     }
                                     
                                     if ([kACCodeSnippetShortcutKey rangeOfString:[key lowercaseString]].location != NSNotFound) {
                                         key = ACCodeSnippetCompletionShortcutKey;
                                         
                                         id newValue = dict[key];
                                         
                                         if (newValue) {
                                             value = newValue;
                                         }
                                     }
                                     
                                     if ([kACCodeSnippetScopeKey rangeOfString:[key lowercaseString]].location != NSNotFound) {
                                         key = ACCodeSnippetCompletionScopeKey;
                                         
                                         @autoreleasepool {
                                             id existingScopesArray = dict[key];
                                             NSMutableSet *existingScopesSet;
                                             
                                             if (!existingScopesArray) {
                                                 existingScopesSet = [NSMutableSet set];
                                             } else {
                                                 existingScopesSet = [NSMutableSet setWithArray:existingScopesArray];
                                             }
                                             
                                             if ([value isKindOfClass:[NSString class]]) {
                                                 value = [value componentsSeparatedByString:@","];
                                             }
                                             
                                             [value makeObjectsPerformSelector:@selector(stringByTrimmingCharactersInSet:)
                                                                    withObject:[NSCharacterSet whitespaceCharacterSet]];
                                             
                                             for (__strong NSString *scopeValue in value) {
                                                 scopeValue = [scopeValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                                                 
                                                 if ([[self allowedScopes] indexOfObject:scopeValue] != NSNotFound) {
                                                     [existingScopesSet addObject:scopeValue];
                                                 }
                                             }
                                             
                                             value = [existingScopesSet allObjects];
                                         }
                                         
                                     }
                                     
                                     NSLog(@"Snippet attribute -> [%@] = %@", key, value);
                                     dict[key] = value;
                                 }];
            
            if (!key && !value) {
                if (i < 2) {
                    value = [[line substringWithRange:NSMakeRange(2, line.length-2)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (i == 0) {
                        dict[ACCodeSnippetTitleKey] = value;
                    }
                    if (i == 1) {
                        dict[ACCodeSnippetSummaryKey] = value;
                    }
                }
            }
            
        } else {
            contents = [contents stringByAppendingFormat:@"%@\n", line]; //stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
        
        i++;
    }];
    
    dict[ACCodeSnippetContentsKey] = contents;
    
    return [dict copy];
}

#pragma mark - Private Methods

+ (NSArray *)allowedScopes {
    static NSArray *allowedScopes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allowedScopes = @[@"All",
                          @"ClassImplementation",
                          @"ClassInterfaceVariables",
                          @"ClassInterfaceMethods",
                          @"CodeBlock",
                          @"CodeExpression",
                          @"Preprocessor",
                          @"StringOrComment",
                          @"TopLevel"
                         ];
    });
    return allowedScopes;
}

+ (NSDictionary *)relationKeysDictionary {
    static NSDictionary *relationKeysDictionary = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        relationKeysDictionary = @{
                                   ACCodeSnippetIdentifierKey:kACCodeSnippetIdentifierKey,
                                   ACCodeSnippetTitleKey:kACCodeSnippetTitleKey,
                                   ACCodeSnippetSummaryKey:kACCodeSnippetSummaryKey,
                                   ACCodeSnippetUserSnippetKey:kACCodeSnippetUserSnippetKey,
                                   ACCodeSnippetLanguageKey:kACCodeSnippetLanguageKey,
                                   ACCodeSnippetCompletionScopeKey:kACCodeSnippetScopeKey,
                                   ACCodeSnippetCompletionShortcutKey:kACCodeSnippetShortcutKey
                                   };
    });
    return relationKeysDictionary;
}

#pragma mark - 

+ (NSString*)identifier {
    CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef strRef = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
    NSString *uuidString = [NSString stringWithString:(__bridge NSString*)strRef];
    CFRelease(strRef);
    CFRelease(uuidRef);
    return uuidString;
}

@end
