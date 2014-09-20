//
//  ssc_media.cpp
//  test-ios-sip-sofia
//
//  Created by Antonis Tsakiridis on 9/15/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#include <string>
//#include <stdio.h>
//#include <stdlib.h>
//#include "ssc_media-cpp.h"

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>

//#include <glib.h>
#include <sofia-sip/sdp.h>

#include "ssc_media.h"
#include "sdp_utils.h"

#if !HAVE_G_DEBUG
///#include "replace_g_debug.h"
#endif

/* Signals */
enum {
    SIGNAL_STATE,
    SIGNAL_LAST
};

/* props */
enum {
    PROP_0,
    PROP_LOCAL_SDP,
    PROP_REMOTE_SDP,
    PROP_AUDIO_INPUT,
    PROP_AUDIO_OUTPUT,
};

using namespace std;

SscMedia::SscMedia()
{
    this->sm_home = (su_home_t *)su_home_new(sizeof (*this->sm_home));
    allocated = true;
}

SscMedia::~SscMedia()
{
    if (allocated) {
        su_home_unref(this->sm_home);
    }
}

void SscMedia::Deallocate()
{
    if (allocated) {
        su_home_unref(this->sm_home);
    }
}

int SscMedia::ssc_media_activate(SscMedia *sscm)
{
    ///SscMedia *parent = SSC_MEDIA(sscm);
    printf("Activating dummy media implementation.");
    if (this->sm_sdp_local == NULL) {
        sdp_session_t *l_sdp;
        
        ssc_media_set_local_to_caps(this);
        
        l_sdp = sdp_session(this->sm_sdp_local);
        
        /* set port to 16384 */
        if (l_sdp && l_sdp->sdp_media) {
            l_sdp->sdp_media->m_port = SSC_MEDIA_RTP_PORT_RANGE_START;
            if (sscm->sm_sdp_local_str)
                free(sscm->sm_sdp_local_str), sscm->sm_sdp_local_str = NULL;
        }
    }
    if (this->sm_sdp_remote == NULL) {
        /* remote SDP not yet known, create a dummy one from
         * our own SDP */
        ssc_media_set_remote_to_local(this);
    }
    
    ssc_media_signal_state_change (this, sm_active);
    return 0;
}
int SscMedia::ssc_media_deactivate(SscMedia *sscm)
{
    printf("Deactivating dummy media implementation.");
    sscm->sm_state = sm_disabled;
    return 0;
}

int SscMedia::ssc_media_refresh(SscMedia *sscm)
{
    printf("Refreshing dummy media implementation state.");
    return 0;
}

int SscMedia::ssc_media_static_capabilities(SscMedia *sscm, char **dest)
{
    if (dest) {
        char cap[] = "v=0\nm=audio 0 RTP/AVP 0\na=rtpmap:0 PCMU/8000";
        *dest = (char *)malloc(strlen(cap));
        strcpy(*dest, cap); //g_strdup("v=0\nm=audio 0 RTP/AVP 0\na=rtpmap:0 PCMU/8000");
    }
    
    return 0;
}

int SscMedia::ssc_media_state(SscMedia *sscm)
{
    return sscm->sm_state;
}

bool SscMedia::ssc_media_is_active(SscMedia *sscm)
{
    return sscm->sm_state == sm_active;
}

bool SscMedia::ssc_media_is_initialized(SscMedia *sscm)
{
    return sscm->sm_state != sm_disabled;
}

void SscMedia::ssc_media_set_remote_to_local(SscMedia *self)
{
    sdp_session_t *sdp;
    sdp_media_t *media;
    //char *tmp_str = NULL;
    string tmp_str;
    
    //g_assert(G_IS_OBJECT(self));
    
    tmp_str = ssc_media_get_property("localsdp");
    //g_object_get(G_OBJECT(self), "localsdp", &tmp_str, NULL);
    
    printf("Set remote SDP based on capabilities: %s\n", tmp_str.c_str());
    
    if (tmp_str.size()) {
        //g_object_set(G_OBJECT(self), "remotesdp", tmp_str, NULL);
        ssc_media_set_property("remotesdp", tmp_str);
    }
    
    /* note: zero out ports for all media */
    if (self->sm_sdp_remote) {
        sdp = sdp_session(self->sm_sdp_remote);
        if (sdp) {
            for(media = sdp->sdp_media; media; media = media->m_next) {
                media->m_port = 0;
            }
        }
    }
}

