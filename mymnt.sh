#!/bin/sh

# 
# mymnt.sh  a semi-auto mount script
#
# Copyright (c) 1992-2011 Zhihao Yuan. All rights reserved.
# This file is distributed under the 2-clause BSD License.

: ${MNTBASE:="$HOME/mnt"}

OPTIONS=""
ALL=0
DEBUG=0
NAME="$(basename "$0")"

usage () {
	echo "Usage: $NAME [OPTIONS] LABEL [NODE]"
	echo "       $NAME [SWITCHES]"
}

help () {
	usage
	echo -n "
LABEL:        volume or device name under /dev/
NODE:         alternative mount point under MNTBASE

OPTIONS:
  -p path     overwrite the default MNTBASE
  -L locale   overwrite the default LC_CTYPE
  -o options  file system specific options
  -r          disable locale
  -D          show mount command only

SWITCHES:
  -a          mount all devices
  -l          list available labels
  -h          show this help
"
}

error () {
	echo "$NAME: $1" >&2
	exit 1
}

warn () {
	echo "warning: $1" >&2
	return 1
}

issue () {
	if [ "$DEBUG" -ne 0 ]; then
		echo "$@"
	else
		"$@"
	fi
}

mount_with () {
	if [ ! -e "$node" ]; then
		issue mkdir -p "$node" || exit 1
	fi
	if [ -z "$OPTIONS" ]; then
		issue "$@" "$device" "$node"
	else
		issue "$@" -o "$OPTIONS" "$device" "$node"
	fi
	if [ $? -ne 0 ]; then
		st=$?
		issue rmdir -p "$node" 2> /dev/null
		exit $st
	fi
}

getgeom () {
	name="$(echo "$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')"
	echo "$(glabel status -s | awk "{sub(/[^\/]*\//,\"\");split(\$0,a,/[[:space:]]*N\/A[[:space:]]*/);if(a[1]==\"$name\"||a[2]==\"$name\"){print a[2];exit}}")"
}

labelof () {
	echo "$(glabel status -s "$1" | awk '{sub(/[^\/]*\//,"");split($0,a,/[[:space:]]*N\/A[[:space:]]+/);print a[1]}')"
}

fstypeof () {
	echo "$(glabel status -s "$1" | cut -d/ -f1)"
}

mount_target () {

geom="$(getgeom "$1")"
if [ -z "$geom" ]; then
	error "No such geom label: $1"
fi

fstype="$(fstypeof "$geom")"
label="$(labelof "$geom")"
device="/dev/$geom"
charmap="${LC_CTYPE:+"$(locale charmap)"}"
node="${2:-${MNTBASE}/$label}"
fmask="$(expr 666 - $(umask))"
dmask="$(expr 777 - $(umask))"

case "$fstype" in
	ufs|ext2fs|xfs)
		mount_with mount -t "$fstype"
		;;
	msdosfs)
		if [ "$MNTCTYPE" -eq 0 ]; then
			mount_with mount_$fstype -M "$dmask" -m "$fmask"
		else
			mount_with mount_$fstype -M "$dmask" -m "$fmask" -L "$LC_CTYPE"
		fi
		;;
	ntfs)
		if [ "$MNTCTYPE" -eq 0 ]; then
			mount_with mount_$fstype -m "$dmask"
		else
			mount_with mount_$fstype -m "$dmask" -C "$charmap"
		fi
		;;
	iso9660)
		if [ "$MNTCTYPE" -eq 0 ]; then
			mount_with mount_cd9660
		else
			mount_with mount_cd9660 -C "$charmap"
		fi
		;;
	udf)
		if [ "$MNTCTYPE" -eq 0 ]; then
			mount_with mount_$fstype
		else
			mount_with mount_$fstype -C "$charmap"
		fi
		;;
	*)
		if [ "$ALL" -ne 1 ]; then
			error "Unsupported file system: $fstype"
		fi
		;;
esac

}

# process options
while getopts 'p:L:o:raDlh' flag; do
	case "$flag" in
		p)
			MNTBASE="${OPTARG%%/}" ;;
		L)
			LC_CTYPE="$OPTARG" ;;
		o)
			OPTIONS="$OPTARG" ;;
		r)
			MNTCTYPE=0 ;;
		a)
			ALL=1 ;;
		D)
			DEBUG=1 ;;
		l)
			glabel status -s | awk '{if(!match($0,/^[[:space:]]*gpt/)){sub(/[^\/]*\//,"");split($0,a,/[[:space:]]*N\/A[[:space:]]+/);print a[1]}}'
			exit ;;
		h)
			help
			exit ;;
		*)
			usage
			echo "Try \`$NAME -h' for more information."
			exit 2
	esac
done

if ! kldstat -qm iconv; then # no kiconv
	if [ -n "$MNTCTYPE" ] && [ "$MNTCTYPE" -ne 0 ]; then
		warn "Locale support is disabled; check your kiconv availability"
	fi
	MNTCTYPE=0
else
	: ${MNTCTYPE:=1}
fi

# if -a is specified, call itself recursively
if [ "$ALL" -eq 1 -a $# -eq $((OPTIND-1)) ]; then
	glabel status -s | awk '{sub(/[^\/]*\//,"");split($0,a,/[[:space:]]*N\/A[[:space:]]*/);print a[2]}' | while read -r dev; do
		"$0" "$@" "$dev"
	done
	exit
fi

shift $((OPTIND-1))

if [ $# -eq 0 ]; then
	mount | while read -r ln; do
		ls -d "$MNTBASE"/* 2> /dev/null | while read -r nd; do
			if echo "$ln" | grep -wF "$nd"; then
				break
			fi
		done
	done
else
	mount_target "$@"
fi

