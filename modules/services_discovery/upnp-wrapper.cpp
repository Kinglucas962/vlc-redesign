/*****************************************************************************
 * upnp-wrapper.cpp :  UPnP Instance Wrapper class
 *****************************************************************************
 * Copyright © 2004-2018 VLC authors and VideoLAN
 *
 * Authors: Rémi Denis-Courmont (original plugin)
 *          Christian Henz <henz # c-lab.de>
 *          Mirsal Ennaime <mirsal dot ennaime at gmail dot com>
 *          Hugo Beauzée-Luyssen <hugo@beauzee.fr>
 *          Shaleen Jain <shaleen@jain.sh>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "upnp-wrapper.hpp"

UpnpInstanceWrapper* UpnpInstanceWrapper::s_instance;
UpnpInstanceWrapper::Listeners UpnpInstanceWrapper::s_listeners;
vlc::threads::mutex UpnpInstanceWrapper::s_lock;
vlc::threads::mutex UpnpInstanceWrapper::s_init_lock;

UpnpInstanceWrapper::UpnpInstanceWrapper()
    : m_handle( -1 )
    , m_refcount( 0 )
{
}

UpnpInstanceWrapper::~UpnpInstanceWrapper()
{
    UpnpUnRegisterClient( m_handle );
    UpnpFinish();
}

UpnpInstanceWrapper *UpnpInstanceWrapper::get(vlc_object_t *p_obj)
{
    // not while the previous instance finishes
    vlc::threads::mutex_locker init_lock( s_init_lock );
    vlc::threads::mutex_locker lock( s_lock );
    if ( s_instance == NULL )
    {
        UpnpInstanceWrapper* instance = new(std::nothrow) UpnpInstanceWrapper;
        if ( unlikely( !instance ) )
        {
            return NULL;
        }

        char *net_iface = var_InheritString( p_obj, "miface" );
        const bool forced = net_iface != NULL;
        if ( net_iface == NULL )
        {
            // No forced multicast network interface, select one by default.
            net_iface = getPreferedAdapter();
        }
        msg_Info( p_obj, "Initializing libupnp on '%s' interface",
                  net_iface ? net_iface : "default" );
        int i_res = UpnpInit2( net_iface, 0 );
        if ( i_res == UPNP_E_INVALID_INTERFACE && !forced && net_iface != NULL )
        {
            // libupnp could not find the interface by our name of it
            msg_Warn( p_obj, "Interface not found by libupnp, letting it choose" );
            i_res = UpnpInit2( NULL, 0 );
        }
        free( net_iface );
        if ( i_res == UPNP_E_SUCCESS )
            msg_Dbg( p_obj, "libupnp uses %s", UpnpGetServerIpAddress() );

        if( i_res != UPNP_E_SUCCESS )
        {
            msg_Err( p_obj, "Initialization failed: %s", UpnpGetErrorMessage( i_res ) );
            delete instance;
            return NULL;
        }

        ixmlRelaxParser( 1 );

        /* Register a control point */
        i_res = UpnpRegisterClient( Callback, NULL, &instance->m_handle );
        if( i_res != UPNP_E_SUCCESS )
        {
            msg_Err( p_obj, "Client registration failed: %s", UpnpGetErrorMessage( i_res ) );
            delete instance;
            return NULL;
        }

        /* libupnp does not treat a maximum content length of 0 as unlimited
         * until 64dedf (~ pupnp v1.6.7) and provides no sane way to discriminate
         * between versions */
        if( (i_res = UpnpSetMaxContentLength( INT_MAX )) != UPNP_E_SUCCESS )
        {
            msg_Err( p_obj, "Failed to set maximum content length: %s",
                    UpnpGetErrorMessage( i_res ));
            delete instance;
            return NULL;
        }
        s_instance = instance;
    }
    s_instance->m_refcount++;
    return s_instance;
}

void UpnpInstanceWrapper::release()
{
    vlc::threads::mutex_locker init_lock( s_init_lock );
    UpnpInstanceWrapper *p_delete = NULL;
    {
        vlc::threads::mutex_locker lock( s_lock );
        if (--s_instance->m_refcount == 0)
        {
            p_delete = s_instance;
            s_instance = NULL;
        }
    }
    // UpnpFinish() waits for the libupnp threads, which can be waiting for
    // s_lock in Callback
    delete p_delete;
}

UpnpClient_Handle UpnpInstanceWrapper::handle() const
{
    return m_handle;
}

int UpnpInstanceWrapper::Callback(Upnp_EventType event_type, UpnpEventPtr p_event, void *p_user_data)
{
    // Without the lock: a listener can download a device description,
    // which takes up to the HTTP timeout when the device does not answer
    // (see Listener::detach)
    Listeners listeners;
    {
        vlc::threads::mutex_locker lock( s_lock );
        listeners = s_listeners;
    }
    for (Listeners::iterator iter = listeners.begin(); iter != listeners.end(); ++iter)
    {
        (*iter)->onEvent(event_type, p_event, p_user_data);
    }

    return 0;
}

void UpnpInstanceWrapper::addListener(ListenerPtr listener)
{
    vlc::threads::mutex_locker lock( s_lock );
    if ( std::find( s_listeners.begin(), s_listeners.end(), listener) == s_listeners.end() )
        s_listeners.push_back( std::move(listener) );
}

void UpnpInstanceWrapper::removeListener(ListenerPtr listener)
{
    listener->detach();
    vlc::threads::mutex_locker lock( s_lock );
    Listeners::iterator iter = std::find( s_listeners.begin(), s_listeners.end(), listener );
    if ( iter != s_listeners.end() )
        s_listeners.erase( iter );
}
