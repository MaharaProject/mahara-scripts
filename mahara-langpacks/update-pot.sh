#!/bin/bash

# Update .pot files

# this is expected to define DATA, SCRIPTS, DOCROOT
. /etc/mahara-langpacks.conf

if [ ! -w ${DATA} ]; then
    echo "${DATA} not writable"
    exit 1
fi

if [ ! -w ${DOCROOT} ]; then
    echo "${DOCROOT} not writable"
    exit 1
fi

WORK=${DATA}/templates
GITDIR=${WORK}/git
TEMP=${WORK}/temp
OUT=${DATA}/po

[ ! -d ${WORK} ] && mkdir ${WORK}
[ ! -d ${TEMP} ] && mkdir ${TEMP}
[ ! -d ${OUT} ] && mkdir ${OUT}
[ ! -d ${DOCROOT}/pot ] && mkdir ${DOCROOT}/pot

remote='git://gitorious.org/mahara/mahara.git'

if [ ! -d ${GITDIR} ]; then
    echo "git clone ${remote} ${GITDIR}"
    git clone --quiet ${remote} ${GITDIR}
fi

cd ${GITDIR}
git fetch --quiet origin

branches="1.2_STABLE 1.3_STABLE master"

for branch in ${branches} ; do
    branchexists=`git branch | grep "${branch}$"`
    if [ -z "${branchexists}" ]; then
        git checkout -b ${branch} origin/${branch}
    else
        git checkout --quiet ${branch}
        git reset --hard -q origin/${branch}
    fi

    remotecommit=`git log --pretty=format:"%H" | head -1`

    last=${WORK}/${branch}.last
    lastruncommit=z
    if [ -f ${last} ]; then
        lastruncommit=`cat ${last}`
    fi

    if [ "$remotecommit" = "$lastruncommit" ] ; then
        echo "${branch} is up to date"
    else
        echo "New commits on ${branch}"

        if [ ! -d ${GITDIR}/htdocs ] ; then
            echo "No htdocs directory in branch ${branch}; skipping."
            continue
        fi

        find htdocs -type f -path "*lang/en.utf8*" | xargs tar zcf ${TEMP}/${branch}.tar.gz

        if [ ! -f ${TEMP}/${branch}.tar.gz ] ; then
            echo "Missing archive ${TEMP}/${branch}.tar.gz; skipping."
            continue
        fi

        # While we have an up-to-date en tarball handy, dump a copy of it in the main tarball directory
        cp ${TEMP}/${branch}.tar.gz ${DOCROOT}/en-${branch}.tar.gz

        langpack=${TEMP}/${branch}
        [ ! -d ${langpack} ] && mkdir ${langpack}

        cd ${langpack}
        tar zxf ../${branch}.tar.gz
        cd ${GITDIR}

        if [ ! -d ${langpack}/htdocs ] ; then
            echo "No htdocs directory in langpack ${langpack}; skipping."
            continue
        fi

        [ ! -d ${OUT}/${branch} ] && mkdir ${OUT}/${branch}
        outputdir=${OUT}/${branch}/mahara
        [ ! -d ${outputdir} ] && mkdir ${outputdir}
        outputfile=${outputdir}/mahara.pot

        echo "Updating ${outputfile}"

        [ -f ${outputfile} ] && rm ${outputfile}
        /usr/bin/php ${SCRIPTS}/php-po.php ${langpack} ${langpack} ${outputfile}

        if [ -f ${outputfile} ]; then
            cd ${OUT}/${branch}
            tar zcf ${DOCROOT}/pot/${branch}.tar.gz mahara/mahara.pot
            cd ${GITDIR}
        fi

        echo "${remotecommit}" > ${last}
    fi
done