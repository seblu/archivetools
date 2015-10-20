#!/bin/bash

# Copyright © Sébastien Luttringer
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

fail() {
	printf "\e[31;1m==> FAIL: \e[;1m%s\e[m\n" "$*" >&2
	exit 1
}

error() {
	printf "\e[31;1m==> ERROR: \e[;1m%s\e[m\n" "$*" >&2
}

msg() {
	printf "\e[1;32m==> \e[;1m%s\e[m\n" "$*"
}

msg2() {
	printf "\e[1;34m  -> \e[;1m%s\e[m\n" "$*"
}

singleton() {
	msg 'Locking'
	local LOCKFILE="${TMPDIR:-/tmp}/.${0##*/}.lock"
	exec 9> "$LOCKFILE"
	flock -n 9 || fail "Unable to lock. ${0##*/} already running."
}

enforce_config_vars() {
	local val
	for val; do
		[[ -n ${!val} ]] || fail "Missing $val directive in config file."
	done
}

# load archive configuration
load_config() {
	local conf=${ARCHIVE_CONFIG:-/etc/archive.conf}
	[[ -e "$conf" ]] || fail "No such config file: $conf."
	msg "Loading configuration: $conf"
	. "$conf" || fail 'Failed to load archive config.'
	enforce_config_vars ARCHIVE_RSYNC ARCHIVE_DIR ARCHIVE_USER \
		ARCHIVE_GROUP PKGEXT PKGSIG UMASK ARCHIVE_REPO ARCHIVE_ISO
	if [[ $ARCHIVE_REPO == "1" ]]; then
		enforce_config_vars REPO_DAYLY REPO_PACKAGES REPO_PACKAGES_INDEX \
			REPO_PACKAGES_FULL_SEARCH REPO_RSYNC_TIMEOUT
	fi
	if [[ $ARCHIVE_ISO == "1" ]]; then
		enforce_config_vars ISO_RSYNC_TIMEOUT
	fi
}

# snapshot a repository
repo_rsync() {
	msg "Snapshoting repositories"
	local SNAPR="$(date +%Y/%m/%d)"
	local SNAP="$REPO_DIR/$SNAPR"

	# ensure destination exists
	[[ -d "$SNAP" ]] || mkdir -p "$SNAP"

	# compute last but today
	local LAST="$(ls -1d "$REPO_DIR"/2???/*/*|sort|grep -v $SNAPR|tail -n1)"

	# display transfert info
	msg2 "snapshot to: $SNAP"
	msg2 "last path: $LAST"

	[[ -n "$LAST" ]] && local LINKDEST="--link-dest=$LAST/"

	msg2 'Rsyncing...'
	# rsync from master using last sync
	# we must use absolute path with --link-dest to avoid errors
	rsync  -rltH $LINKDEST --exclude '*/.*' --exclude 'iso/*' "$ARCHIVE_RSYNC" "$SNAP/" ||
		error "Unable to rsync: $ARCHIVE_RSYNC."

	# only to have a quick check of sync in listdir
	touch "$SNAP"
}

