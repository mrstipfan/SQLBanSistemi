#include <amxmodx>
#include <amxmisc>
#include <sqlx>

#pragma semicolon 1

#define PLUGIN "[SQL Ban] Sistemi"
#define VERSION "3.1"
#define AUTHOR "Onur MrStipFan MASALCI"

#define MAX_REASON_LEN 191
#define MAX_NAME_LEN 32
#define MAX_AUTH_LEN 35
#define MAX_IP_LEN 32
#define MAX_TABLE_LEN 64
#define MAX_LINE_LEN 256
#define MAX_TAG_LEN 64
#define MAX_REASON_ITEMS 24
#define LOCAL_BAN_SLOTS 128

#define TASK_CHECK_A 2000
#define TASK_CHECK_B 3000
#define TASK_CHECK_C 4000

new Handle:g_SqlTuple = Empty_Handle;
new g_msgSayText;

/* SQL config */
new g_szSqlHost[64];
new g_szSqlUser[64];
new g_szSqlPass[64];
new g_szSqlDb[64];
new g_szSqlTable[MAX_TABLE_LEN];

/* General config */
new g_iDefBanMinutes;
new g_iInfoMessage;
new g_iCheckNick;
new g_szDropMessage[192];
new g_szChatTag[MAX_TAG_LEN];

/* Access flags from ini */
new g_iAccessBan;
new g_iAccessUnban;
new g_iAccessSqlMenu;
new g_iAccessSqlDelete;

/* Menus / state */
new g_iMenuTarget[33];
new g_iMenuBanMinutes[33];
new bool:g_bAwaitManualReason[33];

/* Reasons */
new g_iReasonCount;
new g_szReasonList[MAX_REASON_ITEMS][MAX_REASON_LEN];

/* Local instant cache */
new bool:g_bLocalBanUsed[LOCAL_BAN_SLOTS];
new g_szLocalBanNick[LOCAL_BAN_SLOTS][MAX_NAME_LEN];
new g_szLocalBanSteam[LOCAL_BAN_SLOTS][MAX_AUTH_LEN];
new g_szLocalBanIp[LOCAL_BAN_SLOTS][MAX_IP_LEN];
new g_szLocalBanReason[LOCAL_BAN_SLOTS][MAX_REASON_LEN];
new g_szLocalBanAdmin[LOCAL_BAN_SLOTS][MAX_NAME_LEN];
new g_szLocalBanAdminSteam[LOCAL_BAN_SLOTS][MAX_AUTH_LEN];
new g_szLocalBanCreated[LOCAL_BAN_SLOTS][32];
new g_szLocalBanExpires[LOCAL_BAN_SLOTS][32];
new g_iLocalBanMinutes[LOCAL_BAN_SLOTS];
new g_iLocalBanUntil[LOCAL_BAN_SLOTS]; // 0 = sinirsiz

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_concmd("csa_ban", "cmdCssBan");
    register_concmd("csa_unban", "cmdCssUnban");
    register_concmd("csa_banmenu", "cmdCssBanMenu");
    register_concmd("csa_unbanmenu", "cmdCssUnbanMenu");
    register_concmd("csa_sqlmenu", "cmdCssSqlMenu");
    register_concmd("csa_reloadbansql", "cmdReloadBanSql");

    register_clcmd("say", "hookSay");
    register_clcmd("say_team", "hookSay");
    register_clcmd("csa_ban_reason", "cmdManualBanReason");

    g_msgSayText = get_user_msgid("SayText");

    loadBanSqlConfig();
    set_task(1.0, "taskSqlInit");
}

public plugin_cfg()
{
    loadBanSqlConfig();
    sqlReconnect();
}

public plugin_end()
{
    if (g_SqlTuple != Empty_Handle)
    {
        SQL_FreeHandle(g_SqlTuple);
        g_SqlTuple = Empty_Handle;
    }
}

public taskSqlInit()
{
    loadBanSqlConfig();
    sqlReconnect();
    sqlCreateTable();
}

/* =========================================================
   CONFIG
========================================================= */

stock loadBanSqlConfig()
{
    new cfgdir[128], filepath[192];
    get_configsdir(cfgdir, charsmax(cfgdir));
    formatex(filepath, charsmax(filepath), "%s/panel_sqlbansistemi.ini", cfgdir);

    copy(g_szSqlHost, charsmax(g_szSqlHost), "sql.csarea.net");
    copy(g_szSqlUser, charsmax(g_szSqlUser), "srv212_100_185_");
    copy(g_szSqlPass, charsmax(g_szSqlPass), "");
    copy(g_szSqlDb, charsmax(g_szSqlDb), "srv212_100_185_");
    copy(g_szSqlTable, charsmax(g_szSqlTable), "csa_bans");

    g_iDefBanMinutes = 0;
    g_iInfoMessage = 1;
    g_iCheckNick = 1;
    copy(g_szDropMessage, charsmax(g_szDropMessage), "Iletisim: www.CSArea.net");
    copy(g_szChatTag, charsmax(g_szChatTag), "[CSA-SQL Ban]");

    g_iAccessBan = read_flags("d");
    g_iAccessUnban = read_flags("d");
    g_iAccessSqlMenu = read_flags("r");
    g_iAccessSqlDelete = read_flags("r");

    g_iReasonCount = 0;
    copy(g_szReasonList[g_iReasonCount++], charsmax(g_szReasonList[]), "Hile");
    copy(g_szReasonList[g_iReasonCount++], charsmax(g_szReasonList[]), "Kufur");
    copy(g_szReasonList[g_iReasonCount++], charsmax(g_szReasonList[]), "Kural ihlali");
    copy(g_szReasonList[g_iReasonCount++], charsmax(g_szReasonList[]), "Reklam");

    if (!file_exists(filepath))
    {
        createDefaultBanSqlConfig(filepath);
        log_amx("[CSA-SQL Ban] Varsayilan config olusturuldu: %s", filepath);
        return;
    }

    new fp = fopen(filepath, "rt");
    if (!fp)
    {
        log_amx("[CSA-SQL Ban] Config acilamadi: %s", filepath);
        return;
    }

    new line[MAX_LINE_LEN], key[64], value[192];

    while (!feof(fp))
    {
        fgets(fp, line, charsmax(line));
        trim(line);

        if (!line[0] || line[0] == ';' || line[0] == '#')
        {
            continue;
        }

        if (line[0] == '/' && line[1] == '/')
        {
            continue;
        }

        key[0] = 0;
        value[0] = 0;

        parse(line, key, charsmax(key), value, charsmax(value));
        trim(key);
        trim(value);
        remove_quotes(value);

        if (!key[0])
        {
            continue;
        }

        if (equali(key, "sql_host"))
        {
            copy(g_szSqlHost, charsmax(g_szSqlHost), value);
        }
        else if (equali(key, "sql_user"))
        {
            copy(g_szSqlUser, charsmax(g_szSqlUser), value);
        }
        else if (equali(key, "sql_pass"))
        {
            copy(g_szSqlPass, charsmax(g_szSqlPass), value);
        }
        else if (equali(key, "sql_db"))
        {
            copy(g_szSqlDb, charsmax(g_szSqlDb), value);
        }
        else if (equali(key, "sql_table"))
        {
            copy(g_szSqlTable, charsmax(g_szSqlTable), value);
        }
        else if (equali(key, "def_ban_minutes"))
        {
            g_iDefBanMinutes = str_to_num(value);
            if (g_iDefBanMinutes < 0)
            {
                g_iDefBanMinutes = 0;
            }
        }
        else if (equali(key, "info_message"))
        {
            g_iInfoMessage = str_to_num(value) ? 1 : 0;
        }
        else if (equali(key, "check_nick"))
        {
            g_iCheckNick = str_to_num(value) ? 1 : 0;
        }
        else if (equali(key, "drop_message"))
        {
            copy(g_szDropMessage, charsmax(g_szDropMessage), value);
        }
        else if (equali(key, "chat_tag"))
        {
            copy(g_szChatTag, charsmax(g_szChatTag), value);
        }
        else if (equali(key, "access_ban"))
        {
            g_iAccessBan = read_flags(value);
        }
        else if (equali(key, "access_unban"))
        {
            g_iAccessUnban = read_flags(value);
        }
        else if (equali(key, "access_sql_menu"))
        {
            g_iAccessSqlMenu = read_flags(value);
        }
        else if (equali(key, "access_sql_delete"))
        {
            g_iAccessSqlDelete = read_flags(value);
        }
        else if (containi(key, "reason_") == 0)
        {
            if (g_iReasonCount < MAX_REASON_ITEMS && value[0])
            {
                copy(g_szReasonList[g_iReasonCount], charsmax(g_szReasonList[]), value);
                g_iReasonCount++;
            }
        }
    }

    fclose(fp);
}

