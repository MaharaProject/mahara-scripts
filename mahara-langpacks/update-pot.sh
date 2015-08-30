#!/bin/bash

# Update .pot files

# this is expected to define DATA, SCRIPTS, DOCROOT
. /etc/mahara-langpacks.conf

echo -n "Checking for changes to strings "
date "+%Y-%m-%d %H:%M:%S"

if [ ! -w ${DATA} ]; then
    echo "${DATA} not writable"
    exit 1
fi

if [ ! -w ${DOCROOT} ]; then
    echo "${DOCROOT} not writable"
    exit 1
fi

# Lock the script to prevent running in parallel
if ! mkdir ${DATA}/update-pot-lock; then
    echo "The script is running" >&2
    exit 0
fi

WORK=${DATA}/templates
GITDIR=${WORK}/git
TEMP=${WORK}/temp

[ ! -d ${WORK} ] && mkdir ${WORK}
[ ! -d ${TEMP} ] && mkdir ${TEMP}
[ ! -d ${DOCROOT}/pot ] && mkdir ${DOCROOT}/pot

mahararemote='https://git.mahara.org/mahara/mahara.git'
# mahararemote='git@git.mahara.org/mahara/mahara.git'
# mahararemote='git@github.com:MaharaProject/mahara.git'

if [ ! -d ${GITDIR} ]; then
    echo "git clone ${mahararemote} ${GITDIR}"
    git clone --quiet ${mahararemote} ${GITDIR}
fi

bzr launchpad-login dev-mahara
[ ! -d "${WORK}/mahara-lang-bzr" ] && bzr init-repo ${WORK}/mahara-lang-bzr

BZR=${WORK}/mahara-lang-bzr

cd ${GITDIR}
git fetch --quiet origin

branches="1.7_STABLE 1.8_STABLE 1.9_STABLE 1.10_STABLE 15.04_STABLE master"

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

        # Output into a copy of the launchpad mahara-lang repo
        if [ ! -d ${BZR}/${branch} ]; then
            bzr branch lp:~mahara-lang/mahara-lang/${branch} ${BZR}/${branch}
        else
            cd ${BZR}/${branch}
            bzr pull
            cd ${GITDIR}
        fi

        outputdir=${BZR}/${branch}/mahara
        [ ! -d ${outputdir} ] && mkdir ${outputdir}
        outputfile=${outputdir}/mahara.pot

        echo "Updating ${outputfile}"

        [ -f ${outputfile} ] && rm ${outputfile}
        /usr/bin/php ${SCRIPTS}/php-po.php ${langpack}/htdocs ${langpack}/htdocs ${outputfile}

        if [ -f ${outputfile} ]; then
            cd ${BZR}/${branch}

            diffs=`bzr diff mahara/mahara.pot | grep "[+-]msg"`

            if [ -z "${diffs}" ]; then
                bzr revert

            else
                # Update copy of template in webroot
                tar zcf ${DOCROOT}/pot/${branch}.tar.gz mahara/mahara.pot

                # Update template
                bzr add mahara/mahara.pot
                bzr commit -m "Update template to ${remotecommit}"

                if [ $branch = 'master' ] ; then
                    # Update all the .po files from the export repo to avoid unnecessary invalidation
                    # of existing translations

                    exportbranch=${branch}-export
                    if [ ! -d ${BZR}/${exportbranch} ]; then
                        bzr branch lp:~mahara-lang/mahara-lang/${exportbranch} ${BZR}/${exportbranch}
                    else
                        cd ${BZR}/${exportbranch}
                        bzr pull
                    fi

                    cd ${BZR}/${branch}

                    for po in `ls ${BZR}/${exportbranch}/mahara/*.po`; do
                        pobase=${po##*/}
                        /usr/bin/perl ${SCRIPTS}/update-po-from-pot.pl $po mahara/mahara.pot mahara/$pobase

                        status=`bzr status -S mahara/$pobase | grep ?`
                        if [ ! -z "$status" ]; then
                            # New file
                            bzr add mahara/$pobase
                        else
                            # There are always a few changes in the po header, but we don't care about them, so just
                            # check if anything's changed after the "X-Generator:" or "X-Launchpad-Export-Date:" lines
                            podiffs=`bzr diff mahara/${pobase} | awk '/(X-Generator: Launchpad|X-Launchpad-Export-Date:)/ {p+=1;next}; p>1 {print}' | grep "^[+-]"`
                            if [ -z "$podiffs" ] ; then
                                # Nothing worth committing
                                bzr revert mahara/$pobase
                            fi
                        fi
                    done

                    podiffs=`bzr diff mahara`
                    if [ ! -z "$podiffs" ] ; then
                        bzr add mahara
                        bzr commit -m "Update translations to ${remotecommit}"
                    fi

                fi

                # Push everything to lp:mahara-lang, if this is the prod instance.
                if [ "${WWWROOT}" = 'http://langpacks.mahara.org' ]; then
                    bzr push lp:~mahara-lang/mahara-lang/${branch}
                else
                    echo "Not pushing to lp:~mahara-lang/mahara-lang/${branch}"
                fi
            fi

            cd ${GITDIR}
        fi

        echo "${remotecommit}" > ${last}
    fi
done

# Unlock the script
rmdir ${DATA}/update-pot-lock
