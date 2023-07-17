#!/usr/bin/php
<?php
/**
 * This is the script that Jenkins executes to run the tests.
 * If it exits with a status of "0" (success) then Jenkins counts
 * the test as a success.
 *
 * If it exits with a non-0 status, Jenkins count the test as
 * a failure.
 */

/**
 * Environment variables passed to us by Jenkins.
 * This is not an exhaustive list, just the ones we're currently using.
 * For a list of variables provided by Jenkins see:
 *    http://test.mahara.org/env-vars.html/
 *  For a list of variables provided by the Gerrit Trigger plugin see
 *     http://test.mahara.org/plugin/gerrit-trigger/help-whatIsGerritTrigger.html
 *  For a list of variables provided by the Git plugin see
 *     https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin#GitPlugin-Environmentvariables
 */
$GITLAB_BRANCH = getenv('GITLAB_BRANCH');
$JOB_NAME = getenv('JOB_NAME');
$MULTI_JOB_NAME = getenv('MULTI_JOB_NAME');
$BUILD_URL = getenv('BUILD_URL');
$HOME = getenv('HOME');

$PHP_PORT = getenv('PHP_PORT');
$SELENIUM_PORT = getenv('SELENIUM_PORT');

if (!$PHP_PORT) {
    $PHP_PORT = 8000;
}

if (!$SELENIUM_PORT) {
    $SELENIUM_PORT = 4444;
}

/**
 * Environment variables set by us in the Jenkins project itself.
 */
$RESTUSERNAME = getenv('RESTUSERNAME');
$RESTPASSWORD = getenv('RESTPASSWORD');

/**
 * Configuration variables
 */
// If a commit is more than $MAXBEHIND commits behind the current tip of the branch, we require
// it to be rebased before running the tests.
$MAXBEHIND = 30;
// The string to look for in commit messages to indicate that it's okay the commit contains no
// new Behat tests.
$BEHATNOTNEEDED = "behatnotneeded";
// The regex we use to check for whether a commit includes new Behat tests (any changes to files)
// that match this regex)
$BEHATTESTREGEX = "^test/behat/features/";
// If a user belongs to one of these groups in Gerrit, it means that a member of the Mahara community
// has manually checked them out and added them to the group, so we can trust they're probably not
// an attacker.

// If a user's primary email address is one of these, we can trust they're probably not an attacker.
// (Gerrit verifies user email addresses to make sure the account's user also controls the email
// address.)
$TRUSTED_EMAIL_DOMAINS = array(
    'catalyst.net.nz',
    'catalyst-au.net',
    'catalyst-eu.net'
);

# TIGER -- put this back when this mahara_behat.sh is in git.
# this avoids our custom mahara_behat.sh being overwritten by the one in git
# after the reset
if (false) {
    echo "DOING GIT CLEAN AND RESET\n";
    passthru_or_die("git clean -df");
    passthru_or_die("git reset --hard");
}

echo "########## Checking PHP version\n";
echo PHP_BINARY;
echo "\n";

# Check if composer is not available
if (!file_exists("external/composer.json")) {
    exit(0);
}
echo "\n";
echo "########## Install composer dependencies\n";
echo "\n";
# Install composer in the external directory.
echo "Removing  htdocs/vendor and external/vendor to keep things fresh...\n";
passthru_or_die("rm -Rf htdocs/vendor");
passthru_or_die("rm -Rf external/vendor");
chdir('external');
passthru_or_die("curl -sS https://getcomposer.org/installer | php");
# Run composer install in the external directory.
echo "Running compser update on /external";
passthru_or_die(PHP_BINARY . ' composer.phar update');
chdir('..');
# If we have a composer.lock file, then we need to run composer install in the Mahara directory.
if (file_exists("composer.lock")) {
    echo "Running install on docroot";
    passthru_or_die(PHP_BINARY . ' external/composer.phar install');
}

echo "\n";
echo "########## Run make minaccept\n";
echo "\n";
passthru_or_die(
    "make minaccept",
    "This patch did not pass the minaccept script.\n\n"
        . "Please run \"make minaccept\" in your local workspace and fix any problems it finds."
);

echo "\n";
echo "########## Run installer\n";
echo "\n";
passthru("dropdb $MULTI_JOB_NAME");
passthru_or_die("rm -Rf $HOME/mahara/sitedata/$MULTI_JOB_NAME/*");
passthru_or_die("rm -Rf $HOME/mahara/sitedata/behat_$MULTI_JOB_NAME/*");
passthru_or_die("createdb -O jenkins -E utf8 $MULTI_JOB_NAME");
chdir('htdocs');
passthru_or_die("cp $HOME/mahara/mahara-scripts/jenkins/mahara_config.php config.php");
passthru_or_die("PHP_PORT=${PHP_PORT} " . PHP_BINARY . " admin/cli/install.php --adminpassword='password' --adminemail=never@example.com");
chdir('..');

