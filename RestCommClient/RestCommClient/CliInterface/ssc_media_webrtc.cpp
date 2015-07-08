//
//  ssc_media_webrtc.c
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 7/8/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#include <string.h>
#include <stdlib.h>
#include "ssc_media_webrtc.h"

//SscMediaWebrtc * media;

SscMediaWebrtc *priv_create_ssc_media()
{
    SscMediaWebrtc * media = (SscMediaWebrtc *)malloc(sizeof(SscMediaWebrtc));
    media->sm_home = (su_home_t *)su_home_new(sizeof (*media->sm_home));
    
    return media;
}

void ssc_media_finalize(SscMediaWebrtc * media)
{
    su_home_unref(media->sm_home);
}

// TODO: improve mem management
int ssc_media_static_capabilities(SscMediaWebrtc * media, char **dest)
{
    char *caps_sdp_str = NULL;
    
    /* support only G711/PCMU */
    caps_sdp_str = su_strcat(media->sm_home, caps_sdp_str,
                             "v=0\r\n"
                             "m=audio 0 RTP/AVP 0\r\n"
                             "a=rtpmap:0 PCMU/8000\r\n");
    
    *dest = strdup(caps_sdp_str);
    su_free(media->sm_home, caps_sdp_str);
    
    return 0;
}

/*
void ssc_media_set_local_to_caps(SscMediaWebrtc * media)
{
    char *tmp_str = NULL;
    
    ssc_media_static_capabilities(media, &tmp_str);
    
    free(tmp_str);
}

void ssc_media_set_remote_to_local(SscMediaWebrtc * media)
{
    sdp_session_t *sdp;
    sdp_media_t *media;
    gchar *tmp_str = NULL;
    
    g_assert(G_IS_OBJECT(self));
    
    g_object_get(G_OBJECT(self),
                 "localsdp", &tmp_str, NULL);
    
    printf("Set remote SDP based on capabilities: %s\n", tmp_str);
    
    if (tmp_str)
        g_object_set(G_OBJECT(self),
                     "remotesdp", tmp_str, NULL);
    
    if (self->sm_sdp_remote) {
        sdp = sdp_session(self->sm_sdp_remote);
        if (sdp) {
            for(media = sdp->sdp_media; media; media = media->m_next) {
                media->m_port = 0;
            }
        }
    }
}
 */

int ssc_media_activate(SscMediaWebrtc * media)
{
    //SscMediaGst *self = SSC_MEDIA_GST (parent);
    /*
    int len = 0, res = 0;
    char *l_sdp_str = NULL;
    sdp_session_t *l_sdp = NULL;
    
    //g_debug(G_STRFUNC);
    
    if (media->sm_sdp_local == NULL) {
        //ssc_media_set_local_to_caps(media);
    }
    if (media->sm_sdp_remote == NULL) {
        // remote SDP not yet known, create a dummy one from our own SDP
        //ssc_media_set_remote_to_local(media);
    }
     */
    
    // get local port
    /*
    l_sdp = sdp_session(media->sm_sdp_local);
    if (l_sdp && l_sdp->sdp_media->m_port)
        self->sm_rtp_lport = l_sdp->sdp_media->m_port;
    
    g_debug(G_STRFUNC);
     */
    
    // TODO: now that gsreamer is removed we can't have this check. Check if we need to add anything else
    //if (self->sm_depay == NULL) {
    // TODO: this isn't needed anymore, we 're using webrtc media
    //res = priv_setup_rtpelements(self);
    //ssc_media_signal_state_change (parent, sm_active);
    //priv_cb_ready(NULL, self);
    //}
    media->sm_state = sm_active;
    //g_signal_emit_by_name(G_OBJECT(sscm), "state-changed", state, NULL);

    
    return 0;
}

int setLocalSdp(SscMediaWebrtc * media, const char * sdp)
{
    media->local_sdp = sdp;
    return 0;
}

int setRemoteSdp(SscMediaWebrtc * media, const char * sdp)
{
    media->remote_sdp = sdp;
    return 0;
}

string getLocalSdp(SscMediaWebrtc * media)
{
    return media->local_sdp;
    //sdp = su_strdup(media->sm_home, media->local_sdp);
    //return 0;
}

string getRemoteSdp(SscMediaWebrtc * media)
{
    return media->remote_sdp;
    //sdp = su_strdup(media->sm_home, media->remote_sdp);
    //return 0;
}

bool ssc_media_is_initialized(SscMediaWebrtc * media)
{
    return media->sm_state != sm_disabled;
}

int ssc_media_deactivate(SscMediaWebrtc * media)
{
    /*
    SscMediaGst *self = SSC_MEDIA_GST (parent);
    
    g_assert(ssc_media_is_initialized(parent) == TRUE);
    
    g_debug(G_STRFUNC);
    */
    /*
     if (self->sm_pipeline) {
     gst_element_set_state (self->sm_pipeline, GST_STATE_PAUSED);
     gst_element_set_state (self->sm_pipeline, GST_STATE_NULL);
     }
     */
    
    media->sm_state = sm_disabled;
    
    /*
     if (self->sm_netsocket)
     g_object_unref(G_OBJECT (self->sm_netsocket)), self->sm_netsocket = NULL;
     */
    
    /*
    if (self->sm_rtp_sockfd != -1)
        close(self->sm_rtp_sockfd), self->sm_rtp_sockfd = -1;
    if (self->sm_rtcp_sockfd != -1)
        close(self->sm_rtcp_sockfd), self->sm_rtp_sockfd = self->sm_rtcp_sockfd = -1;
    */
    /*
     if (self->sm_pipeline) {
     // XXX: gets stuck on gst-0.10.2, must fix, we are leaking memory otherwise
     gst_object_unref(GST_OBJECT (self->sm_pipeline));
     
     self->sm_pipeline = NULL;
     self->sm_depay = NULL;
     }
     */
    
    //self->sm_rx_elements = 0;
    //self->sm_tx_elements = 0;
    
    //g_assert(ssc_media_is_initialized(parent) != TRUE);
    
    // TODO: need to fix this; normally this return is not needed but for some reason XCode fails to understand that g_assert is a macro that return a value
    return 0;
}
