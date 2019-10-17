#include <sourcemod>
#include <multicolors>

#pragma semicolon 1

#define PLUGIN_VERSION "3.0"

#define MAX_MENU_DISPLAY_TIME 10
#define MAX_DATE_LENGTH 12
#define MAX_ID_LENGTH 32
#define MAX_MSG_LENGTH 64
#define MAX_ERROR_LENGTH 255
//#define MAX_BUFFER_LENGTH 512
#define DATE_FORMAT "%d.%m.%Y"

new Handle:weddings_db;
new Handle:forward_proposal;
new Handle:forward_wedding;
new Handle:forward_weddingpost;
new Handle:forward_divorce;
new Handle:cvar_couples;
new Handle:cvar_database;
new Handle:cvar_delay;
new Handle:cvar_disallow;
new Handle:cvar_kick_msg;
new Handle:usage_cache;

new proposal_checked[MAXPLAYERS + 1];
new proposal_beingChecked[MAXPLAYERS + 1];
new proposal_slots[MAXPLAYERS + 1];
new String:proposal_names[MAXPLAYERS + 1][MAX_NAME_LENGTH];
new String:proposal_ids[MAXPLAYERS + 1][MAX_ID_LENGTH];

new marriage_checked[MAXPLAYERS + 1];
new marriage_beingChecked[MAXPLAYERS + 1];
new marriage_slots[MAXPLAYERS + 1];
new String:marriage_names[MAXPLAYERS + 1][MAX_NAME_LENGTH];
new String:marriage_ids[MAXPLAYERS + 1][MAX_ID_LENGTH];
new marriage_scores[MAXPLAYERS + 1];
new marriage_times[MAXPLAYERS + 1];


#include "weddings\sql_queries.sp"
#include "weddings\functions_general.sp"
#include "weddings\functions_proposals.sp"
#include "weddings\functions_marriages.sp"
#include "weddings\functions_natives.sp"
#include "weddings\menu_handlers.sp"

public Plugin:myinfo = {
	name = "Weddings",
	author = "Dr. O, Franc1sco franug",
	description = "Get married! Propose to other players, browse, accept and revoke proposals or get divorced again. Top couples will be chosen according to their combined score.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Franc1sco/Franug-Weddings"
};


public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	CreateNative("GetPartnerSlot", Native_GetPartnerSlot);
	CreateNative("GetPartnerName", Native_GetPartnerName);
	CreateNative("GetPartnerID", Native_GetPartnerID);
	CreateNative("GetMarriageScore", Native_GetMarriageScore);
	CreateNative("GetWeddingTime", Native_GetWeddingTime);
	CreateNative("GetProposals", Native_GetProposals);
	CreateNative("GetMarriages", Native_GetMarriages);
	
	forward_proposal = CreateGlobalForward("OnProposal", ET_Event, Param_Cell, Param_Cell);
	forward_wedding = CreateGlobalForward("OnWedding", ET_Event, Param_Cell, Param_Cell);
	forward_weddingpost = CreateGlobalForward("OnWeddingPost", ET_Ignore, Param_Cell, Param_Cell);
	forward_divorce = CreateGlobalForward("OnDivorce", ET_Event, Param_Cell, Param_Cell);
	return APLRes_Success;
}

