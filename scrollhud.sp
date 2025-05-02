#include <clientprefs>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <shavit>

#pragma semicolon 1
#pragma newdecls required

chatstrings_t gS_ChatStrings;

int g_iEarlyTicks[MAXPLAYERS+1] = {0, ...};
int g_iLateTicks[MAXPLAYERS+1] = {0, ...};
int g_iPerfed[MAXPLAYERS+1] = {0, ...};
int g_iMissed[MAXPLAYERS+1] = {0, ...};
int g_iGroundTicks[MAXPLAYERS+1] = {0, ...};
int g_iLastCmdNumOrSomething[MAXPLAYERS+1] = {0, ...};
int g_iLastLandTick[MAXPLAYERS+1] = {0, ...};

float g_fLastY[MAXPLAYERS+1] = {0.0, ...};

bool g_bJumped[MAXPLAYERS+1] = {false, ...};
bool g_bSecondHalfOfJump[MAXPLAYERS+1] = {false, ...};
bool g_bEarlyTicksResettable[MAXPLAYERS+1] = {false, ...};
bool g_bBhopping[MAXPLAYERS+1] = {false, ...};
bool g_bScrollHudEnabled[MAXPLAYERS+1] = {false, ...};

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
	{
		return;
	}
	
	if(AreClientCookiesCached(client))
	{
		OnClientCookiesCached(client);
	}
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_GetChatStrings(sMessageText, gS_ChatStrings.sText, sizeof(chatstrings_t::sText));
	Shavit_GetChatStrings(sMessageVariable, gS_ChatStrings.sVariable, sizeof(chatstrings_t::sVariable));
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}
	
	char sCookie[8];
	GetClientCookie(client, g_hScrollHudEnabled, sCookie, 8);
	g_bScrollHudEnabled[client] = strlen(sCookie) > 0 ? view_as<bool>(StringToInt(sCookie)) : false;
}

public Action Command_ScrollHud(int client, int args)
{
	if(AreClientCookiesCached(client))
	{
		g_bScrollHudEnabled[client] = !g_bScrollHudEnabled[client];
		Shavit_PrintToChat(client, "Scroll HUD has been %s%s", gS_ChatStrings.sVariable, g_bScrollHudEnabled[client]?"enabled":"disabled");

		char sValue[4];
		IntToString(g_bScrollHudEnabled[client], sValue, sizeof(sValue));
		SetClientCookie(client, g_hScrollHudEnabled, sValue);
	}
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(Shavit_GetStyleSettingBool((Shavit_IsReplayEntity(client) ? (Shavit_GetReplayBotStyle(client) != -1 ? Shavit_GetReplayBotStyle(client) : 0) : Shavit_GetBhopStyle(client)), "autobhop"))
		return Plugin_Continue;
	
	g_bBhopping[client] = (GetGameTickCount() - g_iLastLandTick[client] < 50 || !Shavit_Bhopstats_IsOnGround(client) || g_iGroundTicks[client] < 50);
	
	if(IsFakeClient(client))
	{
		if(Shavit_GetStyleSettingBool(Shavit_GetBhopStyle(client), "autobhop"))
			return Plugin_Continue;
		
		float vec0;
		buttons = Shavit_GetReplayButtons(client, vec0);
		
		if(!g_bJumped[client] && buttons & IN_JUMP && g_iGroundTicks[client] > 0)
		{
			g_bJumped[client]           = true;
			g_bSecondHalfOfJump[client] = false;
			g_iLastLandTick[client] = GetGameTickCount();
			
			if(g_bBhopping[client])
			{
				if(g_iGroundTicks[client] == 1)
				{
					g_iMissed[client] = 0;
					g_iPerfed[client]++;
				}
				else
				{
					g_iPerfed[client] = 0;
					g_iMissed[client]++;
				}
			}
			g_iGroundTicks[client] = 0;
		}
	}
		
	if(g_bBhopping[client])
	{
		if(Shavit_Bhopstats_IsOnGround(client))
		{
			if(g_iGroundTicks[client] == 0)
			{
				g_iLastLandTick[client] = GetGameTickCount();
			}
			g_iGroundTicks[client]++;
		}
		
		float pos[3];
		GetEntPropVector(client, Prop_Data, "m_vecOrigin", pos);
	
		if(g_fLastY[client] > pos[2])
		{
			g_bSecondHalfOfJump[client] = true;
			if(g_iLastCmdNumOrSomething[client] != cmdnum - 1)
			{
				g_bEarlyTicksResettable[client] = true;
			}
			g_iLastCmdNumOrSomething[client] = cmdnum;
		}
		
		if(buttons & IN_JUMP)
		{
			if(!g_bJumped[client] && g_bSecondHalfOfJump[client])
			{
				if(g_bEarlyTicksResettable[client])
				{
					g_iEarlyTicks[client] = 0;
					g_bEarlyTicksResettable[client] = false;
				}
				g_iEarlyTicks[client]++;
			}
			
			if(!g_bSecondHalfOfJump[client])
			{
				g_iLateTicks[client]++;
			}
			
			if(g_bJumped[client])
			{
				g_iLateTicks[client] = 0;

				g_bJumped[client] = false;
			}
		}
		
		if(cmdnum % 5 == 0)
		{
			char secondln[32];
			Format(secondln, sizeof(secondln), "%s (%i | %i)", g_iLateTicks[client] == g_iEarlyTicks[client] ? "Equal" : g_iEarlyTicks[client] > g_iLateTicks[client] ? "Early" : "Late", g_iEarlyTicks[client], g_iLateTicks[client]);

			for(int s = 1; s <= MaxClients; s++)
			{
				if(IsClientInGame(s) && !IsClientSourceTV(s) && !IsClientReplay(s) && !IsFakeClient(s))
				{
					if(!g_bScrollHudEnabled[s])
						continue;
					
					int target = GetSpectatorTarget(s, s);
					
					if(target < 0 || target > MaxClients)
						continue;
					
					if(!IsClientObserver(s))
					{
						target = s;
					}
					
					if(target == client)
					{
						if(g_iMissed[client])
						{
							SetHudTextParams(-1.0, -0.35, GetTickInterval() * 5, 255, 50, 50, 255, 0, 0.0, 0.0);
							ShowHudText(s, 5, "Miss (%i)\n%s", g_iMissed[client], secondln);
						}
						else if(g_iPerfed[client])
						{
							SetHudTextParams(-1.0, -0.35, GetTickInterval() * 5, 255, 100, 255, 255, 0, 0.0, 0.0);
							ShowHudText(s, 5, "Perf (%i)\n%s", g_iPerfed[client], secondln);
						}
					}
				}
			}
		}
		g_fLastY[client] = pos[2];
	}
	else
	{
		g_iMissed[client] = 0;
		g_iPerfed[client] = 0;
		g_iEarlyTicks[client] = 0;
		g_iLateTicks[client] = 0;
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerJump(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(Shavit_GetStyleSettingBool(Shavit_GetBhopStyle(client), "autobhop"))
		return Plugin_Continue;
	
	g_bJumped[client] = true;
	g_bSecondHalfOfJump[client] = false;
	g_iLastLandTick[client] = GetGameTickCount();
	
	if(g_bBhopping[client])
	{
		if(g_iGroundTicks[client] == 1)
		{
			g_iMissed[client] = 0;
			g_iPerfed[client]++;
		}
		else
		{
			g_iPerfed[client] = 0;
			g_iMissed[client]++;
		}
	}
	g_iGroundTicks[client] = 0;
	return Plugin_Continue;
}
