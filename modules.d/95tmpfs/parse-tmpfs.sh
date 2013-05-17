#!/bin/sh
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type det_fs >/dev/null 2>&1 || . /lib/fs-lib.sh

for m in $(getargs rd.mount.early) ; do
	fs_mount_to_var $m
	[ "${fstype}" = tmpfs ] || continue

	# tmpfs has no fs, so some options might have been parsed as fs instead
	[ -n "${options}" ] && fs="${fs},${options}"
	unset options

	echo "Adding early mount of tmpfs on ${mountpoint}"
	fs_add_mount early none "${mountpoint}" tmpfs "${fs}" 0 0
done
