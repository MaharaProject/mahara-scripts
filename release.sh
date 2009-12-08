#!/bin/bash
#
# Builds release tarballs of Mahara at the given version, ready for
# distribution
set -e


print_usage() {
    echo "Usage is $0 [version] [branch] public|private"
    echo "e.g. $0 0.6.2 0.6_STABLE private"
    echo "e.g. $0 1.0.0alpha1 master public"
}

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    print_usage
    exit 1
fi

# Check for git gpg lp-project-upload

VERSION=$1

MAJOR=${VERSION%.*}
REST=${VERSION##*.}
MINOR=${REST%%[a-z]*}
MICRO=`echo ${REST} | sed 's/^[0-9]*//g'`
MICROA=`echo ${MICRO} | sed 's/[^a-z]//g'`
MICROB=`echo ${MICRO} | sed 's/[a-z]//g'`

BRANCH=$2
OPTION=$3
BUILDDIR="/tmp/mahara/tarballs"
CURRENTDIR="`pwd`"
SCRIPTDIR=$( readlink -f -- "${0%/*}" )

if [ -z "${MAJOR}" ] || [ -z "${MINOR}" ]; then
    print_usage
    exit 1
fi

if [ "$OPTION" != "public" ] && [ "${OPTION}" != 'private' ]; then
    print_usage
    exit 1
fi

if [ -d ${BUILDDIR} ]; then
    rm -rf ${BUILDDIR}
fi

mkdir -p ${BUILDDIR}/mahara
pushd ${BUILDDIR}/mahara




# Get the public & security branches

PUBLIC="git@gitorious.org:mahara/mahara.git"
SECURITY="git+ssh://git.catalyst.net.nz/var/gitprivate/mahara-security.git"

echo "Cloning public repository ${PUBLIC} in ${BUILDDIR}/mahara"
git init
git remote add -t ${BRANCH} mahara ${PUBLIC}
git fetch -q mahara
git checkout -b ${BRANCH} mahara/${BRANCH}

if [ "$OPTION" != "public" ]; then
    echo "Checking out security repository ${SECURITY}..."
    git remote add -t ${BRANCH} mahara-security ${SECURITY}
    git fetch -q mahara-security
    git checkout -b S_${BRANCH} mahara-security/${BRANCH}
    echo "Merging $BRANCH (public) into $BRANCH (security)"
    git merge ${BRANCH}
    # Check for merge conflicts
fi



# Edit ChangeLog

RELEASE="${MAJOR}.${MINOR}${MICRO}"

echo -e "#\n# Please add a description of the major changes in this release, one per line:\n#\n" > ${CURRENTDIR}/ChangeLog.temp
sensible-editor ${CURRENTDIR}/ChangeLog.temp
grep -v "^#" ${CURRENTDIR}/ChangeLog.temp > ${CURRENTDIR}/changes.temp

if [ -f "ChangeLog" ]; then
    cp ChangeLog ChangeLog.back
    echo "$RELEASE (`date +%Y-%m-%d`)" > ChangeLog
    sed 's/^/- /g' ${CURRENTDIR}/changes.temp >> ChangeLog
    echo >> ChangeLog
    cat ChangeLog.back >> ChangeLog
    git add ChangeLog
fi




# Add a version bump commit for the release

VERSIONFILE=htdocs/lib/version.php

# If there's no 'micro' part of the version number, assume it's a stable release, and
# bump version by 1.  If it's an unstable release, use 
if [ -z "${MICRO}" ]; then
    OLDVERSION=$(perl -n -e 'print if s/^\$config->version = (\d{10}).*/$1/' < ${VERSIONFILE})
    NEWVERSION=$(( ${OLDVERSION} + 1 ))
else
    NEWVERSION=`date +%Y%m%d`00
fi

sed "s/\$config->version = [0-9]\{10\};/\$config->version = $NEWVERSION;/" ${VERSIONFILE} > ${VERSIONFILE}.temp
sed "s/\$config->release = .*/\$config->release = '$RELEASE';/" ${VERSIONFILE}.temp > ${VERSIONFILE}

echo
git add ${VERSIONFILE}
git commit -m "Version bump for $RELEASE"



# Tag the version bump commit
LASTTAG=`git describe --abbrev=0`
RELEASETAG="`echo $RELEASE | tr '[:lower:]' '[:upper:]'`_RELEASE"
echo -e "\nTag new version bump commit as '$RELEASETAG'"
git tag -s ${RELEASETAG} -m "$RELEASE release"



# Create tarballs

echo "Creating mahara-${RELEASE}.tar.gz"
git archive --format=tar --prefix=mahara-${VERSION}/ ${RELEASETAG} | gzip -9 > ${CURRENTDIR}/mahara-${RELEASE}.tar.gz
echo "Creating mahara-${RELEASE}.tar.bz2"
git archive --format=tar --prefix=mahara-${VERSION}/ ${RELEASETAG} | bzip2 -9 > ${CURRENTDIR}/mahara-${RELEASE}.tar.bz2
echo "Creating mahara-${RELEASE}.zip"
git archive --format=zip --prefix=mahara-${VERSION}/ -9 ${RELEASETAG} > ${CURRENTDIR}/mahara-${RELEASE}.zip



# Save git changelog
if [ -n "${LASTTAG}" ] ; then
    echo "Getting changelog from previous tag ${LASTTAG}"
    git log --pretty=format:"%s" --no-color ${LASTTAG}..${RELEASETAG} > ${CURRENTDIR}/${RELEASETAG}.cl
else
    git log --pretty=format:"%s" --no-color ${RELEASETAG} > ${CURRENTDIR}/${RELEASETAG}.cl
fi
OLDRELEASE=${LASTTAG%_RELEASE}



# Prepare eduforge release notes

TMP_M4_FILE=/tmp/mahara-releasnotes.m4.tmp
echo "changecom" > $TMP_M4_FILE
echo "define(\`__RELEASE__',\`${RELEASE}')dnl" >> $TMP_M4_FILE
echo "define(\`__OLDRELEASE__',\`${OLDRELEASE}')dnl" >> $TMP_M4_FILE
echo "define(\`__MAJOR__',\`${MAJOR}')dnl" >> $TMP_M4_FILE
sed 's/^/ * /g' ${CURRENTDIR}/changes.temp >> ${CURRENTDIR}/changes.eduforge.temp
echo "define(\`__CHANGES__',\`include(\`${CURRENTDIR}/changes.eduforge.temp')')dnl" >> $TMP_M4_FILE

if [ -z "${MICRO}" ]; then
    TEMPLATE=releasenotes.stable.template
else
    TEMPLATE=releasenotes.${MICROA}.template
fi

m4 ${TMP_M4_FILE} ${SCRIPTDIR}/${TEMPLATE} > ${CURRENTDIR}/releasenotes-${RELEASE}.txt



# Second version bump for post-release

NEWVERSION=$(( ${NEWVERSION} + 1 ))
if [ -z "${MICRO}" ]; then
    NEWRELEASE="${MAJOR}.$(( ${MINOR} + 1 ))testing"
else
    NEWRELEASE="${MAJOR}.${MINOR}${MICROA}$(( ${MICROB} + 1 ))dev"
fi

sed "s/\$config->version = [0-9]\{10\};/\$config->version = $NEWVERSION;/" ${VERSIONFILE} > ${VERSIONFILE}.temp
sed "s/\$config->release = .*/\$config->release = '$NEWRELEASE';/" ${VERSIONFILE}.temp > ${VERSIONFILE}

git add ${VERSIONFILE}
git commit -m "Version bump for $NEWRELEASE"



# Merge security back into public

if [ "$OPTION" != "public" ]; then
    git checkout ${BRANCH}
    git merge S_${BRANCH}
fi



# Output commands to push to the remote repository and clean up

CLEANUPSCRIPT=release-${RELEASE}-cleanup.sh
echo > ${CURRENTDIR}/${CLEANUPSCRIPT}


echo "cd ${BUILDDIR}/mahara" >> ${CURRENTDIR}/${CLEANUPSCRIPT}
echo "git push mahara ${BRANCH}:refs/heads/${BRANCH}" >> ${CURRENTDIR}/${CLEANUPSCRIPT}
echo "git push mahara ${RELEASETAG}:refs/tags/${RELEASETAG}" >> ${CURRENTDIR}/${CLEANUPSCRIPT}
if [ "$OPTION" != "public" ]; then
    echo "git push mahara-security S_${BRANCH}:refs/heads/${BRANCH}" >> ${CURRENTDIR}/${CLEANUPSCRIPT}
    echo "git push mahara-security ${RELEASETAG}:refs/tags/${RELEASETAG}" >> ${CURRENTDIR}/${CLEANUPSCRIPT}
fi

echo "gpg --armor --sign --detach-sig ${CURRENTDIR}/mahara-${RELEASE}.tar.gz" >> ${CURRENTDIR}/${CLEANUPSCRIPT}
echo "gpg --armor --sign --detach-sig ${CURRENTDIR}/mahara-${RELEASE}.tar.bz2" >> ${CURRENTDIR}/${CLEANUPSCRIPT}
echo "gpg --armor --sign --detach-sig ${CURRENTDIR}/mahara-${RELEASE}.zip" >> ${CURRENTDIR}/${CLEANUPSCRIPT}

echo "# lp-project-upload mahara ${RELEASE} ${CURRENTDIR}/mahara-${RELEASE}.tar.gz" >> ${CURRENTDIR}/${CLEANUPSCRIPT}
echo "# lp-project-upload mahara ${RELEASE} ${CURRENTDIR}/mahara-${RELEASE}.tar.bz2" >> ${CURRENTDIR}/${CLEANUPSCRIPT}
echo "# lp-project-upload mahara ${RELEASE} ${CURRENTDIR}/mahara-${RELEASE}.tar.zip" >> ${CURRENTDIR}/${CLEANUPSCRIPT}

echo "rm -rf ${BUILDDIR}" >> ${CURRENTDIR}/${CLEANUPSCRIPT}

chmod 700 ${CURRENTDIR}/${CLEANUPSCRIPT}



# Clean up

rm ${VERSIONFILE}.temp
rm ${CURRENTDIR}/ChangeLog.temp
rm ${CURRENTDIR}/changes.temp
rm ${CURRENTDIR}/changes.eduforge.temp
rm ${TMP_M4_FILE}




echo -e "\n\nTarballs, release notes & changelog for Launchpad:\n"
cd ${CURRENTDIR}
ls -l mahara-${RELEASE}.tar.gz mahara-${RELEASE}.tar.bz2 mahara-${RELEASE}.zip releasenotes-${RELEASE}.txt ${RELEASETAG}.cl

echo -e "\n1. Check that everything is in order in the ${BUILDDIR}/mahara repository."
echo -e "\n2. Create the release on launchpad at https://launchpad.net/mahara/+milestone/${RELEASE}"
echo -e "\n3. Run the commands in ${CLEANUPSCRIPT} to push the changes back to the remote repository and upload the tarballs."
