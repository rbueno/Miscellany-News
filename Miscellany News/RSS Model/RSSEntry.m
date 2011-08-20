//
//  RSSEntry.m
//  Miscellany News
//
//  Created by Jesse Stuart on 8/14/11.
//  Copyright 2011 Vassar College. All rights reserved.
//

#import "RSSEntry.h"

@implementation RSSEntry

@synthesize articleTitle = _articleTitle;
@synthesize articleUrl = _articleUrl;
@synthesize articleDate = _articleDate;
@synthesize articleSummary = _articleSummary;
//@synthesize articleText = _articleText;

- (NSString *)articleText
{
    return _articleText;
}

- (void)setArticleText:(NSString *)articleText
{
    _articleText = [articleText retain];
//    NSLog(@"article text has been set for entry %@", _articleTitle);
}

- (id)initWithArticleTitle:(NSString *)articleTitle 
                articleUrl:(NSString *)articleUrl 
               articleDate:(NSDate *)articleDate 
            articleSummary:(NSString *)articleSummary 
               articleText:(NSString *)articleText
{
//    const RSSArticleTextUnavailable = 
    
    if ((self = [super init]))
    {
        _articleTitle = [articleTitle copy];
        _articleUrl = [articleUrl copy];
        _articleDate = [articleDate copy];
        _articleSummary = [articleSummary copy];
        // even if article text is nil
        _articleText = [articleText retain];
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"dealloc RSSEntry: %@", _articleTitle);
    [_articleTitle release];
    _articleTitle = nil;
    
    [_articleUrl release];
    _articleUrl = nil;
    
    [_articleDate release];
    _articleDate = nil;
    
    [_articleText release];
    _articleText = nil;
    
    [super dealloc];
}

@end
