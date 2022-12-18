#!/bin/bash


#######################
## Check if this script is running
check_dupe=$(ps -ef | grep "$0" | grep -v grep | wc -l | xargs)
check_cron=`echo $-`
if [[ "$check_cron" =~ "i" ]]; then
  process_number="2"
else
  process_number="3"
fi
if [[ "$check_dupe" > "$process_number" ]]; then
  echo "Script already running ($check_dupe)"
  date
  exit 1
fi


#######################
## Generating variables for script
script_name=$(basename $0 | cut -d'.' -f1)
script_name_cap=${script_name^^}
script_name_full=$(basename $0)
script_bin=$0
script_conf=`echo $HOME"/.config/"$script_name"/"$script_name".conf"`
script_remote="https://raw.githubusercontent.com/scoony/$script_name/main/$script_name_full"
script_cron_log=`echo "/var/log/"$script_name".log"`


#######################
## Advanced command arguments
die() { echo "$*" >&2; exit 2; }  # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }

while getopts eushf:cm:l:-: OPT; do
  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi
  case "$OPT" in
    h | help )
            echo -e "\033[1m$script_name_cap - help\033[0m"
            echo ""
            echo "Usage : $script_bin [option]"
            echo ""
            echo "Available options:"
            echo "[value*] means optional argument"
            echo ""
            echo " -h or --help                              : this help menu"
            echo " -u or --update                            : update this script"
            echo " -m [value] or --mode=[value]              : change display mode (full)"
            echo " -l [value] or --language=[value]          : override language (fr or en)"
            echo " -c or --cron-log                          : display latest cron log"
            echo " -e [value*] or --edit-config=[value*]     : edit config file (default: nano)"
            echo " -s [value*] or --status=[value*]          : status/enable/disable the script"
            echo " -f \"[value]\" or --find=\"[value]\"          : find something in the logs"
            exit 0
            ;;
    f | find )
            needs_arg
            arg_search_value="$OPTARG"
            echo -e "\033[1m$script_name_cap - find feature\033[0m"
            echo "This feature require root privileges"
            echo ""
            echo "Checking for root privileges..."
            source "$script_conf" 2>/dev/null
            if [[ "$sudo" == "" ]] && [[ "$EUID" != "0" ]]; then
              echo "No root privileges... exit"
            else
              echo "Root privileges granted"
            fi
            echo "Updating db..."
            echo "$sudo" | sudo -kS updatedb 2>/dev/null
            logs_path=`echo "$sudo" | sudo -kS locate -r "/$script_name/logs$" 2>/dev/null`
            echo "Searching..."
            for log_path in $logs_path ; do
              my_logs=( `echo "$sudo" | sudo -kS find $log_path -type f 2>/dev/null` )
              for my_log in ${my_logs[@]} ; do
                echo "$sudo" | sudo -kS grep -Hin "$arg_search_value" $my_log 2>/dev/null
              done
            done
            exit 0
            ;;
    u | update )
            echo -e "\033[1m$script_name_cap - Update initiated\033[0m"
            read -n 1 -p "Do you want to proceed [y/N]:" yn
            printf "\r                                                     "
            if [[ "${yn}" == @(y|Y) ]]; then
              echo ""
              this_script=$(realpath -s "$0")
              echo "Script location : "$this_script
              script_remote="$script_remote"
              if curl -m 2 --head --silent --fail "$script_remote" 2>/dev/null >/dev/null; then
                echo "Script available online on GitHub "
                md5_local=`md5sum "$this_script" | cut -f1 -d" " 2>/dev/null`
                md5_remote=`curl -s "$script_remote" | md5sum | cut -f1 -d" "`
                echo "MD5 local  : "$md5_local
                echo "MD5 remote : "$md5_remote
                if [[ "$md5_local" != "$md5_remote" ]]; then
                  echo "A new version of the script is available... downloading"
