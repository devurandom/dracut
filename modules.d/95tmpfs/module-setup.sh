#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

check() {
    [[ $hostonly ]] || [[ $mount_needs ]] && {
        for fs in ${host_fs_types[@]}; do
            strstr "$fs" "\|tmpfs"  && return 0
        done
        return 255
    }

    return 0
}

depends() {
	# We use add_early_mount to mount in locations different from rootfs
	echo fs-lib
}

installkernel() {
	return 0
}

install() {
    inst_hook cmdline 95 "$moddir/parse-tmpfs.sh"
}
