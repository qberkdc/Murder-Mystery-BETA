#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <fakemeta>
#include <fakemeta_util>
#include <engine>

#define PLUGIN "Murder Mystery"
#define VERSION "1.0"
#define AUTHOR "Berk"

#define SKYNAME "space"

// Class Arrays
enum Class
{
	MURDER = 0,
	SHERIFF,
	INNOCENT
}

// Win Arrays
enum Wins
{
	NO_ONE = 0
}

// Delete the weapons on the ground
new g_iSpawnForward;

// Class Variables
new bool:murder[33], bool:sheriff[33], bool:innocent[33]
new bool:innocent_pickup[33]
new coin[33]
new Role[33][124]
new Model[33][124]

// Game conditions
new bool:has_started = false
new gameTime
new Winner
new bool:deadTime[33]
new SpawnBug[33]
const req_players = 3
const coin_limit = 5
const Timer = 150
new serif[32]
new katil1[32], katil2[32], katil3[32]
new count_katil = -1

// Defaults
new countdown
new TASKID = 0
new diedLOC[33]
new LOC[33]

public plugin_precache()
{
	// Download Sounds
	precache_sound("murder_mystery/murder_win.wav")
	precache_sound("murder_mystery/innocent_win.wav")
	
	precache_sound("murder_mystery/murder_died.wav")
	precache_sound("murder_mystery/innocent_died.wav")
	precache_sound("murder_mystery/sheriff_died.wav")
	
	precache_sound("murder_mystery/start.wav")
	precache_sound("murder_mystery/countdown.wav")
	precache_sound("murder_mystery/time.wav")
	precache_sound("murder_mystery/cash.wav")
	
	// Download Models
	precache_model("models/player/innocent/innocent.mdl")
	precache_model("models/player/sheriff/sheriff.mdl")
	precache_model("models/murder_mystery/v_revolver.mdl")
	
	// Register Forward
	g_iSpawnForward = register_forward( FM_Spawn, "FwdSpawn" );
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	RegisterHam( Ham_Spawn, "player", 	"fw_Spawn");
	RegisterHam( Ham_TakeDamage , "player", 	"fw_Damage", 0);
	
	register_forward( FM_ClientKill, "Fw_ClientKill" );
	register_clcmd("drop", "clcmd_drop")
	register_event( "DeathMsg", "Fw_Death", "a" );
	register_event("CurWeapon", "Event_CurWeapon", "be","1=1")
	
	register_logevent("round_start", 2, "1=Round_Start") 
	register_logevent("round_end", 2, "1=Round_End") 
	
	RegisterHam( Ham_Touch, "armoury_entity", "FwdHamPlayerPickup" );
    RegisterHam( Ham_Touch, "weaponbox", "FwdHamPlayerPickup" );
	
	countdown = 10
	has_started = false
	gameTime = Timer
	
	set_task(3.0, "check_players", TASKID+400, _, _, "b")
	set_task(1.0, "scoreboard", TASKID+408, _, _, "b")
	set_task(0.2, "check_sheriff", TASKID+411, _, _, "b")
	set_task(0.1, "check_game", TASKID+412, _, _, "b")
	set_task(0.1, "innocent_speed", TASKID+413, _, _, "b")
	set_task(0.1, "murder_speed", TASKID+413, _, _, "b")
	set_task(0.9, "myRole", TASKID+414, _, _, "b")
	set_task(1.0, "playTime", TASKID+415, _, _, "b")
	//set_task(1.5, "show_location", TASKID+420, _, _, "b")
	set_task(15.0, "coinTime", TASKID+416, _, _, "b")
	
	server_cmd("mp_round_infinite 1")
	server_cmd("mp_freeforall 1")
	server_cmd("mp_buytime 0")
	server_cmd("mp_roundtime 2.60")
	server_cmd("sv_skyname %s", SKYNAME)
	
	unregister_forward( FM_Spawn, g_iSpawnForward );
}

public coinTime()
{
	for(new i = 1;i < get_maxplayers(); i++)
	{
		if(is_user_connected(i) && is_user_alive(i) && innocent[i] && has_started)
		{
			if(coin[i] < coin_limit) coin[i] += 1;
			emit_sound( i, CHAN_BODY, "murder_mystery/cash.wav", 1.0, ATTN_NORM, 0, PITCH_NORM )
		}
	}
}