stock createDefaultBanSqlConfig(const filepath[])
{
    write_file(filepath, "; Onur MASALCI - CSArea SQL Ban Config", -1);
    write_file(filepath, "; addons/amxmodx/configs/panel_sqlbansistemi.ini", -1);
    write_file(filepath, "", -1);

    write_file(filepath, "sql_host ^"sql.csarea.net^"", -1);
    write_file(filepath, "sql_user ^"srv212_100_185_^"", -1);
    write_file(filepath, "sql_pass ^"^"", -1);
    write_file(filepath, "sql_db ^"srv212_100_185_^"", -1);
    write_file(filepath, "sql_table ^"csa_bans^"", -1);
    write_file(filepath, "", -1);

    write_file(filepath, "def_ban_minutes ^"0^"", -1);
    write_file(filepath, "info_message ^"1^"", -1);
    write_file(filepath, "check_nick ^"1^"", -1);
    write_file(filepath, "drop_message ^"Iletisim: www.CSArea.net^"", -1);
    write_file(filepath, "chat_tag ^"[CSA-SQL Ban]^"", -1);
    write_file(filepath, "", -1);

    write_file(filepath, "access_ban ^"d^"", -1);
    write_file(filepath, "access_unban ^"d^"", -1);
    write_file(filepath, "access_sql_menu ^"r^"", -1);
    write_file(filepath, "access_sql_delete ^"r^"", -1);
    write_file(filepath, "", -1);

    write_file(filepath, "reason_1 ^"Hile^"", -1);
    write_file(filepath, "reason_2 ^"Kufur^"", -1);
    write_file(filepath, "reason_3 ^"Kural ihlali^"", -1);
    write_file(filepath, "reason_4 ^"Reklam^"", -1);
    write_file(filepath, "reason_5 ^"Spam^"", -1);
    write_file(filepath, "reason_6 ^"Flood^"", -1);
}

public cmdReloadBanSql(id)
{
    if (!hasBanAccess(id))
    {
        return PLUGIN_HANDLED;
    }

    loadBanSqlConfig();
    sqlReconnect();
    sqlCreateTable();

    CC_Send(id, "^4%s^1 Config yeniden yuklendi.", g_szChatTag);
    return PLUGIN_HANDLED;
}

/* =========================================================
   ACCESS
========================================================= */

stock bool:hasAccessByBits(id, bits)
{
    if (id == 0)
    {
        return true;
    }

    return ((get_user_flags(id) & bits) == bits || (get_user_flags(id) & ADMIN_RCON));
}

stock bool:hasBanAccess(id)
{
    if (!hasAccessByBits(id, g_iAccessBan))
    {
        if (id)
        {
            CC_Send(id, "^4%s^1 Ban yetkiniz yok.", g_szChatTag);
        }
        return false;
    }
    return true;
}

stock bool:hasUnbanAccess(id)
{
    if (!hasAccessByBits(id, g_iAccessUnban))
    {
        if (id)
        {
            CC_Send(id, "^4%s^1 Unban yetkiniz yok.", g_szChatTag);
        }
        return false;
    }
    return true;
}

stock bool:hasSqlMenuAccess(id)
{
    if (!hasAccessByBits(id, g_iAccessSqlMenu))
    {
        if (id)
        {
            CC_Send(id, "^4%s^1 SQL menu yetkiniz yok.", g_szChatTag);
        }
        return false;
    }
    return true;
}

stock bool:hasSqlDeleteAccess(id)
{
    if (!hasAccessByBits(id, g_iAccessSqlDelete))
    {
        if (id)
        {
            CC_Send(id, "^4%s^1 SQL kaydi silme yetkiniz yok.", g_szChatTag);
        }
        return false;
    }
    return true;
}

/* =========================================================
   SQL
========================================================= */

stock sqlReconnect()
{
    if (g_SqlTuple != Empty_Handle)
    {
        SQL_FreeHandle(g_SqlTuple);
        g_SqlTuple = Empty_Handle;
    }

    g_SqlTuple = SQL_MakeDbTuple(g_szSqlHost, g_szSqlUser, g_szSqlPass, g_szSqlDb);
}

stock sqlCreateTable()
{
    if (g_SqlTuple == Empty_Handle)
    {
        sqlReconnect();
    }

    new query[4096];
    formatex(query, charsmax(query),
        "CREATE TABLE IF NOT EXISTS `%s` (\
        `id` INT NOT NULL AUTO_INCREMENT,\
        `player_nick` VARCHAR(32) NOT NULL DEFAULT '',\
        `player_steamid` VARCHAR(34) NOT NULL DEFAULT '',\
        `player_ip` VARCHAR(32) NOT NULL DEFAULT '',\
        `admin_nick` VARCHAR(32) NOT NULL DEFAULT '',\
        `admin_steamid` VARCHAR(34) NOT NULL DEFAULT '',\
        `reason` VARCHAR(191) NOT NULL DEFAULT '',\
        `ban_minutes` INT NOT NULL DEFAULT 0,\
        `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,\
        `expires_at` DATETIME NULL DEFAULT NULL,\
        `server_ip` VARCHAR(64) NOT NULL DEFAULT '',\
        `server_port` INT NOT NULL DEFAULT 0,\
        `active` TINYINT(1) NOT NULL DEFAULT 1,\
        `removed_at` DATETIME NULL DEFAULT NULL,\
        `removed_by` VARCHAR(64) NOT NULL DEFAULT '',\
        `removed_by_steamid` VARCHAR(34) NOT NULL DEFAULT '',\
        PRIMARY KEY (`id`),\
        KEY `idx_player_nick` (`player_nick`),\
        KEY `idx_player_steamid` (`player_steamid`),\
        KEY `idx_player_ip` (`player_ip`),\
        KEY `idx_active` (`active`)\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        g_szSqlTable
    );

    SQL_ThreadQuery(g_SqlTuple, "queryIgnoreHandler", query);
}

public queryIgnoreHandler(FailState, Handle:Query, Error[], Errcode, Data[], DataSize)
{
    if (FailState != TQUERY_SUCCESS)
    {
        log_amx("[CSA-SQL Ban] SQL HATA: %s (%d)", Error, Errcode);
    }
}

/* =========================================================
   COLOR CHAT
========================================================= */

stock CC_Send(id, const fmt[], any:...)
{
    new msg[191];
    vformat(msg, charsmax(msg), fmt, 3);

    if (id)
    {
        if (!is_user_connected(id))
        {
            return;
        }

        message_begin(MSG_ONE_UNRELIABLE, g_msgSayText, _, id);
        write_byte(id);
        write_string(msg);
        message_end();
    }
    else
    {
        new players[32], pnum, i, pid;
        get_players(players, pnum, "ch");

        for (i = 0; i < pnum; i++)
        {
            pid = players[i];

            message_begin(MSG_ONE_UNRELIABLE, g_msgSayText, _, pid);
            write_byte(pid);
            write_string(msg);
            message_end();
        }
    }
}

/* =========================================================
   CONNECT CHECK
========================================================= */

public client_authorized(id)
{
    if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
    {
        return;
    }

    scheduleBanChecks(id);
}

public client_putinserver(id)
{
    if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
    {
        return;
    }

    scheduleBanChecks(id);
}

public client_infochanged(id)
{
    if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
    {
        return;
    }

    new oldname[32], newname[32];
    get_user_name(id, oldname, charsmax(oldname));
    get_user_info(id, "name", newname, charsmax(newname));

    if (!equal(oldname, newname))
    {
        scheduleBanChecks(id);
    }
}

public client_disconnected(id)
{
    removeBanCheckTasks(id);
    g_bAwaitManualReason[id] = false;
    g_iMenuTarget[id] = 0;
    g_iMenuBanMinutes[id] = 0;
}

stock scheduleBanChecks(id)
{
    removeBanCheckTasks(id);

    set_task(0.2, "taskBanCheckA", TASK_CHECK_A + id);
    set_task(1.0, "taskBanCheckB", TASK_CHECK_B + id);
    set_task(2.0, "taskBanCheckC", TASK_CHECK_C + id);
}

stock removeBanCheckTasks(id)
{
    if (task_exists(TASK_CHECK_A + id))
    {
        remove_task(TASK_CHECK_A + id);
    }

    if (task_exists(TASK_CHECK_B + id))
    {
        remove_task(TASK_CHECK_B + id);
    }

    if (task_exists(TASK_CHECK_C + id))
    {
        remove_task(TASK_CHECK_C + id);
    }
}

