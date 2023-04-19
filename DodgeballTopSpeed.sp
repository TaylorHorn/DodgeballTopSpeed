#include <sourcemod>
#include <sdktools>
#include <tfdb>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name = "Dodgeball Top Speed",
	author = "Zonas & Elite",
	description = "Top Speed Command and Menu for Dodgeball",
	version = "Version",
	url = "URL"
};

Database g_Database;

/**
 * Plugin state forwards
 */

public void OnPluginStart() {
	Database.Connect(HandleConnectionResult, "db_stats");

	// RegConsoleCmd("sm_topspeed", topspeed, "Show topspeed");
}

public void OnPluginEnd() {
	delete g_Database;
}

/**
 * Actions
 */

// Action topspeed(int client, int args) {   
//     PrintToChat(client, "[TopSpeed] Your top rocket speed: %0.2f MpH with %d deflections", fTopSpeed, iDeflections);
//     return Plugin_Handled;
// }

/**
 * Client authentication and functions
 */

public void OnClientPostAdminCheck(int client) {
	if(!IsValidClient(client)) {
		return;
	}
	
	char auth[32];
	if(GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth))) {
		FindAndInitializeRecords(client, auth);
		AddClientToGameState(client, auth);
	}
}

stock bool IsValidClient(int client, bool allowBot = false) {
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || (!allowBot && IsFakeClient(client))) {
		return false;
	}
	
	return true;
}

void FindAndInitializeRecords(int client, char auth[32]) {
	char query[89];
	FormatEx(query, sizeof(query), "SELECT * FROM `dodgeball_stats` WHERE `steam_id` = '%s'", auth);
	g_Database.Query(ValidateClientRecords, query, client, DBPrio_Normal);
}

void AddClientToGameState(int client, char auth[32])  {
	char table_name[11] = "game_stats";
	CreateRecord(client, auth, table_name);
}

/**
 * Game (Map) state functions
 */
public void OnMapEnd() {
	DumpGameState();
}

/**
 * TFDB forward overrides
 */

// public void TFDB_OnRocketDeflect(int iIndex, int iEntity, int iOwner) {
//     float fCurrentSpeed = TFDB_GetRocketMphSpeed(iIndex);
//     int iDeflections = TFDB_GetRocketEventDeflections(iIndex);

//     if (fCurrentSpeed > fTopSpeed) {
//         PrintToChat(iOwner, "[TopSpeed] New top rocket speed: %0.2f MpH with %d deflections", fCurrentSpeed, iDeflections);
//     }
// }


/**
 * Database related functions
 */

void HandleConnectionResult(Database db, const char[] error, any data) {
	LogError("%s", error);
	g_Database = db;
	ValidateDodgeballStatsTable();
	InitializeGameStatsTable();

}

void ValidateDodgeballStatsTable() {
	char CreateTable[120] = "CREATE TABLE IF NOT EXISTS `dodgeball_stats`\
	(\
		`id` int(32) NOT NULL AUTO_INCREMENT PRIMARY KEY,\
		`steam_id` varchar(32) NOT NULL,\
		`username` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,\
		`top_speed` int(32) NOT NULL DEFAULT '0',\
		`deflections` int(32) NOT NULL DEFAULT '0',\
		UNIQUE KEY `steam_id` (`steam_id`)\
	);";

	char query[120];
	Format(query, sizeof(query), CreateTable);

	ValidateTablePresence("dodgeball_stats", query);
}

void InitializeGameStatsTable() {
	char CreateTable[120] = "CREATE TABLE IF NOT EXISTS `game_stats`\
	(\
		`id` int(32) NOT NULL AUTO_INCREMENT PRIMARY KEY,\
		`steam_id` varchar(32) NOT NULL,\
		`username` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,\
		`top_speed` int(32) NOT NULL DEFAULT '0',\
		`deflections` int(32) NOT NULL DEFAULT '0',\
		UNIQUE KEY `steam_id` (`steam_id`)\
	);";

	char query[120];
	Format(query, sizeof(query), CreateTable);

	ValidateTablePresence("game_stats", query);
}

void ValidateTablePresence(const char[] TableName, char[] query) {
	SQL_FastQuery(g_Database, query);
	
	char error[255];
	if(SQL_GetError(g_Database, error, sizeof(error))) {
		LogError("Error in creating table %s: %s", TableName, error);
	}
}

void ValidateClientRecords(Database db, DBResultSet results, const char[] error, any client) {
	if(db == null || results == null) {
		LogError("Error getting player data: %s", error);
		return;
	} else if (results.RowCount == 0) {
		char auth[32];
		if(GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth))) {
			char table_name[16] = "dodgeball_stats";
			CreateRecord(client, auth, table_name);
		}
	}
}

void CreateRecord(int client, char auth[32], char[] table_name) {
	PrintToServer("Creating %s record for %s", table_name, auth);

	char buffer[MAX_NAME_LENGTH];
	char escaped_username[MAX_NAME_LENGTH*2+1];
	GetClientName(client, buffer, sizeof(buffer));
	SQL_EscapeString(g_Database, buffer, escaped_username, sizeof(escaped_username));

	char query[255];
	FormatEx(query, sizeof(query), "INSERT INTO `%s` (`steam_id`, `username`) VALUES ('%s', '%s')", table_name, auth, escaped_username);
	g_Database.Query(HandleRecordInsert, query);
}

void DumpGameState() {
	PrintToServer("Dumping game_stats...");
	char query[23];
	FormatEx(query, sizeof(query), "DELETE FROM game_stats");
	g_Database.Query(HandleGameStatsDump, query);
}

void HandleRecordInsert(Database db, DBResultSet results, const char[] error, any data) {
	if(db == null || results == null) {
		LogError("Error inserting player into database: %s", error);
		return;
    }
}

void HandleGameStatsDump(Database db, DBResultSet results, const char[] error, any data) {
	if(db == null || results != null) {
		LogError("Error dumping game_stats table: %s", error);
		return;
	}
}
