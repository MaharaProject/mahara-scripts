#!/bin/bash
#
# Builds release tarballs of Mahara at the given version, ready for
# distribution
set -e

print_usage() {
    echo "Usage is $0 [version]"
    echo "e.g. $0 0.6.2"
    echo "e.g. $0 1.0.0alpha1"
}

if [ -z "$1" ]; then
    print_usage
    exit 1
fi

MAJOR=${1:0:3}
MINOR=${1:4:1}
MICRO=${1:5}
BUILDDIR="/tmp/mahara/tarballs"
CURRENTDIR="`pwd`"

if [ -z "${MAJOR}" ] || [ -z "${MINOR}" ]; then
    print_usage
    exit 1
fi

VERSION="${MAJOR}.${MINOR}${MICRO}"

if [ -d ${BUILDDIR} ]; then
    rm -rf ${BUILDDIR}
fi

mkdir -p ${BUILDDIR}

pushd ${BUILDDIR}

# Get the stable branch
git clone -n "http://git.catalyst.net.nz/mahara.git" mahara

pushd ${BUILDDIR}/mahara

# Switch to the release tag
RELEASETAG="`echo $VERSION | tr '[:lower:]' '[:upper:]'`_RELEASE"
git checkout $RELEASETAG

# Remove git stuff
rm .git -rf
find . -name '.gitignore' -exec rm {} \;

popd

mv mahara mahara-${VERSION}

tar zcf ${CURRENTDIR}/mahara-${VERSION}.tar.gz mahara-${VERSION}
tar jcf ${CURRENTDIR}/mahara-${VERSION}.tar.bz2 mahara-${VERSION}
zip -qrT9 ${CURRENTDIR}/mahara-${VERSION}.zip mahara-${VERSION}

popd
rm -rf ${BUILDDIR}
