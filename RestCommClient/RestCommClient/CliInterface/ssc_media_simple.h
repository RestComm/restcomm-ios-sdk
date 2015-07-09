/*
 * TeleStax, Open Source Cloud Communications
 * Copyright 2011-2015, Telestax Inc and individual contributors
 * by the @authors tag.
 *
 * This program is free software: you can redistribute it and/or modify
 * under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation; either version 3 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 *
 * For questions related to commercial use licensing, please contact sales@telestax.com.
 *
 */

#ifndef HAVE_SSC_MEDIA_SIMPLE
#define HAVE_SSC_MEDIA_SIMPLE

/* The SscMediaSimple class is not an actual media implementation, more like 
 * a placeholder able to store the SDPs used by WebRTC. Maybe it would make sense to migrate
 * the WebRTC implementation here but it's objective-C and would be really painful
 */

#include <stdio.h>
#include <stdbool.h>
#include <sofia-sip/sdp.h>
#include <iostream>
#include <string>

enum SscMediaState {
    sm_init = 0,     /**< Media setup ongoing */
    sm_local_ready,  /**< Local resources are set up */
    sm_active,       /**< Media send/recv active */
    sm_error,        /**< Error state has been noticed, client has to call
                      ssc_media_deactivate() */
    sm_disabled
};

using namespace std;
class SscMediaSimple {
public:
    SscMediaSimple();
    string ssc_media_static_capabilities();
    int ssc_media_activate();
    int ssc_media_deactivate();
    bool ssc_media_is_initialized();
    int setLocalSdp(const char * sdp);
    int setRemoteSdp(const char * sdp);
    string getLocalSdp();
    string getRemoteSdp();

    int          sm_state;

private:
    string       local_sdp;
    string       remote_sdp;
};

#endif