public FwdSpawn( iEntity ) {
    if( pev_valid( iEntity ) ) {
        static szClassname[ 32 ];
        pev( iEntity, pev_classname, szClassname, 31 );
        
        static const armoury_entity[ ] = "armoury_entity";
        if( equal( szClassname, armoury_entity ) ) {
            engfunc( EngFunc_RemoveEntity, iEntity );
            return FMRES_SUPERCEDE;
        }
    }
    
    return FMRES_IGNORED;
}

public clcmd_drop(id)
{
	if(innocent[id] && coin[id] == coin_limit && get_class_num(SHERIFF) == 0)
	{
		coin[id] -= coin_limit
		set_class(id, SHERIFF)
		new szName[32]; get_user_name(id, szName, 31)
		client_print(id, print_chat, "%s serif gorevini uslendi", szName)
	}
	
	return PLUGIN_HANDLED;
}

public client_putinserver(id)
{
	innocent[id] = false
	murder[id] = false
	sheriff[id] = false
	coin[id]  = 0
}

public playTime()
{
	if(!has_started) return PLUGIN_HANDLED;
	
	if(gameTime > 0)
	{
		gameTime -= 1
		
		if(gameTime < 11)
		{
			client_cmd(0, "spk murder_mystery/time.wav")
		}
	}
	
	if(gameTime == 0)
	{
		win(INNOCENT)
	}
}

public myRole()
{
	for(new i = 1;i < get_maxplayers(); i++)
	{
		if(is_user_alive(i) && is_user_connected(i))
		{
			your_role(i)
		}
	}
}

public innocent_speed()
{
	for(new i = 1;i < get_maxplayers(); i++)
	{
		if(is_user_alive(i) && is_user_connected(i) && innocent[i] || sheriff[i])
		{
			fm_set_user_maxspeed(i, 255.0)
		}
	}
}

public murder_speed()
{
	for(new i = 1;i < get_maxplayers(); i++)
	{
		if(is_user_alive(i) && is_user_connected(i) && murder[i])
		{
			fm_set_user_maxspeed(i, 280.0)
		}
	}
}

public FwdHamPlayerPickup( iEntity, id )
{
	new Name[32]
	get_user_name(id, Name, 31)
	
	if(innocent[id])
	{
		if(get_class_num(SHERIFF) == 0 && has_started)
		{
			client_print(id, print_chat, "%s silahi bulup yerden aldi!", Name)
			set_class(id, SHERIFF)
		}
		else
		{
			return HAM_SUPERCEDE; return HAM_IGNORED;
		}
	}
	
	if(murder[id])
	{
		return HAM_SUPERCEDE; return HAM_IGNORED;
	}
}

public Event_CurWeapon(id) 
{
	new weaponID = read_data(2) 
	if(weaponID == CSW_DEAGLE) { entity_set_string(id, EV_SZ_viewmodel, "models/murder_mystery/v_revolver.mdl"); }
	if(weaponID == CSW_KNIFE) { entity_set_string(id, EV_SZ_weaponmodel, ""); }
}

public check_game()
{
	if(has_started && get_class_num(INNOCENT) == 0 && get_class_num(SHERIFF) == 0)
	{
		win(MURDER)
	}
	
	if(has_started && get_class_num(MURDER) == 0)
	{
		win(INNOCENT)
	}
}

public check_sheriff()
{
	for(new i = 1;i < get_maxplayers(); i++)
	{
		if(is_user_alive(i) && is_user_connected(i) && sheriff[i] && cs_get_user_bpammo(i, CSW_DEAGLE) == 0)
		{
			cs_set_user_bpammo(i, CSW_DEAGLE, 1)
			client_cmd(i, "spk ^"items/9mmclip1.wav^"")
		}
	}
}

public client_disconnected(id)
{
	innocent[id] = false
	murder[id] = false
	sheriff[id] = false
	coin[id] = 0
	
	if(!is_user_alive(id) && deadTime[id])
	{
		new szName[32]
		get_user_name(id, szName, 31)
		
		SpawnBug[id] = 1
		client_print(0, print_chat, "%s Spawn bug detectorune yakalandi.!", szName)
		client_cmd(0, "spk vox/bizwarn.wav")
	}
}

