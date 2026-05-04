/* Copyright (C) 2024 HyperXTalk Contributors

This file is part of HyperXTalk.

HyperXTalk is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.  */

#include "prefix.h"

#include "globdefs.h"
#include "platform.h"
#include "platform-internal.h"

#include "player.h"
#include "globals.h"

void MCPlatformBreakWait(void)
{
    MCscreen->pingwait();
}

bool MCPlatformWaitForEvent(double duration, bool blocking)
{
    bool t_dispatch = !blocking;
    return MCscreen->wait(duration, t_dispatch, false);
}

static MCPlayer *find_player(MCPlatformPlayerRef p_player)
{
    for (MCPlayerHandle t_player = MCplayers; t_player.IsValid();
         t_player = t_player->getnextplayer())
    {
        if (t_player->getplatformplayer() == p_player)
            return t_player;
    }
    return nil;
}

void MCPlatformCallbackSendPlayerFrameChanged(MCPlatformPlayerRef p_player)
{
    MCPlayer *t_player = find_player(p_player);
    if (t_player == nil)
        return;
    t_player->layer_redrawall();
    MCPlatformBreakWait();
}

void MCPlatformCallbackSendPlayerMarkerChanged(MCPlatformPlayerRef p_player, MCPlatformPlayerDuration p_time)
{
    MCPlayer *t_player = find_player(p_player);
    if (t_player == nil)
        return;
    t_player->markerchanged(p_time);
}

void MCPlatformCallbackSendPlayerCurrentTimeChanged(MCPlatformPlayerRef p_player)
{
    MCPlayer *t_player = find_player(p_player);
    if (t_player == nil)
        return;
    t_player->currenttimechanged();
}

void MCPlatformCallbackSendPlayerFinished(MCPlatformPlayerRef p_player)
{
    MCPlayer *t_player = find_player(p_player);
    if (t_player == nil)
        return;
    MCPlatformBreakWait();
    t_player->layer_redrawall();
    t_player->moviefinished();
}
