#!/bin/bash

# Generate .po files from mahara langpacks

# Some working directory we can write to
WORK=${HOME}/temp

# A git checkout of mahara (to read en.utf8 langpacks from)
MAHARA=${WORK}/mahara

# Base working directory in which to check out all the mahara-lang repos
GITDIR=${WORK}/mahara-lang

# Somewhere to put .po files
OUT=${WORK}/po

# Location of php script to generate .po file from mahara langpack
PHPSCRIPT=${HOME}/mahara-scripts/mahara-langpacks/php-po.php

[ ! -f ${PHPSCRIPT} ] && exit 1
[ ! -w ${WORK} ] && exit 1
[ ! -d ${GITDIR} ] && mkdir ${GITDIR}
[ ! -d ${OUT} ] && mkdir ${OUT}

mahararemote='git://gitorious.org/mahara/mahara.git'

if [ ! -d ${MAHARA} ] ; then
    cd ${WORK}
    git clone ${mahararemote} ${MAHARA}
fi

langremotebase='git://gitorious.org/mahara-lang'
langs="ca cs da de en_us es eu fi fr he it ja ko nl no_nb sl zh_tw"

for lang in ${langs} ; do
    remote=${langremotebase}/${lang}.git
    gitlangdir=${GITDIR}/${lang}

    if [ ! -d ${gitlangdir} ]; then
        echo "git clone ${remote} ${gitlangdir}"
        git clone ${remote} ${gitlangdir}
    fi

    cd ${gitlangdir}
    git fetch --quiet
done

branches="1.2_STABLE 1.3_STABLE 1.4_STABLE master"

for branch in ${branches} ; do
    echo "${branch}:"
    cd ${MAHARA}
    git checkout --quiet ${branch}
    git pull

    for lang in ${langs} ; do
        gitlangdir=${GITDIR}/${lang}

        cd ${gitlangdir}

        remotebranchexists=`git branch -r | grep "origin\/${branch}$"`
        if [ -z "${remotebranchexists}" ]; then
            continue;
        fi

        branchexists=`git branch | grep "${branch}$"`
        if [ -z "${branchexists}" ]; then
            git checkout --quiet -b ${branch} origin/${branch}
        else
            git checkout --quiet ${branch}
            git reset --hard -q origin/${branch}
        fi

        outputfile=${OUT}/${lang}-${branch}.po
        [ -f ${outputfile} ] && rm ${outputfile}

        # If there's already a po file on the branch, assume it's the master version of the
        # langpack, and don't generate one.
        if [ -f ${gitlangdir}/${lang}-${branch}.po ] ; then
            echo "${lang}-${branch}.po already exists in the ${lang} git repository; skipping"
            continue
        fi

        echo "Generating ${lang}-${branch}.po"
        /usr/bin/php ${PHPSCRIPT} ${MAHARA}/htdocs/ ${gitlangdir} ${outputfile}
    done
done