public taskBanCheckA(taskid)
{
    new id = taskid - TASK_CHECK_A;
    if (is_user_connected(id))
    {
        checkPlayerBan(id);
    }
}

public taskBanCheckB(taskid)
{
    new id = taskid - TASK_CHECK_B;
    if (is_user_connected(id))
    {
        checkPlayerBan(id);
    }
}

public taskBanCheckC(taskid)
{
    new id = taskid - TASK_CHECK_C;
    if (is_user_connected(id))
    {
        checkPlayerBan(id);
    }
}

/* =========================================================
   HELPERS
========================================================= */

stock sql_escape(dest[], len, const source[])
{
    new i, j, ch;

    for (i = 0, j = 0; source[i] != 0 && j < len - 1; i++)
    {
        ch = source[i];

        if (ch == 39)
        {
            if (j < len - 2)
            {
                dest[j++] = 39;
                dest[j++] = 39;
            }
            else
            {
                break;
            }
        }
        else if (ch == 92)
        {
            if (j < len - 2)
            {
                dest[j++] = 92;
                dest[j++] = 92;
            }
            else
            {
                break;
            }
        }
        else
        {
            dest[j++] = ch;
        }
    }

    dest[j] = 0;
}

stock parse_ip_parts(const ip[], part1[], len1, part2[], len2)
{
    new i, j, sec;
    new tmp[4][16];

    for (i = 0, j = 0, sec = 0; ip[i] != 0 && sec < 4; i++)
    {
        if (ip[i] == '.')
        {
            tmp[sec][j] = 0;
            sec++;
            j = 0;
            continue;
        }

        if (j < 15)
        {
            tmp[sec][j++] = ip[i];
        }
    }

    if (sec < 4)
    {
        tmp[sec][j] = 0;
    }

    copy(part1, len1, tmp[0]);
    copy(part2, len2, tmp[1]);
}

stock mask_ip(const ip[], output[], len)
{
    new p1[8], p2[8];
    parse_ip_parts(ip, p1, charsmax(p1), p2, charsmax(p2));
    formatex(output, len, "%s.%s.***.***", p1, p2);
}

stock get_text_after_token_count(const source[], skipCount, dest[], len)
{
    new i, tokenCount;

    dest[0] = 0;

    while (source[i] != 0 && tokenCount < skipCount)
    {
        while (source[i] == ' ' || source[i] == '^t')
        {
            i++;
        }

        if (source[i] == 0)
        {
            return;
        }

        if (source[i] == '^"')
        {
            i++;

            while (source[i] != 0)
            {
                if (source[i] == '^"')
                {
                    i++;
                    break;
                }
                i++;
            }
        }
        else
        {
            while (source[i] != 0 && source[i] != ' ' && source[i] != '^t')
            {
                i++;
            }
        }

        tokenCount++;
    }

    while (source[i] == ' ' || source[i] == '^t')
    {
        i++;
    }

    copy(dest, len, source[i]);
    trim(dest);
    remove_quotes(dest);
}

stock get_first_token(const source[], dest[], len)
{
    new i, j;

    while (source[i] == ' ' || source[i] == '^t')
    {
        i++;
    }

    if (source[i] == '^"')
    {
        i++;
        while (source[i] != 0 && source[i] != '^"' && j < len - 1)
        {
            dest[j++] = source[i++];
        }
    }
    else
    {
        while (source[i] != 0 && source[i] != ' ' && source[i] != '^t' && j < len - 1)
        {
            dest[j++] = source[i++];
        }
    }

    dest[j] = 0;
}

stock get_second_token(const source[], dest[], len)
{
    new i, j, tokenCount;

    while (source[i] != 0 && tokenCount < 1)
    {
        while (source[i] == ' ' || source[i] == '^t')
        {
            i++;
        }

        if (source[i] == 0)
        {
            dest[0] = 0;
            return;
        }

        if (source[i] == '^"')
        {
            i++;

            while (source[i] != 0)
            {
                if (source[i] == '^"')
                {
                    i++;
                    break;
                }
                i++;
            }
        }
        else
        {
            while (source[i] != 0 && source[i] != ' ' && source[i] != '^t')
            {
                i++;
            }
        }

        tokenCount++;
    }

    while (source[i] == ' ' || source[i] == '^t')
    {
        i++;
    }

    if (source[i] == '^"')
    {
        i++;
        while (source[i] != 0 && source[i] != '^"' && j < len - 1)
        {
            dest[j++] = source[i++];
        }
    }
    else
    {
        while (source[i] != 0 && source[i] != ' ' && source[i] != '^t' && j < len - 1)
        {
            dest[j++] = source[i++];
        }
    }

    dest[j] = 0;
}

/* =========================================================
   LOCAL CACHE
========================================================= */

stock clearExpiredLocalBans()
{
    new now = get_systime();
    new i;

    for (i = 0; i < LOCAL_BAN_SLOTS; i++)
    {
        if (!g_bLocalBanUsed[i])
        {
            continue;
        }

        if (g_iLocalBanUntil[i] != 0 && g_iLocalBanUntil[i] <= now)
        {
            g_bLocalBanUsed[i] = false;
            g_szLocalBanNick[i][0] = 0;
            g_szLocalBanSteam[i][0] = 0;
            g_szLocalBanIp[i][0] = 0;
            g_szLocalBanReason[i][0] = 0;
            g_szLocalBanAdmin[i][0] = 0;
            g_szLocalBanAdminSteam[i][0] = 0;
            g_szLocalBanCreated[i][0] = 0;
            g_szLocalBanExpires[i][0] = 0;
            g_iLocalBanMinutes[i] = 0;
            g_iLocalBanUntil[i] = 0;
        }
    }
}

stock addLocalBanCache(const nick[], const steamid[], const ip[], const admin[], const adminSteam[], const reason[], minutes)
{
    clearExpiredLocalBans();

    new i, slot = -1;
    new now = get_systime();

    for (i = 0; i < LOCAL_BAN_SLOTS; i++)
    {
        if (!g_bLocalBanUsed[i])
        {
            slot = i;
            break;
        }
    }

    if (slot == -1)
    {
        slot = 0;
    }

    g_bLocalBanUsed[slot] = true;
    copy(g_szLocalBanNick[slot], charsmax(g_szLocalBanNick[]), nick);
    copy(g_szLocalBanSteam[slot], charsmax(g_szLocalBanSteam[]), steamid);
    copy(g_szLocalBanIp[slot], charsmax(g_szLocalBanIp[]), ip);
    copy(g_szLocalBanReason[slot], charsmax(g_szLocalBanReason[]), reason);
    copy(g_szLocalBanAdmin[slot], charsmax(g_szLocalBanAdmin[]), admin);
    copy(g_szLocalBanAdminSteam[slot], charsmax(g_szLocalBanAdminSteam[]), adminSteam);
    g_iLocalBanMinutes[slot] = minutes;

    format_time(g_szLocalBanCreated[slot], charsmax(g_szLocalBanCreated[]), "%Y-%m-%d %H:%M:%S", now);

    if (minutes <= 0)
    {
        g_iLocalBanUntil[slot] = 0;
        copy(g_szLocalBanExpires[slot], charsmax(g_szLocalBanExpires[]), "Sinirsiz");
    }
    else
    {
        g_iLocalBanUntil[slot] = now + (minutes * 60);
        format_time(g_szLocalBanExpires[slot], charsmax(g_szLocalBanExpires[]), "%Y-%m-%d %H:%M:%S", g_iLocalBanUntil[slot]);
    }
}

stock setLocalBanInactiveByText(const target[])
{
    new i;
    for (i = 0; i < LOCAL_BAN_SLOTS; i++)
    {
        if (!g_bLocalBanUsed[i])
        {
            continue;
        }

        if (equal(g_szLocalBanNick[i], target) || equal(g_szLocalBanSteam[i], target) || equal(g_szLocalBanIp[i], target))
        {
            g_bLocalBanUsed[i] = false;
            g_szLocalBanNick[i][0] = 0;
            g_szLocalBanSteam[i][0] = 0;
            g_szLocalBanIp[i][0] = 0;
            g_szLocalBanReason[i][0] = 0;
            g_szLocalBanAdmin[i][0] = 0;
            g_szLocalBanAdminSteam[i][0] = 0;
            g_szLocalBanCreated[i][0] = 0;
            g_szLocalBanExpires[i][0] = 0;
            g_iLocalBanMinutes[i] = 0;
            g_iLocalBanUntil[i] = 0;
        }
    }
}

