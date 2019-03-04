#!/bin/bash
# build companion synology app
#
# Example:
# ./build_spk.sh # create spk from current branch
#
# ./build_spk.sh 1.2.3 # create spk from specified tag
#
# Structure:
#----------------------------------------------------------------------------------------
# ./APP --> actual app
# ./PKG  --> package information
#

set -euo pipefail
IFS=$'\n\t'

function finish {
	git worktree remove --force "$build_tmp"
	rm -rf "$build_tmp"
}
trap finish EXIT

#######

project="Kopano"

#######

if ! [ -x "$(command -v git)" ]; then
	echo 'Error: git is not installed.' >&2
	exit 1
fi

if ! [ -x "$(command -v fakeroot)" ]; then
	echo 'Error: fakeroot is not installed.' >&2
	exit 1
fi

# Arbeitsverzeichnis auslesen und hineinwechseln:
# ---------------------------------------------------------------------
# shellcheck disable=SC2086
APPDIR=$(cd "$(dirname $0)";pwd)
cd "${APPDIR}"

build_tmp=$(mktemp -d -t tmp.XXXXXXXXXX)
buildversion=${1:-latest}
taggedversions=$(git tag)

echo " - INFO: Erstelle den temporären Buildordner und kopiere Sourcen hinein ..."

git worktree add --force "$build_tmp" "$(git rev-parse --abbrev-ref HEAD)"
pushd "$build_tmp"
set_spk_version="latest-$(date +%s)-$(git log -1 --format="%h")"

if echo "$taggedversions" | egrep -q "$buildversion"; then
	echo "git checkout zu $buildversion"
	git checkout "$buildversion"
	set_spk_version="$buildversion"
else
	echo "ACHTUNG: Die gewünschte Version wurde im Repository nicht gefunden!"
	echo "Die $(git rev-parse --abbrev-ref HEAD)-branch wird verwendet!"
fi

# fallback to old app dir
if [ -d "$build_tmp"/Build ]; then
	APP=Build
else
	APP=APP
fi

# fallback to old pkg dir
if [ -d "$build_tmp"/Pack ]; then
	PKG=Pack
else
	PKG=PKG
fi

build_version=$(grep version "$build_tmp/$PKG/INFO" | awk -F '"' '{print $2}')
#set_spk_version=$build_version

echo " - INFO: Es wird foldende Version geladen und gebaut: $set_spk_version - BUILD-Version (INFO-File): $build_version"

# Ausführung: Erstellen des SPK
echo ""
echo "-----------------------------------------------------------------------------------"
echo "   SPK wird erstellt..."
echo "-----------------------------------------------------------------------------------"

# Falls versteckter Ordners /.helptoc vorhanden, diesen nach /helptoc umbenennen
if test -d "${build_tmp}/.helptoc"; then
	echo ""
	echo " - INFO: Versteckter Ordner /.helptoc wurde lokalisiert und nach /helptoc umbenannt"
	mv "${build_tmp}/.helptoc" "${build_tmp}/helptoc"
fi

# Packen und Ablegen der aktuellen Installation in den entsprechenden /Pack - Ordner
echo ""
echo " - INFO: Das Archiv package.tgz wird erstellt..."

fakeroot tar -C "${build_tmp}"/"$APP" -czf "${build_tmp}"/"$APP"/package.tgz .

# Wechsel in den Ablageort von package.tgz bezüglich Aufbau des SPK's
cd "${build_tmp}"/"$PKG"

# Erstellen des eigentlichen SPK's
echo ""
echo " - INFO: Das SPK wird erstellt..."
fakeroot tar -cf "${project}"_"$set_spk_version".spk ./*
cp -f "${project}"_"$set_spk_version".spk "${APPDIR}"

popd

echo ""
echo "-----------------------------------------------------------------------------------"
echo "   Das SPK wurde erstellt und befindet sich unter..."
echo "-----------------------------------------------------------------------------------"
echo ""
echo "   ${APPDIR}/${project}_$set_spk_version.spk"
echo ""

exit 0
