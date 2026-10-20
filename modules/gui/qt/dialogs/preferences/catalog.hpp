/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *****************************************************************************/
/****************************************************************************
 * catalog.hpp : Curated configuration entries for the QML preferences view
 ****************************************************************************/
#ifndef VLC_QT_PREFERENCES_CATALOG_HPP
#define VLC_QT_PREFERENCES_CATALOG_HPP

#include <cstddef>

namespace PrefsCatalog
{
struct Option
{
    const char *category;
    const char *name;
};

const Option *options();
size_t count();
}

#endif