public OnPluginStart() {
	LoadTranslations("weddings.phrases");
	RegConsoleCmd("sm_marry", Marry, "List connected singles.");
	RegConsoleCmd("sm_revoke", Revoke, "Revoke proposal.");
	RegConsoleCmd("sm_proposals", Proposals, "List incoming proposals.");
	RegConsoleCmd("sm_divorce", Divorce, "End marriage.");
	RegConsoleCmd("sm_couples", Couples, "List top couples.");
	RegAdminCmd("sm_weddings_reset", Reset, ADMFLAG_BAN, "Reset database tables of the weddings plugin.");
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	
	CreateConVar("sm_fweddings_version", PLUGIN_VERSION, "Version of the weddings plugin.", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_REPLICATED);
	cvar_couples = CreateConVar("sm_weddings_show_couples", "10", "How many couples to show in the !couples menu.", FCVAR_NOTIFY, true, 3.0, true, 100.0);
	cvar_database = CreateConVar("sm_weddings_database", "1", "What database to use. Change takes effect on plugin reload.\n0 = sourcemod-local | 1 = custom\nIf set to 1, a \"weddings\" entry is needed in \"sourcemod\\configs\\databases.cfg\".", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvar_delay = CreateConVar("sm_weddings_command_delay", "0", "How many minutes clients must wait after successful command usage.", FCVAR_NOTIFY, true, 0.0, true, 30.0);
	cvar_disallow = CreateConVar("sm_weddings_disallow_unmarried", "0", "Whether to prevent unmarried clients from joining the server.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvar_kick_msg = CreateConVar("sm_weddings_kick_message", "Unmarried clients currently not allowed", "Message to display to kicked clients.\nOnly applies if sm_weddings_disallow_unmarried is set to 1.", FCVAR_NOTIFY);
	AutoExecConfig(true, "weddings");
	usage_cache = CreateArray(MAX_ID_LENGTH, 0);
	for(new i = 1; i <= MaxClients; i++) {
		proposal_checked[i] = false;
		marriage_checked[i] = false;
		proposal_beingChecked[i] = false;
		marriage_beingChecked[i] = false;
	}
}

public OnConfigsExecuted() {
	initDatabase();
}

public OnClientAuthorized(client, const String:auth[]) {
	decl String:client_id[MAX_ID_LENGTH];	
	
	if(!IsFakeClient(client) && !IsClientReplay(client) && !proposal_beingChecked[client] && !marriage_beingChecked[client]) {
		strcopy(client_id, sizeof(client_id), auth);
		proposal_beingChecked[client] = true;
		marriage_beingChecked[client] = true;
		checkProposal(client_id);
		checkMarriage(client_id);
	}
}

public OnClientSettingsChanged(client) {
	new partner;
	decl String:client_name[MAX_NAME_LENGTH];
	
	if(proposal_checked[client] && marriage_checked[client]) {
		if(IsClientInGame(client) && !IsFakeClient(client) && !IsClientReplay(client) && GetClientName(client, client_name, sizeof(client_name))) {
			partner = marriage_slots[client];
			if(partner != -2) {
				if(partner != -1) {
					marriage_names[partner] = client_name;
				}
			} else {
				for(new i = 1; i <= MaxClients; i++) {
					if(proposal_slots[i] == client) {
						proposal_names[i] = client_name;
					}
				}
			}
		}
	}
}

public OnClientDisconnect(client) {
	new partner;
	
	proposal_checked[client] = false;
	marriage_checked[client] = false;
	proposal_beingChecked[client] = false;
	marriage_beingChecked[client] = false;
	for(new i = 1; i <= MaxClients; i++) {
		if(proposal_slots[i] == client) {
			proposal_slots[i] = -1;
		}
	}
	partner = marriage_slots[client];
	if(partner > 0) {
		marriage_slots[partner] = -1;
	}
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
	new attacker;
	new partner;
	decl String:attacker_id[MAX_ID_LENGTH];
	
	attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(attacker != 0 && GetClientAuthId(attacker, AuthId_Engine, attacker_id, sizeof(attacker_id))) {
		partner = marriage_slots[attacker];
		if(partner != -2) {
			if(partner != -1) {				
				marriage_scores[partner] = marriage_scores[partner] + 1;
			}
			marriage_scores[attacker] = marriage_scores[attacker] + 1;
			updateMarriageScore(attacker_id);	
		}		 	
	}
}

public Action:Uncache(Handle:timer, Handle:data) {
	new entries = GetArraySize(usage_cache);
	decl String:client_id[MAX_ID_LENGTH];
	decl String:client_id_stored[MAX_ID_LENGTH];
	
	ReadPackString(data, client_id, sizeof(client_id));
	CloseHandle(data);
	for(new i = 0; i < entries; i++) {
		GetArrayString(usage_cache, i, client_id_stored, sizeof(client_id_stored));
		if(StrEqual(client_id, client_id_stored)) {
			RemoveFromArray(usage_cache, i);
			break;
		}
	}
	return Plugin_Handled;
}

public Action:Marry(client, args) {		
	decl String:client_id[MAX_ID_LENGTH];
	
	if(GetClientAuthId(client, AuthId_Engine, client_id, sizeof(client_id))) {
		if(proposal_checked[client] && marriage_checked[client]) {		
			if(checkUsage(client_id)) {
				if(marriage_slots[client] == -2) {
					if(proposal_slots[client] == -2) {
						new Handle:marry_menu = CreateMenu(MarryMenuHandler, MENU_ACTIONS_DEFAULT);
						SetMenuTitle(marry_menu, "%t", "!marry menu title");
						if(addTargets(marry_menu, client) > 0) {
							DisplayMenu(marry_menu, client, MAX_MENU_DISPLAY_TIME);
						} else {
							PrintToChat(client, " [LOVE] %t", "no singles on server");
						}
					} else {
						CPrintToChat(client, " [LOVE] %t", "already proposed", proposal_names[client]);
						PrintToChat(client,  " [LOVE] %t", "revoke info");
					}					
				} else {
					CPrintToChat(client, " [LOVE] %t", "already married", marriage_names[client]);
					PrintToChat(client, " [LOVE] %t", "divorce info");
				}
			} else {
				PrintToChat(client, " [LOVE] %t", "spam");
				CPrintToChat(client, " [LOVE] %t", "delay info", GetConVarFloat(cvar_delay));
			}			
		} else {
			PrintToChat(client, " [LOVE] %t", "status being checked");
		}
	}
	return Plugin_Handled;
}

public Action:Revoke(client, args) {
	decl String:client_id[MAX_ID_LENGTH];
	
	if(GetClientAuthId(client, AuthId_Engine, client_id, sizeof(client_id))) {
		if(proposal_checked[client] && marriage_checked[client]) {
			if(checkUsage(client_id)) {		
				if(marriage_slots[client] == -2) {
					if(proposal_slots[client] == -2) {
						PrintToChat(client, " [LOVE] %t", "not proposed");	
					} else {
						revokeProposal(client_id);
						cacheUsage(client_id);						
						CPrintToChat(client, " [LOVE] %t", "proposal revoked", proposal_names[client]);
						proposal_slots[client] = -2;
						proposal_names[client] = "";
						proposal_ids[client] = "";
					}
				} else {
					CPrintToChat(client, " [LOVE] %t", "already married", marriage_names[client]);
					PrintToChat(client, " [LOVE] %t", "divorce info");
				}
			} else {
				PrintToChat(client, " [LOVE] %t", "spam");
				CPrintToChat(client, " [LOVE] %t", "delay info", GetConVarFloat(cvar_delay));
			}
		} else {
			PrintToChat(client, " [LOVE] %t", "status being checked");
		}
	}
	return Plugin_Handled;
}

public Action:Proposals(client, args) {
	decl String:client_id[MAX_ID_LENGTH];
	
	if(GetClientAuthId(client, AuthId_Engine, client_id, sizeof(client_id))) {
		if(proposal_checked[client] && marriage_checked[client]) {
			if(checkUsage(client_id)) {
				if(marriage_slots[client] == -2) {
					findProposals(client_id);
				} else {
					CPrintToChat(client, " [LOVE] %t", "already married", marriage_names[client]);
					PrintToChat(client, " [LOVE] %t", "divorce info");
				}		
			} else {
				PrintToChat(client, " [LOVE] %t", "spam");
				CPrintToChat(client, " [LOVE] %t", "delay info", GetConVarFloat(cvar_delay));
			}
		} else {
			PrintToChat(client, " [LOVE] %t", "status being checked");
		}
	}
	return Plugin_Handled;
}

public Action:Divorce(client, args) {
	decl String:client_id[MAX_ID_LENGTH];
	
	if(GetClientAuthId(client, AuthId_Engine, client_id, sizeof(client_id))) {
		if(proposal_checked[client] && marriage_checked[client]) {
			if(checkUsage(client_id)) {
				if(marriage_slots[client] == -2) {
					PrintToChat(client, " [LOVE] %t", "not married");
					PrintToChat(client, " [LOVE] %t", "marriage info");
				} else {
					new format;
					new time_spent;
					new partner = marriage_slots[client];
					decl String:client_name[MAX_NAME_LENGTH];				
					
					if(GetClientName(client, client_name, sizeof(client_name))) {
						int value;
						
						Call_StartForward(forward_divorce);
						Call_PushCell(client);
						Call_PushCell(partner);
						Call_Finish(value);
						if (value != 0)
							return Plugin_Handled;
						
						revokeMarriage(client_id);
						//forwardDivorce(client, partner);
						cacheUsage(client_id);				
						computeTimeSpent(marriage_times[client], time_spent, format);						
						switch(format) {
							case 0 : {
								CPrintToChatAll(" [LOVE] %t", "marriage revoked days", client_name, marriage_names[client], time_spent);
							}
							case 1 : {
								CPrintToChatAll(" [LOVE] %t", "marriage revoked months", client_name, marriage_names[client], time_spent);
							}
							case 2 : {
								CPrintToChatAll(" [LOVE] %t", "marriage revoked years", client_name, marriage_names[client], time_spent);
							}
						}
						PrintToChatAll(" [LOVE] %t", "divorce notification");
						marriage_slots[client] = -2;
						marriage_names[client] = "";
						marriage_ids[client] = "";
						marriage_scores[client] = -1;
						marriage_times[client] = -1;
						if(partner != -1) {
							marriage_slots[partner] = -2;
							marriage_names[partner] = "";
							marriage_ids[partner] = "";
							marriage_scores[partner] = -1;
							marriage_times[partner] = -1;						
						}						
					}
				}
			} else {
				PrintToChat(client, " [LOVE] %t", "spam");
				CPrintToChat(client, " [LOVE] %t", "delay info", GetConVarFloat(cvar_delay));
			}			
		} else {
			PrintToChat(client, " [LOVE] %t", "status being checked");
		}
	}
	return Plugin_Handled;
}

public Action:Couples(client, args) {
	decl String:client_id[MAX_ID_LENGTH];
	
	if(GetClientAuthId(client, AuthId_Engine, client_id, sizeof(client_id))) {
		findMarriages(client_id);
	}
	return Plugin_Handled;
}

public Action:Reset(client, args) {
	resetTables(client);
	return Plugin_Handled;
}