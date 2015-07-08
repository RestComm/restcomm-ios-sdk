//
//  ssc_media_webrtc.h
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 7/8/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#ifndef __RestCommClient__ssc_media_webrtc__
#define __RestCommClient__ssc_media_webrtc__

#include <stdio.h>
#include <stdbool.h>
#include <sofia-sip/sdp.h>
#include <iostream>
#include <string>

using namespace std;
typedef struct  {
    su_home_t    *sm_home;
    string       local_sdp;    /**< remote SDP, parsed */
    string       remote_sdp;   /**< remote SDP, raw text */
    int          sm_state;

    sdp_parser_t *sm_sdp_local;
    sdp_parser_t *sm_sdp_remote;
    char         *sm_sdp_local_str;    /**< remote SDP, parsed */
    char         *sm_sdp_remote_str;   /**< remote SDP, raw text */
    char         *sm_ad_input_type;
    char         *sm_ad_input_device;
    char         *sm_ad_output_type;
    char         *sm_ad_output_device;

} SscMediaWebrtc;

enum SscMediaState {
    sm_init = 0,     /**< Media setup ongoing */
    sm_local_ready,  /**< Local resources are set up */
    sm_active,       /**< Media send/recv active */
    sm_error,        /**< Error state has been noticed, client has to call
                      ssc_media_deactivate() */
    sm_disabled
};

SscMediaWebrtc *priv_create_ssc_media();
int ssc_media_static_capabilities(SscMediaWebrtc * media, char **dest);
void ssc_media_finalize(SscMediaWebrtc * media);
int ssc_media_activate(SscMediaWebrtc * media);
bool ssc_media_is_initialized(SscMediaWebrtc * media);
int setLocalSdp(SscMediaWebrtc * media, const char * sdp);
int setRemoteSdp(SscMediaWebrtc * media, const char * sdp);
string getLocalSdp(SscMediaWebrtc * media);
string getRemoteSdp(SscMediaWebrtc * media);
int ssc_media_deactivate(SscMediaWebrtc * media);



#endif /* defined(__RestCommClient__ssc_media_webrtc__) */
