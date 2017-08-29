/*
 * libjingle
 * Copyright 2015 Google Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ARDVideoCallView.h"

#import <AVFoundation/AVFoundation.h>

static CGFloat const kLocalVideoViewWidth = 90;
static CGFloat const kLocalVideoViewHeight = 120;
static CGFloat const kLocalVideoViewPadding = 8;

@interface ARDVideoCallView () <RTCEAGLVideoViewDelegate>
@end

@implementation ARDVideoCallView {
  CGSize _localVideoSize;
  CGSize _remoteVideoSize;
}

@synthesize localVideoView = _localVideoView;
@synthesize remoteVideoView = _remoteVideoView;

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _remoteVideoView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectZero];
    _remoteVideoView.delegate = self;
    [self addSubview:_remoteVideoView];

    _localVideoView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectZero];
    _localVideoView.transform = CGAffineTransformMakeScale(-1, 1);
    _localVideoView.delegate = self;
    [self addSubview:_localVideoView];
  }
  return self;
}

- (void)layoutSubviews {
  CGRect bounds = self.bounds;
  if (_remoteVideoSize.width > 0 && _remoteVideoSize.height > 0) {
    // Aspect fill remote video into bounds.
    CGRect remoteVideoFrame =
        AVMakeRectWithAspectRatioInsideRect(_remoteVideoSize, bounds);
    CGFloat scale = 1;
    if (remoteVideoFrame.size.width > remoteVideoFrame.size.height) {
      // Scale by height.
      scale = bounds.size.height / remoteVideoFrame.size.height;
    } else {
      // Scale by width.
      scale = bounds.size.width / remoteVideoFrame.size.width;
    }
    remoteVideoFrame.size.height *= scale;
    remoteVideoFrame.size.width *= scale;
    _remoteVideoView.frame = remoteVideoFrame;
    _remoteVideoView.center =
        CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
  } else {
    _remoteVideoView.frame = bounds;
  }

  CGRect localVideoFrame = CGRectZero;
  localVideoFrame.origin.x =
      CGRectGetMaxX(bounds) - kLocalVideoViewWidth - kLocalVideoViewPadding;
    localVideoFrame.origin.y = kLocalVideoViewPadding * 3;
  //    CGRectGetMaxY(bounds) - kLocalVideoViewHeight - kLocalVideoViewPadding;
  localVideoFrame.size.width = kLocalVideoViewWidth;
  localVideoFrame.size.height = kLocalVideoViewHeight;
  _localVideoView.frame = localVideoFrame;
}

#pragma mark - RTCEAGLVideoViewDelegate

- (void)videoView:(RTCEAGLVideoView*)videoView didChangeVideoSize:(CGSize)size {
  if (videoView == _localVideoView) {
    _localVideoSize = size;
  } else if (videoView == _remoteVideoView) {
    _remoteVideoSize = size;
  }
  [self setNeedsLayout];
}

@end
