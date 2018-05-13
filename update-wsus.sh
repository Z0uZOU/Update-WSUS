#!/bin/bash
 
########################
## Script de ZouZOU
########################
## Installation: wget -q https://raw.githubusercontent.com/Z0uZOU/Update-WSUS/master/update-wsus.sh -O update-wsus.sh && sed -i -e 's/\r//g' update-wsus.sh && shc -f update-wsus.sh -o update-wsus.bin && chmod +x update-wsus.bin && rm -f *.x.c && rm -f update-wsus.sh
## Installation: wget -q https://raw.githubusercontent.com/Z0uZOU/Update-WSUS/master/update-wsus.sh -O update-wsus.sh && sed -i -e 's/\r//g' update-wsus.sh && chmod +x update-wsus.sh
 
## Micro-config
version="Version: 0.0.0.3" #base du système de mise à jour
description="MAJ du serveur WSUS" #description pour le menu
description_eng="WSUS Updater" #description pour le menu
script_github="https://raw.githubusercontent.com/Z0uZOU/Update-WSUS/master/update-wsus.sh" #emplacement du script original
changelog_github="https://raw.githubusercontent.com/Z0uZOU/Update-WSUS/master/changelog" #emplacement du changelog de ce script
langue_fr="https://raw.githubusercontent.com/Z0uZOU/Update-WSUS/master/lang/french.lang"
langue_eng="https://raw.githubusercontent.com/Z0uZOU/Update-WSUS/master/lang/english.lang"
icone_github="https://raw.githubusercontent.com/Z0uZOU/Update-WSUS/master/.cache-icons/update-wsus.png" #emplacement de l'icône du script
required_repos="" #ajout de repository
required_tools="curl cabextract hashdeep wget xmlstarlet trash-cli" #dépendances du script (APT)
required_tools_pip="" #dépendances du script (PIP)
script_cron="0 2 * * *" #ne définir que la planification
verification_process="" #si ces process sont détectés on ne notifie pas (ou ne lance pas en doublon)
########################
 
#### Vérification de la langue du system
if [[ "$@" =~ "--langue=FR" ]] || [[ "$@" =~ "--langue=ENG" ]]; then
  if [[ "$@" =~ "--langue=FR" ]]; then
    affichage_langue="french"
  else
    affichage_langue="english"
  fi
else
  os_langue=$(locale | grep LANG | sed -n '1p' | cut -d= -f2 | cut -d_ -f1)
  if [[ "$os_langue" == "fr" ]]; then
    affichage_langue="french"
  else
    affichage_langue="english"
  fi
fi
 
#### Déduction des noms des fichiers (pour un portage facile)
mon_script_fichier=`basename "$0"`
mon_script_base=`echo ''$mon_script_fichier | cut -f1 -d'.'''`
mon_script_base_maj=`echo ${mon_script_base^^}`
mon_script_config=`echo "/root/.config/"$mon_script_base"/"$mon_script_base".conf"`
mon_script_ini=`echo "/root/.config/"$mon_script_base"/"$mon_script_base".ini"`
mon_script_langue=`echo "/root/.config/"$mon_script_base"/"$affichage_langue".lang"`
mon_script_log=`echo $mon_script_base".log"`
mon_script_desktop=`echo $mon_script_base".desktop"`
mon_script_updater=`echo $mon_script_base"-update.sh"`
 
#### Chargement du fichier pour la langue (ou installation)
if [[ "$affichage_langue" == "french" ]]; then
  langue_distant_check=`wget -q -O- "$langue_fr" | sed 's/\r//g' | wc -c`
else
  langue_distant_check=`wget -q -O- "$langue_eng" | sed 's/\r//g' | wc -c`
fi
langue_local_check=`cat "$mon_script_langue" 2>/dev/null | wc -c`
if [[ "$langue_distant_check" != "$langue_local_check" ]]; then
  if [[ "$affichage_langue" == "french" ]]; then
    echo "mise à jour du fichier de language disponible"
    echo "téléchargement de la mise à jour et installation..."
    wget -q "$langue_fr" -O "$mon_script_langue" 
    sed -i -e 's/\r//g' $mon_script_langue
  else
    echo "language file update available"
    echo "downloading and applying update..."
    wget -q "$langue_eng" -O "$mon_script_langue"
    sed -i -e 's/\r//g' $mon_script_langue
  fi
fi
source $mon_script_langue
 
#### Vérification que le script possède les droits root
## NE PAS TOUCHER
if [[ "$EUID" != "0" ]]; then
  if [[ "$CRON_SCRIPT" == "oui" ]]; then
    exit 1
  else
    if [[ "$CHECK_MUI" != "" ]]; then
      source $mon_script_langue
      echo "$mui_root_check"
    else
      echo "Vous devrez impérativement utiliser le compte root"
    fi
    exit 1
  fi
fi
 
#### Fonction pour envoyer des push
push-message() {
  push_title=$1
  push_content=$2
  for user in {1..10}; do
    destinataire=`eval echo "\\$destinataire_"$user`
    if [ -n "$destinataire" ]; then
      curl -s \
        --form-string "token=$token_app" \
        --form-string "user=$destinataire" \
        --form-string "title=$push_title" \
        --form-string "message=$push_content" \
        --form-string "html=1" \
        --form-string "priority=0" \
        https://api.pushover.net/1/messages.json > /dev/null
    fi
  done
}
 
#### Vérification de process pour éviter les doublons (commandes externes)
for process_travail in $verification_process ; do
  process_important=`ps aux | grep $process_travail | sed '/grep/d'`
  if [[ "$process_important" != "" ]] ; then
    if [[ "$CRON_SCRIPT" != "oui" ]] ; then
      if [[ "$CHECK_MUI" != "" ]]; then
        source $mon_script_langue
        echo $process_travail"$mui_prevent_dupe_task"
      else
        echo $process_travail" est en cours de fonctionnement, arrêt du script"
      fi
      fin_script=`date`
      if [[ "$CHECK_MUI" != "" ]]; then
        source $mon_script_langue
        echo -e "$mui_end_of_script"
      else
        if [[ "$CHECK_MUI" != "" ]]; then
          source $mon_script_langue
          echo -e "$mui_end_of_script"
        else
          echo -e "\e[43m -- FIN DE SCRIPT: $fin_script -- \e[0m "
        fi
      fi
    fi
    exit 1
  fi
