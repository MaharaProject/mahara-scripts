#!/bin/bash

DATA=/var/local/mahara-langpacks
SCRIPTS=/usr/local/lib/mahara-langpacks
PROJDIR='git://gitorious.org/mahara-lang'
GITDIR=${DATA}/git
DIRTY=${DATA}/old
CLEAN=${DATA}/new
TARBALLS=${DATA}/tarballs
DOCROOT=/var/www/mahara-langpacks
WWWROOT=http://langpacks.dev.mahara.org

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

langs="ca cs de es eu fr he it ja ko nl no_nb sl zh_tw"

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

    for remotebranch in `git branch -r | grep -v "HEAD\|1.0_STABLE"`; do

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
                git pull --quiet
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

index="<html><head><title>Mahara Language Packs</title><style>td,th {padding:0 .5em;} tr.next td {border-top: 1px dotted #ccc;}</style></head>"
index+="<body><h3>Mahara Language Packs</h3>"
index+="<table>"
index+="<thead>"
index+="<tr><th><th colspan=\"2\">Last good version</th><th>Last commit</th><th>Changes</th><th>Status</th></tr>"
index+="</thead>"
for file in `find ${TARBALLS} -name "*.last" | sort`; do
    base=${file##*/}
    base=${base%.last}

    lang=${base%%-*}
    
    index+="<tr"
    if [ "${lang}" != "${lastlang}" ]; then
        index+=" class=\"next\""
    fi
    index+=">"
    index+="<td style=\"font-weight:bold;\">"
    if [ "${lang}" != "${lastlang}" ]; then
        index+="${lang}"
    fi
    index+="</td>"
    index+="<td style=\"font-weight:bold; border-left: 1px dotted #ccc;\">"
    if [ -f ${DOCROOT}/${base}.tar.gz ]; then
        index+="<a href=\"${WWWROOT}/${base}.tar.gz\">${base}.tar.gz</a>"
    fi
    date=`stat -c "%y" ${DOCROOT}/${base}.tar.gz 2>/dev/null`
    date=${date%% *}
    index+="</td><td>${date}</td>"
    last=`cat ${file}`
    index+="<td style=\"color: #888; border-left: 1px dotted #ccc;\">${last#* }</td>"
    diffsize=`stat -c "%s" ${DOCROOT}/${base}-diff.txt 2>/dev/null`
    index+="<td style=\"text-align:center;\">"
    if [ "${diffsize}" != '0' ] ; then
        index+="<a href=\"${WWWROOT}/${base}-diff.txt\">diff</a>"
    fi
    index+="</td>"
    if [ -f ${DOCROOT}/${base}-errors.txt ]; then
        index+="<td style=\"text-align:center;\"><a style=\"color:#a00;\" href=\"${WWWROOT}/${base}-errors.txt\">errors</a></td>"
    else
        index+="<td style=\"text-align:center;color:#080;\">ok</td>"
    fi
    index+="</tr>"

    lastlang=${lang}
done
index+="</table></body></html>"

echo -e "${index}" > ${DOCROOT}/index.html

echo "Done."



