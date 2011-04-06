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

CLEANCMD="/usr/bin/php ${SCRIPTS}/langpack.php"
SYNTAXCMD="/usr/bin/php -l"
UTF8CMD="/usr/bin/perl ${SCRIPTS}/check-utf8.pl"

if [ ! -w ${DATA} ]; then
    echo "${DATA} not writable"
    exit 1
fi
if [ ! -w ${DOCROOT} ]; then
    echo "${DOCROOT} not writable"
    exit 1
fi

echo "Checking langpacks for updates: `date \"+%Y-%m-%d %H:%M:%S\"`"

[ ! -d ${GITDIR} ] && mkdir ${GITDIR}
[ ! -d ${DIRTY} ] && mkdir ${DIRTY}
[ ! -d ${CLEAN} ] && mkdir ${CLEAN}
[ ! -d ${TARBALLS} ] && mkdir ${TARBALLS}

langs="ca cs da de en_us es eu fi fr he it ja ko nl no_nb sl zh_tw"

for lang in ${langs} ; do

    remote=${PROJDIR}/${lang}.git
    gitlangdir=${GITDIR}/${lang}
    dirtylangdir=${DIRTY}/${lang}
    cleanlangdir=${CLEAN}/${lang}

    if [ ! -d ${gitlangdir} ]; then
        git clone --quiet ${remote} ${gitlangdir}
    fi

    [ ! -d ${dirtylangdir} ] && mkdir ${dirtylangdir}
    [ ! -d ${cleanlangdir} ] && mkdir ${cleanlangdir}

    cd ${gitlangdir}

    git fetch --quiet

    for remotebranch in `git branch -r | grep -v "HEAD\|1.0_STABLE\|1.1_STABLE"`; do

        remotecommit=`git log --pretty=format:"%H %ai %an" ${remotebranch} | head -1`

        localbranch=${remotebranch##origin/}

        filenamebase=${lang}-${localbranch}

        log=${TARBALLS}/${filenamebase}.log
        tarball=${TARBALLS}/${filenamebase}.tar.gz
        diff=${TARBALLS}/${filenamebase}.diff
        [ -f ${log} ] && rm ${log}
        [ -f ${tarball} ] && rm ${tarball}
        [ -f ${diff} ] && rm ${diff}

        last=${TARBALLS}/${filenamebase}.last
        lastruncommit=z
        if [ -f ${last} ]; then
            lastruncommit=`cat ${last}`
        fi

        if [ "$remotecommit" != "$lastruncommit" ] ; then

            echo "Updating $lang $localbranch"

            branchexists=`git branch | grep "${localbranch}$"`
            if [ -z "${branchexists}" ]; then
                git checkout --quiet -b ${localbranch} ${remotebranch}
            else
                git checkout --quiet ${localbranch}
                git reset --hard -q ${remotebranch}
            fi

            dirtybranchdir=${dirtylangdir}/${localbranch}
            cleanbranchdir=${cleanlangdir}/${localbranch}
            [ ! -d ${dirtybranchdir} ] && mkdir ${dirtybranchdir}
            [ -d ${cleanbranchdir}/lang ] && rm -fr ${cleanbranchdir}
            [ ! -d ${cleanbranchdir} ] && mkdir ${cleanbranchdir}

            cp -r ${gitlangdir}/[^\\.]* ${dirtybranchdir}

            # Clean out stray php from the langpacks
            ${CLEANCMD} ${dirtybranchdir} ${cleanbranchdir}

            errors=0

            cd ${DATA}
            diff -Bwr ${dirtybranchdir} ${cleanbranchdir} > ${diff}

            # Check syntax of php files
            cd ${cleanbranchdir}
            for file in `find . -name "*.php"`; do
                output=`${SYNTAXCMD} $file`
                if [ $? -ne 0 ]; then
                    echo ${file} >> ${log}
                    echo -e "${output}" >> ${log}
                    errors=1
                fi
            done

            # Check utf8ness of all files
            for file in `find .`; do
                output=`${UTF8CMD} ${file}`
                if [ $? -ne 0 ]; then
                    echo ${file} >> ${log}
                    echo -e "${output}" >> ${log}
                    errors=1
                fi
            done

            if [ $errors = 0 ]; then
                strip=`echo ${cleanbranchdir} | sed 's,^/,,'`
                tar --transform "s,${strip},${lang}.utf8," -zcf ${tarball} ${cleanbranchdir}
            fi

            cd ${gitlangdir}
            localcommit=`git log --pretty=format:"%H %ai %an" ${localbranch} | head -1`

            echo "${localcommit}" > ${last}
        fi
    done
done

# Move new tarballs & log files to web directory
for file in `find ${TARBALLS} -name "*.tar.gz"`; do

    mv ${file} ${DOCROOT}

    # Remove the old log file
    base=${file##*/}
    base=${base%.tar.gz}
    [ -f ${DOCROOT}/${base}-errors.txt ] && rm ${DOCROOT}/${base}-errors.txt

done

for file in `find ${TARBALLS} -name "*.log"`; do
    base=${file##*/}
    base=${base%.log}
    mv ${file} ${DOCROOT}/${base}-errors.txt
done

for file in `find ${TARBALLS} -name "*.diff"`; do
    base=${file##*/}
    base=${base%.diff}
    mv ${file} ${DOCROOT}/${base}-diff.txt
done

# Generate index.html
/usr/bin/perl ${SCRIPTS}/generate-index.pl ${DOCROOT}

# Generate status.html
/usr/bin/perl ${SCRIPTS}/generate-status.pl ${TARBALLS} ${DOCROOT}

echo "Done."
