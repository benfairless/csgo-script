#!/usr/bin/env bash

# Check yo' privledge
if [[ $(id -u) != '0' ]]; then
  echo 'You must be root to run this script!'
  exit 1
fi

USER="steam"
DIR='/opt/steam'
APP_ID='740'
STEAM="${DIR}/Steam"
CONF="${DIR}/conf"
GAME="${DIR}/csgo"


################################################################################
############################## COSMETIC FUNCTIONS ##############################
################################################################################

echo() { /usr/bin/echo -e "$@"; }

say() {
  echo "$(tput bold)$@$(tput sgr0)"
}

output() {
  local LABEL='CS:GO Installer'
  local COLOUR='\033[34m' # Blue
  local RESET='\033[0m'   # Standard
  case ${1} in
      ERROR) local COLOUR='\033[31m' ;; # Red
    SUCCESS) local COLOUR='\033[32m' ;; # Green
       WARN) local COLOUR='\033[33m' ;; # Yellow
  esac
  while read LINE; do
    echo "${COLOUR}$(tput bold)[${LABEL}]$(tput sgr0)${RESET} ${LINE}"
  done
}

onfail() {
  local TICK="\033[32m✔\033[0m"
  local CROSS="\033[31m✗\033[0m"
  if [[ ${?} != 0 ]]; then
    echo "${1} ${CROSS}" | output ERROR
  elif [[ ! -z ${2} ]]; then
    echo "${2} ${TICK}" | output SUCCESS
  fi
}


################################################################################
############################## RUNTIME FUNCTIONS ###############################
################################################################################

intro() {
  cat <<INTRO | output

  Counter-Strike: Global Offensive
  ================================

  - Installs a competitive CS:GO server

INTRO
}

systemdeps() {
  yum install -q -y tar curl screen htop aspell aspell-en glibc glibc.i686 libgcc libgcc.i686 >/dev/null 2>&1 #libstdc++.i686
  onfail "Dependencies failed to install" "Package dependencies installed"
  if [[ ! $(id $USER 2>/dev/null) ]]; then
    useradd $USER -d $DIR >/dev/null 2>&1
    onfail "Failed to create user account" "User account created"
  fi
}

download_steam() {
  local TAR="${DIR}/steamcmd.tar.gz"
  if [[ ! -f $TAR ]]; then
    sudo -u $USER curl -sL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" -o $TAR
    onfail "Failed to download steamcmd" "Downloaded steamcmd"
  fi
  if [[ ! -f "${STEAM}/steamcmd.sh" ]]; then
    sudo -u $USER mkdir -p $STEAM
    sudo -u $USER tar -xzvf ${TAR} -C $STEAM >/dev/null 2>&1
    onfail "Failed to unpack steamcmd" "Unpacked steamcmd"
  fi
}

download_game() {
  local GAME_PATH="${STEAM}/steamapps/common/Counter-Strike Global Offensive Beta - Dedicated Server"
  if [[ ! -f "${GAME_PATH}/srcds_linux" ]]; then
    sudo -u $USER $STEAM/steamcmd.sh +login anonymous +force_install_dir $STEAM +app_update $APP_ID validate +quit| output
    onfail "Failed to correctly download CS:GO" "CS:GO game files downloaded successfully"
  fi
  [[ ! -L ${GAME} ]] && ln -sf "${GAME_PATH}/" ${GAME}
}

