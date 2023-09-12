#include <sourcemod>
#include <sdktools_trace>
#include <sdktools_engine>
#include <sdktools_functions>
#include <multicolors>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "0.0.1"

ConVar g_cPluginEnabled;

bool g_bPluginEnabled;
bool g_bPressedRecently[MAXPLAYERS+1];

public Plugin myinfo =
{
    name = "Easy spectate",
    author = "faketuna",
    description = "Spectate player with easy method.",
    version = PLUGIN_VERSION,
    url = "https://short.f2a.dev/s/github"
};

public void OnPluginStart() {
    LoadTranslations("easySpectate.phrases");

    g_cPluginEnabled        = CreateConVar("espec_enabled", "1", "Enable Disable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_cPluginEnabled.AddChangeHook(OnCvarsChanged);
}

public void OnConfigsExecuted() {
    syncValues();
}

public void OnClientConnected(int client) {
    g_bPressedRecently[client] = false;
}

public void syncValues() {
    g_bPluginEnabled    = g_cPluginEnabled.BoolValue;
}

public void OnCvarsChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    syncValues();
}

public Action OnPlayerRunCmd(int client, int& buttons)
{
    if(g_bPluginEnabled && !IsPlayerAlive(client) && !g_bPressedRecently[client]) {
        if(buttons & IN_USE) {
            g_bPressedRecently[client] = true;
            trySpectate(client);
            CreateTimer(1.0, preventKickTimer, client, TIMER_FLAG_NO_MAPCHANGE);
        }
        return Plugin_Continue;
    }
    return Plugin_Continue;
}

public Action preventKickTimer(Handle timer, int client) {
    g_bPressedRecently[client] = false;
    return Plugin_Stop;
}

void trySpectate(int client) {
    int target = getClientViewClient(client);
    if(target != -1) {
        FakeClientCommand(client, "spec_player %N", target);
        return;
    }
    DisplaySettingsMenu(client);
}

stock int getClientViewClient(int client) {
    float m_vecOrigin[3];
    float m_angRotation[3];
    GetClientEyePosition(client, m_vecOrigin);
    GetClientEyeAngles(client, m_angRotation);
    Handle tr = TR_TraceRayFilterEx(m_vecOrigin, m_angRotation, MASK_SOLID_BRUSHONLY, RayType_Infinite, TRDontHitSelf, client);
    int pEntity = -1;
    if (TR_DidHit(tr)) {
        pEntity = TR_GetEntityIndex(tr);
        delete tr;
        if (!isValidClient(client))
            return -1;
        if (!IsValidEntity(pEntity))
            return -1;
        if (!isValidClient(pEntity))
            return -1;

        return pEntity;
    }
    delete tr;
    return -1;
}

stock bool TRDontHitSelf(int entity, int mask, any data) {
    if (entity == data)
        return false;
    return true;
}

stock bool isValidClient(int client) {
    return (1 <= client <= MaxClients && IsClientInGame(client));
} 


void DisplaySettingsMenu(int client)
{
    SetGlobalTransTarget(client);
    Menu prefmenu = CreateMenu(PrefMenuHandler, MENU_ACTIONS_DEFAULT);

    char menuTitle[64];
    Format(menuTitle, sizeof(menuTitle), "%t", "spec player pick menu title", client);
    prefmenu.SetTitle(menuTitle);
    
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i) && IsPlayerAlive(i)) {
            int team = GetClientTeam(i);
            char teamTransKey[32];
            switch(team) {
                case 2: { strcopy(teamTransKey, sizeof(teamTransKey), "spec menu T");}
                case 3: { strcopy(teamTransKey, sizeof(teamTransKey), "spec menu CT");}
                default: {return;}
            }
            char pName[128];
            Format(pName, sizeof(pName), "%N", i);
            char translatedPName[128];
            Format(translatedPName, sizeof(translatedPName), "%t%N", teamTransKey, i);
            prefmenu.AddItem(pName, translatedPName);
        }
    }
    
    prefmenu.Display(client, MENU_TIME_FOREVER);
}

public int PrefMenuHandler(Menu prefmenu, MenuAction actions, int client, int item)
{
    SetGlobalTransTarget(client);
    if (actions == MenuAction_Select)
    {
        char preference[128];
        GetMenuItem(prefmenu, item, preference, sizeof(preference));
        FakeClientCommand(client, "spec_player %s", preference);
    }
    else if (actions == MenuAction_End)
    {
        CloseHandle(prefmenu);
    }
    return 0;
}