public scoreboard()
{
	set_hudmessage(80, 80, 80, -1.0, 0.01, 0, 0.0, 0.5, 0.0, 0.5, -1)
	
	if(has_started)
	{
		// Get Role Stats
		new sts_innocent[64]
		new sts_murder[64]
		new sts_sheriff[64]
		
		if(get_class_num(INNOCENT) > 1) formatex(sts_innocent, 63, "%d", get_class_num(INNOCENT));
		if(get_class_num(INNOCENT) == 1) formatex(sts_innocent, 63, "Yasiyor");
		if(get_class_num(INNOCENT) == 0) formatex(sts_innocent, 63, "Olu");
		
		if(get_class_num(MURDER) > 1) formatex(sts_murder, 63, "%d", get_class_num(MURDER));
		if(get_class_num(MURDER) == 1) formatex(sts_murder, 63, "Yasiyor");
		if(get_class_num(MURDER) == 0) formatex(sts_murder, 63, "Olu");
		
		if(get_class_num(SHERIFF) > 1) formatex(sts_sheriff, 63, "%d", get_class_num(SHERIFF));
		if(get_class_num(SHERIFF) == 1) formatex(sts_sheriff, 63, "Yasiyor");
		if(get_class_num(SHERIFF) == 0) formatex(sts_sheriff, 63, "Olu");
		
		show_hudmessage(0, "- - Murder Mystery - -^nSheriff [%s] | Murder [%s] | Innocent [%s]^nSure: %ds", sts_sheriff, sts_murder, sts_innocent, gameTime)
	}
	else
	{
		show_hudmessage(0, "- - Murder Mystery - -^nOyunun baslamasi bekleniyor..")
	}
}

public show_location()
{
	for(new i = 1; i<get_maxplayers();i++)
	{
		if(is_user_alive(i))
		{
			new location[3]
			get_user_origin(i,location,0)
			set_hudmessage(0, 255, 0, 0.01, 0.25, 0, 0.0, 1.5, 0.0, 0.0, -1)
			show_hudmessage(i, "Lokasyonun: %d %d %d", location[0],location[1],location[2])
		}
		else
		{
			set_hudmessage(255, 0, 0, 0.01, 0.25, 0, 0.0, 1.5, 0.0, 0.0, -1)
			show_hudmessage(i, "Oldugun Lokasyon: %s", diedLOC[i])
		}
	}
}

public un_deadTime(id) deadTime[id] = false;

public Fw_Death()
{
	new killer = read_data(1);
	new victim = read_data(2);
	
	new location[3]
	get_user_origin(victim,location,0)
	formatex(diedLOC[victim], 63, "%d %d %d", location[0],location[1],location[2])
	
	deadTime[victim] = true
	set_task(10.0, "un_deadTime", victim)
	
	set_user_frags(victim, get_user_frags(victim) + 1)
	
	if(murder[victim])
	{
		send("Katil olduruldu !")
		emit_sound( victim, CHAN_BODY, "murder_mystery/murder_died.wav", 1.0, ATTN_NORM, 0, PITCH_NORM )
	}
	
	if(innocent[victim])
	{
		emit_sound( victim, CHAN_BODY, "murder_mystery/innocent_died.wav", 1.0, ATTN_NORM, 0, PITCH_NORM )
	}
	
	if(sheriff[victim])
	{
		emit_sound( victim, CHAN_BODY, "murder_mystery/sheriff_died.wav", 1.0, ATTN_NORM, 0, PITCH_NORM )
		send("Serif olduruldu !")
	}
	
	innocent[victim] = false
	murder[victim] = false
	sheriff[victim] = false
}

public Fw_ClientKill(id)
{
	client_print(id, print_console, "Kendini oldurmen imkansiz, yere cakilmak disinda :D")
	return FMRES_SUPERCEDE;
	return FMRES_IGNORED;
}

