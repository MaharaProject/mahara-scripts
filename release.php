#!/usr/bin/php
<?php
define('INTERNAL', 1);
define('CLI', 1);

#
# Builds release tarballs of Mahara at the given version, ready for
# distribution
#
# If you're doing a release which has security fixes, add the names
# of the patches to the end of the command line, and the script will
# apply the patches before committing the version bumps and editing
# the changelog.
#

$usage = <<<STRING
Usage is ${argv[0]} [version] [branch] [<changesetnumber>...]
e.g. ${argv[0]} 16.04.3 16.04_STABLE
e.g. ${argv[0]} 15.10.1 15.10_STABLE 5793 5795

STRING;

if (count($argv) < 3) {
    echo $usage;
    exit(1);
}

# Check for git gpg lp-project-upload

if (!@is_executable('/usr/bin/gpg')) {
  echo "You need to install gpg: apt-get install gnupg\n";
  exit(1);
}

if (!@is_executable('/usr/bin/git')) {
  echo "You need to install git: apt-get install git-core\n";
  exit(1);
}

if (!@is_executable('/usr/bin/lp-project-upload')) {
  echo "You need to install lp-project-upload: apt-get install ubuntu-dev-tools (maverick or earlier) or lptools\n";
  exit(1);
}

if (!@is_executable('/usr/bin/m4')) {
  echo "You need to install m4: apt-get install m4\n";
  exit(1);
}

$GIT_MAJOR = `git --version | cut -d' ' -f 3 | cut -d'.' -f 1`;
$GIT_MINOR = `git --version | cut -d' ' -f 3 | cut -d'.' -f 2`;

if ($GIT_MAJOR < 1 || ($GIT_MAJOR == 1 && $GIT_MINOR < 6 )) {
  echo "Your version of git is too old. Install git 1.6.\n";
  exit(1);
}

# Check all parameters

$VERSION=$argv[1];

$result = preg_match('/([0-9]+\.[0-9]+)(\.|rc)([0-9]+)/i', $VERSION, $matches);
if (!$result) {
    echo "Invalid version number. It must match the pattern \"15.04.1\" or \"15.04rc1\".\n";
    echo $usage;
    exit(1);
}
$MAJOR = $matches[1];
$MINOR = $matches[3];
$releasecandidate = ($matches[2] == 'rc');

$BRANCH = $argv[2];

// Check for unmerged drafts
if ($releasecandidate) {
    // If it's a release candidate, draft patches will be on the master branch still
    $draftbranch = 'master';
}
else {
    $draftbranch = $BRANCH;
}
$draftlines = explode(
    "\n",
    `ssh \$USER@reviews.mahara.org -p 29418 gerrit query is:draft branch:$draftbranch project:mahara "label:Code-Review>=0" "label:Verified>=0"`
);
$draftcount = 0;
foreach ($draftlines as $line) {
    if (preg_match("/rowCount: *([0-9]+)/", $line, $matches)) {
        $draftcount = $matches[1];
        break;
    }
}
if ($draftcount > 0) {
    $response = readline("There are Draft patches that may need to be merged. Do you want to continue with release [y/n]?");
    $response = trim(strtolower($response));
    if ($response == 'yes' || $response == 'y') {
        echo "Continuing...";
    }
    else {
        echo "Quitting out";
        exit(1);
    }
}

$BUILDDIR = trim(`mktemp -d /tmp/mahara.XXXXX`);
$CURRENTDIR = getcwd();
$SCRIPTDIR = dirname(__FILE__);

mkdir("${BUILDDIR}/mahara", 0777, true);
chdir("${BUILDDIR}/mahara");

# Main Mahara repo to pull from
$PUBLIC="git@github.com:MaharaProject/mahara.git";
$PUBLIC = "https://git.mahara.org/mahara/mahara.git";

echo "Cloning public repository ${PUBLIC} in ${BUILDDIR}/mahara\n";
passthru('git init');
passthru("git remote add -t ${BRANCH} mahara ${PUBLIC}");
passthru("git fetch -q mahara");
passthru("git checkout -b ${BRANCH} mahara/${BRANCH}");
passthru("git fetch -q -t");


