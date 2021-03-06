#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# Copyright 2005-2010 Harald Hoyer <harald@redhat.com>
# Copyright 2005-2010 Red Hat, Inc.  All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

usage()
{
    {
        echo "Usage: ${0##*/} [options] [<initramfs file> [<filename> [<filename> [...] ]]]"
        echo "Usage: ${0##*/} [options] -k <kernel version>"
        echo
        echo "-h, --help                  print a help message and exit."
        echo "-s, --size                  sort the contents of the initramfs by size."
        echo "-f, --file <filename>       print the contents of <filename>."
        echo "-k, --kver <kernel version> inspect the initramfs of <kernel version>."
        echo
    } >&2
}

sorted=0
declare -A filenames

unset POSIXLY_CORRECT
TEMP=$(getopt \
    -o "shf:k:" \
    --long kver: \
    --long file: \
    --long help \
    --long size \
    -- "$@")

if (( $? != 0 )); then
    usage
    exit 1
fi

eval set -- "$TEMP"

while (($# > 0)); do
    case $1 in
        -k|--kver)  KERNEL_VERSION="$2"; shift;;
        -f|--file)  filenames[${2#/}]=1; shift;;
        -s|--size)  sorted=1;;
        -h|--help)  usage; exit 0;;
        --)         shift;break;;
        *)          usage; exit 1;;
    esac
    shift
done

[[ $KERNEL_VERSION ]] || KERNEL_VERSION="$(uname -r)"

if [[ $1 ]]; then
    image="$1"
    if ! [[ -f "$image" ]]; then
        {
            echo "$image does not exist"
            echo
        } >&2
        usage
        exit 1
    fi
else
    [[ -f /etc/machine-id ]] && read MACHINE_ID < /etc/machine-id

    if [[ -d /boot/loader/entries || -L /boot/loader/entries ]] \
        && [[ $MACHINE_ID ]] \
        && [[ -d /boot/${MACHINE_ID} || -L /boot/${MACHINE_ID} ]] ; then
        image="/boot/${MACHINE_ID}/${KERNEL_VERSION}/initrd"
    else
        image="/boot/initramfs-${KERNEL_VERSION}.img"
    fi
fi

shift
while (($# > 0)); do
    filenames[${1#/}]=1;
    shift
done

if ! [[ -f "$image" ]]; then
    {
        echo "No <initramfs file> specified and the default image '$image' cannot be accessed!"
        echo
    } >&2
    usage
    exit 1
fi

read -N 6 bin < "$image"
case $bin in
    $'\x1f\x8b'*)
        CAT="zcat";;
    BZh*)
        CAT="bzcat";;
    070701)
        CAT="cat";;
    *)
        CAT="xzcat";
        if echo "test"|xz|xzcat --single-stream >/dev/null 2>&1; then
            CAT="xzcat --single-stream"
        fi
        ;;
esac

ret=0

if (( ${#filenames[@]} > 0 )); then
    (( ${#filenames[@]} == 1 )) && nofileinfo=1
    for f in ${!filenames[@]}; do
        [[ $nofileinfo ]] || echo "initramfs:/$f"
        [[ $nofileinfo ]] || echo "========================================================================"
        $CAT $image | cpio --extract --verbose --quiet --to-stdout $f 2>/dev/null
        ((ret+=$?))
        [[ $nofileinfo ]] || echo "========================================================================"
        [[ $nofileinfo ]] || echo
    done
else
    echo "Image: $image: $(du -h $image | while read a b; do echo $a;done)"
    echo "========================================================================"
    version=$($CAT "$image" | cpio --extract --verbose --quiet --to-stdout '*lib/dracut/dracut-*' 2>/dev/null)
    ((ret+=$?))
    echo "$version with dracut modules:"
    $CAT "$image" | cpio --extract --verbose --quiet --to-stdout 'usr/lib/dracut/modules.txt' 2>/dev/null
    ((ret+=$?))
    echo "========================================================================"
    if [ "$sorted" -eq 1 ]; then
        $CAT "$image" | cpio --extract --verbose --quiet --list | sort -n -k5
    else
        $CAT "$image" | cpio --extract --verbose --quiet --list | sort -k9
    fi
    ((ret+=$?))
    echo "========================================================================"
fi

exit $ret
