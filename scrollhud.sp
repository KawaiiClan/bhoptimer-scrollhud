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
	bool bPerfSoundEnabled;
	bool bPlayedPerfSound;
	int iPerfSoundChoice;
	int iEarlyTicks;
	int iLateTicks;
	int iPerfed;
	int iMissed;
	int iGroundTicks;
	int iLastCmdNumOrSomething;
	int iLastLandTick;
	int iPerfPB;
	float fLastY;
}

char g_sSounds[][] =
{
	"Drip",
	"Blub",
	"Ding",
	"Click",
	"Alarm"
};

char g_sFiles[][] =
{
	"kawaii/perf_drip.wav",
	"kawaii/perf_blub.wav",
	"kawaii/perf_ding.wav",
	"kawaii/perf_click.wav",
	"kawaii/perf_alarm.wav"
};

chatstrings_t g_sChatStrings;
stats_t g_Stats[MAXPLAYERS+1];

Handle g_hScrollHudEnabled = INVALID_HANDLE;
Handle g_hPerfSoundEnabled= INVALID_HANDLE;
Handle g_hPerfSoundChoice = INVALID_HANDLE;
Handle g_hPerfPB = INVALID_HANDLE;

public Plugin myinfo =
{
	name        = "Kawaii-Scroll HUD",
	author      = "may, olivia",
	description = "Show scroll stats on HUD, now with perf sounds",
	version     = "c:",
	url         = "https://KawaiiClan.com"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_scrollhud", Command_ScrollHud, "Enable scroll stats hud");
	RegConsoleCmd("sm_perfhud", Command_ScrollHud, "Enable scroll stats hud");
	RegConsoleCmd("sm_perf", Command_Perf);
	RegConsoleCmd("sm_perfsound", Command_Perf);
	RegConsoleCmd("sm_perfpb", Command_PerfPB);
	HookEvent("player_jump", Event_PlayerJump, EventHookMode_Post);
	g_hScrollHudEnabled = RegClientCookie("scrollhud_enabled", "Scroll Hud Enabled", CookieAccess_Protected);
	g_hPerfSoundEnabled = RegClientCookie("shavit_perf", "Perfect jump enabled.", CookieAccess_Protected);
	g_hPerfSoundChoice = RegClientCookie("shavit_perfsound", "Perfect jump sound.", CookieAccess_Protected);
	g_hPerfPB = RegClientCookie("shavit_perfpb", "Perfect jump string PB.", CookieAccess_Protected);
	Shavit_OnChatConfigLoaded();
}

public void OnMapStart()
{
	char buf[PLATFORM_MAX_PATH];
	for(int i = 0; i < sizeof(g_sFiles); i++)
	{
		FormatEx(buf, sizeof(buf), "sound/%s", g_sFiles[i]);
		PrecacheSound(g_sFiles[i], true);
		AddFileToDownloadsTable(buf);
	}
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

	GetClientCookie(client, g_hPerfSoundEnabled, sCookie, sizeof(sCookie));
	g_Stats[client].bPerfSoundEnabled = strlen(sCookie) > 0 ? view_as<bool>(StringToInt(sCookie)) : false;

	GetClientCookie(client, g_hPerfSoundChoice, sCookie, sizeof(sCookie));
	g_Stats[client].iPerfSoundChoice = strlen(sCookie) > 0 ? StringToInt(sCookie) : 0;

	GetClientCookie(client, g_hPerfPB, sCookie, sizeof(sCookie));
	g_Stats[client].iPerfPB = strlen(sCookie) > 0 ? StringToInt(sCookie) : 0;
}

public Action Command_ScrollHud(int client, int args)
{
	if(AreClientCookiesCached(client))
	{
		g_Stats[client].bScrollHudEnabled = !g_Stats[client].bScrollHudEnabled;
		Shavit_PrintToChat(client, "Scroll HUD has been %s%s", g_sChatStrings.sVariable, g_Stats[client].bScrollHudEnabled?"enabled":"disabled");

		char sValue[2];
		IntToString(g_Stats[client].bScrollHudEnabled, sValue, sizeof(sValue));
		SetClientCookie(client, g_hScrollHudEnabled, sValue);
	}

	return Plugin_Handled;
}

public Action Command_Perf(int client, int args)
{
	if(IsValidClient(client))
		PerfMenu(client);
	return Plugin_Handled;
}

public Action Command_PerfPB(int client, int args)
{
	if(IsValidClient(client))
		Shavit_PrintToChat(client, "Most perfs achieved in a row: %s%i", g_sChatStrings.sVariable, g_Stats[client].iPerfPB);
	return Plugin_Handled;
}

