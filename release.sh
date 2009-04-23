#!/bin/bash
#
# Builds release tarballs of Mahara at the given version, ready for
# distribution
set -e


print_usage() {
    echo "Usage is $0 [version] [branch]"
    echo "e.g. $0 0.6.2 0.6_STABLE"
    echo "e.g. $0 1.0.0alpha1 master"
}

if [ -z "$1" ] || [ -z "$2" ]; then
    print_usage
    exit 1
fi



MAJOR=${1%.*}
REST=${1##*.}
MINOR=${REST%%[a-z]*}
MICRO=`echo ${REST} | sed 's/^[0-9]*//g'`
MICROA=`echo ${MICRO} | sed 's/[^a-z]//g'`
MICROB=`echo ${MICRO} | sed 's/[a-z]//g'`

BRANCH=$2
OPTION=$3
BUILDDIR="/tmp/mahara/tarballs"
#BUILDDIR="/home/richard/foobar44/mahara/tarballs"
CURRENTDIR="`pwd`"

if [ -z "${MAJOR}" ] || [ -z "${MINOR}" ]; then
    print_usage
    exit 1
fi

if [ -d ${BUILDDIR} ]; then
    rm -rf ${BUILDDIR}
fi

mkdir -p ${BUILDDIR}/mahara
pushd ${BUILDDIR}/mahara




# Get the public & security branches

PUBLIC="http://git.mahara.org/git/mahara.git"
SECURITY="git+ssh://git.catalyst.net.nz/var/gitprivate/mahara-security.git"

echo "Cloning public repository ${PUBLIC} in ${BUILDDIR}/mahara"
git-init
git-remote add -t ${BRANCH} mahara ${PUBLIC}
git fetch -q mahara
git checkout -b ${BRANCH} mahara/${BRANCH}

if [ "$OPTION" != "--public" ]; then
    echo "Checking out security repository ${SECURITY}..."
    git-remote add -t ${BRANCH} mahara-security ${SECURITY}
    git fetch -q mahara-security
    git checkout -b S_${BRANCH} mahara-security/${BRANCH}
    echo "Merging $BRANCH (public) into $BRANCH (security)"
    git merge ${BRANCH}
fi



# Update ChangeLog

RELEASE="${MAJOR}.${MINOR}${MICRO}"

if [ -f "ChangeLog" ]; then
    cp ChangeLog ChangeLog.back
    echo "$RELEASE (`date +%Y-%m-%d`)" > ChangeLog
    echo "- " >> ChangeLog
    echo >> ChangeLog
    cat ChangeLog.back >> ChangeLog
    sensible-editor ${BUILDDIR}/mahara/ChangeLog
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
RELEASETAG="`echo $RELEASE | tr '[:lower:]' '[:upper:]'`_RELEASE"
echo -e "\nTag new version bump commit as '$RELEASETAG'"
git tag -s ${RELEASETAG} -m "$RELEASE release"



# Create tarballs

echo "Creating mahara-${RELEASE}.tar.gz"
git archive --format=tar ${RELEASETAG} | gzip > ${CURRENTDIR}/mahara-${RELEASE}.tar.gz
echo "Creating mahara-${RELEASE}.tar.bz2"
git archive --format=tar ${RELEASETAG} | bzip2 > ${CURRENTDIR}/mahara-${RELEASE}.tar.bz2
echo "Creating mahara-${RELEASE}.zip"
git archive --format=zip -9 ${RELEASETAG} > ${CURRENTDIR}/mahara-${RELEASE}.zip



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


exit

popd
rm -rf ${BUILDDIR}
