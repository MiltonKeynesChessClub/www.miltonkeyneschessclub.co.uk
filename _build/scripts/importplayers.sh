#! /bin/bash

# This script imports MK club players from the ECF ratings database
# and makes them available as raw data files for the Jekyll site.
# In addition, it stubs pages for the website for each player
# when they do not already exist.
#
# It depends on the following being available:
#
# * jq: https://jqlang.github.io/jq/
# * csvkit: https://csvkit.readthedocs.io/en/latest/

TMP_DIR=${TMP_DIR:-~/tmp}
FULL_CSV=$TMP_DIR/allplayers.csv
MK_CSV=$TMP_DIR/mkplayers.csv
MK_TMP_JSON=$TMP_DIR/mkplayers.jsonl
MK_DATA_FILE=../../_data/mkplayers.yml
MK_PLAYER_PAGES=../../players
ALL_CSV_HEADERS="\"ECF_code\",\"full_name\",\"member_no\",\"FIDE_no\",\"gender\",\"nation\",\"original_standard\",\"standard_original_category\",\"revised_standard\",\"standard_revised_category\",\"original_rapid\",\"rapid_origina l_category\",\"revised_rapid\",\"rapid_revised_category\",\"original_blitz\",\"blitz_original_category\",\"revised_blitz\",\"blitz_revised_category\",\"original_standard_online\",\"standard_online_original_ category\",\"revised_standard_online\",\"standard_online_revised_category\",\"original_rapid_online\",\"rapid_online_original_category\",\"revised_rapid_online\",\"rapid_online_revised_category\",\"origin al_blitz_online\",\"blitz_online_original_category\",\"revised_blitz_online\",\"blitz_online_revised_category\",\"club_code\",\"club_name\",\"title\""
LIMITED_HEADERS=ECF_code,full_name,revised_standard,standard_revised_category,revised_rapid,rapid_revised_category,revised_blitz,blitz_revised_category,title

function slugify() {
	text=$(echo "$1" | tr '[:upper:]' '[:lower:]')

	# Replace spaces with hyphens
	text=$(echo "$text" | sed 's/ /-/g')

	# Remove any characters that aren't letters, numbers, or hyphens
	text=$(echo "$text" | sed 's/[^a-z0-9-]//g')

	echo $text
}

# Fetch all rated players from ECF (no filters for club)
if [[ ! -f $FULL_CSV ]] ; then
	curl "https://rating.englishchess.org.uk/v2/new/api.php?v2/rating_list_csv" >> $FULL_CSV
fi

# Filter Milton Keynes club players
if [[ ! -f $MK_CSV ]] ; then
	echo $ALL_CSV_HEADERS > $MK_CSV
	cat $FULL_CSV | grep '"9BAQ","Milton Keynes"' >> $MK_CSV
fi

# Convert our CSV into a jsonl file for easier processing
csvcut -c $LIMITED_HEADERS $MK_CSV | csvjson --no-inference --stream > $MK_TMP_JSON

# Make the data more useful and write down to files
rm -f $MK_DATA_FILE
touch $MK_DATA_FILE
mkdir -p $MK_PLAYER_PAGES
while read player; do
	ecf=$( echo $player | jq --raw-output '.ECF_code' )
	name=$( echo $player | jq --raw-output '.full_name' )
	title=$( echo $player | jq --raw-output '.title' )
	slug=$( slugify "$name" )

	standard="$( echo $player | jq --raw-output '.revised_standard' )"
	if [[ "$standard" == "null" ]] ; then
		standard=""
	else
		standard="$standard$( echo $player | jq --raw-output  '.standard_revised_category' )"
	fi

	rapid="$( echo $player | jq --raw-output '.revised_rapid' )"
	if [[ "$rapid" == "null" ]] ; then
		rapid=""
	else
		rapid="$rapid$( echo $player | jq --raw-output  '.rapid_revised_category' )"
	fi

	blitz="$( echo $player | jq --raw-output '.revised_blitz' )"
	if [[ "$blitz" == "null" ]] ; then
		blitz=""
	else
		blitz="$blitz$( echo $player | jq --raw-output  '.blitz_revised_category' )"
	fi

  	echo "${slug}:" >> $MK_DATA_FILE
  	echo "  name: $name" >> $MK_DATA_FILE
  	echo "  ecfcode: $ecf" >> $MK_DATA_FILE

  	if [[ -n $title && "$title" != "null" ]] ; then
  		echo "  title: $title" >> $MK_DATA_FILE
  	fi
  	if [[ -n $standard ]] ; then
  		echo "  standardrating: $standard" >> $MK_DATA_FILE
  	fi
  	if [[ -n $rapid ]] ; then
  		echo "  rapidrating: $rapid" >> $MK_DATA_FILE
  	fi
  	if [[ -n $blitz ]] ; then
  		echo "  blitzrating: $blitz" >> $MK_DATA_FILE
  	fi

  	echo >> $MK_DATA_FILE

  	if [[ ! -f "${MK_PLAYER_PAGES}/${slug}.markdown" ]] ; then
  		echo "---
layout: player
title:  \"$name\"
player: $slug
---" > "${MK_PLAYER_PAGES}/${slug}.markdown"
  	fi
done < $MK_TMP_JSON