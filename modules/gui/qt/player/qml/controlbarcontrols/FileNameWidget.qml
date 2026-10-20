/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *****************************************************************************/
import VLC.Player

// Figma 2160:8732: the title of the top bar moved into the bar, a text
MetadataText {
    value: {
        if (Player.name)
            return Player.name
        const mrl = Player.url.toString().split(/[?#]/)[0]
        const leaf = mrl.substring(mrl.lastIndexOf("/") + 1)
        try { return decodeURIComponent(leaf) }
        catch (error) { return leaf }
    }
    placeholder: qsTr("File name unavailable")
}