##                  curl -s -m 3 --create-dir -o "$this_script" "$script_remote"
                  echo "Update completed... exit"
                else
                  echo "The script is up to date... exit"
                fi
              else
                echo "Script offline"
              fi
            else
              echo ""
              echo "Nothing was done"
            fi
            exit 0
            ;;
    c | cron-log )
            echo -e "\033[1m$script_name_cap - latest cron log\033[0m"
            echo ""
            if [[ -f "$script_cron_log" ]]; then
              date_log=`date -r "$script_cron_log" `
              cat "$script_cron_log"
              echo ""
              echo "Log created : "$date_log
            else
              echo "No log found"
            fi
            exit 0
            ;;
    m | mode )
            needs_arg
            arg_display_mode="$OPTARG"
            display_mode_supported=( "full" )
            echo -e "\033[1m$script_name_cap - display mode override\033[0m"
            echo ""
            if [[ "${display_mode_supported[@]}" =~ "$arg_display_mode" ]]; then
              echo "Display mode activated: $arg_display_mode"
            else
              echo "Display mode $arg_display_mode not supported yet"
              exit 0
            fi
            ;;
    l | language )
            needs_arg
            display_language="$OPTARG"
            language_supported=( "fr" "en" )
            echo
            if [[ "${language_supported[@]}" =~ "$display_language" ]]; then
              echo "Language selected : $display_language"
            else
              echo "Language $display_language not supported yet"
              exit 0
            fi
            ;;
    e | edit-config )
            eval next_arg=\${$OPTIND}
            if [[ "$next_arg" == "" ]]; then
              echo -e "\033[1m$script_name_cap - config editor\033[0m"
              echo ""
              echo "No editor specified, using default (nano)"
              nano "$script_conf"
              exit 0
            else
              echo -e "\033[1m$script_name_cap - config editor\033[0m"
              echo ""
              if command -v $next_arg ; then
                echo "Editing config with: $next_arg"
                $next_arg "$script_conf"
              else
                echo "There is no software called \"$next_arg\" installed"
              fi
              exit 0
            fi
            ;;
    s | status )
            echo -e "\033[1m$script_name_cap - status (cron)\033[0m"
            echo ""
            eval next_arg=\${$OPTIND}
            if [[ "$next_arg" == @(|status) ]]; then
              echo "Checking scheduler status..."
              crontab -l > $HOME/my_old_cron.txt
              cron_check=`cat $HOME/my_old_cron.txt | grep $script_name`
              if [[ "$cron_check" != "" ]]; then
                echo "- script was added in the cron"
                cron_status=`cat $HOME/my_old_cron.txt | grep $script_name | grep "^#"`
                if [[ "$cron_status" == "" ]]; then
                  echo "- script is currently enabled"
                else
                  echo "- script is currently disabled"
                fi
              else
                echo "- script wasn't added in the cron"
              fi
            elif [[ "$next_arg" == "enable" ]]; then
              echo "Enabling the script in the cron"
              crontab -l > $HOME/my_old_cron.txt
              safety_check=`cat $HOME/my_old_cron.txt | grep $script_name | grep "^#"`
              if [[ "$safety_check" != "" ]]; then
                cat $HOME/my_old_cron.txt | grep $script_name | sed  's/^#//' > $HOME/my_new_cron.txt
                crontab $HOME/my_new_cron.txt
              else
                echo "Script is already enabled"
              fi
            elif [[ "$next_arg" == "disable" ]]; then
              echo "Disabling the script in the cron"
              crontab -l > $HOME/my_old_cron.txt
              safety_check=`cat $HOME/my_old_cron.txt | grep $script_name | grep "^#"`
              if [[ "$safety_check" == "" ]]; then
                cat $HOME/my_old_cron.txt | grep $script_name | sed 's/^/#/' > $HOME/my_new_cron.txt
                crontab $HOME/my_new_cron.txt
              else
                echo "Script is already disabled"
              fi
            fi
            rm $HOME/my_old_cron.txt 2>/dev/null
            rm $HOME/my_new_cron.txt 2>/dev/null
            exit 0
            ;;
    ??* )          die "Illegal option --$OPT" ;;  # bad long option
    ? )            exit 2 ;;  # bad short option (error reported via getopts)
  esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list