done
 
#### Tests des arguments
if [[ "$@" == "--version" ]]; then
  echo "$version"
  exit 1
fi
if [[ "$@" == "--debug" ]]; then
  debug="yes"
fi
if [[ "$@" == "--edit-config" ]]; then
  nano $mon_script_config
  exit 1
fi
if [[ "$@" == "--debug" ]]; then
  debug="yes"
fi
if [[ "$@" == "--efface-lock" ]]; then
  mon_lock=`echo "/root/.config/"$mon_script_base"/lock-"$mon_script_base`
  rm -f "$mon_lock"
  echo "Fichier lock effacé"
  exit 1
fi
if [[ "$@" == "--statut-lock" ]]; then
  statut_lock=`cat $mon_script_config | grep "maj_force=\"oui\""`
  if [[ "$statut_lock" == "" ]]; then
    echo "Système de lock activé"
  else
    echo "Système de lock désactivé"
  fi
  exit 1
fi
if [[ "$@" == "--active-lock" ]]; then
  sed -i 's/maj_force="oui"/maj_force="non"/g' $mon_script_config
  echo "Système de lock activé"
  exit 1
fi
if [[ "$@" == "--desactive-lock" ]]; then
  sed -i 's/maj_force="non"/maj_force="oui"/g' $mon_script_config
  echo "Système de lock désactivé"
  exit 1
fi
if [[ "$@" == "--extra-log" ]]; then
  date_log=`date +%Y%m%d`
  heure_log=`date +%H%M`
  path_log=`echo "/root/.config/"$mon_script_base"/log/"$date_log`
  mkdir -p $path_log 2>/dev/null
  fichier_log_perso=`echo $path_log"/"$heure_log".log"`
  mon_log_perso="| tee -a $fichier_log_perso"
fi
if [[ "$@" == "--purge-process" ]]; then
  ps aux | grep $mon_script_base | awk '{print $2}' | xargs kill -9
  echo "Les processus de ce script ont été tués"
fi
if [[ "$@" == "--purge-log" ]]; then
  path_global_log=`echo "/root/.config/"$mon_script_base"/log"`
  cd $path_global_log
  mon_chemin=`echo $PWD`
  if [[ "$mon_chemin" == "$path_global_log" ]]; then
    printf "Êtes-vous sûr de vouloir effacer l'intégralité des logs de --extra-log? (oui/non) : "
    read question_effacement
    if [[ "$question_effacement" == "oui" ]]; then
      rm -rf *
      echo "Les logs ont été effacés"
    fi
  else
    echo "Une erreur est survenue, veuillez contacter le développeur"
  fi
  exit 1
fi
if [[ "$@" == "--changelog" ]]; then
  wget -q -O- $changelog_github
  echo ""
  exit 1
fi
if [[ "$@" == --message=* ]]; then
  source $mon_script_config
  message=`echo "$1" | sed 's/--message=//g'`
  curl -s \
    --form-string "token=arocr9cyb3x5fdo7i4zy7e99da6hmx" \
    --form-string "user=uauyi2fdfiu24k7xuwiwk92ovimgto" \
    --form-string "title=$mon_script_base_maj MESSAGE" \
    --form-string "message=$message" \
    --form-string "html=1" \
    --form-string "priority=0" \
    https://api.pushover.net/1/messages.json > /dev/null
  exit 1
fi
if [[ "$@" == "--help" ]]; then
  if [[ "$CHECK_MUI" != "" ]]; then
    i=""
    for i in _ {a..z} {A..Z}; do eval "echo \${!$i@}" ; done | xargs printf "%s\n" | grep mui_menu_help > variables
    help_lignes=`wc -l variables | awk '{print $1}'`
    rm -f variables
    j=""
    mui_menu_help="mui_menu_help_"
    path_log=`echo "/root/.config/"$mon_script_base"/log/"$date_log`
    for j in $(seq 1 $help_lignes); do
      source $mon_script_langue
      echo -e "${!mui_menu_help_display}"
    done
    exit 1
  fi
  if [[ "$CHECK_MUI" == "" ]]; then
    path_log=`echo "/root/.config/"$mon_script_base"/log/"$date_log`
    echo -e "\e[1m$mon_script_base_maj\e[0m ($version)"
    echo "Objectif du programme: $description"
    echo "Auteur: Z0uZOU <zouzou.is.reborn@hotmail.fr>"
    echo ""
    echo "Utilisation: \"$mon_script_fichier [--option]\""
    echo ""
    echo -e "\e[4mOptions:\e[0m"
    echo "  --version               Affiche la version de ce programme"
    echo "  --edit-config           Édite la configuration de ce programme"
    echo "  --extra-log             Génère un log à chaque exécution dans "$path_log
    echo "  --debug                 Lance ce programme en mode debug"
    echo "  --efface-lock           Supprime le fichier lock qui empêche l'exécution"
    echo "  --statut-lock           Affiche le statut de la vérification de process doublon"
    echo "  --active-lock           Active le système de vérification de process doublon"
    echo "  --desactive-lock        Désactive le système de vérification de process doublon"
    echo "  --maj-uniquement        N'exécute que la mise à jour"
    echo "  --changelog             Affiche le changelog de ce programme"
    echo "  --help                  Affiche ce menu"
    echo ""
    echo "Les options \"--debug\" et \"--extra-log\" sont cumulables"
    echo ""
    echo -e "\e[4mUtilisation avancée:\e[0m"
    echo "  --message=\"...\"         Envoie un message push au développeur (urgence uniquement)"
    echo "  --purge-log             Purge définitivement les logs générés par --extra-log"
    echo "  --purge-process         Tue tout les processus générés par ce programme"
    echo ""
    echo -e "\e[3m ATTENTION: CE PROGRAMME DOIT ÊTRE EXÉCUTÉ AVEC LES PRIVILÈGES ROOT \e[0m"
    echo "Des commandes comme les installations de dépendances ou les recherches nécessitent de tels privilèges."
    echo ""
    exit 1
  fi
fi
 
### Paramètre du dossier d'installation
install_dir=""
if [[ "$@" =~ "--install-dir:" ]];then
  install_dir=`echo $@ | sed 's/.*--install-dir://' | sed 's/ .*//'`
