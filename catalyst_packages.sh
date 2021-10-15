#!/bin/bash
#
# Builds and releases Mahara to the debian repo
#
# This script can release just one version (stable|unstable), or both at once
#
set -e

BUILDDIR="/tmp/mahara/release"
REPODIR="/tmp/mahara/repo"
ARCHLIST="i386 amd64"
DATE="`date`"


echo " *** STOP *** "
echo " Make sure you have merged main into pkg-catalyst, and the latest"
echo " stable branch into the appropriate pkg-catalyst-* branch. If you"
echo " have not done this, hit Ctrl-C now and do so."
read junk

RELEASE=$1
if [ "$RELEASE" = "" ]; then
    echo -n "Building ALL versions: are you sure? (y/N) "
    read ANS
    if [ "$ANS" != "y" ] && [ "$ANS" != "Y" ]; then
        echo "Abort."
        exit 1
    fi
    RELEASELIST="stable unstable"
elif [ "$RELEASE" != "stable" ] && [ "$RELEASE" != "unstable" ]; then
    echo "Invalid release: $RELEASE"
    exit 1
else
    RELEASELIST=$RELEASE
fi

if [ -d ${BUILDDIR} ]; then
    rm -rf ${BUILDDIR}
fi
if [ -d ${REPODIR} ]; then
    rm -rf ${REPODIR}
fi

mkdir -p ${BUILDDIR}

# Create repo dirs
for release in $RELEASELIST; do
    mkdir -p ${REPODIR}/dists/${release}/mahara
    pushd ${REPODIR}/dists/${release}/mahara
    mkdir binary-all
    for arch in ${ARCHLIST}; do mkdir binary-${arch}; done
    popd
    mkdir -p ${REPODIR}/pool/${release}
done

pushd ${BUILDDIR}

# Get a checkout of Mahara for working with, and find out what the stable
# release is currently
git clone -n "git+ssh://git.catalyst.net.nz/git/public/mahara.git" mahara
pushd mahara
STABLE_RELEASE="`ls -1 .git/refs/tags | egrep '[0-9]+\.[0-9]+\.[0-9]+_RELEASE$' | tail -n1`"
STABLE_DEBIAN_BRANCH=${STABLE_RELEASE:0:3}
popd


# Build Stable
if [ "$RELEASE" = "" ] || [ "$RELEASE" = "stable" ]; then
    echo
    echo "Building ${STABLE_RELEASE} ..."

    pushd ${BUILDDIR}/mahara
    git checkout -b "pkg-catalyst-${STABLE_DEBIAN_BRANCH}" "origin/pkg-catalyst-${STABLE_DEBIAN_BRANCH}"
    make
    popd
    mv *.deb ${REPODIR}/pool/stable/
fi

# Build Unstable
if [ "$RELEASE" = "" ] || [ "$RELEASE" = "unstable" ]; then
    echo
    echo "Building Unstable ..."

    pushd ${BUILDDIR}/mahara
    git checkout -b pkg-catalyst origin/pkg-catalyst
    make
    popd
    mv *.deb ${REPODIR}/pool/unstable/
fi

# Link other arches into all and build packages
for release in $RELEASELIST; do
    pushd ${REPODIR}/pool

    for arch in all ${ARCHLIST}; do
        dpkg-scanpackages ${release} /dev/null /pool/ | /bin/gzip -9 > ${REPODIR}/dists/${release}/mahara/binary-${arch}/Packages.gz
        dpkg-scanpackages ${release} /dev/null /pool/ > ${REPODIR}/dists/${release}/mahara/binary-${arch}/Packages
    done

    popd

    pushd ${REPODIR}/dists/${release}

    # Create Release file
    cat <<EOHDR >Release
Origin: Mahara
Label: Mahara
Suite: ${release}
Date: ${DATE}
Architectures: ${ARCHLIST}
Components: mahara
Description: Mahara ${release} repository
MD5Sum:
EOHDR

    for file in `find mahara -type f -name 'Packages*'`; do
        MD5="`md5sum $file | cut -c1-32`"
        SIZE="`cat $file | wc -c`"
        printf " %s %16d %s\n" "${MD5}" "${SIZE}" "${file}" >>Release
    done

    gpg --yes --armour --sign-with 1D18A55D --detach-sign --output Release.gpg Release

    popd
done

# Steal the latest index.html and dump into
pushd ${BUILDDIR}/mahara
git cat-file blob origin/pkg-catalyst:debian/index.html > ${REPODIR}/index.html
popd

popd

# Now (optionally) sync the repo to the git repository
echo " The repo has now been set up in ${REPODIR}. If you're really sure,"
echo " this script can rsync this to the git repository."
echo " rsync to git repository? [y/N] "
read ANS
if [ "$ANS" != "y" ] && [ "$ANS" != "Y" ]; then
    echo "Abort."
    exit 1
fi

if [ "$RELEASE" = "" ]; then
    rsync -PIlvr --delete-after --no-p --no-g --chmod=Dg+ws,Fg+w ${REPODIR}/* locke.catalyst.net.nz:/home/ftp/pub/mahara/
else
    rsync -PIlvr --no-p --no-g --chmod=Dg+ws,Fg+w ${REPODIR}/* locke.catalyst.net.nz:/home/ftp/pub/mahara/
fi

rm -rf ${BUILDDIR}
rm -rf ${REPODIR}
