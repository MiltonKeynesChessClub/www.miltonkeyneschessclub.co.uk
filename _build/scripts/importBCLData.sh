#! /bin/bash

# This script imports bedfordshire league results
# from the LMS into jekyll data files for use in the website
#
# Requirements:
#
# * yq: https://github.com/mikefarah/yq
# * jq: https://jqlang.github.io/jq/

LMS_ORG=123451 # Bedfordshire Chess Assoc.
LMS_ENDPOINT=https://lms.englishchess.org.uk/lms/lmsrest/league
TMP_DIR=${TMP_DIR:-~/tmp}
DIVISIONS="BCL Division 1
BCL Division 2"

ACTIVECHECK=$( yq ".competitions.bcl[0].active" ../../_data/general.yml )
CURRENTSEASON=$( yq ".competitions.bcl[0].season" ../../_data/general.yml )
ECF_DATA_DIR=../../_data/_generated/bcl/$CURRENTSEASON

if [[ "$ACTIVECHECK" == "false" ]] ; then
	echo "Aborting fetching of BCL results. Current season is over, awaiting next one to start."
	exit
fi

function slugify() {
	text=$(echo "$1" | tr '[:upper:]' '[:lower:]')
	text=$(echo "$text" | sed 's/ /-/g')
	text=$(echo "$text" | sed 's/[^a-z0-9-]//g')

	echo $text
}

function striptags() {
	echo "$1" | sed 's|<[^>]*>||g'
}

function fetchresults() {
	resetGeneratedFiles

	while IFS= read -r DIVISION; do
		DIVSLUG=$( slugify "$DIVISION" )

		mkdir -p "$TMP_DIR/$DIVSLUG"
		curl -s -XPOST -F org="$LMS_ORG" -F name="$DIVISION" -o "$TMP_DIR/$DIVSLUG/table.json" "${LMS_ENDPOINT}/table.json"
		curl -s -XPOST -F org="$LMS_ORG" -F name="$DIVISION" -o "$TMP_DIR/$DIVSLUG/fixtures.json" "${LMS_ENDPOINT}/event.json"
		curl -s -XPOST -F org="$LMS_ORG" -F name="$DIVISION" -o "$TMP_DIR/$DIVSLUG/results.json" "${LMS_ENDPOINT}/match.json"

		processresults "$DIVSLUG"
	done <<< "$DIVISIONS"
}

function processresults() {
	RESULTS_DIR="$TMP_DIR/$1"

	processTable "$1" "$RESULTS_DIR/table.json"
	processFixtures "$1" "$RESULTS_DIR/fixtures.json" "$RESULTS_DIR/results.json"
}

function resetGeneratedFiles() {
	mkdir -p $ECF_DATA_DIR
	echo "# File generated by importBCLData.sh script. Do not modify." > "$ECF_DATA_DIR/table.yaml"
	echo "# File generated by importBCLData.sh script. Do not modify." > "$ECF_DATA_DIR/fixtures.yaml"
	echo "# File generated by importBCLData.sh script. Do not modify." > "$ECF_DATA_DIR/matches.yaml"
}

function processTable() {
	DIVSLUG=$1
	SRCFILE=$2
	TEAMCOUNT=$( jq '.[0].data|length' "$SRCFILE" ) # ecf lms chooses to bring back the data in a fun format :)- an array of arrays with column mappings
	TARGETFILE=$ECF_DATA_DIR/table.yaml

	echo ""            >> $TARGETFILE
	echo "${DIVSLUG}:" >> $TARGETFILE

	for i in $(seq 0 $(($TEAMCOUNT-1))); do
		TEAM_NAME=$( striptags "$( jq --raw-output ".[0].data[$i][0]" "$SRCFILE" )" );
		TEAM_PLAYED=$( jq --raw-output ".[0].data[$i][1]" "$SRCFILE" );
		TEAM_WON=$( jq --raw-output ".[0].data[$i][2]" "$SRCFILE" );
		TEAM_DRAWN=$( jq --raw-output ".[0].data[$i][3]" "$SRCFILE" );
		TEAM_LOST=$( jq --raw-output ".[0].data[$i][4]" "$SRCFILE" );
		TEAM_FOR=$( jq --raw-output ".[0].data[$i][5]" "$SRCFILE" );
		TEAM_AGAINST=$( jq --raw-output ".[0].data[$i][6]" "$SRCFILE" );
		TEAM_POINTS=$( striptags "$( jq --raw-output ".[0].data[$i][7]" "$SRCFILE" )" );

		echo "  - team: $TEAM_NAME"       >> $TARGETFILE
		echo "    played: $TEAM_PLAYED"   >> $TARGETFILE
		echo "    won: $TEAM_WON"         >> $TARGETFILE
		echo "    drawn: $TEAM_DRAWN"     >> $TARGETFILE
		echo "    lost: $TEAM_LOST"       >> $TARGETFILE
		echo "    for: $TEAM_FOR"         >> $TARGETFILE
		echo "    against: $TEAM_AGAINST" >> $TARGETFILE
		echo "    points: $TEAM_POINTS"   >> $TARGETFILE
		echo ""                         >> $TARGETFILE
	done
}