stock clearAllLocalBans()
{
    new i;

    for (i = 0; i < LOCAL_BAN_SLOTS; i++)
    {
        g_bLocalBanUsed[i] = false;
        g_szLocalBanNick[i][0] = 0;
        g_szLocalBanSteam[i][0] = 0;
        g_szLocalBanIp[i][0] = 0;
        g_szLocalBanReason[i][0] = 0;
        g_szLocalBanAdmin[i][0] = 0;
        g_szLocalBanAdminSteam[i][0] = 0;
        g_szLocalBanCreated[i][0] = 0;
        g_szLocalBanExpires[i][0] = 0;
        g_iLocalBanMinutes[i] = 0;
        g_iLocalBanUntil[i] = 0;
    }
}

stock bool:findLocalBanMatch(const steamid[], const ip[], const nick[], reason[], rlen, admin[], alen, created[], clen, expires[], elen, &minutes)
{
    clearExpiredLocalBans();

    new i;
    for (i = 0; i < LOCAL_BAN_SLOTS; i++)
    {
        if (!g_bLocalBanUsed[i])
        {
            continue;
        }

        if (g_szLocalBanSteam[i][0] && equal(g_szLocalBanSteam[i], steamid))
        {
            copy(reason, rlen, g_szLocalBanReason[i]);
            copy(admin, alen, g_szLocalBanAdmin[i]);
            copy(created, clen, g_szLocalBanCreated[i]);
            copy(expires, elen, g_szLocalBanExpires[i]);
            minutes = g_iLocalBanMinutes[i];
            return true;
        }

        if (g_szLocalBanIp[i][0] && equal(g_szLocalBanIp[i], ip))
        {
            copy(reason, rlen, g_szLocalBanReason[i]);
            copy(admin, alen, g_szLocalBanAdmin[i]);
            copy(created, clen, g_szLocalBanCreated[i]);
            copy(expires, elen, g_szLocalBanExpires[i]);
            minutes = g_iLocalBanMinutes[i];
            return true;
        }

        if (g_iCheckNick && g_szLocalBanNick[i][0] && equal(g_szLocalBanNick[i], nick))
        {
            copy(reason, rlen, g_szLocalBanReason[i]);
            copy(admin, alen, g_szLocalBanAdmin[i]);
            copy(created, clen, g_szLocalBanCreated[i]);
            copy(expires, elen, g_szLocalBanExpires[i]);
            minutes = g_iLocalBanMinutes[i];
            return true;
        }
    }

    return false;
}

/* =========================================================
   BAN CHECK / ANNOUNCE
========================================================= */

stock announceBanAttempt(id, const steamid[], const reason[], const createdAt[], const expiresAt[], const adminNick[])
{
    if (!g_iInfoMessage)
    {
        return;
    }

    new currentName[32], currentIp[32], maskedIp[32];
    get_user_name(id, currentName, charsmax(currentName));
    get_user_ip(id, currentIp, charsmax(currentIp), 1);
    mask_ip(currentIp, maskedIp, charsmax(maskedIp));

    CC_Send(0, "^4%s^1 -------------------- ^3Banli Giris^1 --------------------", g_szChatTag);
    CC_Send(0, "^4%s^3 IP:^1 %s ^3| Nick:^1 %s ^3| Oyuncu ID:^1 %s", g_szChatTag, maskedIp, currentName, steamid);
    CC_Send(0, "^4%s^3 Sebep:^1 %s", g_szChatTag, reason);
    CC_Send(0, "^4%s^3 Ban:^1 %s ^3| unBan:^1 %s", g_szChatTag, createdAt, expiresAt);
    CC_Send(0, "^4%s^3 Admin:^1 %s", g_szChatTag, adminNick);
}

stock forceKickBannedPlayer(id, const reason[], minutes)
{
    new kickMsg[256];

    if (minutes <= 0)
    {
        formatex(kickMsg, charsmax(kickMsg), "Sunucudan sinirsiz banlandiniz. Sebep: %s | %s", reason, g_szDropMessage);
    }
    else
    {
        formatex(kickMsg, charsmax(kickMsg), "Sunucudan %d dakika banlandiniz. Sebep: %s | %s", minutes, reason, g_szDropMessage);
    }

    server_cmd("kick #%d ^"%s^"", get_user_userid(id), kickMsg);
    server_exec();
}

stock checkPlayerBan(id)
{
    if (!is_user_connected(id))
    {
        return;
    }

    new authid[MAX_AUTH_LEN], ip[MAX_IP_LEN], name[MAX_NAME_LEN];
    get_user_authid(id, authid, charsmax(authid));
    get_user_ip(id, ip, charsmax(ip), 1);
    get_user_name(id, name, charsmax(name));

    new lReason[MAX_REASON_LEN], lAdmin[32], lCreated[32], lExpires[32], lMinutes;
    if (findLocalBanMatch(authid, ip, name, lReason, charsmax(lReason), lAdmin, charsmax(lAdmin), lCreated, charsmax(lCreated), lExpires, charsmax(lExpires), lMinutes))
    {
        announceBanAttempt(id, authid, lReason, lCreated, lExpires, lAdmin);
        forceKickBannedPlayer(id, lReason, lMinutes);
        return;
    }

    if (g_SqlTuple == Empty_Handle)
    {
        sqlReconnect();
    }

    new escAuth[96], escIp[96], escName[96], query[3072];
    sql_escape(escAuth, charsmax(escAuth), authid);
    sql_escape(escIp, charsmax(escIp), ip);
    sql_escape(escName, charsmax(escName), name);

    if (g_iCheckNick)
    {
        formatex(query, charsmax(query),
            "SELECT `reason`,`ban_minutes`,`player_steamid`,`admin_nick`,\
            DATE_FORMAT(`created_at`,'%%Y-%%m-%%d %%H:%%i:%%s'),\
            IFNULL(DATE_FORMAT(`expires_at`,'%%Y-%%m-%%d %%H:%%i:%%s'),'Sinirsiz') \
            FROM `%s` \
            WHERE `active`=1 AND (\
                (`player_steamid`='%s' AND `player_steamid`!='') OR \
                (`player_ip`='%s' AND `player_ip`!='') OR \
                (`player_nick`='%s' AND `player_nick`!='')\
            ) AND (`ban_minutes`=0 OR `expires_at` IS NULL OR `expires_at` > NOW()) \
            ORDER BY `id` DESC LIMIT 1;",
            g_szSqlTable, escAuth, escIp, escName
        );
    }
    else
    {
        formatex(query, charsmax(query),
            "SELECT `reason`,`ban_minutes`,`player_steamid`,`admin_nick`,\
            DATE_FORMAT(`created_at`,'%%Y-%%m-%%d %%H:%%i:%%s'),\
            IFNULL(DATE_FORMAT(`expires_at`,'%%Y-%%m-%%d %%H:%%i:%%s'),'Sinirsiz') \
            FROM `%s` \
            WHERE `active`=1 AND (\
                (`player_steamid`='%s' AND `player_steamid`!='') OR \
                (`player_ip`='%s' AND `player_ip`!='')\
            ) AND (`ban_minutes`=0 OR `expires_at` IS NULL OR `expires_at` > NOW()) \
            ORDER BY `id` DESC LIMIT 1;",
            g_szSqlTable, escAuth, escIp
        );
    }

    new data[1];
    data[0] = get_user_userid(id);
    SQL_ThreadQuery(g_SqlTuple, "queryCheckBanHandler", query, data, sizeof(data));
}

public queryCheckBanHandler(FailState, Handle:Query, Error[], Errcode, Data[], DataSize)
{
    if (FailState != TQUERY_SUCCESS)
    {
        log_amx("[CSA-SQL Ban] Ban kontrol SQL hatasi: %s (%d)", Error, Errcode);
        return;
    }

    new id = find_player("k", Data[0]);
    if (!id || !is_user_connected(id))
    {
        return;
    }

    if (!SQL_NumResults(Query))
    {
        return;
    }

    new reason[MAX_REASON_LEN], banSteam[35], adminNick[32], createdAt[32], expiresAt[32];
    new banMinutes = SQL_ReadResult(Query, 1);

    SQL_ReadResult(Query, 0, reason, charsmax(reason));
    SQL_ReadResult(Query, 2, banSteam, charsmax(banSteam));
    SQL_ReadResult(Query, 3, adminNick, charsmax(adminNick));
    SQL_ReadResult(Query, 4, createdAt, charsmax(createdAt));
    SQL_ReadResult(Query, 5, expiresAt, charsmax(expiresAt));

    announceBanAttempt(id, banSteam, reason, createdAt, expiresAt, adminNick);
    forceKickBannedPlayer(id, reason, banMinutes);
}