// Applying gerrit patches named on the command line
if (count($argv) > 3) {
    $successwithpatches = true;
    for ($i = 3; $i < count($argv); $i++) {
        $patchno = $argv[$i];
        $refline = shell_exec("ssh reviews.mahara.org -p 29418 gerrit query --current-patch-set --format=TEXT change:'{$patchno}'| grep ref");
        if ($refline) {
            $result = preg_match('#ref: (refs/changes/[/0-9]+)#', $refline, $matches);
            if ($result) {
                $return_var = passthru("git fetch ssh://reviews.mahara.org:29418/mahara {$matches[1]} && git cherry-pick FETCH_HEAD");
                if ($return_var != 0) {
                    echo "Couldn't cherry-pick Gerrit change number {$patchno}.\n";
                    $successwithpatches = false;
                }
            }
            else {
                echo "Couldn't find latest patch number for Gerrit change number {$patchno}.\n";
                $succesoverall = false;
            }
        } else {
            echo "Couldn't retrieve information about Gerrit change number {$patchno}.\n";
            $successwithpatches = false;
        }
    }
    if (!$successwithpatches) {
        exit();
    }
}

# Edit ChangeLog
if (!file_exists("ChangeLog")) {
    echo "The ChangeLog file is missing and this is a stable release. Create an empty file called ChangeLog and commit it.";
    exit(1);
}

// This is a separate variable for historical reasons
$RELEASE = $VERSION;

passthru("echo \"#\n# Please add a description of the major changes in this release, one per line.\n# Don't put a dash or asterisk at the front of each line, they'll get added automatically.\n# Also, don't leave any blank lines at the bottom of this file.\n#\" > ${CURRENTDIR}/ChangeLog.temp");
passthru("sensible-editor ${CURRENTDIR}/ChangeLog.temp");
passthru("grep -v \"^#\" ${CURRENTDIR}/ChangeLog.temp > ${CURRENTDIR}/changes.temp");

if (file_exists("ChangeLog")) {
    copy('ChangeLog', 'ChangeLog.back');
    passthru("echo \"$RELEASE (`date +%Y-%m-%d`)\" > ChangeLog");
    passthru("sed 's/^/- /g' ${CURRENTDIR}/changes.temp >> ChangeLog");
    passthru("echo >> ChangeLog");
    passthru("cat ChangeLog.back >> ChangeLog");
    passthru("git add ChangeLog");
}

# Add a version bump commit for the release
$VERSIONFILE='htdocs/lib/version.php';

# If there's no 'micro' part of the version number, assume it's a stable release, and
# bump version by 1.  If it's an unstable release, use
$OLDVERSION = call_user_func(function($versionfile) {
    require($versionfile);
    return $config->version;
}, $VERSIONFILE);;
$NEWVERSION = $OLDVERSION + 1;

passthru("sed \"s/\$config->version = [0-9]\{10\};/\$config->version = $NEWVERSION;/\" ${VERSIONFILE} > ${VERSIONFILE}.temp");
passthru("sed \"s/\$config->release = .*/\$config->release = '$RELEASE';/\" ${VERSIONFILE}.temp > ${VERSIONFILE}");

echo "\n\n";
passthru("git add ${VERSIONFILE}");
passthru("git commit -s -m \"Version bump for $RELEASE\"");

# Tag the version bump commit
$LASTTAG = trim(`git describe --abbrev=0`);
$RELEASETAG = strtoupper($RELEASE) . '_RELEASE';
echo "\nTag new version bump commit as '$RELEASETAG'\n";
passthru("git tag -s ${RELEASETAG} -m \"$RELEASE release\"");

# Build the css
if ($OLDVERSION >= 2015091700) {
    echo "Building css...\n";
    passthru("make css >> ../make.log 2>&1");
    if (!file_exists('htdocs/theme/raw/style/style.css')) {
        echo "CSS files did not build correctly! Check $BUILDDIR/make.log for details.";
        exit(1);
    }
}