fi
  
#### je dois charger le fichier conf ici ou trouver une solution (script_url et maj_force)
dossier_config=`echo "/root/.config/"$mon_script_base`
if [[ -d "$dossier_config" ]]; then
  useless="1"
else
  mkdir -p $dossier_config
fi
 
if [[ -f "$mon_script_config" ]] ; then
  source $mon_script_config
else
    if [[ "$script_url" != "" ]] ; then
      script_github=$script_url
    fi
    if [[ "$maj_force" == "" ]] ; then
      maj_force="non"
    fi
fi
 
#### Vérification qu'au reboot les lock soient bien supprimés
if [[ -f "/etc/rc.local" ]]; then
  test_rc_local=`cat /etc/rc.local | grep -e 'find /root/.config -name "lock-\*" | xargs rm -f'`
  if [[ "$test_rc_local" == "" ]]; then
    sed -i -e '$i \find /root/.config -name "lock-*" | xargs rm -f\n' /etc/rc.local >/dev/null
  fi
else
  test_crontab=`crontab -l | grep "clean-lock"`
  if [[ "$test_crontab" == "" ]]; then
    crontab -l > mon_cron.txt
    sed -i '5i@reboot\t\t\tsleep 10 && /opt/scripts/clean-lock.sh # $mon_script_base' mon_cron.txt
    crontab mon_cron.txt
    rm -f mon_cron.txt
  fi
fi
 
#### Vérification qu'une autre instance de ce script ne s'exécute pas
computer_name=`hostname`
pid_script=`echo "/root/.config/"$mon_script_base"/lock-"$mon_script_base`
if [[ "$maj_force" == "non" ]] ; then
  if [[ -f "$pid_script" ]] ; then
    if [[ "$CHECK_MUI" != "" ]]; then
      source $mon_script_langue
      echo "$mui_pid_check"
      message_alerte=`echo -e "$mui_pid_push"`
    else
      echo "Il y a au moins un autre process du script en cours"
      message_alerte=`echo -e "Un process bloque mon script sur $computer_name"`
    fi
    ## petite notif pour zouzou
    curl -s \
    --form-string "token=arocr9cyb3x5fdo7i4zy7e99da6hmx" \
    --form-string "user=uauyi2fdfiu24k7xuwiwk92ovimgto" \
    --form-string "title=$mon_script_base_maj HS" \
    --form-string "message=$message_alerte" \
    --form-string "html=1" \
    --form-string "priority=1" \
    https://api.pushover.net/1/messages.json > /dev/null
    exit 1
  fi
fi
touch $pid_script
 
#### Chemin du script
## necessaire pour le mettre dans le cron
cd /opt/scripts
 
#### Indispensable aux messages de chargement
mon_printf="\r                                                                             "

#### Nettoyage obligatoire et push pour annoncer la maj
if [[ -f "$mon_script_updater" ]] ; then
  rm "$mon_script_updater"
  source $mon_script_config 2>/dev/null
  version_maj=`echo $version | awk '{print $2}'`
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    message_maj=`echo -e "$mui_pushover_updated_msg"`
    message_titre=`echo -e "$mui_pushover_updated_title"`
  else
    message_maj=`echo -e "Le progamme $mon_script_base est désormais en version $version_maj"`
    message_titre=`echo -e "Mise à jour"`
  fi  
  for user in {1..10}; do
    destinataire=`eval echo "\\$destinataire_"$user`
    if [ -n "$destinataire" ]; then
      curl -s \
      --form-string "token=$token_app" \
      --form-string "user=$destinataire" \
      --form-string "title=$message_titre" \
      --form-string "message=$message_maj" \
      --form-string "html=1" \
      --form-string "priority=-1" \
      https://api.pushover.net/1/messages.json > /dev/null
    fi
  done
fi
 
#### Vérification de version pour éventuelle mise à jour
version_distante=`wget -O- -q "$script_github" | grep "Version:" | awk '{ print $2 }' | sed -n 1p | awk '{print $1}' | sed -e 's/\r//g' | sed 's/"//g'`
version_locale=`echo $version | awk '{print $2}'`
 
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}
testvercomp () {
    vercomp $1 $2
    case $? in
        0) op='=';;
        1) op='>';;
        2) op='<';;
    esac
    if [[ $op != $3 ]]
    then
        echo "FAIL: Expected '$3', Actual '$op', Arg1 '$1', Arg2 '$2'"
    else
        echo "Pass: '$1 $op $2'"
    fi
}
compare=`testvercomp $version_locale $version_distante '<' | grep Pass`
if [[ "$compare" != "" ]] ; then
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'echo -e "$mui_update_available"' $mon_log_perso
    eval 'echo -e "$mui_update_download"' $mon_log_perso
  else
    eval 'echo "une mise à jour est disponible ($version_distante) - version actuelle: $version_locale"' $mon_log_perso
    eval 'echo "téléchargement de la mise à jour et installation..."' $mon_log_perso
  fi
  touch $mon_script_updater
  chmod +x $mon_script_updater
  echo "#!/bin/bash" >> $mon_script_updater
  mon_script_fichier_temp=`echo $mon_script_fichier"-temp"`
  echo "wget -q $script_github -O $mon_script_fichier_temp" >> $mon_script_updater
  echo "sed -i -e 's/\r//g' $mon_script_fichier_temp" >> $mon_script_updater
  if [[ "$mon_script_fichier" =~ \.sh$ ]]; then
    echo "mv $mon_script_fichier_temp $mon_script_fichier" >> $mon_script_updater
    echo "chmod +x $mon_script_fichier" >> $mon_script_updater
    echo "bash $mon_script_fichier $1 $2" >> $mon_script_updater
  else
    echo "shc -f $mon_script_fichier_temp -o $mon_script_fichier" >> $mon_script_updater
    echo "rm -f $mon_script_fichier_temp" >> $mon_script_updater
    compilateur=`echo $mon_script_fichier".x.c"`
    echo "rm -f *.x.c" >> $mon_script_updater
    echo "chmod +x $mon_script_fichier" >> $mon_script_updater
    if [[ "$CHECK_MUI" != "" ]]; then
      source $mon_script_langue
      echo "$mui_update_done" >> $mon_script_updater
    else
      echo "echo mise à jour mise en place" >> $mon_script_updater
    fi
    echo "./$mon_script_fichier $1 $2" >> $mon_script_updater
  fi
  echo "exit 1" >> $mon_script_updater
  rm "$pid_script"
  bash $mon_script_updater
  exit 1