/* =========================================================
   COMMANDS
========================================================= */

public cmdCssBan(id)
{
    if (!hasBanAccess(id))
    {
        return PLUGIN_HANDLED;
    }

    new allArgs[256], argTarget[64], argMinutes[16], argReason[MAX_REASON_LEN];
    read_args(allArgs, charsmax(allArgs));
    trim(allArgs);

    read_argv(1, argTarget, charsmax(argTarget));
    read_argv(2, argMinutes, charsmax(argMinutes));
    get_text_after_token_count(allArgs, 2, argReason, charsmax(argReason));

    remove_quotes(argTarget);
    remove_quotes(argMinutes);
    trim(argTarget);
    trim(argMinutes);
    trim(argReason);

    if (!argTarget[0] || !argMinutes[0])
    {
        if (id)
        {
            console_print(id, "Kullanim: csa_ban <nick/#userid> <dakika> [sebep]");
        }
        return PLUGIN_HANDLED;
    }

    new minutes = str_to_num(argMinutes);
    if (minutes < 0)
    {
        if (id)
        {
            console_print(id, "Sure 0 veya daha buyuk olmali.");
        }
        return PLUGIN_HANDLED;
    }

    if (!argReason[0])
    {
        copy(argReason, charsmax(argReason), "Yetkili tarafindan yasaklandi.");
    }

    new target = cmd_target(id, argTarget, CMDTARGET_OBEY_IMMUNITY | CMDTARGET_NO_BOTS);
    if (!target)
    {
        if (id)
        {
            console_print(id, "Oyuncu bulunamadi: %s", argTarget);
        }
        return PLUGIN_HANDLED;
    }

    doBanPlayerOnline(id, target, minutes, argReason);
    return PLUGIN_HANDLED;
}

public cmdCssUnban(id)
{
    if (!hasUnbanAccess(id))
    {
        return PLUGIN_HANDLED;
    }

    new target[64];
    read_argv(1, target, charsmax(target));
    remove_quotes(target);
    trim(target);

    if (!target[0])
    {
        if (id)
        {
            console_print(id, "Kullanim: csa_unban <nick/authid/ip>");
        }
        return PLUGIN_HANDLED;
    }

    doNormalUnbanByText(id, target);
    return PLUGIN_HANDLED;
}

public cmdCssBanMenu(id)
{
    if (!hasBanAccess(id))
    {
        return PLUGIN_HANDLED;
    }

    showBanPlayerMenu(id);
    return PLUGIN_HANDLED;
}

public cmdCssUnbanMenu(id)
{
    if (!hasUnbanAccess(id))
    {
        return PLUGIN_HANDLED;
    }

    showUnbanMenu(id);
    return PLUGIN_HANDLED;
}

public cmdCssSqlMenu(id)
{
    if (!hasSqlMenuAccess(id))
    {
        return PLUGIN_HANDLED;
    }

    showSqlCleanupMainMenu(id);
    return PLUGIN_HANDLED;
}

/* =========================================================
   SAY COMMANDS
========================================================= */

public hookSay(id)
{
    if (!is_user_connected(id))
    {
        return PLUGIN_CONTINUE;
    }

    new text[192];
    read_args(text, charsmax(text));
    remove_quotes(text);
    trim(text);

    if (!text[0])
    {
        return PLUGIN_CONTINUE;
    }

    if (equali(text, "!bm") || equali(text, ".bm") || equali(text, "/bm")
    || equali(text, "!banmenu") || equali(text, ".banmenu") || equali(text, "/banmenu"))
    {
        if (hasBanAccess(id))
        {
            showBanPlayerMenu(id);
        }
        return PLUGIN_HANDLED;
    }

    if (equali(text, "!ubm") || equali(text, ".ubm") || equali(text, "/ubm")
    || equali(text, "!unbanmenu") || equali(text, ".unbanmenu") || equali(text, "/unbanmenu"))
    {
        if (hasUnbanAccess(id))
        {
            showUnbanMenu(id);
        }
        return PLUGIN_HANDLED;
    }

    if (equali(text, "!sqlban") || equali(text, ".sqlban") || equali(text, "/sqlban")
    || equali(text, "!sqlmenu") || equali(text, ".sqlmenu") || equali(text, "/sqlmenu"))
    {
        if (hasSqlMenuAccess(id))
        {
            showSqlCleanupMainMenu(id);
        }
        return PLUGIN_HANDLED;
    }

    if (containi(text, ".ban ") == 0 || containi(text, "!ban ") == 0 || containi(text, "/ban ") == 0)
    {
        if (hasBanAccess(id))
        {
            handleSayBan(id, text);
        }
        return PLUGIN_HANDLED;
    }

    if (containi(text, ".unban ") == 0 || containi(text, "!unban ") == 0 || containi(text, "/unban ") == 0
    || containi(text, ".ub ") == 0 || containi(text, "!ub ") == 0 || containi(text, "/ub ") == 0)
    {
        if (hasUnbanAccess(id))
        {
            handleSayUnban(id, text);
        }
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public handleSayBan(id, const text[])
{
    new cmd[16], arg1[64], arg2[16], reason[MAX_REASON_LEN];

    get_first_token(text, cmd, charsmax(cmd));
    get_second_token(text, arg1, charsmax(arg1));
    get_text_after_token_count(text, 2, reason, charsmax(reason));

    get_first_token(reason, arg2, charsmax(arg2));
    get_text_after_token_count(text, 3, reason, charsmax(reason));

    if (!arg1[0] || !arg2[0])
    {
        CC_Send(id, "^4%s^1 Kullanim:^3 .ban nick dakika [sebep]", g_szChatTag);
        return;
    }

    new target = cmd_target(id, arg1, CMDTARGET_OBEY_IMMUNITY | CMDTARGET_NO_BOTS);
    if (!target)
    {
        CC_Send(id, "^4%s^1 Oyuncu bulunamadi:^3 %s", g_szChatTag, arg1);
        return;
    }

    new minutes = str_to_num(arg2);
    if (minutes < 0)
    {
        CC_Send(id, "^4%s^1 Sure 0 veya daha buyuk olmali.", g_szChatTag);
        return;
    }

    if (!reason[0])
    {
        copy(reason, charsmax(reason), "Yetkili tarafindan yasaklandi.");
    }

    doBanPlayerOnline(id, target, minutes, reason);
}

public handleSayUnban(id, const text[])
{
    new cmd[16], arg1[64];
    get_first_token(text, cmd, charsmax(cmd));
    get_second_token(text, arg1, charsmax(arg1));

    if (!arg1[0])
    {
        CC_Send(id, "^4%s^1 Kullanim:^3 .unban nick", g_szChatTag);
        return;
    }

    doNormalUnbanByText(id, arg1);
}

/* =========================================================
   MANUAL REASON
========================================================= */

public cmdManualBanReason(id)
{
    if (!is_user_connected(id))
    {
        return PLUGIN_HANDLED;
    }

    if (!g_bAwaitManualReason[id])
    {
        return PLUGIN_HANDLED;
    }

    new text[MAX_REASON_LEN];
    read_args(text, charsmax(text));
    remove_quotes(text);
    trim(text);

    if (!text[0])
    {
        CC_Send(id, "^4%s^1 Manuel sebep bos olamaz.", g_szChatTag);
        showBanReasonMenu(id);
        return PLUGIN_HANDLED;
    }

    new target = g_iMenuTarget[id];
    new minutes = g_iMenuBanMinutes[id];

    g_bAwaitManualReason[id] = false;

    if (!target || !is_user_connected(target))
    {
        CC_Send(id, "^4%s^1 Hedef oyuncu oyundan cikmis.", g_szChatTag);
        return PLUGIN_HANDLED;
    }

    doBanPlayerOnline(id, target, minutes, text);
    return PLUGIN_HANDLED;
}

/* =========================================================
   BAN MENU
========================================================= */

public showBanPlayerMenu(id)
{
    new menu = menu_create("\rCSA-SQL Ban Menu\w - Oyuncu Sec", "menuBanPlayerHandler");

    new players[32], pnum, i, target;
    new name[32], info[8];
    new added;

    get_players(players, pnum, "ch");

    for (i = 0; i < pnum; i++)
    {
        target = players[i];

        if (target == id)
        {
            continue;
        }

        get_user_name(target, name, charsmax(name));
        num_to_str(target, info, charsmax(info));
        menu_additem(menu, name, info);
        added++;
    }

    if (!added)
    {
        menu_additem(menu, "Uygun oyuncu yok", "0");
    }

    menu_setprop(menu, MPROP_EXITNAME, "Cikis");
    menu_display(id, menu, 0);
}

public menuBanPlayerHandler(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new info[8], dummyName[64], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), dummyName, charsmax(dummyName), callback);
    menu_destroy(menu);

    new target = str_to_num(info);
    if (target <= 0 || !is_user_connected(target))
    {
        CC_Send(id, "^4%s^1 Oyuncu oyunda degil.", g_szChatTag);
        return PLUGIN_HANDLED;
    }

    g_iMenuTarget[id] = target;
    g_iMenuBanMinutes[id] = 0;
    g_bAwaitManualReason[id] = false;

    showBanTimeMenu(id);
    return PLUGIN_HANDLED;
}

