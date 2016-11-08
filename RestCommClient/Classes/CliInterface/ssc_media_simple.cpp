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

#include <string.h>
#include <stdlib.h>
#include <iostream>
#include "ssc_media_simple.h"

SscMediaSimple::SscMediaSimple()
{
    local_sdp = "";
    remote_sdp = "";
    sm_state = sm_disabled;
}

string SscMediaSimple::ssc_media_static_capabilities()
{
    return "v=0\r\n"
        "m=audio 0 RTP/AVP 0\r\n"
        "a=rtpmap:0 PCMU/8000\r\n";
}


int SscMediaSimple::ssc_media_activate()
{
    sm_state = sm_active;
    
    return 0;
}

int SscMediaSimple::setLocalSdp(const char * sdp)
{
    local_sdp = sdp;
    return 0;
}

int SscMediaSimple::setRemoteSdp(const char * sdp)
{
    remote_sdp = sdp;
    return 0;
}

string SscMediaSimple::getLocalSdp()
{
    return local_sdp;
}

string SscMediaSimple::getRemoteSdp()
{
    return remote_sdp;
}

bool SscMediaSimple::ssc_media_is_initialized()
{
    return sm_state != sm_disabled;
}

int SscMediaSimple::ssc_media_deactivate()
{
    sm_state = sm_disabled;
    return 0;
}