else
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    my_title_count=`echo -n "$mui_title" | sed "s/\\\e\[[0-9]\{1,2\}m//g" | wc -c`
    line_lengh="78"
    before_after_count=$(bc -l <<<"scale=1; ( $line_lengh - $my_title_count ) / 2")
    if [[ $before_after_count =~ ".5" ]]; then
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      before_after_count=$(((($line_lengh-$my_title_count)/2)+1))
      after=`eval printf "%0.s-" {1..$before_after_count}`
    else
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      after=`eval printf "%0.s-" {1..$before_after_count}`
    fi
    eval 'printf "\e[43m%s%s%s\e[0m\n" "$before" "$mui_title" "$after"' $mon_log_perso
  else
    eval 'echo -e "\e[43m-- $mon_script_base_maj - VERSION: $version_locale --\e[0m"' $mon_log_perso
  fi
fi
 
#### Nécessaire pour l'argument --maj-uniquement
if [[ "$@" == "--maj-uniquement" ]]; then
  rm "$pid_script"
  exit 1
fi
 
#### Vérification de la conformité du cron
crontab -l > mon_cron.txt
cron_path=`cat mon_cron.txt | grep "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"`
if [[ "$cron_path" == "" ]]; then
  sed -i '1iPATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin # $mon_script_base' mon_cron.txt
  cron_a_appliquer="oui"
fi
if [[ "$affichage_langue" == "french" ]]; then
  cron_lang=`cat mon_cron.txt | grep "LANG=fr_FR.UTF-8"`
else
  cron_lang=`cat mon_cron.txt | grep "LANG=en_US.UTF-8"`
fi
if [[ "$cron_lang" == "" ]]; then
  if [[ "$affichage_langue" == "french" ]]; then
    sed -i '1iLANG=fr_FR.UTF-8 # $mon_script_base' mon_cron.txt
    cron_a_appliquer="oui"
  else
    sed -i '1iLANG=en_US.UTF-8 # $mon_script_base' mon_cron.txt
    cron_a_appliquer="oui"
  fi
fi
cron_variable=`cat mon_cron.txt | grep "CRON_SCRIPT=\"oui\""`
if [[ "$cron_variable" == "" ]]; then
  sed -i '1iCRON_SCRIPT="oui" # $mon_script_base' mon_cron.txt
  cron_a_appliquer="oui"
fi
if [[ "$cron_a_appliquer" == "oui" ]]; then
  crontab mon_cron.txt
  rm -f mon_cron.txt
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'echo -e "$mui_cron_path_updated"' $mon_log_perso
  else
    eval 'echo "-- Cron mis en conformité"' $mon_log_perso
  fi
else
  rm -f mon_cron.txt
fi
 
#### Mise en place éventuelle d'un cron
if [[ "$script_cron" != "" ]]; then
  mon_cron=`crontab -l`
  verif_cron=`echo "$mon_cron" | grep "$mon_script_fichier"`
  if [[ "$verif_cron" == "" ]]; then
    if [[ "$CHECK_MUI" != "" ]]; then
      source $mon_script_langue
      eval 'echo -e "$mui_no_cron_entry"' $mon_log_perso
      eval 'echo -e "$mui_no_cron_creating"' $mon_log_perso
    else
      eval 'echo -e "\e[41mAUCUNE ENTRÉE DANS LE CRON\e[0m"' $mon_log_perso
      eval 'echo "-- Création..."' $mon_log_perso
    fi
    ajout_cron=`echo -e "$script_cron\t\t/opt/scripts/$mon_script_fichier > /var/log/$mon_script_log 2>&1"`
    if [[ "$CHECK_MUI" != "" ]]; then
      source $mon_script_langue
      eval 'echo -e "$mui_no_cron_adding"' $mon_log_perso
    else
      eval 'echo "-- Mise en place dans le cron..."' $mon_log_perso
    fi
    crontab -l > mon_cron.txt
    echo -e "$ajout_cron" >> mon_cron.txt
    crontab mon_cron.txt
    rm -f mon_cron.txt
    if [[ "$CHECK_MUI" != "" ]]; then
      source $mon_script_langue
      eval 'echo -e "$mui_no_cron_updated"' $mon_log_perso
    else
      eval 'echo "-- Cron mis à jour"' $mon_log_perso
    fi
  else
    if [[ "${verif_cron:0:1}" == "#" ]]; then
 
      if [[ "$CHECK_MUI" != "" ]]; then
        source $mon_script_langue
        my_title_count=`echo -n "$mui_script_in_cron_disable" | sed "s/\\\e\[[0-9]\{1,2\}m//g" | wc -c`
        line_lengh="78"
        before_after_count="0"
        before_after_count=$(bc -l <<<"scale=1; ( $line_lengh - $my_title_count ) / 2")
        if [[ $before_after_count =~ ".5" ]]; then
          before_after_count=$((($line_lengh-$my_title_count)/2))
          before=`eval printf "%0.s-" {1..$before_after_count}`
          before_after_count=$(((($line_lengh-$my_title_count)/2)+1))
          after=`eval printf "%0.s-" {1..$before_after_count}`
        else
          before_after_count=$((($line_lengh-$my_title_count)/2))
          before=`eval printf "%0.s-" {1..$before_after_count}`
          after=`eval printf "%0.s-" {1..$before_after_count}`
        fi
        eval 'printf "\e[101m%s%s%s\e[0m\n" "$before" "$mui_script_in_cron_disable" "$after"' $mon_log_perso
      else
        eval 'echo -e "\e[101mLE SCRIPT EST PRÉSENT DANS LE CRON MAIS DÉSACTIVÉ\e[0m"' $mon_log_perso
      fi

    else
      if [[ "$CHECK_MUI" != "" ]]; then
        source $mon_script_langue
        my_title_count=`echo -n "$mui_script_in_cron" | sed "s/\\\e\[[0-9]\{1,2\}m//g" | wc -c`
        line_lengh="78"
        before_after_count=$(bc -l <<<"scale=1; ( $line_lengh - $my_title_count ) / 2")
        if [[ $before_after_count =~ ".5" ]]; then
          before_after_count=$((($line_lengh-$my_title_count)/2))
          before=`eval printf "%0.s-" {1..$before_after_count}`
          before_after_count=$(((($line_lengh-$my_title_count)/2)+1))
          after=`eval printf "%0.s-" {1..$before_after_count}`
        else
          before_after_count=$((($line_lengh-$my_title_count)/2))
          before=`eval printf "%0.s-" {1..$before_after_count}`
          after=`eval printf "%0.s-" {1..$before_after_count}`
        fi
        eval 'printf "\e[101m%s%s%s\e[0m\n" "$before" "$mui_script_in_cron" "$after"' $mon_log_perso
      else
        eval 'echo -e "\e[101mLE SCRIPT EST PRÉSENT DANS LE CRON\e[0m"' $mon_log_perso
      fi
    fi
  fi