public showBanTimeMenu(id)
{
    new title[128], targetName[32];
    new target = g_iMenuTarget[id];

    if (!target || !is_user_connected(target))
    {
        CC_Send(id, "^4%s^1 Hedef oyuncu bulunamadi.", g_szChatTag);
        return;
    }

    get_user_name(target, targetName, charsmax(targetName));
    formatex(title, charsmax(title), "\rCSA-SQL Ban Menu\w - Sure Sec^n\yHedef: \w%s", targetName);

    new menu = menu_create(title, "menuBanTimeHandler");
    menu_additem(menu, "Varsayilan Sure", "-1");
    menu_additem(menu, "5 Dakika", "5");
    menu_additem(menu, "30 Dakika", "30");
    menu_additem(menu, "60 Dakika", "60");
    menu_additem(menu, "120 Dakika", "120");
    menu_additem(menu, "Sinirsiz", "0");

    menu_setprop(menu, MPROP_EXITNAME, "Cikis");
    menu_display(id, menu, 0);
}

public menuBanTimeHandler(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new info[16], dummyName[64], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), dummyName, charsmax(dummyName), callback);
    menu_destroy(menu);

    new target = g_iMenuTarget[id];
    if (!target || !is_user_connected(target))
    {
        CC_Send(id, "^4%s^1 Hedef oyuncu oyundan cikmis.", g_szChatTag);
        return PLUGIN_HANDLED;
    }

    new minutes = str_to_num(info);
    if (minutes == -1)
    {
        minutes = g_iDefBanMinutes;
    }

    if (minutes < 0)
    {
        minutes = 0;
    }

    g_iMenuBanMinutes[id] = minutes;
    showBanReasonMenu(id);
    return PLUGIN_HANDLED;
}

public showBanReasonMenu(id)
{
    new target = g_iMenuTarget[id];
    if (!target || !is_user_connected(target))
    {
        CC_Send(id, "^4%s^1 Hedef oyuncu bulunamadi.", g_szChatTag);
        return;
    }

    new title[128], targetName[32], info[8];
    get_user_name(target, targetName, charsmax(targetName));
    formatex(title, charsmax(title), "\rCSA-SQL Ban Menu\w - Sebep Sec^n\yHedef: \w%s", targetName);

    new menu = menu_create(title, "menuBanReasonHandler");

    new i;
    for (i = 0; i < g_iReasonCount; i++)
    {
        num_to_str(i, info, charsmax(info));
        menu_additem(menu, g_szReasonList[i], info);
    }

    menu_additem(menu, "\yManuel Sebep Gir", "999");

    menu_setprop(menu, MPROP_EXITNAME, "Cikis");
    menu_display(id, menu, 0);
}

public menuBanReasonHandler(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new info[8], dummyName[64], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), dummyName, charsmax(dummyName), callback);
    menu_destroy(menu);

    new target = g_iMenuTarget[id];
    new minutes = g_iMenuBanMinutes[id];

    if (!target || !is_user_connected(target))
    {
        CC_Send(id, "^4%s^1 Hedef oyuncu oyundan cikmis.", g_szChatTag);
        return PLUGIN_HANDLED;
    }

    new idx = str_to_num(info);

    if (idx == 999)
    {
        g_bAwaitManualReason[id] = true;
        CC_Send(id, "^4%s^1 Manuel sebep giriniz...", g_szChatTag);
        client_cmd(id, "messagemode csa_ban_reason");
        return PLUGIN_HANDLED;
    }

    if (idx < 0 || idx >= g_iReasonCount)
    {
        CC_Send(id, "^4%s^1 Gecersiz sebep secimi.", g_szChatTag);
        return PLUGIN_HANDLED;
    }

    doBanPlayerOnline(id, target, minutes, g_szReasonList[idx]);
    return PLUGIN_HANDLED;
}

/* =========================================================
   NORMAL UNBAN MENU
========================================================= */

public showUnbanMenu(id)
{
    if (g_SqlTuple == Empty_Handle)
    {
        sqlReconnect();
    }

    new query[1536];
    formatex(query, charsmax(query),
        "SELECT `id`,`player_nick`,`player_steamid`,`ban_minutes` \
        FROM `%s` \
        WHERE `active`=1 AND (`ban_minutes`=0 OR `expires_at` IS NULL OR `expires_at` > NOW()) \
        ORDER BY `id` DESC LIMIT 50;",
        g_szSqlTable
    );

    new data[1];
    data[0] = get_user_userid(id);
    SQL_ThreadQuery(g_SqlTuple, "queryShowUnbanMenuHandler", query, data, sizeof(data));
}

public queryShowUnbanMenuHandler(FailState, Handle:Query, Error[], Errcode, Data[], DataSize)
{
    if (FailState != TQUERY_SUCCESS)
    {
        log_amx("[CSA-SQL Ban] Unban menu SQL hatasi: %s (%d)", Error, Errcode);
        return;
    }

    new id = find_player("k", Data[0]);
    if (!id || !is_user_connected(id))
    {
        return;
    }

    new menu = menu_create("\rKCS Unban Menu\w - Normal Unban", "menuUnbanHandler");
    new text[192], info[16];

    if (!SQL_NumResults(Query))
    {
        menu_additem(menu, "Aktif ban bulunamadi", "0");
    }
    else
    {
        new banId, playerNick[32], steamid[35], banMinutes;

        while (SQL_MoreResults(Query))
        {
            banId = SQL_ReadResult(Query, 0);
            SQL_ReadResult(Query, 1, playerNick, charsmax(playerNick));
            SQL_ReadResult(Query, 2, steamid, charsmax(steamid));
            banMinutes = SQL_ReadResult(Query, 3);

            if (banMinutes == 0)
            {
                formatex(text, charsmax(text), "%s | %s | Sinirsiz", playerNick, steamid);
            }
            else
            {
                formatex(text, charsmax(text), "%s | %s | %d dk", playerNick, steamid, banMinutes);
            }

            num_to_str(banId, info, charsmax(info));
            menu_additem(menu, text, info);

            SQL_NextRow(Query);
        }
    }

    menu_setprop(menu, MPROP_EXITNAME, "Cikis");
    menu_display(id, menu, 0);
}

public menuUnbanHandler(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new info[16], dummyName[128], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), dummyName, charsmax(dummyName), callback);
    menu_destroy(menu);

    new banId = str_to_num(info);
    if (banId <= 0)
    {
        CC_Send(id, "^4%s^1 Gecerli aktif ban bulunamadi.", g_szChatTag);
        return PLUGIN_HANDLED;
    }

    doNormalUnbanById(id, banId);
    return PLUGIN_HANDLED;
}

/* =========================================================
   SQL CLEANUP MENU
========================================================= */

public showSqlCleanupMainMenu(id)
{
    new menu = menu_create("\rKCS SQL Temizleme Menu", "menuSqlCleanupMainHandler");
    menu_additem(menu, "SQL Kayit Menusu", "1");
    menu_additem(menu, "Pasif Kayitlari Temizle", "2");
    menu_additem(menu, "Suresi Dolanlari Temizle", "3");
    menu_additem(menu, "Tum SQL Kayitlarini Sil", "4");
    menu_additem(menu, "Tum Local Cache Temizle", "5");

    menu_setprop(menu, MPROP_EXITNAME, "Cikis");
    menu_display(id, menu, 0);
}