public round_end()
{
	has_started = false
	remove_task(TASKID+400)
	remove_task(TASKID+401)
	remove_task(TASKID+402)
	remove_task(TASKID+403)
	remove_task(TASKID+404)
	
	set_task(0.08, "block_round_draw_msg")
	
	for(new i = 1;i < get_maxplayers(); i++)
	{
		if(is_user_connected(i)) SpawnBug[i] = 0;
		
		if(is_user_alive(i) && is_user_connected(i)) 
		{
			disarm(i);
		}
	}
}

public round_start()
{
	set_task(3.0, "check_players", TASKID+400, _, _, "b")
	gameTime = Timer
	
	if(alives() >= req_players)
	{
		remove_task(TASKID+404)
		countdown = 10
	}
}

public check_players()
{
	if(alives() >= req_players)
	{
		remove_task(TASKID+404)
		countdown = 10
		set_task(1.0, "game_countdown", TASKID+404, _, _, "b")
		remove_task(TASKID+400)
	}
}

public fw_Damage( victim, inflictor, attacker, Float:damage, damagebits )
{
	if(!has_started)
	{
		SetHamParamFloat(4, damage * 0.0)
		return HAM_SUPERCEDE;
	}
	
	if(murder[attacker])
	{
		if(!murder[victim]) user_kill(victim);
		if(murder[victim]) return HAM_SUPERCEDE; SetHamParamFloat(4, damage * 0.0); return PLUGIN_HANDLED;
	}
	
	if(sheriff[attacker])
	{
		if(murder[victim]) { SetHamParamFloat(4, 100.0); return PLUGIN_HANDLED; }
		if(innocent[victim]) { SetHamParamFloat(4, 100.0); user_kill(attacker); send("Serif masumu oldurdugu icin cezalandirildi."); }
	}
	
	if(innocent[attacker])
	{
		if(murder[victim]) { SetHamParamFloat(4, 100.0); return PLUGIN_HANDLED; }
		if(innocent[victim]) { SetHamParamFloat(4, 100.0); user_kill(attacker); send("Masum masumu oldurdugu icin cezalandirildi."); }
	}
}

public fw_Spawn(id)
{
	set_task(0.1, "setin_class", id)
}

public setin_class(id) 
{
	set_task(0.1, "disarm", id)
	set_task(0.25, "give", id) 
	set_class(id, INNOCENT)
}

public give(id) give_item(id, "weapon_knife");

public set_ammo(id)
{
	if(is_user_alive(id) && is_user_connected(id) && sheriff[id])
	{
		give_item(id, "weapon_deagle");
		cs_set_user_bpammo(id, CSW_DEAGLE, 1)
		cs_set_weapon_ammo(find_ent_by_owner(-1, "weapon_deagle", id), 1)
	}
}

public game_countdown()
{
	if(countdown > 0)
	{
		set_hudmessage(10, 255, 100, -1.0, 0.1, 0, 0.0, 0.1, 0.1, 0.7, -1)
		show_hudmessage(0, "%d sn sonra oyun basliyor.", countdown)
		server_print("%d sn sonra oyun basliyor. ", countdown)
		
		client_cmd(0, "spk murder_mystery/countdown.wav")
		
		countdown -= 1
	}
	
	if(countdown == 0)
	{
		remove_task(TASKID+401)
		remove_task(TASKID+404)
		client_cmd(0, "spk murder_mystery/start.wav")
		set_task(0.0, "random_class", TASKID+402)
	}
}

public showRoles()
{
	for(new i = 1 ; i < get_maxplayers(); i++)
	{
		if(is_user_alive(i) && is_user_connected(i)) { show_role(i); }
	}
}