fi
 
#### Vérification/création du fichier conf
if [[ -f "$mon_script_config" ]] ; then
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    my_title_count=`echo -n "$mui_conf_ok" | sed "s/\\\e\[[0-9]\{1,2\}m//g" | wc -c`
    line_lengh="78"
    before_after_count=$(bc -l <<<"scale=1; ( $line_lengh - $my_title_count ) / 2")
    if [[ $before_after_count =~ ".5" ]]; then
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      before_after_count=$(((($line_lengh-$my_title_count)/2)+1))
      after=`eval printf "%0.s-" {1..$before_after_count}`
    else
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      after=`eval printf "%0.s-" {1..$before_after_count}`
    fi
    eval 'printf "\e[42m%s%s%s\e[0m\n" "$before" "$mui_conf_ok" "$after"' $mon_log_perso
  else
    eval 'echo -e "\e[42mLE FICHIER CONF EST PRESENT\e[0m"' $mon_log_perso
  fi
else
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    my_title_count=`echo -n "$mui_no_conf_missing" | sed "s/\\\e\[[0-9]\{1,2\}m//g" | wc -c`
    line_lengh="78"
    before_after_count=$(bc -l <<<"scale=1; ( $line_lengh - $my_title_count ) / 2")
    if [[ $before_after_count =~ ".5" ]]; then
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      before_after_count=$(((($line_lengh-$my_title_count)/2)+1))
      after=`eval printf "%0.s-" {1..$before_after_count}`
    else
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      after=`eval printf "%0.s-" {1..$before_after_count}`
    fi
    eval 'printf "\e[42m%s%s%s\e[0m\n" "$before" "$mui_no_conf_missing" "$after"' $mon_log_perso
    my_title_count=`echo -n "$mui_no_conf_creating" | sed "s/\\\e\[[0-9]\{1,2\}m//g" | wc -c`
    line_lengh="78"
    before_after_count=$(bc -l <<<"scale=1; ( $line_lengh - $my_title_count ) / 2")
    if [[ $before_after_count =~ ".5" ]]; then
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      before_after_count=$(((($line_lengh-$my_title_count)/2)+1))
      after=`eval printf "%0.s-" {1..$before_after_count}`
    else
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      after=`eval printf "%0.s-" {1..$before_after_count}`
    fi
    eval 'printf "\e[42m%s%s%s\e[0m\n" "$before" "$mui_no_conf_creating" "$after"' $mon_log_perso
  else
    eval 'echo -e "\e[41mLE FICHIER CONF EST ABSENT\e[0m"' $mon_log_perso
    eval 'echo "-- Création du fichier conf..."' $mon_log_perso
  fi
  touch "$mon_script_config"
  chmod 777 "$mon_script_config"
  if [[ "$affichage_langue" == "french" ]]; then
    cat <<EOT >> "$mon_script_config"
####################################
## Configuration
####################################
 
#### Mise à jour forcée
## à n'utiliser qu'en cas de soucis avec la vérification de process (oui/non)
maj_force="non"
 
#### Chemin complet vers le script source (pour les maj)
script_url=""
 
#### Affichage de la section dépendances
## mettre oui/non
affiche_dependances="non"
 
#### Dossier d'installation de WSUS Offline Update
dossier_installation="/opt"
 
#### Paramètres des mise à jour
## w60 (Windows Server 2008, 32-bit), w60-x64 (Windows Server 2008, 64-bit), w61 (Windows 7, 32-bit), w61-x64 (Windows 7 / Server 2008 R2, 64-bit), w62-x64 (Windows Server 2012, 64-bit), w63 (Windows 8.1, 32-bit), w63-x64 (Windows 8.1 / Server 2012 R2, 64-bit), w100 (Windows 10, 32-bit), w100-x64 (Windows 10 / Server 2016, 64-bit), o2k10 (Office 2010, 32-bit), o2k10-x64 (Office 2010, 32-bit and 64-bit), o2k13 (Office 2013, 32-bit), o2k13-x64 (Office 2013, 32-bit and 64-bit), o2k16 (Office 2016, 32-bit), o2k16-x64 (Office 2016, 32-bit and 64-bit), all (All Windows and Office updates, 32-bit and 64-bit), all-x86 (All Windows and Office updates, 32-bit), all-x64 (All Windows and Office updates, 64-bit), all-win (All Windows updates, 32-bit and 64-bit), all-win-x86 (All Windows updates, 32-bit), all-win-x64 (All Windows updates, 64-bit), all-ofc (All Office updates, 32-bit and 64-bit), all-ofc-x86 (All Office updates, 32-bit)
maj="w61,w61-64"
## deu (German), enu (English), ara (Arabic), chs (Chinese (Simplified)), cht (Chinese (Traditional)), csy (Czech), dan (Danish), nld (Dutch), fin (Finnish), fra (French), ell (Greek), heb (Hebrew), hun (Hungarian), ita (Italian), jpn (Japanese), kor (Korean), nor (Norwegian), plk (Polish), ptg (Portuguese), ptb (Portuguese (Brazil)), rus (Russian), esn (Spanish), sve (Swedish), trk (Turkish)
langue="fra"
 