#######################
## Script configuration
if [[ ! -f "$HOME/.config/plex_convert/plex_convert.conf" ]]; then
  my_settings_variables="home_temp convert_folder error_folder audio_required profile_4K profile_QHD profile_Full_HD profile_HD profile_DVD profile_Default sudo ffmpeg_check"
  mkdir -p "$HOME/.config/plex_convert"
  touch "$HOME/.config/plex_convert/plex_convert.conf"
  my_config_file=`cat "$HOME/.config/plex_convert/plex_convert.conf"`
  for script_variable in $my_settings_variables ; do
    if [[ ! "$my_config_file" =~ "$script_variable" ]]; then
      echo $script_variable"=\"\"" >> $HOME/.config/plex_convert/plex_convert.conf
    edit_conf="1"
    fi
  done
  if [[ "$edit_conf" == "1" ]]; then
    echo "... edit your configuration"
    exit 0
  fi
else
  source "$HOME/.config/plex_convert/plex_convert.conf"
fi


#######################
## Fix printf special char issue
Lengh1="55"
Lengh2="61"
lon() ( echo $(( Lengh1 + $(wc -c <<<"$1") - $(wc -m <<<"$1") )) )
lon2() ( echo $(( Lengh2 + $(wc -c <<<"$1") - $(wc -m <<<"$1") )) )


printf "\e[46m\u23E5\u23E5   \e[0m \e[46m \e[1m %-61s  \e[0m \e[46m  \e[0m \e[46m \e[0m \e[36m\u2759\e[0m\n" "PLEX CONVERT"
echo ""

#######################
## Creating required folders
mkdir -p "$home_temp" 2>/dev/null
mkdir -p "$convert_folder" 2>/dev/null
mkdir -p "$error_folder" 2>/dev/null


#######################
## UI tags
ui_tag_checking="[\e[43m \u003F \e[0m]"
ui_tag_encoding="[\e[7m \u238B \e[0m]"
ui_tag_ok="[\e[42m \u2713 \e[0m]"
ui_tag_ok_sed="[\\\e[42m \\\u2713 \\\e[0m]"
ui_tag_bad="[\e[41m \u2713 \e[0m]"
ui_tag_warning="[\e[43m \u2713 \e[0m]"
ui_tag_section="\e[44m[\u2263\u2263\u2263]\e[0m \e[44m \e[1m %-*s  \e[0m \e[44m  \e[0m \e[44m \e[0m \e[34m\u2759\e[0m\n"