function processFixtures() {
	DIVSLUG=$1
	FIXTURESRCFILE=$2
	RESULTSSRCFILE=$3
	FIXTURECOUNT=$( jq '.[0].data|length' "$FIXTURESRCFILE" ) # ecf lms chooses to bring back the data in a fun format :)- an array of arrays with column mappings
	TARGETFILE=

	echo ""            >> ${ECF_DATA_DIR}/fixtures.yaml
	echo "${DIVSLUG}:" >> ${ECF_DATA_DIR}/fixtures.yaml
	echo ""            >> ${ECF_DATA_DIR}/matches.yaml
	echo "${DIVSLUG}:" >> ${ECF_DATA_DIR}/matches.yaml

	for i in $(seq 0 $(($FIXTURECOUNT-1))); do
		TARGETFILE=$ECF_DATA_DIR/fixtures.yaml
		FIXTURE_HOMETEAM=$( striptags "$( jq --raw-output ".[0].data[$i][0]" "$FIXTURESRCFILE" )" );
		FIXTURE_RESULT=$( striptags "$( jq --raw-output ".[0].data[$i][1]" "$FIXTURESRCFILE" )" );
		FIXTURE_AWAYTEAM=$( striptags "$( jq --raw-output ".[0].data[$i][2]" "$FIXTURESRCFILE" )" );
		FIXTURE_DATE=$( jq --raw-output ".[0].data[$i][3]" "$FIXTURESRCFILE" );
		FIXTURE_TIME=$( striptags "$( jq --raw-output ".[0].data[$i][4]" "$FIXTURESRCFILE" )" );
		FIXTURE_STATUS=$( jq --raw-output ".[0].data[$i][5]" "$FIXTURESRCFILE" );
		FIXTURE_ID=$( slugify "$DIVSLUG $FIXTURE_DATE $FIXTURE_HOMETEAM v $FIXTURE_AWAYTEAM" );

		echo "  - id: $FIXTURE_ID"             >> $TARGETFILE
		echo "    hometeam: $FIXTURE_HOMETEAM" >> $TARGETFILE
		echo "    awayteam: $FIXTURE_AWAYTEAM" >> $TARGETFILE
		echo "    date: $FIXTURE_DATE"         >> $TARGETFILE
		echo "    time: \"$FIXTURE_TIME\""     >> $TARGETFILE
		echo "    status: $FIXTURE_STATUS"     >> $TARGETFILE
		echo "    result: $FIXTURE_RESULT"     >> $TARGETFILE
		echo ""                                >> $TARGETFILE

		GAME_NAME="$FIXTURE_HOMETEAM v $FIXTURE_AWAYTEAM"
		GAME_INDEX=$( jq "map(.title==\"${GAME_NAME}\") | index(true)" "$RESULTSSRCFILE" )

		if [[ -n $GAME_INDEX && "$GAME_INDEX" != "null" ]] ; then
			processFixtureGames "$DIVSLUG" "$RESULTSSRCFILE" "$FIXTURE_ID" $GAME_INDEX "$FIXTURE_HOMETEAM" "$FIXTURE_AWAYTEAM"
		fi
	done
}

function processFixtureGames() {
	DIVSLUG="$1"
	SRCFILE="$2"
	FIXTUREID="$3"
	GAME_INDEX=$4
	HOMETEAM=$5
	AWAYTEAM=$6
	GAMECOUNT=$( jq ".[$GAME_INDEX].data|length" "$SRCFILE" )
	TARGETFILE=$ECF_DATA_DIR/matches.yaml

	for i in $(seq 0 $(($GAMECOUNT-1))); do
		GAME_HOMECOLOUR=$( jq --raw-output ".[$GAME_INDEX].data[$i][0]" "$SRCFILE" );
		GAME_BOARD=$( jq --raw-output ".[$GAME_INDEX].data[$i][1]" "$SRCFILE" );
		GAME_HOMEPLAYER=$( jq --raw-output ".[$GAME_INDEX].data[$i][2]" "$SRCFILE" );
		GAME_HOMERATING=$( jq --raw-output ".[$GAME_INDEX].data[$i][3]" "$SRCFILE" );
		GAME_RESULT=$( jq --raw-output ".[$GAME_INDEX].data[$i][4]" "$SRCFILE" );
		GAME_AWAYPLAYER=$( jq --raw-output ".[$GAME_INDEX].data[$i][5]" "$SRCFILE" );
		GAME_AWAYRATING=$( jq --raw-output ".[$GAME_INDEX].data[$i][6]" "$SRCFILE" );

		if [[ "$GAME_HOMECOLOUR" == "B" ]] ; then
			GAME_AWAYCOLOUR="W"
		else
			GAME_AWAYCOLOUR="B"
		fi

		echo "  - fixture: $FIXTURE_ID"          >> $TARGETFILE
		echo "    result: $GAME_RESULT"          >> $TARGETFILE
		echo "    home:"                         >> $TARGETFILE
		echo "      name: $GAME_HOMEPLAYER"      >> $TARGETFILE
		echo "      rating: $GAME_HOMERATING"    >> $TARGETFILE
		echo "      color: $GAME_HOMECOLOUR"     >> $TARGETFILE
		echo "      team: $HOMETEAM"             >> $TARGETFILE
		echo "    away:"                         >> $TARGETFILE
		echo "      name: $GAME_AWAYPLAYER"      >> $TARGETFILE
		echo "      rating: $GAME_AWAYRATING"    >> $TARGETFILE
		echo "      color: $GAME_AWAYCOLOUR"     >> $TARGETFILE
		echo "      team: $AWAYTEAM"             >> $TARGETFILE
		echo ""                                  >> $TARGETFILE

	done
}

fetchresults