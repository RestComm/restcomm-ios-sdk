//
//  sofia-ua-wrapper.h
//  test-sip1
//
//  Created by Antonis Tsakiridis on 8/30/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#ifndef test_sip2_sofia_ua_wrapper_h
#define test_sip2_sofia_ua_wrapper_h

// use 'caller' functionality
#define CALLER
#define SIP_MSG_RECEPIENT "sip:test@192.168.2.30:5060"

int sofia_loop(const char * msg);
//int printSum(int a, int b);

#endif