#### Paramètre du push
## ces réglages se trouvent sur le site http://www.pushover.net
token_app=""
destinataire_1=""
destinataire_2=""
titre_push=""
 
####################################
## Fin de configuration
####################################
EOT
  else
    cat <<EOT >> "$mon_script_config"
####################################
## Settings
####################################
 
#### Overriding updates
## only use if the process dupe checker is stuck (oui/non)
maj_force="non"
 
#### Full path to script's source (for updates)
script_url=""
 
#### Display the dependencies checking
## use yes/no
display_dependencies="no"
 
#### Installation folder of WSUS Offline Update
installation_folder="/opt"
 
#### Update parameters
## w60 (Windows Server 2008, 32-bit), w60-x64 (Windows Server 2008, 64-bit), w61 (Windows 7, 32-bit), w61-x64 (Windows 7 / Server 2008 R2, 64-bit), w62-x64 (Windows Server 2012, 64-bit), w63 (Windows 8.1, 32-bit), w63-x64 (Windows 8.1 / Server 2012 R2, 64-bit), w100 (Windows 10, 32-bit), w100-x64 (Windows 10 / Server 2016, 64-bit), o2k10 (Office 2010, 32-bit), o2k10-x64 (Office 2010, 32-bit and 64-bit), o2k13 (Office 2013, 32-bit), o2k13-x64 (Office 2013, 32-bit and 64-bit), o2k16 (Office 2016, 32-bit), o2k16-x64 (Office 2016, 32-bit and 64-bit), all (All Windows and Office updates, 32-bit and 64-bit), all-x86 (All Windows and Office updates, 32-bit), all-x64 (All Windows and Office updates, 64-bit), all-win (All Windows updates, 32-bit and 64-bit), all-win-x86 (All Windows updates, 32-bit), all-win-x64 (All Windows updates, 64-bit), all-ofc (All Office updates, 32-bit and 64-bit), all-ofc-x86 (All Office updates, 32-bit)
update="w61,w61-64"
## deu (German), enu (English), ara (Arabic), chs (Chinese (Simplified)), cht (Chinese (Traditional)), csy (Czech), dan (Danish), nld (Dutch), fin (Finnish), fra (French), ell (Greek), heb (Hebrew), hun (Hungarian), ita (Italian), jpn (Japanese), kor (Korean), nor (Norwegian), plk (Polish), ptg (Portuguese), ptb (Portuguese (Brazil)), rus (Russian), esn (Spanish), sve (Swedish), trk (Turkish)
language="fra"
 
#### Paramètre du push
## ces réglages se trouvent sur le site http://www.pushover.net
token_app=""
destinataire_1=""
destinataire_2=""
titre_push=""
 
####################################
## Fin de configuration
####################################
EOT
  fi
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'echo -e "$mui_no_conf_created"' $mon_log_perso
    eval 'echo -e "$mui_no_conf_edit"' $mon_log_perso
    eval 'echo -e "$mui_no_conf_help"' $mon_log_perso
  else
    eval 'echo "-- Fichier conf créé"' $mon_log_perso
    eval 'echo "Vous dever éditer le fichier \"$mon_script_config\" avant de poursuivre"' $mon_log_perso
    eval 'echo "Vous pouvez utiliser: ./"$mon_script_fichier" --edit-config"' $mon_log_perso
  fi
  rm $pid_script
  exit 1
fi
 
#### Vérification/création du fichier ini
if [[ -f "$mon_script_ini" ]] ; then
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    my_title_count=`echo -n "$mui_ini_ok" | sed "s/\\\e\[[0-9]\{1,2\}m//g" | wc -c`
    line_lengh="78"
    before_after_count=$(bc -l <<<"scale=1; ( $line_lengh - $my_title_count ) / 2")
    if [[ $before_after_count =~ ".5" ]]; then
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      before_after_count=$(((($line_lengh-$my_title_count)/2)+1))
      after=`eval printf "%0.s-" {1..$before_after_count}`
    else
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      after=`eval printf "%0.s-" {1..$before_after_count}`
    fi
    eval 'printf "\e[42m%s%s%s\e[0m\n" "$before" "$mui_ini_ok" "$after"' $mon_log_perso
  else
    eval 'echo -e "\e[42mLE FICHIER INI EST PRESENT\e[0m"' $mon_log_perso
  fi
else
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'echo -e "$mui_ini_missing"' $mon_log_perso
    eval 'echo -e "$mui_ini_creating"' $mon_log_perso
  else
    eval 'echo -e "\e[41mLE FICHIER INI EST ABSENT\e[0m"' $mon_log_perso
    eval 'echo "-- Création du fichier ini..."' $mon_log_perso
  fi
  touch $mon_script_ini
  chmod 777 $mon_script_ini
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'echo -e "$mui_ini_created"' $mon_log_perso
  else
    eval 'echo "-- Fichier ini créé"' $mon_log_perso
  fi
fi
 
echo "------------------------------------------------------------------------------"
 
