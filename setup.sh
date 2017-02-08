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
RCON='password'


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
  yum install -q -y tar curl glibc glibc.i686 libgcc libgcc.i686 >/dev/null 2>&1 #libstdc++.i686
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
  cat <<AUTOEXEC > "${CONF}/autoexec.cfg"
log on
hostname "Counter-Strike: Global Offensive Dedicated Server"
rcon_password "${RCON}"
sv_password "" // PRIVATE SERVER PASSWORD
sv_cheats 0 // CHEAT MODE
sv_lan 0
exec banned_user.cfg
AUTOEXEC
  cat <<SERVER > "${CONF}/server.cfg"
mp_autokick 0        // Kicks inactive players
mp_autoteambalance 1 // The teams are balanced more in the same number or a player
mp_fadetoblack 0     // Sets whether the screen is black after death or not
mp_friendlyfire 0    // Team players take damage if you fire
mp_roundtime 2       // Sets the time per round in minutes
mp_maxrounds 15      // Specifies after how many rounds a map change takes place
mp_limitteams 0      // Specifies how many players a team may more than the other
mp_friendly_grenade_damage 1 // Team players take damage if hit with a hand grenade
mp_tkpunish 0        // Determines whether a player is punished for a team kill
mp_startmoney 10000  // Sets with how much money players have in the first round
mp_playerid 0        // Specifies whether you can read the names of players
mp_forcecamera 1     // Determines if you can only watch team players after death
mp_allowspectators 1 // Determines whether players can join as spectators
mp_winlimit 8        // Defines how many rounds a team must win

sv_enablevoice 1     // Determines whether you can use a voice in-game or not
sv_alltalk 1         // Specifies whether the opposing team hears voice chat

writeid
writeip
SERVER
ln -sf $CONF/autoexec.cfg ${GAME}/csgo/cfg/autoexec.cfg
ln -sf $CONF/server.cfg ${GAME}/csgo/cfg/server.cfg
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
  systemctl enable game-csgo
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
onfail "Failed to set appropriate permissions" "Permissions set correctly"