void SscMedia::ssc_media_set_local_to_caps(SscMedia *sscm)
{
    char *tmp_str = NULL;
    
    ssc_media_static_capabilities(this, &tmp_str);
    printf("Set local SDP based on capabilities: %s\n", tmp_str);
    
    ///g_object_set(G_OBJECT(self), "localsdp", tmp_str, NULL);
    ssc_media_set_property("localsdp", tmp_str);

    
    free(tmp_str);
}



/* Helper Routines for subclasses */
/* ------------------------------ */
void SscMedia::ssc_media_signal_state_change(SscMedia *sscm, enum SscMediaState state)
{
    if (this->sm_state != state) {
        printf ("Signaling media subsystem change from %u to %u.\n", sscm->sm_state, state);
        sscm->sm_state = state;
        // this is going to be a bit tricky as we need to somehow emulate glib signals. Let's see which
        // closures/callbacks are registered to this event
        //g_signal_emit_by_name(G_OBJECT(sscm), "state-changed", state, NULL);
    }
}

int SscMedia::priv_set_local_sdp(SscMedia *self, const char *str)
{
    su_home_t *home = self->sm_home;
    const char *pa_error;
    int res = 0;
    
    //g_debug(__func__);
    
    if (self->sm_sdp_local)
        sdp_parser_free(self->sm_sdp_local);
    
    /* XXX: only update if SDP has really changed */
    /* printf("parsing SDP:\n%s\n---", str); */
    
    self->sm_sdp_local = sdp_parse(home, str, strlen(str), sdp_f_insane);
    pa_error = sdp_parsing_error(self->sm_sdp_local);
    if (pa_error) {
        printf("%s: error parsing SDP: %s\n", __func__, pa_error);
        res = -1;
    }
    else {
        if (self->sm_sdp_local_str)
            free(self->sm_sdp_local_str), self->sm_sdp_local_str = NULL;
    }
    
    return res;
    
}

int SscMedia::priv_set_remote_sdp(SscMedia *self, const char *str)
{
    su_home_t *home = self->sm_home;
    const char *pa_error;
    int res = 0, dlen = strlen(str);
    
    //g_debug(__func__);
    
    if (self->sm_sdp_remote)
        sdp_parser_free(self->sm_sdp_remote);
    
    /* XXX: only update if SDP has really changed */
    /* printf("parsing SDP:\n%s\n---", str); */
    
    self->sm_sdp_remote = sdp_parse(home, str, dlen, sdp_f_insane);
    pa_error = sdp_parsing_error(self->sm_sdp_remote);
    if (pa_error) {
        printf("%s: error parsing SDP: %s\n", __func__, pa_error);
        res = -1;
    }
    else {
        if (self->sm_sdp_remote_str)
            free(self->sm_sdp_remote_str);
    }
    
    return res;
}

void SscMedia::ssc_media_set_property (string prop_id, string value)
{
    //SscMedia *self;
    int res = 0;
    ///g_return_if_fail (SSC_IS_MEDIA (object));
    
    ///self = SSC_MEDIA (object);
    this->properties[prop_id] = value;
    
    
    if (prop_id == "localsdp") {
        res = priv_set_local_sdp(this, value.c_str());
        // note: succesfully set new l-SDP, update the media config
        if (!res && ssc_media_is_initialized(this))
            ssc_media_refresh(this);
    }
    else if (prop_id == "remotesdp") {
            res = priv_set_remote_sdp(this, value.c_str());
            // note: succesfully set new r-SDP, update the media config
            if (!res && ssc_media_is_initialized(this))
                ssc_media_refresh(this);
    }
    else {
        printf("Unknown object property %s.", prop_id.c_str());
    }
}

string SscMedia::ssc_media_get_property (string prop_id)
{
    string value;
    if (prop_id == "localsdp") {
        if (!this->sm_sdp_local_str) {
            sdp_print_to_text(this->sm_home, this->sm_sdp_local, &this->sm_sdp_local_str);
        }
        value = this->sm_sdp_local_str;
    }
    else if (prop_id == "remotesdp") {
        if (!this->sm_sdp_remote_str) {
            sdp_print_to_text(this->sm_home, this->sm_sdp_remote, &this->sm_sdp_remote_str);
        }
        value = this->sm_sdp_remote_str;
    }
    else {
        printf("Unknown object property %s", prop_id.c_str());
    }
    
    return value;
}