if [[ "$display_dependencies" == "yes" ]] || [[ "$affiche_dependances" == "oui" ]]; then
  #### VERIFICATION DES DEPENDANCES
  ##########################
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'printf  "\e[44m\u2263\u2263  \e[0m \e[44m \e[1m %-62s  \e[0m \e[44m  \e[0m \e[44m \e[0m \e[34m\u2759\e[0m\n" "$mui_section_dependencies"' $mon_log_perso
  else
    eval 'echo -e "\e[44m\u2263\u2263  \e[0m \e[44m \e[1mVÉRIFICATION DES DÉPENDANCES  \e[0m \e[44m  \e[0m \e[44m \e[0m \e[34m\u2759\e[0m"' $mon_log_perso
  fi
  
  #### Vérification et installation des repositories (apt)
  for repo in $required_repos ; do
    ppa_court=`echo $repo | sed 's/.*ppa://' | sed 's/\/ppa//'`
    check_repo=`grep ^ /etc/apt/sources.list /etc/apt/sources.list.d/* | grep "$ppa_court"`
    if [[ "$check_repo" == "" ]]; then
      add-apt-repository $repo -y
      update_a_faire="1"
    else
      if [[ "$CHECK_MUI" != "" ]]; then
        source $mon_script_langue
        eval 'echo -e "$mui_required_repository"' $mon_log_perso
      else
        eval 'echo -e "[\e[42m\u2713 \e[0m] Le dépôt apt: "$repo" est installé"' $mon_log_perso
      fi
    fi
  done
  if [[ "$update_a_faire" == "1" ]]; then
    apt update
  fi
  
  #### Vérification et installation des outils requis si besoin (apt)
  for tools in $required_tools ; do
    check_tool=`dpkg --get-selections | grep -w "$tools"`
    if [[ "$check_tool" == "" ]]; then
      apt-get install $tools -y
    else
      if [[ "$CHECK_MUI" != "" ]]; then
        source $mon_script_langue
        eval 'echo -e "$mui_required_apt"' $mon_log_perso
      else
        eval 'echo -e "[\e[42m\u2713 \e[0m] La dépendance: "$tools" est installée"' $mon_log_perso
      fi
    fi
  done
  
  #### Vérification et installation des outils requis si besoin (pip)
  for tools_pip in $required_tools_pip ; do
    check_tool=`pip freeze | grep "$tools_pip"`
      if [[ "$check_tool" == "" ]]; then
        pip install $tools_pip
      else
        if [[ "$CHECK_MUI" != "" ]]; then
          source $mon_script_langue
          eval 'echo -e "$mui_required_pip"' $mon_log_perso
        else
          eval 'echo -e "[\e[42m\u2713 \e[0m] La dépendance: "$tools_pip" est installée"' $mon_log_perso
        fi
      fi
  done
fi
 
#### Ajout de ce script dans le menu
if [[ -f "/etc/xdg/menus/applications-merged/scripts-scoony.menu" ]] ; then
  useless=1
else
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'echo -e "$mui_creating_menu_entry"' $mon_log_perso
  else
    echo "... création du menu"
  fi
  mkdir -p /etc/xdg/menus/applications-merged
  touch "/etc/xdg/menus/applications-merged/scripts-scoony.menu"
  cat <<EOT >> /etc/xdg/menus/applications-merged/scripts-scoony.menu
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
"http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
<Menu>
<Name>Applications</Name>
 
<Menu> <!-- scripts-scoony -->
<Name>scripts-scoony</Name>
<Directory>scripts-scoony.directory</Directory>
<Include>
<Category>X-scripts-scoony</Category>
</Include>
</Menu> <!-- End scripts-scoony -->
 
</Menu> <!-- End Applications -->
EOT
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'echo -e "$mui_created_menu_entry"' $mon_log_perso
  else
    eval 'echo "... menu créé"' $mon_log_perso
  fi
fi
 
if [[ -f "/usr/share/desktop-directories/scripts-scoony.directory" ]] ; then
  useless=1
else
## je met l'icone en place
  wget -q http://i.imgur.com/XRCxvJK.png -O /usr/share/icons/scripts.png
  if [[ "$CHECK_MUI" != "" ]]; then
    source $mon_script_langue
    eval 'echo "$mui_creating_menu_folder"' $mon_log_perso
  else
    eval 'echo "... création du dossier du menu"' $mon_log_perso
  fi
  if [[ ! -d "/usr/share/desktop-directories" ]] ; then
    mkdir -p /usr/share/desktop-directories
  fi
  touch "/usr/share/desktop-directories/scripts-scoony.directory"
  cat <<EOT >> /usr/share/desktop-directories/scripts-scoony.directory
[Desktop Entry]
Type=Directory
Name=Scripts Scoony
Icon=/usr/share/icons/scripts.png
EOT
fi
 
if [[ -f "/usr/local/share/applications/$mon_script_desktop" ]] ; then
  useless=1
else
  wget -q $icone_github -O /usr/share/icons/$mon_script_base.png
  if [[ -d "/usr/local/share/applications" ]]; then
    useless="1"
  else
    mkdir -p /usr/local/share/applications
  fi
  touch "/usr/local/share/applications/$mon_script_base.desktop"
  cat <<EOT >> /usr/local/share/applications/$mon_script_base.desktop
#!/usr/bin/env xdg-open
[Desktop Entry]
Type=Application
Terminal=true
Name=Script $mon_script_base
Icon=/usr/share/icons/$mon_script_base.png
Exec=/opt/scripts/$mon_script_fichier --menu
Comment[fr_FR]=$description
Comment=$description
Categories=X-scripts-scoony;
EOT
fi
 
####################
## On commence enfin
####################
 
cd /opt/scripts
 
#### Téléchargement de wsusoffline
if [[ "$install_dir" != "" ]]; then
  eval 'echo -e "[\e[42m\u2713 \e[0m] Répertoire d\0047installation :" $install_dir' $mon_log_perso
  if [[ "$dossier_installation" != "" ]] || [[ "$installation_folder" != "" ]]; then
    if [[ "$dossier_installation" != "" ]]; then
      eval 'echo -e "[\e[42m\u2713 \e[0m] Le paramètre \"dossier_installation\" est ignoré :" $dossier_installation' $mon_log_perso
    else
      eval 'echo -e "[\e[42m\u2713 \e[0m] Le paramètre \"dossier_installation\" est ignoré :" $installation_folder' $mon_log_perso
    fi
  fi
else
  if [[ "$dossier_installation" != "" ]]; then
    eval 'echo -e "[\e[42m\u2713 \e[0m] Répertoire d\0047installation :" $dossier_installation' $mon_log_perso
    install_dir=$dossier_installation
  else
    eval 'echo -e "[\e[42m\u2713 \e[0m] Répertoire d\0047installation :" $installation_folder' $mon_log_perso
    install_dir=$installation_folder
  fi
fi
if [[ -d "$install_dir/wsusoffline" ]]; then
  eval 'echo -e "[\e[42m\u2713 \e[0m] La dépendance: wsusoffline est installée"' $mon_log_perso