public menuSqlCleanupMainHandler(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new info[8], dummyName[64], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), dummyName, charsmax(dummyName), callback);
    menu_destroy(menu);

    switch (str_to_num(info))
    {
        case 1:
        {
            if (!hasSqlDeleteAccess(id))
            {
                return PLUGIN_HANDLED;
            }
            showSqlDeleteMenu(id);
        }
        case 2:
        {
            if (!hasSqlDeleteAccess(id))
            {
                return PLUGIN_HANDLED;
            }
            purgePassiveSqlBans(id);
        }
        case 3:
        {
            if (!hasSqlDeleteAccess(id))
            {
                return PLUGIN_HANDLED;
            }
            purgeExpiredSqlBans(id);
        }
        case 4:
        {
            if (!hasSqlDeleteAccess(id))
            {
                return PLUGIN_HANDLED;
            }
            purgeAllSqlBans(id);
        }
        case 5:
        {
            clearAllLocalBans();
            CC_Send(id, "^4%s^1 Tum local cache temizlendi.", g_szChatTag);
        }
    }

    return PLUGIN_HANDLED;
}

public showSqlDeleteMenu(id)
{
    if (g_SqlTuple == Empty_Handle)
    {
        sqlReconnect();
    }

    new query[1536];
    formatex(query, charsmax(query),
        "SELECT `id`,`player_nick`,`player_steamid`,`active`,`ban_minutes` \
        FROM `%s` \
        ORDER BY `id` DESC LIMIT 50;",
        g_szSqlTable
    );

    new data[1];
    data[0] = get_user_userid(id);
    SQL_ThreadQuery(g_SqlTuple, "queryShowSqlDeleteMenuHandler", query, data, sizeof(data));
}

public queryShowSqlDeleteMenuHandler(FailState, Handle:Query, Error[], Errcode, Data[], DataSize)
{
    if (FailState != TQUERY_SUCCESS)
    {
        log_amx("[CSA-SQL Ban] SQL delete menu hatasi: %s (%d)", Error, Errcode);
        return;
    }

    new id = find_player("k", Data[0]);
    if (!id || !is_user_connected(id))
    {
        return;
    }

    new menu = menu_create("\rKCS SQL Kayit Menusu\w - Fiziksel Sil", "menuSqlDeleteHandler");
    new text[192];
    new info[16];

    if (!SQL_NumResults(Query))
    {
        menu_additem(menu, "SQL kayit bulunamadi", "0");
    }
    else
    {
        new banId;
        new playerNick[32];
        new steamid[35];
        new active;
        new minutes;
        new szState[16];

        while (SQL_MoreResults(Query))
        {
            banId = SQL_ReadResult(Query, 0);
            SQL_ReadResult(Query, 1, playerNick, charsmax(playerNick));
            SQL_ReadResult(Query, 2, steamid, charsmax(steamid));
            active = SQL_ReadResult(Query, 3);
            minutes = SQL_ReadResult(Query, 4);

            if (active != 0)
            {
                copy(szState, charsmax(szState), "Aktif");
            }
            else
            {
                copy(szState, charsmax(szState), "Pasif");
            }

            if (minutes == 0)
            {
                formatex(text, charsmax(text), "[%s] %s | %s | Sinirsiz", szState, playerNick, steamid);
            }
            else
            {
                formatex(text, charsmax(text), "[%s] %s | %s | %d dk", szState, playerNick, steamid, minutes);
            }

            num_to_str(banId, info, charsmax(info));
            menu_additem(menu, text, info);

            SQL_NextRow(Query);
        }
    }

    menu_setprop(menu, MPROP_EXITNAME, "Cikis");
    menu_display(id, menu, 0);
}

public menuSqlDeleteHandler(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new info[16], dummyName[128], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), dummyName, charsmax(dummyName), callback);
    menu_destroy(menu);

    new banId = str_to_num(info);
    if (banId <= 0)
    {
        CC_Send(id, "^4%s^1 Gecerli SQL kaydi bulunamadi.", g_szChatTag);
        return PLUGIN_HANDLED;
    }

    doSqlDeleteById(id, banId);
    return PLUGIN_HANDLED;
}

/* =========================================================
   BAN / UNBAN / DELETE OPERATIONS
========================================================= */

stock doBanPlayerOnline(admin, target, minutes, const reason[])
{
    if (!is_user_connected(target))
    {
        return;
    }

    if (admin == target)
    {
        if (admin)
        {
            CC_Send(admin, "^4%s^1 Kendinizi banlayamazsiniz.", g_szChatTag);
        }
        return;
    }

    if (admin > 0 && (get_user_flags(target) & ADMIN_IMMUNITY) && !(get_user_flags(admin) & ADMIN_RCON))
    {
        CC_Send(admin, "^4%s^1 Bu oyuncuda immunity var.", g_szChatTag);
        return;
    }

    if (g_SqlTuple == Empty_Handle)
    {
        sqlReconnect();
    }

    new playerName[32], playerAuth[MAX_AUTH_LEN], playerIp[MAX_IP_LEN];
    new adminName[32], adminAuth[MAX_AUTH_LEN];
    new serverIp[64], serverPort[16];

    get_user_name(target, playerName, charsmax(playerName));
    get_user_authid(target, playerAuth, charsmax(playerAuth));
    get_user_ip(target, playerIp, charsmax(playerIp), 1);

    if (admin > 0 && is_user_connected(admin))
    {
        get_user_name(admin, adminName, charsmax(adminName));
        get_user_authid(admin, adminAuth, charsmax(adminAuth));
    }
    else
    {
        copy(adminName, charsmax(adminName), "Console");
        copy(adminAuth, charsmax(adminAuth), "SERVER");
    }

    get_cvar_string("ip", serverIp, charsmax(serverIp));
    get_cvar_string("port", serverPort, charsmax(serverPort));

    addLocalBanCache(playerName, playerAuth, playerIp, adminName, adminAuth, reason, minutes);

    new escPlayerName[96], escPlayerAuth[96], escPlayerIp[96];
    new escAdminName[96], escAdminAuth[96], escReason[256], escServerIp[96];

    sql_escape(escPlayerName, charsmax(escPlayerName), playerName);
    sql_escape(escPlayerAuth, charsmax(escPlayerAuth), playerAuth);
    sql_escape(escPlayerIp, charsmax(escPlayerIp), playerIp);
    sql_escape(escAdminName, charsmax(escAdminName), adminName);
    sql_escape(escAdminAuth, charsmax(escAdminAuth), adminAuth);
    sql_escape(escReason, charsmax(escReason), reason);
    sql_escape(escServerIp, charsmax(escServerIp), serverIp);

    new query[3072];
    if (minutes == 0)
    {
        formatex(query, charsmax(query),
            "INSERT INTO `%s` \
            (`player_nick`,`player_steamid`,`player_ip`,`admin_nick`,`admin_steamid`,`reason`,`ban_minutes`,`expires_at`,`server_ip`,`server_port`,`active`) \
            VALUES ('%s','%s','%s','%s','%s','%s',0,NULL,'%s',%d,1);",
            g_szSqlTable,
            escPlayerName, escPlayerAuth, escPlayerIp,
            escAdminName, escAdminAuth, escReason,
            escServerIp, str_to_num(serverPort)
        );
    }
    else
    {
        formatex(query, charsmax(query),
            "INSERT INTO `%s` \
            (`player_nick`,`player_steamid`,`player_ip`,`admin_nick`,`admin_steamid`,`reason`,`ban_minutes`,`expires_at`,`server_ip`,`server_port`,`active`) \
            VALUES ('%s','%s','%s','%s','%s','%s',%d,DATE_ADD(NOW(), INTERVAL %d MINUTE),'%s',%d,1);",
            g_szSqlTable,
            escPlayerName, escPlayerAuth, escPlayerIp,
            escAdminName, escAdminAuth, escReason,
            minutes, minutes,
            escServerIp, str_to_num(serverPort)
        );
    }

    SQL_ThreadQuery(g_SqlTuple, "queryIgnoreHandler", query);

    if (minutes == 0)
    {
        CC_Send(0, "^4%s^3 %s^1, ^4%s^1 tarafindan ^3sinirsiz^1 banlandi. Sebep:^4 %s", g_szChatTag, playerName, adminName, reason);
    }
    else
    {
        CC_Send(0, "^4%s^3 %s^1, ^4%s^1 tarafindan ^3%d dakika^1 banlandi. Sebep:^4 %s", g_szChatTag, playerName, adminName, minutes, reason);
    }

    log_amx("[CSA-SQL Ban] Ban atildi | player=%s userid=%d steamid=%s ip=%s admin=%s sure=%d reason=%s",
        playerName, get_user_userid(target), playerAuth, playerIp, adminName, minutes, reason);

    forceKickBannedPlayer(target, reason, minutes);
}