public random_class()
{
		new id = random_num(1,32)
		new random_class = random_num(1,2)
		new min_murders
		
		if(alives() <= 8) min_murders  = 1;
		if(alives() > 8) min_murders  = 2;
		if(alives() > 15) min_murders  = 3;
	
		if(!is_user_alive(id) && is_user_connected(id))
		{
			set_task(0.05, "random_class", TASKID+402, _, _, "b")
			return PLUGIN_HANDLED;
		}
	
		if(!is_user_connected(id))
		{
			set_task(0.05, "random_class", TASKID+402, _, _, "b")
			return PLUGIN_HANDLED;
		}
	
		if(murder[id])
		{
			set_task(0.05, "random_class", TASKID+402, _, _, "b")
			return PLUGIN_HANDLED
		}
	
		if(sheriff[id])
		{
			set_task(0.05, "random_class", TASKID+402, _, _, "b")
			return PLUGIN_HANDLED
		}
	
		if(random_class == 1)
		{
			if(get_class_num(MURDER) < min_murders && !murder[id])
			{
				count_katil += 1
				if(count_katil == 0) get_user_name(id, katil1, 31);
				if(count_katil == 1) get_user_name(id, katil2, 31);
				if(count_katil == 2) get_user_name(id, katil3, 31);
				
				set_class(id, MURDER)
				server_print("==========================")
				server_print("(%d) Katil secildi..", count_katil)
				server_print("==========================")
				server_print(" ")
				
				set_task(0.1, "random_class", TASKID+402, _, _, "b")
			}
		}
		
		if(random_class == 2)
		{
			if(get_class_num(SHERIFF) < 1 && !sheriff[id])
			{
				set_class(id, SHERIFF)
				server_print("==========================")
				server_print("Serif secildi..")
				server_print("==========================")
				server_print(" ")
				get_user_name(id, serif, 31)
				set_task(0.1, "random_class", TASKID+402, _, _, "b")
			}
		}
	
		if(get_class_num(SHERIFF) == 1)
		{
			if(get_class_num(MURDER) == min_murders)
			{
				remove_task(TASKID+402)
				
				server_print("==========================")
				server_print("Serif: %s", serif)
				server_print("Katil: %s", katil1)
				if(get_class_num(MURDER) >= 2) server_print("Katil: %s", katil2);
				if(get_class_num(MURDER) >= 3) server_print("Katil: %s", katil3);
				server_print("==========================")
				server_print(" ")
				server_print("Oyun basladi")
				
				set_task(0.5, "send_role", TASKID+415)
				has_started  = true
				
				// Reset int
				count_katil = -1
				
				return PLUGIN_HANDLED;
			}
		}
}

public send_role()
{
	for(new id = 1;id < get_maxplayers(); id++)
	{
		if(innocent[id])
		{
			show_role(id)
		}
	}
}

public THEISWINNER()
{
	if(Winner == INNOCENT) client_cmd(0, "stopsound;wait;wait;wait;spk murder_mystery/innocent_win.wav");
	if(Winner == MURDER) client_cmd(0, "stopsound;wait;wait;wait;spk murder_mystery/murder_win.wav");
}

public disarm(id) strip_user_weapons(id);
public block_round_draw_msg() { client_print(0, print_center, "  "); }

// STOCKS
// ==============================
stock set_class(id, class_id)
{
	if(class_id == MURDER)
	{
		innocent[id] = false; murder[id] = true; sheriff[id] = false
		give_item(id, "weapon_knife")
		show_role(id)
		return PLUGIN_HANDLED;
	}
	
	if(class_id == SHERIFF)
	{
		innocent[id] = false; murder[id] = false; sheriff[id] = true
		set_task(0.15, "set_ammo", id)
		show_role(id)
		return PLUGIN_HANDLED;
	}
	
	if(class_id == INNOCENT)
	{
		innocent[id] = true; murder[id] = false; sheriff[id] = false
		set_task(0.4, "disarm", id)
		coin[id] = 0
		cs_set_user_team(id, CS_TEAM_CT)
		cs_set_user_model(id, "innocent")
		return PLUGIN_HANDLED;
	}
		
	if(class_id != MURDER && class_id != SHERIFF && class_id != INNOCENT)
	{
		set_fail_state("Unknown class id")
	}
}

stock win(class_id)
{
	server_cmd("endround")
	
	if(class_id == INNOCENT)
	{
		send("Masum'lar kazandi")
		Winner = INNOCENT
		win_sound(INNOCENT)
		
		for(new id = 1;id < get_maxplayers();id++)
		{
			if(is_user_alive(id) && innocent[id]) set_user_frags(id, get_user_frags(id) + 1);
		}
	}
	
	if(class_id == MURDER)
	{
		send("Katil'ler kazandi")
		Winner = MURDER
		win_sound(MURDER)
		
		for(new id = 1;id < get_maxplayers();id++)
		{
			if(is_user_alive(id) && murder[id]) set_user_frags(id, get_user_frags(id) + 1);
		}
	}
}