else
  eval 'echo -e "[\e[41m\u2717 \e[0m] La dépendance: wsusoffline n\0047est pas installée"' $mon_log_perso
  mkdir -p "$install_dir/wsusoffline"
  if [[ "$install_dir" != "/opt" ]]; then
    ln -sf "$install_dir/wsusoffline" "/opt/"
  fi
  wget -q -O- "http://download.wsusoffline.net/" > $install_dir/wsusoffline/download.html &
  pid=$!
  spin='-\|/'
  i=0
  while kill -0 $pid 2>/dev/null
  do
    i=$(( (i+1) %4 ))
    printf "\rVérification de la version de wsusoffline en ligne... ${spin:$i:1}"
    sleep .1
  done
  printf "$mon_printf" && printf "\r"
  link_wsusoffline=`cat $install_dir/wsusoffline/download.html | grep -m 1 "\">Version " | sed 's/">Version .*//' | sed 's/.*a href="//'`
  file_wsusoffline=`echo $link_wsusoffline | sed 's/.*\(.*\)\//\1/'`
  version_wsusoffline=`cat $install_dir/wsusoffline/download.html | grep -m 1 "\">Version " | sed 's/<\/a> (<a href=".*//' | sed 's/.*">Version //'`
  wget -q $link_wsusoffline -O $install_dir/wsusoffline/$file_wsusoffline &
  pid=$!
  spin='-\|/'
  i=0
  while kill -0 $pid 2>/dev/null
  do
    i=$(( (i+1) %4 ))
    printf "\r[  ] Téléchargement de wsusoffline $version_wsusoffline ($file_wsusoffline)... ${spin:$i:1}"
    sleep .1
  done
  printf "$mon_printf" && printf "\r"
  check_zip=`unzip -t $install_dir/wsusoffline/$file_wsusoffline | grep "No errors detected"`
  if [[ "$check_zip" != "" ]]; then
    unzip $install_dir/wsusoffline/$file_wsusoffline -d $install_dir/ >> $install_dir/wsusoffline/wsusoffline.log &
    pid=$!
    spin='-\|/'
    i=0
    while kill -0 $pid 2>/dev/null
    do
      i=$(( (i+1) %4 ))
      printf "\r[  ] Décompression de wsusoffline... ${spin:$i:1}"
      sleep .1
    done
    printf "$mon_printf" && printf "\r"
    eval 'echo -e "[\e[42m\u2713 \e[0m] La dépendance: wsusoffline $version_wsusoffline est installée"' $mon_log_perso
    wget -q -O- "http://downloads.hartmut-buhrmester.de/available-version.txt" > $install_dir/wsusoffline/available-version.html &
    pid=$!
    spin='-\|/'
    i=0
    while kill -0 $pid 2>/dev/null
    do
      i=$(( (i+1) %4 ))
      printf "\r[  ] Vérification de la version des scripts de wsusoffline en ligne... ${spin:$i:1}"
      sleep .1
    done
    printf "$mon_printf" && printf "\r"
    version_scripts=`cat $install_dir/wsusoffline/available-version.html | awk '{print $1}'`
    link_scripts=`cat $install_dir/wsusoffline/available-version.html | awk '{print $2}'`
    file_scripts=`echo $link_scripts | sed 's/.*\(.*\)\//\1/'`
    nom_scripts=`cat $install_dir/wsusoffline/available-version.html | awk '{print $4}'`
    wget -q $link_scripts -O $install_dir/wsusoffline/$file_scripts &
    pid=$!
    spin='-\|/'
    i=0
    while kill -0 $pid 2>/dev/null
    do
      i=$(( (i+1) %4 ))
      printf "\r[  ] Mise à jour des scripts $nom_scripts ($version_scripts) de wsusoffline... ${spin:$i:1}"
      sleep .1
    done
    printf "$mon_printf" && printf "\r"
    check_zip=`gunzip -t $install_dir/wsusoffline/$file_scripts`
    if [[ "$check_zip" == "" ]]; then
      tar zxf "$install_dir/wsusoffline/$file_scripts" -C "$install_dir/wsusoffline/"
      rm -r -f "$install_dir/wsusoffline/sh"
      mv -f "$install_dir/wsusoffline/$nom_scripts/" "$install_dir/wsusoffline/sh/"
      bash $install_dir/wsusoffline/sh/fix-file-permissions.bash
      eval 'echo -e "[\e[42m\u2713 \e[0m] La dépendance: maj des scripts $nom_scripts ($version_scripts) de wsusoffline installée"' $mon_log_perso
    else
      eval 'echo -e "[\e[41m\u2717 \e[0m] La dépendance: installation de la maj des scripts $nom_scripts ($version_scripts) de wsusoffline en erreur"' $mon_log_perso
    fi
  else
    eval 'echo -e "[\e[41m\u2717 \e[0m] La dépendance: installation de wsusoffline $version_wsusoffline en erreur"' $mon_log_perso
  fi
  chmod 777 -R "$install_dir/wsusoffline/"
fi
 
### Téléchargement des mises à jour
if [[ -d "$install_dir/wsusoffline" ]]; then
  for majId in ${maj//,/ }; do
    echo "Windows : $majId - langue : $langue"
  done
fi
 
fin_script=`date`
if [[ "$CHECK_MUI" != "" ]]; then
  source $mon_script_langue
  my_title_count=`echo -n "$mui_end_of_script" | sed "s/\\\e\[[0-9]\{1,2\}m//g" | wc -c`
  line_lengh="78"
  before_after_count=$((($line_lengh-$my_title_count)/2))
  if [[ $before_after_count =~ ".5" ]]; then
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      before_after_count=$(((($line_lengh-$my_title_count)/2)+1))
      after=`eval printf "%0.s-" {1..$before_after_count}`
    else
      before_after_count=$((($line_lengh-$my_title_count)/2))
      before=`eval printf "%0.s-" {1..$before_after_count}`
      after=`eval printf "%0.s-" {1..$before_after_count}`
  fi
  if [[ -f "$fichier_log_perso" ]]; then
    eval 'printf "\e[43m%s%s%s\e[0m\n" "$before" "$mui_end_of_script" "$after"' $mon_log_perso
  else
    printf "\e[43m%s%s%s\e[0m\n" "$before" "$mui_end_of_script" "$after"
  fi
else
  if [[ -f "$fichier_log_perso" ]]; then
    eval 'echo -e "\e[43m -- FIN DE SCRIPT: $fin_script -- \e[0m "' $mon_log_perso
  else
    echo -e "\e[43m -- FIN DE SCRIPT: $fin_script -- \e[0m "
  fi
fi
rm "$pid_script"

if [[ "$1" == "--menu" ]]; then
  read -rsp $'Press a key to close the window...\n' -n1 key
fi
