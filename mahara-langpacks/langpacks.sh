#!/bin/bash

# Copyright (C) 2010 Catalyst IT Ltd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# this is expected to defind DATA, SCRIPTS, DOCROOT, PROJDIR and WWWROOT
. /etc/mahara-langpacks.conf

GITDIR=${DATA}/git
DIRTY=${DATA}/old
CLEAN=${DATA}/new
TARBALLS=${DATA}/tarballs

if [ ! -w ${DATA} ]; then
    echo "${DATA} not writable"
    exit 1
fi
if [ ! -w ${DOCROOT} ]; then
    echo "${DOCROOT} not writable"
    exit 1
fi

[ ! -d ${GITDIR} ] && mkdir ${GITDIR}
[ ! -d ${DIRTY} ] && mkdir ${DIRTY}
[ ! -d ${CLEAN} ] && mkdir ${CLEAN}
[ ! -d ${TARBALLS} ] && mkdir ${TARBALLS}

# Lock the script to prevent running in parallel
if [ ! mkdir ${DATA}/lock ]; then
    echo "The script is running" >&2
    exit 0
fi

env DATA=$DATA DOCROOT=$DOCROOT SCRIPTS=$SCRIPTS /usr/bin/perl ${SCRIPTS}/langpacks.pl

rm -rf ${DATA}/lock
