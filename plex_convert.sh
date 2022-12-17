#!/bin/bash


#######################
## Script configuration
if [[ ! -f "$HOME/.config/plex_convert/plex_convert.conf" ]]; then
  my_settings_variables="home_temp convert_folder error_folder audio_required profile_4K profile_QHD profile_Full_HD profile_HD profile_DVD profile_Default sudo ffmpeg_check"
  my_config_file=`cat "$HOME/.config/plex_convert/plex_convert.conf"`
  for script_variable in $my_settings_variables ; do
    if [[ ! "$my_config_file" =~ "$script_variable" ]]; then
      echo $script_variable"=\"\"" >> $HOME/.config/plex_convert/plex_convert.conf
      echo "... edit your configuration"
      exit 0
    fi
  done
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
## Function to get standardized resolution
standard-resolution() {
x=`echo $1 | awk '{ print $1}'`
y=`echo $1 | awk '{ print $3}'`
## resolution_4k="3840 x 2160"     ## (x) 10% 3456 / (y) 27% donc 1577
## resolution_qhd="2560 x 1440"    ## (x) 10% 2304 / (y) 27% donc 1051
## resolution_fullhd="1920 x 1080" ## (x) 10% 1728 / (y) 27% donc 788
## resolution_hd="1280 x 720"      ## (x) 10% 1152 / (y) 27% donc 525
## resolution_dvd="720 × 576"      ## (x) 10% 648  / (y) 27% donc 420
if [[ "$x" -ge "3456" ]] && [[ "$y" -ge "1577" ]]; then
  echo "4K"
elif [[ "$x" -ge "2304" ]] && [[ "$y" -ge "1051" ]]; then
  echo "QHD"
elif [[ "$x" -ge "1728" ]] && [[ "$y" -ge "788" ]]; then
  echo "Full_HD"
elif [[ "$x" -ge "1152" ]] && [[ "$y" -ge "525" ]]; then
  echo "HD"
elif [[ "$x" -ge "648" ]] && [[ "$y" -ge "420" ]]; then
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


#######################
## Getting the files
find "$convert_folder" -type f -iname '*[avi|mp4|mkv]' > $home_temp/medias.log
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
  if [[ "$media_standard_resolution" == "4K" ]]; then
    resolution_tag="4k|UHD|2160p"
  elif [[ "$media_standard_resolution" == "QHD" ]]; then
    resolution_tag="qhd|2k|1440p"
  elif [[ "$media_standard_resolution" == "Full_HD" ]]; then
    resolution_tag="full_hd|1080p"
  elif [[ "$media_standard_resolution" == "HD" ]]; then
    resolution_tag="hd|720p"
  elif [[ "$media_standard_resolution" == "DVD" ]]; then
    resolution_tag="dvd|576p"
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
fi
done

rm $home_temp/filebot_conf.conf
rm $home_temp/filebot_conf_full.conf