echo "\n";
echo "########## Build & Minify CSS\n";
echo "\n";
echo "Cleaning up node_modules \n";
passthru('make clean-css');
passthru('echo npm libraries && node -v && npm list fibers');
passthru_or_die(
    'make',
    "This patch encountered an error while attempting to build its CSS.\n\n"
        . "This may be an error in Jenkins"
);
passthru("echo node version && node -v");

echo "\n";
echo "########## Run phpunit tests\n";
echo "\n";
passthru_or_die(
    'external/vendor/bin/phpunit htdocs/lib/',
    "This patch caused one or more phpunit tests to fail.\n\n"
        . $BUILD_URL . "console\n\n"
        . "Please see the console output on test.mahara.org for details, and fix any failing tests."
);


echo "\n";
echo "########## Run Behat tests\n";
echo "\n";
# make sure we have totally clean behat
passthru_or_die("rm -Rf $HOME/mahara/sitedata/behat_$MULTI_JOB_NAME/behat/*");
exec_or_die("psql $MULTI_JOB_NAME -c \"SET client_min_messages TO WARNING;DO \\\$do\\\$ DECLARE _tbl text; BEGIN FOR _tbl  IN SELECT quote_ident(table_schema) || '.' || quote_ident(table_name) FROM   information_schema.tables WHERE  table_name LIKE 'behat_' || '%' AND table_schema NOT LIKE 'pg_%' LOOP EXECUTE 'DROP TABLE ' || _tbl || ' CASCADE'; END LOOP; END \\\$do\\\$;\"", $cleanbehat);

// Walk over the directories in test/behat/features
$behatfeaturesdir = 'test/behat/features';
$skipdirs = ['.', '..', 'manual_checks', 'elasticsearch7'];
$behatdirs = array_diff(scandir($behatfeaturesdir), $skipdirs);
foreach ($behatdirs as $behatdir) {
    // Skip the $behatdir if it's not a directory.
    if (!is_dir($behatfeaturesdir . '/' . $behatdir)) {
        continue;
    }
    echo "Running behat for the $behatdir directory\n";
    // Run the behat features in the $behatdir.
    passthru_or_die(
        "MULTI_JOB_NAME=${MULTI_JOB_NAME} PHP_PORT=${PHP_PORT} SELENIUM_PORT=${SELENIUM_PORT} test/behat/mahara_behat.sh runheadless $behatdir",
        "This patch caused one or more Behat tests to fail in the features/ " . $behatdir . ".\n\n"
            . $BUILD_URL . "console\n\n"
            . "Please see the console output on test.mahara.org for details, and fix any failing tests."
    );
}
exit(0);

///////////////////////////////////// FUNCTIONS ///////////////////////////////////////
/**
 * Call this function to do passthru(), but die if the command that was being
 * invoked exited with a non-success return value.
 *
 * @param string $command The command to run
 * @param string $diemsg If we die, then print this message explaining why we died.
 */
function passthru_or_die($command, $diemsg = null) {
    passthru($command, $return_var);
    if ($return_var !== 0) {
        log_and_die($command, $return_var);
    }
}

/**
 * Call this function to do exec() but die if the command errored out.
 * @param unknown $command
 */
function exec_or_die($command, &$output = null, &$return_var = null) {
    $returnstring = exec($command, $output, $return_var);
    if ($return_var !== 0) {
        log_and_die($command, $return_var);
    }

    return $returnstring;
}


/**
 * This function emulates shellexec(), but dies if the command that was being
 * invoked exited with a non-success exit value.
 *
 * Because it calls exec() on the backend, it also has the side effect of
 * trimming whitespace from the return value (unlike shellexec(), which normally
 * includes the ending "\n" on the output)
 *
 * @param unknown $command
 */
function shell_exec_or_die($command) {
    // shellexec() doesn't normally give you access to the command's exit code,
    // so we instead will call exec()
    exec_or_die($command, $output);

    return implode("\n", $output);
}


/**
 * Call this method to die after a bad command. It prints an error message
 * about the command that failed, and then exits with status code 1.
 * @param string $commandtolog The command to log a message about
 * @param integer $itsreturnvar The return value of that command
 */
function log_and_die($commandtolog, $itsreturnvar) {
    echo "\nEXITING WITH FAILURE\n";
    echo "ERROR: Return value of '$itsreturnvar' on this command:\n";
    echo "$commandtolog\n";
    echo "\n";
    debug_print_backtrace();
    echo "\n";
    exit(1);
}


/**
 * Check that the branch of the patch we are testing is above a certain version
 * This is useful if the branch doesn't have certain Makefile commands
 *
 * @param string $branch
 * @param string $major
 * @param string $minor
 * @return bool
 */
function branch_above($branch, $major, $minor) {
    // If the branch is main it should have all we need
    if ($branch == 'main') {
        return true;
    }
    $branch = explode('_', $branch);
    // Get the major.minor version
    $branchversion = explode('.', $branch[0]);
    // print("dumping branchversion\n");
    // var_dump($branchversion);
    // print("\n\n");

    if (((int) $major >= (int) $branchversion[0]) && ((int) $minor > (int) $branchversion[1])) {
        return true;
    }
    return false;
}
