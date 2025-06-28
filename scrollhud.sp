#include <clientprefs>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <shavit>

#pragma semicolon 1
#pragma newdecls required

enum struct stats_t
{
	bool bJumped;
	bool bSecondHalfOfJump;
	bool bEarlyTicksResettable;
	bool bBhopping;
	bool bScrollHudEnabled;
	int iEarlyTicks;
	int iLateTicks;
	int iPerfed;
	int iMissed;
	int iGroundTicks;
	int iLastCmdNumOrSomething;
	int iLastLandTick;
	float fLastY;
}

chatstrings_t g_sChatStrings;
stats_t g_Stats[MAXPLAYERS+1];

Handle g_hScrollHudEnabled = INVALID_HANDLE;

public Plugin myinfo =
{
	name        = "Kawaii-Scroll HUD",
	author      = "may, olivia",
	description = "Show scroll stats on HUD",
	version     = "c:",
	url         = "https://KawaiiClan.com"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_scrollhud", Command_ScrollHud, "Enable scroll stats hud");
	HookEvent("player_jump", Event_PlayerJump, EventHookMode_Post);
	g_hScrollHudEnabled = RegClientCookie("scrollhud_enabled", "Scroll Hud Enabled", CookieAccess_Protected);
	Shavit_OnChatConfigLoaded();
}

public void OnClientPutInServer(int client)
{
	if(!IsClientConnected(client) || IsFakeClient(client))
		return;

	if(AreClientCookiesCached(client))
		OnClientCookiesCached(client);
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_GetChatStringsStruct(g_sChatStrings);
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client))
		return;

	char sCookie[2];
	GetClientCookie(client, g_hScrollHudEnabled, sCookie, sizeof(sCookie));
	g_Stats[client].bScrollHudEnabled = strlen(sCookie) > 0 ? view_as<bool>(StringToInt(sCookie)) : false;
}

public Action Command_ScrollHud(int client, int args)
{
	if(AreClientCookiesCached(client))
	{
		g_Stats[client].bScrollHudEnabled = !g_Stats[client].bScrollHudEnabled;
		Shavit_PrintToChat(client, "Scroll HUD has been %s%s", g_sChatStrings.sVariable, g_Stats[client].bScrollHudEnabled?"enabled":"disabled");

		char sValue[4];
		IntToString(g_Stats[client].bScrollHudEnabled, sValue, sizeof(sValue));
		SetClientCookie(client, g_hScrollHudEnabled, sValue);
	}

	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(Shavit_GetStyleSettingBool((Shavit_IsReplayEntity(client) ? (Shavit_GetReplayBotStyle(client) != -1 ? Shavit_GetReplayBotStyle(client) : 0) : Shavit_GetBhopStyle(client)), "autobhop"))
		return Plugin_Continue;

	g_Stats[client].bBhopping = (GetGameTickCount() - g_Stats[client].iLastLandTick < 50 || !Shavit_Bhopstats_IsOnGround(client) || g_Stats[client].iGroundTicks < 50);

	if(IsFakeClient(client))
	{
		if(Shavit_GetStyleSettingBool(Shavit_GetBhopStyle(client), "autobhop"))
			return Plugin_Continue;

		float f0;
		buttons = Shavit_GetReplayButtons(client, f0);

		if(!g_Stats[client].bJumped && buttons & IN_JUMP && g_Stats[client].iGroundTicks > 0)
		{
			g_Stats[client].bJumped = true;
			g_Stats[client].bSecondHalfOfJump = false;
			g_Stats[client].iLastLandTick = GetGameTickCount();

			if(g_Stats[client].bBhopping)
			{
				if(g_Stats[client].iGroundTicks == 1)
				{
					g_Stats[client].iMissed = 0;
					g_Stats[client].iPerfed++;
				}
				else
				{
					g_Stats[client].iPerfed = 0;
					g_Stats[client].iMissed++;
				}
			}
			g_Stats[client].iGroundTicks = 0;
		}
	}

	if(g_Stats[client].bBhopping)
	{
		if(Shavit_Bhopstats_IsOnGround(client))
		{
			if(g_Stats[client].iGroundTicks == 0)
				g_Stats[client].iLastLandTick = GetGameTickCount();

			g_Stats[client].iGroundTicks++;
		}

		float pos[3];
		GetEntPropVector(client, Prop_Data, "m_vecOrigin", pos);

		if(g_Stats[client].fLastY > pos[2])
		{
			g_Stats[client].bSecondHalfOfJump = true;
			if(g_Stats[client].iLastCmdNumOrSomething != cmdnum - 1)
				g_Stats[client].bEarlyTicksResettable = true;

			g_Stats[client].iLastCmdNumOrSomething = cmdnum;
		}

		if(buttons & IN_JUMP)
		{
			if(!g_Stats[client].bJumped && g_Stats[client].bSecondHalfOfJump)
			{
				if(g_Stats[client].bEarlyTicksResettable)
				{
					g_Stats[client].iEarlyTicks = 0;
					g_Stats[client].bEarlyTicksResettable = false;
				}
				g_Stats[client].iEarlyTicks++;
			}

			if(!g_Stats[client].bSecondHalfOfJump)
				g_Stats[client].iLateTicks++;

			if(g_Stats[client].bJumped)
			{
				g_Stats[client].iLateTicks = 0;
				g_Stats[client].bJumped = false;
			}
		}

		if(cmdnum % 5 == 0)
		{
			char sSecondLine[32];
			Format(sSecondLine, sizeof(sSecondLine), "Early %i | %i Late", g_Stats[client].iEarlyTicks, g_Stats[client].iLateTicks);

			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && !IsFakeClient(i))
				{
					if(!g_Stats[i].bScrollHudEnabled)
						continue;

					int target = GetSpectatorTarget(i, i);

					if(target < 0 || target > MaxClients)
						continue;

					if(!IsClientObserver(i))
						target = i;

					if(target == client)
					{
						if(g_Stats[client].iMissed)
						{
							SetHudTextParams(-1.0, -0.35, GetTickInterval() * 5, 255, 50, 50, 255, 0, 0.0, 0.0);
							ShowHudText(i, 5, "Miss (%i)\n%s", g_Stats[client].iMissed, sSecondLine);
						}
						else if(g_Stats[client].iPerfed)
						{
							SetHudTextParams(-1.0, -0.35, GetTickInterval() * 5, 255, 100, 255, 255, 0, 0.0, 0.0);
							ShowHudText(i, 5, "Perf (%i)\n%s", g_Stats[client].iPerfed, sSecondLine);
						}
					}
				}
			}
		}
		g_Stats[client].fLastY = pos[2];
	}
	else
	{
		g_Stats[client].iMissed = 0;
		g_Stats[client].iPerfed = 0;
		g_Stats[client].iEarlyTicks = 0;
		g_Stats[client].iLateTicks = 0;
	}

	return Plugin_Continue;
}

public Action Event_PlayerJump(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(Shavit_GetStyleSettingBool(Shavit_GetBhopStyle(client), "autobhop"))
		return Plugin_Continue;

	g_Stats[client].bJumped = true;
	g_Stats[client].bSecondHalfOfJump = false;
	g_Stats[client].iLastLandTick = GetGameTickCount();

	if(g_Stats[client].bBhopping)
	{
		if(g_Stats[client].iGroundTicks == 1)
		{
			g_Stats[client].iMissed = 0;
			g_Stats[client].iPerfed++;
		}
		else
		{
			g_Stats[client].iPerfed = 0;
			g_Stats[client].iMissed++;
		}
	}
	g_Stats[client].iGroundTicks = 0;
	return Plugin_Continue;
}