void PerfMenu(int client)
{
	if(!IsValidClient(client))
		return;

	Panel hPanel = CreatePanel();
	hPanel.SetTitle("Perfect Jump Sound");

	char sDisplay[32];
	FormatEx(sDisplay, sizeof(sDisplay), "[%s] Enabled\n ", g_Stats[client].bPerfSoundEnabled ? "X" : "  ");
	hPanel.DrawItem(sDisplay, ITEMDRAW_CONTROL);

	for(int i = 0; i < sizeof(g_sSounds); i++)
		hPanel.DrawItem(g_sSounds[i], g_Stats[client].iPerfSoundChoice == i ? ITEMDRAW_DISABLED : ITEMDRAW_CONTROL);

	hPanel.DrawItem("", ITEMDRAW_SPACER);

	FormatEx(sDisplay, sizeof(sDisplay), "Consecutive Perfs PB: %i\n ", g_Stats[client].iPerfPB);
	hPanel.DrawItem(sDisplay, ITEMDRAW_RAWLINE);

	SetPanelCurrentKey(hPanel, 10);
	hPanel.DrawItem("Exit", ITEMDRAW_CONTROL);

	hPanel.Send(client, PerfMenuHandler, MENU_TIME_FOREVER);
	CloseHandle(hPanel);
}

public int PerfMenuHandler(Menu hPanel, MenuAction action, int param1, any param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(IsValidClient(param1))
			{
				if(param2 == 1)
				{
					EmitSoundToClient(param1, "buttons/button14.wav");
					g_Stats[param1].bPerfSoundEnabled = !g_Stats[param1].bPerfSoundEnabled;
					SetClientCookie(param1, g_hPerfSoundEnabled, g_Stats[param1].bPerfSoundEnabled?"1":"0");
					PerfMenu(param1);
					return Plugin_Handled;
				}
				else if(param2 == 10)
				{
					EmitSoundToClient(param1, "buttons/combine_button7.wav");
					CloseHandle(hPanel);
					return Plugin_Handled;
				}

				EmitSoundToClient(param1, g_sFiles[param2-2], _, _, 150);
				g_Stats[param1].iPerfSoundChoice = param2-2;

				char s[2];
				IntToString(param2-2, s, sizeof(s));
				SetClientCookie(param1, g_hPerfSoundChoice, s);
				PerfMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if(IsValidClient(param1))
			{
				EmitSoundToClient(param1, "buttons/combine_button7.wav");
				CloseHandle(hPanel);
			}
		}
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
					if(!g_Stats[i].bScrollHudEnabled && !g_Stats[i].bPerfSoundEnabled)
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
							if(g_Stats[i].bScrollHudEnabled)
							{
								SetHudTextParams(-1.0, -0.35, GetTickInterval() * 5, 255, 50, 50, 255, 0, 0.0, 0.0);
								ShowHudText(i, 5, "Miss (%i)\n%s", g_Stats[client].iMissed, sSecondLine);
							}
						}
						else if(g_Stats[client].iPerfed)
						{
							if(g_Stats[i].bScrollHudEnabled)
							{
								SetHudTextParams(-1.0, -0.35, GetTickInterval() * 5, 255, 100, 255, 255, 0, 0.0, 0.0);
								ShowHudText(i, 5, "Perf (%i)\n%s", g_Stats[client].iPerfed, sSecondLine);
							}
							if(g_Stats[i].bPerfSoundEnabled && !g_Stats[i].bPlayedPerfSound)
							{
								EmitSoundToClient(i, g_sFiles[g_Stats[i].iPerfSoundChoice], _, _, 150);
								g_Stats[i].bPlayedPerfSound = true;
							}
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

public void ResetPlayedPerfSound(int client)
{
	g_Stats[client].bPlayedPerfSound = false;
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
			if(g_Stats[client].iPerfed > g_Stats[client].iPerfPB)
			{
				g_Stats[client].iPerfPB = g_Stats[client].iPerfed;
				char sValue[8];
				IntToString(g_Stats[client].iPerfPB, sValue, sizeof(sValue));
				SetClientCookie(client, g_hPerfPB, sValue);
			}
		}
		else
		{
			g_Stats[client].iPerfed = 0;
			g_Stats[client].iMissed++;
		}
	}
	g_Stats[client].iGroundTicks = 0;
	g_Stats[client].bPlayedPerfSound = false;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && !IsFakeClient(i))
		{
			if(GetSpectatorTarget(i, i) == client)
			{
				ResetPlayedPerfSound(i);
			}
		}
	}
	return Plugin_Continue;
}