create_conf() {
  [[ ! -d ${CONF} ]] && sudo -u $USER mkdir -p $CONF
  RCON=$(aspell dump master | shuf -n 1)
  cat <<AUTOEXEC > "${CONF}/autoexec.cfg"
log on
hostname      "LR Tournament Server"
rcon_password "${RCON}"
sv_password   "" // PRIVATE SERVER PASSWORD
sv_cheats     0  // CHEAT MODE
sv_lan        0
sv_maxrate    0
sv_pausable   1
exec banned_user.cfg
AUTOEXEC
  cat <<SERVER > "${CONF}/server.cfg"
mp_autokick        0 // Kicks inactive players
mp_autoteambalance 0 // The teams are balanced more in the same number or a player
sv_consistency     0 // Whether the server enforces file consistency for critical files
sv_forcepreload    0 // Force server side preloading.
sv_friction        5 // World friction?
sv_kick_players_with_cooldown 0 // (0: do not kick; 1: kick Untrusted players; 2: kick players with any cooldown)
sv_kick_ban_duration          0 // How long should a kick ban from the server should last (in minutes)
sv_pure                 1
sv_pure_kick_clients    0 // If set to 1, the server will kick clients with mismatching files. Otherwise, it will issue a warning to the client.
sv_steamgroup_exclusive 0

writeid
writeip
SERVER
  cat <<COMPETITIVE > "${CONF}/gamemode_competitive_server.cfg"
// Game mode
mp_halftime                         1
mp_halftime_duration                60
mp_halftime_pausetimer              0
mp_match_can_clinch                 1 // 0=No mercy, 1=Win > 1/2 total rounds
mp_maxrounds                        15
mp_warmuptime                       300
mp_warmup_pausetimer                0
mp_roundtime                        1.92
mp_roundtime_defuse                 1.92
mp_round_restart_delay              10
mp_c4timer                          40
mp_timelimit                        0
mp_default_team_winner_no_objective -1 // 2 == CTs, 3 == Ts


// Friendly-fire
mp_friendlyfire                  1    // 0=disabled, 1=enabled
mp_tkpunish                      0
ff_damage_reduction_bullets      0.33
ff_damage_reduction_grenade      0.85
ff_damage_reduction_grenade_self 1
ff_damage_reduction_other        0.4
mp_solid_teammates               1

// Deaths
mp_death_drop_defuser 1  // 0=disabled, 1=enabled
mp_death_drop_grenade 2  // 0=none, 1=best, 2=current or best
mp_death_drop_gun     1  // 0=none, 1=best, 2=current or best

// Gear
mp_free_armor                1 // 0=disabled, 1=enabled
mp_defuser_allocation        0 // 0=disabled, 1=enabled
ammo_grenade_limit_flashbang 2
ammo_grenade_limit_total     4
mp_weapons_allow_zeus        1
mp_molotovusedelay           0
mp_weapons_allow_map_placed  0

// Buying
mp_startmoney 10000
mp_afterroundmoney     0
mp_maxmoney            16000
mp_buytime             30
mp_freezetime          15
mp_buy_anywhere        0
mp_buy_during_immunity 0

// Cash rewards
mp_playercashawards                      1
mp_teamcashawards                        1
cash_player_bomb_defused                 300
cash_player_bomb_planted                 300
cash_player_killed_enemy_default         300
cash_player_killed_enemy_factor          1
cash_player_killed_teammate              -300
cash_team_elimination_bomb_map           3250
cash_team_elimination_hostage_map_t      3000
cash_team_elimination_hostage_map_ct     3000
cash_team_loser_bonus                    1400
cash_team_loser_bonus_consecutive_rounds 500
cash_team_planted_bomb_but_defused       800
cash_team_terrorist_win_bomb             3500
cash_team_win_by_defusing_bomb           3500
cash_team_win_by_time_running_out_bomb   3250

// Bots
bot_autodifficulty_threshold_high 2.0  // Value between -20.0 and 20.0 (Amount above avg human contribution score, above which a bot should lower its difficulty)
bot_autodifficulty_threshold_low  -2.0 // Value between -20.0 and 20.0 (Amount below avg human contribution score, below which a bot should raise its difficulty)
bot_chatter                       normal
bot_defer_to_human_goals          1
bot_defer_to_human_items          1
bot_difficulty                    2
bot_quota                         10
bot_quota_mode                    fill

// Respawns
mp_respawn_immunitytime 0
mp_respawn_on_death_t   0
mp_respawn_on_death_ct  0
mp_randomspawn_los      0

// VoIP
sv_talk_enemy_living                        0
sv_talk_enemy_dead                          0
sv_deadtalk                                 0
sv_auto_full_alltalk_during_warmup_half_end 0
sv_ignoregrenaderadio                       0
sv_voiceenable                              0
sv_alltalk                                  0

// Spectating
mp_forcecamera                  1
sv_competitive_official_5v5     1
sv_occlude_players              1
spec_replay_enable              1
spec_freeze_panel_extended_time 0
spec_freeze_time                3.0

// Default loadouts
mp_ct_default_melee     weapon_knife
mp_ct_default_secondary weapon_hkp2000
mp_ct_default_primary   ""
mp_t_default_melee      weapon_knife
mp_t_default_secondary  weapon_glock
mp_t_default_primary    ""

// Miscellaneous server stuff
mp_playerid               0 // 0=all, 1=team, 2=none
mp_autokick               0
mp_autoteambalance        0
mp_randomspawn            0
mp_limitteams             0
sv_allow_votes            0
sv_allow_wait_command     0
sv_infinite_ammo          0
mp_display_kill_assists   1
mp_weapons_glow_on_ground 0
mp_force_pick_time        180
mp_win_panel_display_time 15
sv_damage_print_enable    0
sv_competitive_minspec    1
cl_cmdrate    128
cl_updaterate 128

// Customisation
say ">> Welcome to the LR CS:GO Tournament"

COMPETITIVE
ln -sf $CONF/autoexec.cfg                    ${GAME}/csgo/cfg/autoexec.cfg
ln -sf $CONF/server.cfg                      ${GAME}/csgo/cfg/server.cfg
ln -sf $CONF/gamemode_competitive_server.cfg ${GAME}/csgo/cfg/gamemode_competitive_server.cfg
}

create_service() {
  local SYSTEMD='/usr/lib/systemd/system/game-csgo.service'
  cat <<STARTUP > "${CONF}/startup.sh"
#!/usr/bin/env bash

MAP='de_dust2'

export LD_LIBRARY_PATH='${GAME}/bin:\$LD_LIBRARY_PATH' # Required to find Steam libs
${GAME}/srcds_linux -game csgo -console -usercon +game_type 0 +game_mode 1 +mapgroup mg_active +map \$MAP
STARTUP
  onfail "Failed to create startup script" "Startup script created"
  chmod +x ${CONF}/startup.sh

  cat <<SERVICE > $SYSTEMD
[Unit]
Description=Counter Strike : Global Offensive game server
After=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$DIR
ExecStart='${CONF}/startup.sh'
ExecStop=/bin/kill -9 $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICE
  onfail "Failed to create service file" "Service file created"
  systemctl daemon-reload
  onfail "Failed to reload systemctl daemon" "Reloaded systemctl daemon"
  ln -sf $SYSTEMD "${CONF}/game-csgo.service"
}

start_service() {
  systemctl enable game-csgo >/dev/null 2>&1
  onfail "Failed to set service to start on boot" "Service enabled on boot"
  systemctl restart game-csgo
  onfail "Failed to launch Counter Strike service" "Counter Strike launched successfully"
}

################################################################################
################################# MAIN RUNTIME #################################
################################################################################

intro
systemdeps
download_steam
download_game
create_conf
create_service
start_service

chown -R $USER:$USER $DIR
chmod 775 $DIR
onfail "Failed to set appropriate permissions" "Permissions set correctly"

say "CS:GO installation complete" | output SUCCESS
say 'You can run the CS:GO server by typing `systemctl start game-csgo`' | output
say "RCON PASSWORD: ${RCON}" | output