# Build the ssphp
if ($OLDVERSION >= 2016090206) {
    echo "Building ssphp...\n";
    passthru("make ssphp >> ../make.log 2>&1");
    if (!file_exists('htdocs/auth/saml/extlib/simplesamlphp/config/config.php')) {
        echo "SimpleSAMLphp files did not build correctly! Check $BUILDDIR/make.log for details.";
        exit(1);
    }
}

# Package up the release
$PACKAGEDIR = 'mahara-' . $VERSION;
echo "Package directory: $BUILDDIR/$PACKAGEDIR\n";
passthru("cp -r $BUILDDIR/mahara $BUILDDIR/$PACKAGEDIR");
chdir("$BUILDDIR/$PACKAGEDIR");

# Delete everything that shouldn't be included
if (getcwd() != "$BUILDDIR/$PACKAGEDIR" || $PACKAGEDIR == '') {
    echo "Couldn't cd into the right directory";
    exit(1);
}
passthru('find . -type d -name ".git" -execdir rm -Rf {} \; 2> /dev/null');
passthru('find . -type f -name ".gitignore" -execdir rm -Rf {} \; 2> /dev/null');
passthru('find . -type d -name "node_modules" -execdir rm -Rf {} \; 2> /dev/null');
passthru('find . -type f -name "gulpfile.js" -execdir rm -Rf {} \; 2> /dev/null');
passthru('find htdocs/theme -type d -name "sass" -execdir rm -Rf {} \; 2> /dev/null');
passthru("rm -Rf test");
passthru("rm -Rf .gitattributes");
passthru("rm -Rf Makefile");
passthru("rm -Rf phpunit.xml");
passthru("rm -Rf external");
passthru("rm -Rf package.json");
passthru("rm -Rf ChangeLog.back");

# Get the location for all phpunit directories
$phpunitdirs = explode("\n", `find . -type d -name 'phpunit' -path '*/tests/phpunit' 2> /dev/null`);
foreach ($phpunitdirs as $dir) {
    $parentdir = dirname($dir);
    # Determine whether the parent directory contains anything other than
    # phpunit. If not, remove the whole parent directory.
    $siblings = explode("\n", `find "$parentdir" -maxdepth 1 -mindepth 1 2> /dev/null`);
    if (count($siblings) == 1) {
        passthru("rm -Rf $parentdir");
    }
    else {
        passthru("rm -Rf $dir");
    }
}

# Create tarballs
chdir($BUILDDIR);
echo "Creating mahara-${RELEASE}.tar.gz\n";
passthru("tar c $PACKAGEDIR | gzip -9 > ${CURRENTDIR}/mahara-${RELEASE}.tar.gz");
echo "Creating mahara-${RELEASE}.tar.bz2\n";
passthru("tar c $PACKAGEDIR | bzip2 -9 > ${CURRENTDIR}/mahara-${RELEASE}.tar.bz2");
echo "Creating mahara-${RELEASE}.zip\n";
passthru("zip -rq ${CURRENTDIR}/mahara-${RELEASE}.zip $PACKAGEDIR");


# Save git changelog
chdir("$BUILDDIR/mahara");
if ($LASTTAG) {
    echo "Getting changelog from previous tag ${LASTTAG}\n";
    passthru("git log --pretty=format:\"%s\" --no-color --no-merges ${LASTTAG}..${RELEASETAG} > ${CURRENTDIR}/${RELEASETAG}.cl");
    $OLDRELEASE = substr($LASTTAG, 0, -1 * strlen('_RELEASE'));
}
else {
    passthru("git log --pretty=format:\"%s\" --no-color --no-merges ${RELEASETAG} > ${CURRENTDIR}/${RELEASETAG}.cl");
    $OLDRELEASE = '';
}