stock send(const message[])
{
	client_print(0, print_chat, message)
}

stock get_class_num(class_id)
{
	if(class_id == INNOCENT)
	{
		new Innocents
		for(new pnum = 1;pnum < get_maxplayers();pnum++)
		{
			if(innocent[pnum] && is_user_connected(pnum) && is_user_alive(pnum))
			{
				Innocents++
			}
		}
		
		return Innocents;
	}
	
	if(class_id == MURDER)
	{
		new Murders
		for(new pnum = 1;pnum < get_maxplayers();pnum++)
		{
			if(murder[pnum] && is_user_connected(pnum) && is_user_alive(pnum))
			{
					Murders++
			}
		}
		
		return Murders;
	}
	
	if(class_id == SHERIFF)
	{
		new Sheriffs
		for(new pnum = 1;pnum < get_maxplayers();pnum++)
		{
			if(sheriff[pnum] && is_user_connected(pnum) && is_user_alive(pnum))
			{
				Sheriffs++
			}
		}
		
		return Sheriffs;
	}
}

stock show_role(id)
{
	new color[3]
	
	if(murder[id])
	{ 
		Role[id] = "Murder"
		color[0] = 255
		color[1] = 0
		color[2] = 0
		Model[id] = "innocent"
	}
	
	if(innocent[id])
	{
		Role[id] = "Innocent"
		color[0] = 255
		color[1] = 255
		color[2] = 255
		Model[id] = "innocent"
	}
	
	if(sheriff[id])
	{
		Role[id] = "Sheriff"
		color[0] = 0
		color[1] = 255
		color[2] = 55
		Model[id] = "sheriff"
	}
	
	set_hudmessage(color[0], color[1], color[2], -1.0, 0.25, 0, 0.0, 0.0, 0.0, 1.5, -1)
	show_hudmessage(id, "Senin Rolun: %s", Role[id])
	cs_set_user_model(id, Model[id])
}

stock your_role(id)
{
	new color[3]
	
	if(murder[id])
	{ 
		Role[id] = "Murder"
		color[0] = 255
		color[1] = 0
		color[2] = 0
	}
	
	if(innocent[id])
	{
		Role[id] = "Innocent"
		color[0] = 255
		color[1] = 255
		color[2] = 255
	}
	
	if(sheriff[id])
	{
		Role[id] = "Sheriff"
		color[0] = 0
		color[1] = 255
		color[2] = 55
	}
	
	if(has_started && !innocent[id])
	{
		new location[3]
		get_user_origin(id,location,0)
		formatex(LOC[id], 64, "%d %d %d", location[0], location[1], location[2])
		set_hudmessage(color[0], color[1], color[2], 0.01, 0.22, 0, 0.0, 1.0, 0.0, 0.0, -1)
		show_hudmessage(id, "Rol: %s^nLokasyon: %s", Role[id], LOC[id])
	}
	
	if(has_started && innocent[id])
	{
		new stats_revolver[64]
		if(get_class_num(SHERIFF) >= 1) formatex(stats_revolver, 63,  "Yasayan serif var iken alamazsin"); else formatex(stats_revolver, 63,  "Serif yok, revolver almak icin drop tusuna bas");
		
		new location[3]
		get_user_origin(id,location,0)
		formatex(LOC[id], 64, "%d %d %d", location[0], location[1], location[2])
		set_hudmessage(color[0], color[1], color[2], 0.01, 0.22, 0, 0.0, 1.0, 0.0, 0.0, -1)
		show_hudmessage(id, "Rol: %s^nAltin: %d^nLokasyon: %s^nRevolver: %s", Role[id], coin[id], LOC[id], stats_revolver)
	}
}

stock alives()
{
	new alive
	for(new i = 1;i < get_maxplayers(); i++)
	{
		if(is_user_connected(i) && is_user_alive(i))
		{
			alive++
		}
	}
	return alive;
}

stock win_sound(class_id)
{
	if(class_id == INNOCENT) client_cmd(0, "stopsound"); set_task(0.1, "THEISWINNER");
	if(class_id == MURDER) client_cmd(0, "stopsound"); set_task(0.1, "THEISWINNER");
}
// ==============================