#######################
## Loading spinner
function display_loading() {
  pid="$*"
  if [[ "$mui_loading_spinner" == "" ]]; then                                               ## MUI
    mui_loading_spinner="Loading..."                                                        ##
  fi                                                                                        ##
  lengh_spinner=${#mui_loading_spinner}
  if [[ "$loading_spinner" == "" ]]; then
    spin='⣾⣽⣻⢿⡿⣟⣯⣷'
  else
    spin=$loading_spinner
  fi
  charwidth=1
  i=0
  tput civis # cursor invisible
  mon_printf="\r                                                                             "
  while kill -0 "$pid" 2>/dev/null; do
    i=$(((i + $charwidth) % ${#spin}))
    printf "\r[\e[43m \u039E \e[0m] %"$lengh_spinner"s %s" "$mui_loading_spinner" "${spin:$i:$charwidth}"
    sleep .1
  done
  tput cnorm
  printf "$mon_printf" && printf "\r"
}


#######################
## Encoding spinner
function encoding_loading() {
  pid="$*"
  if [[ "$mui_encoding_spinner" == "" ]]; then                                               ## MUI
    mui_encoding_spinner="Encoding..."                                                        ##
  fi                                                                                        ##
  lengh_spinner2=${#mui_encoding_spinner}
  if [[ "$encoding_spinner" == "" ]]; then
    spin2='⣾⣽⣻⢿⡿⣟⣯⣷'
  else
    spin2=$encoding_spinner
  fi
  charwidth=1
  i=0
  tput civis # cursor invisible
  mon_printf="\r                                                                             "
  while kill -0 "$pid" 2>/dev/null; do
    progress=`cat -A "$home_temp/handbrake_process.txt" | tr "^M" "\n" | tail -n1 | awk '{ print $6 }'`
    i=$(((i + $charwidth) % ${#spin}))
    printf "$mon_printf"
    printf "\r[\e[7m \u238B \e[0m] [$progress \u0025] %"$lengh_spinner2"s %s" "$mui_encoding_spinner" "${spin2:$i:$charwidth}"
    sleep .1
  done
  tput cnorm
  printf "$mon_printf" && printf "\r"
}


#######################
## Function to get standardized resolution
standard-resolution() {
x=`echo $1 | awk '{ print $1}'`
y=`echo $1 | awk '{ print $3}'`
## resolution_4k="3840 x 2160"     ## (x) 27% 2803 / (y) 27% donc 1577
## resolution_qhd="2560 x 1440"    ## (x) 27% 1868 / (y) 27% donc 1051
## resolution_fullhd="1920 x 1080" ## (x) 27% 1401 / (y) 27% donc 788
## resolution_hd="1280 x 720"      ## (x) 27% 934  / (y) 27% donc 525
## resolution_dvd="720 × 576"      ## (x) 27% 525  / (y) 27% donc 420
if [[ "$x" -ge "2561" ]] && [[ "$y" -ge "1577" ]]; then
  echo "4K"
elif [[ "$x" -ge "1921" ]] && [[ "$y" -ge "1051" ]]; then
  echo "QHD"
elif [[ "$x" -ge "1281" ]] && [[ "$y" -ge "788" ]]; then
  echo "Full_HD"
elif [[ "$x" -ge "721" ]] && [[ "$y" -ge "525" ]]; then
  echo "HD"
elif [[ "$x" -ge "641" ]] && [[ "$y" -ge "420" ]]; then
  echo "DVD"
else
  echo "\e[41m! Too low !\e[0m"
fi
}


#######################
## Dependencies
section_title="Checking dependencies"
printf "$ui_tag_section" $(lon2 "$section_title") "$section_title"
my_dependencies="filebot curl awk HandBrakeCLI"
for dependency in $my_dependencies ; do
  if $dependency -help > /dev/null 2>/dev/null ; then
    echo -e "$ui_tag_ok Dependency: $dependency"
  else
    echo -e "$ui_tag_bad Dependency missing: $dependency"
  fi
done
echo ""


#######################
## Update the locate db and load plex_sort config
section_title="Searching for existing configs"
printf "$ui_tag_section" $(lon2 "$section_title") "$section_title"
echo -e "$ui_tag_ok Updating locate DB..."
echo "$sudo" | sudo -kS updatedb 2>/dev/null & display_loading $!
check_root_cron=`echo "$sudo" | sudo -kS crontab -l 2>/dev/null | grep "plex_sort.sh"`
if [[ "$check_root_cron" != "" ]]; then
  check_root_status=`echo "$sudo" | sudo -kS crontab -l 2>/dev/null | grep "plex_sort.sh" | grep "^#"`
  if [[ "$check_root_status" == "" ]]; then
    plex_sort_config=`echo "$sudo" | sudo -kS locate "plex_sort.conf" 2>/dev/null | grep "\/root\/"`
    echo -e "$ui_tag_ok Plex_Sort is currently activated in the root account"
    if [[ "$plex_sort_config" != "" ]]; then
      echo -e "$ui_tag_ok Configuration found: $plex_sort_config"
      echo "$sudo" | sudo -kS cat "$plex_sort_config" 2>/dev/null > $home_temp/filebot_conf_full.conf
      cat $home_temp/filebot_conf_full.conf | grep -i "filebot" > $home_temp/filebot_conf.conf
      source "$home_temp/filebot_conf.conf"
      echo -e "$(cat $home_temp/filebot_conf.conf | sed "s/^/$ui_tag_ok_sed Import: /g" | sed 's/##.*$//g' )"
    else
      echo -e "$ui_tag_bad Unable to find Plex_Sort configuration"
      echo -e "$ui_tag_bad Critical error... exit"
      exit 0
    fi
  fi
fi
echo ""


#######################
## Checking / Downloading encoder profiles
section_title="Checking HandBrake presets"
printf "$ui_tag_section" $(lon2 "$section_title") "$section_title"
for profile in $(curl -s -m 3 "https://raw.githubusercontent.com/scoony/plex_convert/main/Profiles/.content") ; do
  profile_remote=`echo "https://raw.githubusercontent.com/scoony/plex_convert/main/Profiles/$profile"`
  profile_local=`echo "$home_temp/Profiles/$profile"`
  if curl -m 2 --head --silent --fail "$profile_remote" 2>/dev/null >/dev/null; then
    md5_remote_profile=`curl -s -m 3 "$profile_remote" | md5sum | cut -f1 -d" "`
    md5_local_profile=`md5sum "$profile_local" 2>/dev/null | cut -f1 -d" " 2>/dev/null`
    if [[ "$md5_local_profile" != "$md5_remote_profile" ]]; then
      curl -s -m 3 --create-dir -o "$profile_local" "$profile_remote"
      echo -e "$ui_tag_ok Preset updated: $profile"
    else
      echo -e "$ui_tag_ok Preset up to date: $profile"
    fi
  else
    echo -e "$tag_ui_bad Preset is offline ($profile)"
  fi
done
echo ""


#######################
## Getting the files
find "$convert_folder" -type f -iname '*[avi|mp4|mkv]' > $home_temp/medias_temp.log
sort $home_temp/medias_temp.log > $home_temp/medias.log
rm $home_temp/medias_temp.log
my_files=()
while IFS= read -r -d $'\n'; do
my_files+=("$REPLY")
done <$home_temp/medias.log
rm $home_temp/medias.log
array_total=${#my_files[@]}
array_current="1"

section_title="Processing the files"
printf "$ui_tag_section" $(lon2 "$section_title") "$section_title"

for file in "${my_files[@]}" ; do


#######################
## Pre-processing checkings
echo -e "$ui_tag_checking \e[43mChecking source file... \e[0m[ "$array_current" / $array_total ]\e[43m  \e[0m"
media_format=`mediainfo --Inform="Video;%Format%" "$file"`
media_bitrate=`mediainfo --Inform="Video;%BitRate%" "$file"`
media_resolution=`mediainfo --Inform="Video;%Width% x %Height%" "$file"`
media_standard_resolution=`standard-resolution "$media_resolution"`
media_duration=`mediainfo --Inform="Video;%Duration/String3%" "$file"`
mediainfo --Inform="Audio;%Language/String%\n" "$file" > $home_temp/media-audio-language.log
media_audio_language=()
while IFS= read -r -d $'\n'; do
media_audio_language+=("$REPLY")
done <$home_temp/media-audio-language.log
rm $home_temp/media-audio-language.log
mediainfo --Inform="Audio;%Format_Commercial%\n" "$file" > $home_temp/media-audio-format.log
if [[ "$(cat $home_temp/media-audio-format.log)" == "" ]]; then
  rm $home_temp/media-audio-format.log
  mediainfo --Inform="Audio;%CodecID/Hint%\n" "$file" > $home_temp/media-audio-format.log
fi
media_audio_format=()
while IFS= read -r -d $'\n'; do
media_audio_format+=("$REPLY")
done <$home_temp/media-audio-format.log
rm $home_temp/media-audio-format.log
#filebot -rename "$file" --action test -non-strict > $home_temp/media-filebot.log 2>&1 & display_loading $!
filebot --action test -script fn:amc -rename "$file" -non-strict --def "seriesFormat=/{genres}/{n} - {s}x{e} - {t}" --def "movieFormat=/{genres}/{n} ({y})" --output $home_temp > $home_temp/media-filebot.log 2>&1 & display_loading $!
media_type=` cat $home_temp/media-filebot.log | grep "^Rename" | awk '{ print $2 }'`
media_name_raw=`cat $home_temp/media-filebot.log | grep "^\[TEST\]" | grep -oP '(?<=to \[).*(?=\]$)'`
media_name=` echo ${media_name_raw##*/} | cut -f 1 -d '.'`
if [[ "$(cat $home_temp/media-filebot.log)" =~ "Failed" ]] || [[ "$media_name_raw" == "" ]]; then
  media_name="\e[41m! FileBot can't process this file !\e[0m"
fi
media_filename=` basename "$file"`
media_genres=`echo "$media_name_raw" | grep -oP '(?<=\[).*(?=\]\/)'`
rm $home_temp/media-filebot.log
echo -e "$ui_tag_ok Filename: "$media_filename
echo -e "$ui_tag_ok Type: "$(echo $media_type | sed 's/s$//')
echo -e "$ui_tag_ok Real name: "$media_name
echo -e "$ui_tag_ok Genres: "$media_genres
echo -e "$ui_tag_ok Format: "$media_format
echo -e "$ui_tag_ok Bit rate: "$(echo $media_bitrate | numfmt --to=iec --suffix=b/s --format=%.2f 2>/dev/null)
echo -e "$ui_tag_ok Resolution: $media_standard_resolution ( $media_resolution )"
echo -e "$ui_tag_ok Duration: "$media_duration
no_language_info="0"
for i in {0..10} ; do
  audio_language=${media_audio_language[$i]}
  audio_format=${media_audio_format[$i]}
  if [[ "$audio_language" != "" ]] || [[ "$audio_format" != "" ]]; then
    if [[ "$audio_language" == "" ]]; then
      audio_language="\e[41m! Unknown !\e[0m"
      no_language_info="1"
    fi
    echo -e "$ui_tag_ok Audio track #$((i + 1)): $audio_language ($audio_format)"
  fi
done
((array_current = array_current + 1))
processing="yes"

## Check integrity (ffmpeg)
if [[ "$ffmpeg_check" == "yes" ]]; then
  echo -e "$ui_tag_checking Checking file integrity..."
  time1=`date +%s`
  ffmpeg -hide_banner -i "$file" -f null - > $home_temp/ffmpeg_check.log 2>&1 & display_loading $!
  time2=`date +%s`
  duration=$(($time2-$time1))
  ffmpeg_error=`cat $home_temp/ffmpeg_check.log | grep "error"`
  rm $home_temp/ffmpeg_check.log
## Doit paufiner absolument
  if [[ "$ffmpeg_error" != "" ]]; then
    echo -e "$ui_tag_bad Error reading the file"
    echo -e "$ui_tag_bad Skipping this file"
    processing="no"
  else
    echo -e "$ui_tag_ok File checked, no error ("$duration"s)"
  fi
fi

## Check language
if [[ "$no_language_info" == "1" ]] || [[ ! "${media_audio_language[@]}" =~ "$audio_required" ]]; then
  echo -e "$ui_tag_bad No conversion because language missing ($audio_required)"
  processing="no"
fi

## Check resolution
if [[ "$media_standard_resolution" == "\e[41m! Too low !\e[0m" ]]; then
  echo -e "$ui_tag_bad No conversion because resolution is too low"
  processing="no"
fi

## Moving crap files to error folder
if [[ "$processing" == "no" ]]; then
  echo -e "$ui_tag_bad Moving file to the error folder"
##  mv "$file" "$error_folder"
fi

## Processing
if [[ "$processing" != "no" ]]; then
  echo -e "$ui_tag_ok Starting the encoding process..."
  current_profile=`echo "profile_"$media_standard_resolution`
  handbrake_profile=${!current_profile}
  handbrake_default=""
  if [[ "$handbrake_profile" == "" ]]; then
    handbrake_profile=$profile_Default
    handbrake_default=" (default)"
  fi
  echo -e "$ui_tag_ok Movie resolution: $media_standard_resolution - Encoding profile: $handbrake_profile$handbrake_default"
  if [[ "$media_standard_resolution" == "DVD" ]]; then
    resolution_tag="dvd|576p"
  elif [[ "$media_standard_resolution" == "HD" ]]; then
    resolution_tag="hd|720p"
  elif [[ "$media_standard_resolution" == "Full_HD" ]]; then
    resolution_tag="full_hd|1080p"
  elif [[ "$media_standard_resolution" == "QHD" ]]; then
    resolution_tag="qhd|2k|1440p"
  elif [[ "$media_standard_resolution" == "4K" ]]; then
    resolution_tag="4k|UHD|2160p"
  fi
  if [[ "$media_type" == "movies" ]]; then
    type_tag="movie|film"
  elif [[ "$media_type" == "episodes" ]]; then
    if [[ "$media_genres" =~ "Animation" ]]; then
      type_tag="anime|animation|manga"
    else
      type_tag="serie|tv|show"
    fi
  fi
  target_folder=`cat "$home_temp/filebot_conf.conf" | grep -i "filebot" | egrep -i "$type_tag" | egrep -i "$resolution_tag" | cut -f 1 -d '='`
  if [[ "$target_folder" != "" ]]; then
    echo -e "$ui_tag_ok Target folder: $target_folder"
    download_folder_location=`cat $home_temp/filebot_conf_full.conf | grep "download_folder=" | cut -d'"' -f 2`
    echo -e "$ui_tag_ok Full destination: $download_folder_location/$target_folder"
  else
    ## default
    if [[ "$(cat "$home_temp/filebot_conf.conf" | grep -i "filebot" | egrep -i "$type_tag" | cut -f 1 -d '=' | wc -l)" == "1" ]]; then
      target_folder=`cat "$home_temp/filebot_conf.conf" | grep -i "filebot" | egrep -i "$type_tag" | cut -f 1 -d '='`
      echo -e "$ui_tag_ok Target folder: $target_folder (only one detected, using as default)"
      download_folder_location=`cat $home_temp/filebot_conf_full.conf | grep "download_folder=" | cut -d'"' -f 2`
      echo -e "$ui_tag_ok Full destination: $download_folder_location/$target_folder"
    else
      echo -e "$ui_tag_bad Target not found"
    fi
  fi
  ## Encoding
  my_preset_file=`echo "$home_temp/Profiles/"$handbrake_profile".json"`
##  echo "DEBUG: $my_preset_file"
  if [[ -f "$my_preset_file" ]]; then
    echo -e "$ui_tag_ok Handbrake preset found ("$handbrake_profile".json)"
    temp_folder=`echo $download_folder_location"/"$script_name"_temp"`
    mkdir -p "$temp_folder"
    temp_target=`echo $temp_folder"/"$media_filename"-part"`
    final_target=`echo $download_folder_location"/"$target_folder/$media_filename"-part"`
    echo -e "$ui_tag_encoding Sending the file to HandBrake..."
    time1=`date +%s`
    HandBrakeCLI --preset-import-file $my_preset_file -Z $handbrake_profile -i "$file" -o "$temp_target" > $home_temp/handbrake_process.txt 2>&1 & encoding_loading $!
    time2=`date +%s`
    duration=$(($time2-$time1))
    echo -e "$ui_tag_encoding Conversion completed in $(date -d@$duration -u +%H:%M:%S)..."
    file_size_before=`stat -c%s "$file" | numfmt --to=iec-i --suffix=B --format="%.2f"`
    file_size_after=`stat -c%s "$temp_target" | numfmt --to=iec-i --suffix=B --format="%.2f"`
    echo -e "$ui_tag_ok Files size: $file_size_before \u279F $file_size_after"
    file_duration=`mediainfo --Inform="Video;%Duration/String3%" "$temp_target"`
    if [[ "$media_duration" == "$file_duration" ]]; then
      echo -e "$ui_tag_ok Medias durations match: $media_duration \u279F $file_duration"
    else
      echo -e "$ui_tag_ok Durations mismatch: $media_duration \u279F $file_duration"
      echo -e "$ui_tag_bad Sending to error folder"
    fi
  else
      echo -e "$ui_tag_bad Handbrake preset not found ($handbrake_profile.json)"
  fi
fi
done

rm $home_temp/filebot_conf.conf
rm $home_temp/filebot_conf_full.conf