# Prepare release notes
// TODO: Replace this with a simple find/replace, to remove the m4 dependency
$TMP_M4_FILE = '/tmp/mahara-releasenotes.m4.tmp';
passthru("sed 's/^/ * /g' ${CURRENTDIR}/changes.temp >> ${CURRENTDIR}/changes.withasterisks.temp");
$m4script = <<<STRING
changecom
define(`__RELEASE__',`${RELEASE}')dnl
define(`__OLDRELEASE__',`${OLDRELEASE}')dnl
define(`__MAJOR__',`${MAJOR}')dnl
define(`__CHANGES__',`include(`${CURRENTDIR}/changes.withasterisks.temp')')dnl

STRING;
file_put_contents($TMP_M4_FILE, $m4script);

if ($releasecandidate) {
    $TEMPLATE = 'releasenotes.rc.template';
}
else {
    $TEMPLATE = 'releasenotes.stable.template';
}
passthru("m4 ${TMP_M4_FILE} ${SCRIPTDIR}/${TEMPLATE} > ${CURRENTDIR}/releasenotes-${RELEASE}.txt");

# Second version bump for post-release
$NEWVERSION = $NEWVERSION + 1;
$NEWRELEASE = $MAJOR . ($releasecandidate ? 'rc' : '.') . ($MINOR + 1) . "testing";

passthru("sed \"s/\$config->version = [0-9]\{10\};/\$config->version = $NEWVERSION;/\" ${VERSIONFILE} > ${VERSIONFILE}.temp");
passthru("sed \"s/\$config->release = .*/\$config->release = '$NEWRELEASE';/\" ${VERSIONFILE}.temp > ${VERSIONFILE}");

passthru("git add ${VERSIONFILE}");
passthru("git commit -s -m \"Version bump for $NEWRELEASE\"");

# Add gerrit repo, for pushing the new security patches, version bump & changelog commits
$GERRIT = "ssh://reviews.mahara.org:29418/mahara";
passthru("git remote add gerrit ${GERRIT}");

# Output commands to push to the remote repository and clean up
$CLEANUPSCRIPT = "$CURRENTDIR/release-${RELEASE}-cleanup.sh";
$cleanup  = <<<CLEANUP
#!/bin/sh

set -e

cd ${BUILDDIR}/mahara
git push gerrit ${BRANCH}:refs/heads/${BRANCH}
git push gerrit ${RELEASETAG}:refs/tags/${RELEASETAG}

gpg --armor --sign --detach-sig ${CURRENTDIR}/mahara-${RELEASE}.tar.gz
gpg --armor --sign --detach-sig ${CURRENTDIR}/mahara-${RELEASE}.tar.bz2
gpg --armor --sign --detach-sig ${CURRENTDIR}/mahara-${RELEASE}.zip

cd ${CURRENTDIR}
${CURRENTDIR}/lptools/lp-project-upload mahara ${RELEASE} mahara-${RELEASE}.tar.gz changes.withasterisks.temp releasenotes-${RELEASE}.txt
${CURRENTDIR}/lptools/lp-project-upload mahara ${RELEASE} mahara-${RELEASE}.tar.bz2 changes.withasterisks.temp releasenotes-${RELEASE}.txt
${CURRENTDIR}/lptools/lp-project-upload mahara ${RELEASE} mahara-${RELEASE}.zip changes.withasterisks.temp releasenotes-${RELEASE}.txt

echo
echo "All done. Once you've checked that the files were uploaded successfully, run this:"
echo "  rm -rf ${BUILDDIR}"
CLEANUP;

file_put_contents($CLEANUPSCRIPT, $cleanup);
chmod($CLEANUPSCRIPT, 0700);

# Clean up
// Let people clean these up manually. They might be useful for debugging.
// passthru("rm ${VERSIONFILE}.temp");
// passthru("rm ${CURRENTDIR}/ChangeLog.temp");
// passthru("rm ${CURRENTDIR}/changes.temp");
// passthru("rm ${TMP_M4_FILE}");

echo "\n\nTarballs, release notes & changelog for Launchpad:\n\n";
chdir($CURRENTDIR);
passthru("ls -l mahara-${RELEASE}.tar.gz mahara-${RELEASE}.tar.bz2 mahara-${RELEASE}.zip releasenotes-${RELEASE}.txt ${RELEASETAG}.cl");

echo "\n1. Check that everything is in order in the ${BUILDDIR}/mahara repository.\n";
echo "\n2. Create the release on launchpad at https://launchpad.net/mahara/+milestone/${RELEASE}\n";
echo "\n3. Run the commands in ${CLEANUPSCRIPT} to push the changes back to the remote repository and upload the tarballs.\n";