stock doNormalUnbanByText(admin, const target[])
{
    if (g_SqlTuple == Empty_Handle)
    {
        sqlReconnect();
    }

    setLocalBanInactiveByText(target);

    new adminName[32], adminSteam[35];
    if (admin > 0 && is_user_connected(admin))
    {
        get_user_name(admin, adminName, charsmax(adminName));
        get_user_authid(admin, adminSteam, charsmax(adminSteam));
    }
    else
    {
        copy(adminName, charsmax(adminName), "Console");
        copy(adminSteam, charsmax(adminSteam), "SERVER");
    }

    new escTarget[128], escAdmin[96], escAdminSteam[96];
    sql_escape(escTarget, charsmax(escTarget), target);
    sql_escape(escAdmin, charsmax(escAdmin), adminName);
    sql_escape(escAdminSteam, charsmax(escAdminSteam), adminSteam);

    new query[3072];
    formatex(query, charsmax(query),
        "UPDATE `%s` SET `active`=0, `removed_at`=NOW(), `removed_by`='%s', `removed_by_steamid`='%s' \
        WHERE `active`=1 AND (`player_nick`='%s' OR `player_steamid`='%s' OR `player_ip`='%s');",
        g_szSqlTable, escAdmin, escAdminSteam, escTarget, escTarget, escTarget
    );

    SQL_ThreadQuery(g_SqlTuple, "queryIgnoreHandler", query);

    if (admin)
    {
        CC_Send(admin, "^4%s^1 Normal unban uygulandi. SQL kaydi silinmedi:^3 %s", g_szChatTag, target);
    }
}

stock doNormalUnbanById(admin, banId)
{
    if (g_SqlTuple == Empty_Handle)
    {
        sqlReconnect();
    }

    if (banId <= 0)
    {
        return;
    }

    new querySelect[256];
    formatex(querySelect, charsmax(querySelect),
        "SELECT `player_nick`,`player_steamid`,`player_ip` FROM `%s` WHERE `id`=%d LIMIT 1;",
        g_szSqlTable, banId
    );

    new data[2];
    data[0] = get_user_userid(admin);
    data[1] = banId;
    SQL_ThreadQuery(g_SqlTuple, "queryNormalUnbanByIdPrepare", querySelect, data, sizeof(data));
}

public queryNormalUnbanByIdPrepare(FailState, Handle:Query, Error[], Errcode, Data[], DataSize)
{
    if (FailState != TQUERY_SUCCESS)
    {
        log_amx("[CSA-SQL Ban] Normal unban prepare hatasi: %s (%d)", Error, Errcode);
        return;
    }

    new admin = find_player("k", Data[0]);
    new banId = Data[1];

    if (!SQL_NumResults(Query))
    {
        if (admin)
        {
            CC_Send(admin, "^4%s^1 SQL kaydi bulunamadi.", g_szChatTag);
        }
        return;
    }

    new nick[32], steamid[35], ip[32];
    SQL_ReadResult(Query, 0, nick, charsmax(nick));
    SQL_ReadResult(Query, 1, steamid, charsmax(steamid));
    SQL_ReadResult(Query, 2, ip, charsmax(ip));

    if (nick[0])
    {
        setLocalBanInactiveByText(nick);
    }
    if (steamid[0])
    {
        setLocalBanInactiveByText(steamid);
    }
    if (ip[0])
    {
        setLocalBanInactiveByText(ip);
    }

    new adminName[32], adminSteam[35];
    if (admin && is_user_connected(admin))
    {
        get_user_name(admin, adminName, charsmax(adminName));
        get_user_authid(admin, adminSteam, charsmax(adminSteam));
    }
    else
    {
        copy(adminName, charsmax(adminName), "Console");
        copy(adminSteam, charsmax(adminSteam), "SERVER");
    }

    new escAdmin[96], escAdminSteam[96], queryUpdate[512];
    sql_escape(escAdmin, charsmax(escAdmin), adminName);
    sql_escape(escAdminSteam, charsmax(escAdminSteam), adminSteam);

    formatex(queryUpdate, charsmax(queryUpdate),
        "UPDATE `%s` SET `active`=0, `removed_at`=NOW(), `removed_by`='%s', `removed_by_steamid`='%s' WHERE `id`=%d;",
        g_szSqlTable, escAdmin, escAdminSteam, banId
    );

    SQL_ThreadQuery(g_SqlTuple, "queryIgnoreHandler", queryUpdate);

    if (admin)
    {
        CC_Send(admin, "^4%s^1 Normal unban uygulandi. SQL kaydi silinmedi. ID:^3 %d", g_szChatTag, banId);
    }
}

stock doSqlDeleteById(admin, banId)
{
    if (g_SqlTuple == Empty_Handle)
    {
        sqlReconnect();
    }

    if (banId <= 0)
    {
        return;
    }

    new querySelect[256];
    formatex(querySelect, charsmax(querySelect),
        "SELECT `player_nick`,`player_steamid`,`player_ip` FROM `%s` WHERE `id`=%d LIMIT 1;",
        g_szSqlTable, banId
    );

    new data[2];
    data[0] = get_user_userid(admin);
    data[1] = banId;
    SQL_ThreadQuery(g_SqlTuple, "querySqlDeleteByIdPrepare", querySelect, data, sizeof(data));
}

public querySqlDeleteByIdPrepare(FailState, Handle:Query, Error[], Errcode, Data[], DataSize)
{
    if (FailState != TQUERY_SUCCESS)
    {
        log_amx("[CSA-SQL Ban] SQL delete prepare hatasi: %s (%d)", Error, Errcode);
        return;
    }

    new admin = find_player("k", Data[0]);
    new banId = Data[1];

    if (!SQL_NumResults(Query))
    {
        if (admin)
        {
            CC_Send(admin, "^4%s^1 SQL kaydi bulunamadi.", g_szChatTag);
        }
        return;
    }

    new nick[32], steamid[35], ip[32];
    SQL_ReadResult(Query, 0, nick, charsmax(nick));
    SQL_ReadResult(Query, 1, steamid, charsmax(steamid));
    SQL_ReadResult(Query, 2, ip, charsmax(ip));

    if (nick[0])
    {
        setLocalBanInactiveByText(nick);
    }
    if (steamid[0])
    {
        setLocalBanInactiveByText(steamid);
    }
    if (ip[0])
    {
        setLocalBanInactiveByText(ip);
    }

    new queryDelete[256];
    formatex(queryDelete, charsmax(queryDelete),
        "DELETE FROM `%s` WHERE `id`=%d;",
        g_szSqlTable, banId
    );

    SQL_ThreadQuery(g_SqlTuple, "queryIgnoreHandler", queryDelete);

    if (admin)
    {
        CC_Send(admin, "^4%s^1 SQL kaydi fiziksel olarak silindi. ID:^3 %d", g_szChatTag, banId);
    }
}

stock purgePassiveSqlBans(admin)
{
    if (g_SqlTuple == Empty_Handle)
    {
        sqlReconnect();
    }

    new query[256];
    formatex(query, charsmax(query), "DELETE FROM `%s` WHERE `active`=0;", g_szSqlTable);
    SQL_ThreadQuery(g_SqlTuple, "queryIgnoreHandler", query);

    if (admin)
    {
        CC_Send(admin, "^4%s^1 Pasif SQL kayitlari silindi.", g_szChatTag);
    }
}

stock purgeExpiredSqlBans(admin)
{
    if (g_SqlTuple == Empty_Handle)
    {
        sqlReconnect();
    }

    new query[512];
    formatex(query, charsmax(query),
        "DELETE FROM `%s` WHERE `ban_minutes`>0 AND `expires_at` IS NOT NULL AND `expires_at`<=NOW();",
        g_szSqlTable
    );
    SQL_ThreadQuery(g_SqlTuple, "queryIgnoreHandler", query);

    if (admin)
    {
        CC_Send(admin, "^4%s^1 Suresi dolan SQL kayitlari silindi.", g_szChatTag);
    }
}

stock purgeAllSqlBans(admin)
{
    if (g_SqlTuple == Empty_Handle)
    {
        sqlReconnect();
    }

    clearAllLocalBans();

    new query[256];
    formatex(query, charsmax(query), "DELETE FROM `%s`;", g_szSqlTable);
    SQL_ThreadQuery(g_SqlTuple, "queryIgnoreHandler", query);

    if (admin)
    {
        CC_Send(admin, "^4%s^1 Tum SQL ban kayitlari silindi.", g_szChatTag);
    }
}