# output the last repository snapshot
repo_last() {
	ls -1d "$REPO_DIR"/2???/*/*|sort|tail -n1
}

# update last,weekly,monthly symlinks
repo_daily() {
	msg 'Updating daily links'
	# update last
	ln -svrnf "$(repo_last)" "$REPO_DIR/last"

	# update last week
	ln -srvnf "$REPO_DIR/$(date -d 'last monday' +%Y/%m/%d)" "$REPO_DIR/week"

	# update last month
	ln -srvnf "$REPO_DIR/$(date +%Y/%m/01)" "$REPO_DIR/month"
}

# update the packages tree with packages in snapshoted repositories
repo_packages() {
	msg "Updating package tree"
	local PACKAGES_DIR="$ARCHIVE_DIR/packages"
	local PKGFLAT="$PACKAGES_DIR/.all" #must be subdirectory of $PACKAGES_DIR
	local SCANDIR filename pkgname first parent tdst fdst

	if (( REPO_PACKAGES_FULL_SEARCH )); then
		msg2 'Searching in all snapshots'
		SCANDIR="$REPO_DIR"
	else
		msg2 'Searching in last snapshot'
		SCANDIR="$(repo_last)"
	fi

	# ensure dirs are here and no listing
	[[ -e "$PKGFLAT" ]] || mkdir -p "$PKGFLAT"
	echo 'No listing allowed here.' > "$PKGFLAT/index.html"

	msg2 "removing dead links in ${PACKAGES_DIR##*/}"
	find -L "$PACKAGES_DIR" -type l -delete -print

	# create new links pass
	msg2 'creating new links'
	find "$SCANDIR" -type f -name "*$PKGEXT" -o -name "*$PKGSIG"| while read src; do
	  filename="${src##*/}"
	  pkgname="${filename%-*}" #remove arch and extension
	  pkgname="${pkgname%-*}" #remove pkgrel
	  pkgname="${pkgname%-*}" #remove pkgver
	  first="${pkgname:0:1}"
	  parent="$PACKAGES_DIR/${first,,}/$pkgname"
	  # destination in tree
	  tdst="$parent/$filename"
	  # destination in flat dir
	  fdst="$PKGFLAT/$filename"
	  # ensure pkgtree parent dir is present
	  [[ -d "$parent" ]] || mkdir -v -p "$parent"
	  # copy file if necessary
	  if [[ "$src" -nt "$tdst" ]]; then
	    # remove is necessary to be done and not use -f in ln
	    # because this create buggy relative symlink in some case.
	    # there is fix around this in next coreutils
	    [[ -e "$tdst" ]] && rm -f -v "$tdst"
	    # don't use harlink, to be able to easily remove package by date
	    # removing a directory by date, will remove symlink in the clean pass
	    ln -v -r -s "$src" "$tdst"
	  fi
	  if [[ "$src" -nt "$fdst" ]]; then
	    [[ -e "$fdst" ]] && rm -f -v "$fdst"
	    ln -v -r -s "$src" "$fdst"
	  fi
	done

	msg2 "removing empty directories in ${PACKAGES_DIR##*/}"
	find "$PACKAGES_DIR" -type d -empty -delete -print

	touch "$PACKAGES_DIR" "$PKGFLAT"

	(( $REPO_PACKAGES_INDEX )) && repo_packages_index "$PKGFLAT"
}

# creating a lightweight index (v0) for filenames
# modification time is used to minimize download, so we don't update the file if equal
repo_packages_index() {
	msg 'Updating package index'
	local INDEX="$1/index.0.xz"
	local TMPINDEX="$1/.index.0.xz"

	rm -f "$TMPINDEX"
	find "$1" -name "*$PKGEXT" -printf '%f\n'|sed 's/.\{'${#PKGEXT}'\}$//'|sort|xz -9 > "$TMPINDEX"
	if [[ ! -e "$INDEX" ]]; then
	  mv "$TMPINDEX" "$INDEX"
	elif diff -q "$INDEX" "$TMPINDEX"; then
	  rm "$TMPINDEX"
	else
	  rm "$INDEX"
	  mv "$TMPINDEX" "$INDEX"
	fi
}

# archive iso tree
iso_rsync() {
	msg "Rsyncing ISO"

	local ISO_RSYNC="$ARCHIVE_RSYNC/iso/"
	local ISO_DIR="$ARCHIVE_DIR/iso"

	# ensure destination exists
	[[ -d "$ISO_DIR" ]] || mkdir -p "$ISO_DIR"

	# Rsync from master using last sync
	rsync -vrltH "$ISO_RSYNC" --include='/????.??.??/***' --exclude='*' "$ISO_DIR/" ||
		error "Unable to rsync: $ISO_RSYNC."
}

main() {
	# more verbose when launched from a tty
	[[ -t 1 && -n "$DEBUG" ]] && set -x

	load_config

	# check running user/group
	[[ "$(id -u -n)" == "$ARCHIVE_USER" ]] ||
		fail "The script must be run as user $ARCHIVE_USER."
	[[ "$(id -g -n)" == "$ARCHIVE_GROUP" ]] ||
		fail "The script must be run as group $ARCHIVE_GROUP."

	# we love IOs and we are nice guys
	renice -n 19 -p $$ >/dev/null
	ionice -c 2 -n 7 -p $$

	# load umask
	umask "${UMASK:-022}"

	# Only one run at a time
	singleton

	if (( $ARCHIVE_REPO )); then
		REPO_DIR="$ARCHIVE_DIR/repos"

		repo_rsync

		(( $REPO_DAYLY )) && repo_daily

		(( $REPO_PACKAGES )) && repo_packages
	fi

	(( $ARCHIVE_ISO )) && iso_rsync

	return 0
}

main "$@"
