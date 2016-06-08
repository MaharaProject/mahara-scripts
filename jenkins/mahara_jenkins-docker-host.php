#!/usr/bin/php
<?php
/**
 * This is the script that Jenkins executes to run the tests.
 * If it exits with a status of "0" (success) then Jenkins counts
 * the test as a success.
 *
 * If it exits with a non-0 status, Jenkins count the test as
 * a failure.
 *
 * (Specifically, in the "mahara-gerrit" project on our Jenkins
 * server, the one and only build step is to update the
 * mahara-scripts project and then execute this command.)
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
// $GERRIT_REFSPEC = getenv('GERRIT_REFSPEC');
// $GERRIT_BRANCH = getenv('GERRIT_BRANCH');
// $GERRIT_CHANGE_ID = getenv('GERRIT_CHANGE_ID');
// $GERRIT_PATCHSET_REVISION = getenv('GERRIT_PATCHSET_REVISION');
// $JOB_NAME = getenv('JOB_NAME');
// $HOME = getenv('HOME');

// /**
//  * Environment variables set by us in the Jenkins project itself.
//  */
// $RESTUSERNAME = getenv('RESTUSERNAME');
// $RESTPASSWORD = getenv('RESTPASSWORD');
// if (!$RESTUSERNAME || !$RESTPASSWORD) {
//     echo "\n";
//     echo "WARNING: Username and password for the REST api are not present, which prevents posting comments in gerrit.\n";
// }

$GERRIT_REFSPEC = 'd093d7e6fe955668457908d5a395b3c036633dd5';
$GERRIT_BRANCH = 'master';
$GERRIT_CHANGE_ID = '';
$GERRIT_PATCHSET_REVISION = '';
$JOB_NAME = '1';
$HOME = '/home/aaronw/Downloads/mahara';

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


// echo "\n";
// echo "########## Check the patch is less than $MAXBEHIND patches behind remote branch HEAD\n";
// echo "\n";
// passthru_or_die("git fetch origin $GERRIT_BRANCH");
// echo "";
// $behindby = shell_exec_or_die("git rev-list HEAD..origin/$GERRIT_BRANCH | wc -l");
// echo "This patch is behind $GERRIT_BRANCH by $behindby commit(s)\n";
// if ($behindby > $MAXBEHIND) {
//     gerrit_comment(
//             "This patch is more than {$MAXBEHIND} commits behind {$GERRIT_BRANCH}.\n\n"
//             ."Please rebase it."
//     );
//     exit(1);
// }

// echo "\n";
// echo "########## Check the patch and its parents are not already rejected\n";
// echo "\n";

// # Fetch the git commit ids that exist between this commit and the origin
// # that exists when the patch was made.
// $headcommithash = shell_exec_or_die("git rev-parse HEAD");
// exec_or_die("git log --pretty=format:'%H' origin/$GERRIT_BRANCH..$headcommithash", $commitancestors);
// if (empty($commitancestors)) {
//     // No ancestors means this commit is the head of the branch, or is an ancestor of the branch.
//     // In which case... well, it's not really either a pass or a failure. But a pass makes more sense.
//     echo "Patch already merged\n";
//     exit(0);
// }
// else {
//     if (count($commitancestors) === 1) {
//         echo "Patch has no unmerged dependencies. That's good. :)\n";
//     }
//     else {
//         echo "Patch has " . (count($commitancestors)-1) . " unmerged ancestor(s).\n";
//     }
// }
// $firstcommit = true;
// $i = 0;

// $trustedusers = array();
// foreach ($commitancestors as $commit) {
//     $commit = trim($commit);

//     $content = gerrit_get('/changes/?q=commit:' . $commit . '+branch:' . $GERRIT_BRANCH . '&o=LABELS&o=CURRENT_REVISION&pp=0');
//     // Because we queried by commit and branch, should return exactly one record.
//     $content = $content[0];

//     // Doublecheck to see if this has already been merged
//     if ($content->status == 'MERGED') {
//         // If this commit has been merged, then there's no reason to check it or any earlier ones.
//         break;
//     }

//     $myurl = 'https://reviews.mahara.org/' . $content->_number;

//     // Check that the patch we are testing is the latest (current) patchset in series
//     if ($content->current_revision != $commit) {
//         if ($firstcommit) {
//             gerrit_comment(
//                     "This patchset has been made obsolete by a later patchset in the same Gerrit change set.\n\n"
//                         ."This requires no further action; the latest for this change patchset will be tested automatically instead."
//             );
//         }
//         else {
//             $comment = "This patchset is descended from a patchset that is not the latest in its Gerrit change set: $myurl\n\n";
//             // This patch is the direct child of the obsolete patch, so just rebase it.
//             if ($i === 1) {
//                 $comment .= "You will need to rebase this patch for the automated tests to pass.";
//             }
//             else {
//                 $comment .= "You will need to rebase the descendents of that change, up to and including this change, for the automated tests to pass.";
//             }
//             gerrit_comment($comment);
//         }
//         exit(1);
//     }

//     if ($content->status == 'ABANDONED') {
//         if ($firstcommit) {
//             gerrit_comment("This patch has been abandoned, so there is no need to test it.");
//         }
//         else {
//             gerrit_comment(
//                     "This patch is descended from an abandoned Gerrit patch: $myurl\n\n"
//                         ."You will need to either: restore its abandoned parent patch (probably a bad idea), "
//                         ."rebase it onto a different parent (if this patch is still useful), or abandon this patch."
//             );
//         }
//         exit(1);
//     }

//     if (!empty($content->labels->{'Verified'}->rejected)) {
//         if ($firstcommit) {
//             gerrit_comment(
//                     "This patch was marked \"Verified:-1\", which means that it has failed manual testing\n\n"
//                         ."Please fix the problems found by the manual testers and submit a revision to this patch."
//             );
//         } else {
//             gerrit_comment(
//                     "This patch is descended from a patch that has failed manual testing: $myurl\n\n"
//                         ."Please fix the problems in the parent patch. Once the parent patch has passed manual testing, "
//                         ."rebase this patch onto the latest version of the parent."
//             );
//         }
//         exit(1);
//     }

//     if (!empty($content->labels->{'Code-Review'}->rejected) || !empty($content->labels->{'Code-Review'}->disliked)) {
//         if ($firstcommit) {
//             gerrit_comment(
//                     "This patch failed manual code review.\n\n"
//                     ."Please fix the problems pointed out by the code reviewers, and submit a new revision of this patch."
//             );
//         } else {
//             gerrit_comment(
//                     "This patch is descended from a patch that has failed code review: $myurl\n\n"
//                         ."Please fix the problems in the parent patch. Once the parent patch has passed code review, "
//                         ."rebase this patch onto the latest version of the parent."
//             );
//         }
//         exit(1);
//     }

//     if (!$firstcommit && !empty($content->labels->{'Automated-Tests'}->rejected)) {
//         gerrit_comment(
//                 "This patch is descended from a patch that has failed automated testing: $myurl\n\n"
//                     ."Please fix the problems in the parent patch. Once the parent patch has passed automated testing, "
//                     ."rebase this patch onto the latest version of the parent."
//         );
//         exit(1);
//     }

//     // To prevent attackers from using our Jenkins to execute arbitrary unsafe code, reject any
//     // code that was uploaded by someone who has not been manually added to the Mahara Reviewers
//     // or Mahara Testers group. Or if the code has a +2 code review, then it's also okay to run.
//     $uploader = $content->revisions->{$commit}->uploader->_account_id;

//     // Cacheing the list of trusted users to reduce the number of queries we have to make.
//     if (!array_key_exists($uploader, $trustedusers)) {
//         // Assume we don't trust them, until we find that they belong to a trusted group.
//         $trustedusers[$uploader] = false;

//         // (note that because we're not authenticating, this will only return their membership
//         // in groups that are set to make their list of members public)
//         $groups = gerrit_get('/accounts/' . $uploader . '/groups/?pp=0');
//         foreach ($groups as $group) {
//             if ($group->owner == 'Mahara Reviewers' || $group->owner == 'Mahara Testers') {
//                 $trustedusers[$uploader] = true;
//             }
//         }
//     }

//     // If they're not a trusted user, then only run their code if it has passed code review.
//     if (!$trustedusers[$uploader]) {
//         if (empty($content->labels->{'Code-Review'}->approved)) {
//             if ($firstcommit) {
//                 $comment = "This patch was uploaded by an unvetted user in Gerrit.\n\n";
//             }
//             else {
//                 $comment = "This patch is descended from a patch that was uploaded by an unvetted user in Gerrit: $myurl\n\n";
//             }
//             $comment .= "For security purposes, it needs to be code reviewed before it is put through automated testing.";
//             gerrit_comment($comment);
//             exit(1);
//         }
//         else {
//             echo "Commit {$commit} was uploaded by an unvetted user in Gerrit, however it has passed code review, so it is assumed safe for automated testing.\n";
//         }
//     }

//     // SUCCESS!
//     if ($firstcommit) {
//         echo "$i. This patch is ready for automated testing, so we will continue\n";
//     }
//     else {
//         echo "$i. Ancestor patch with git commit id $commit looks ok so we will continue\n";
//     }
//     $firstcommit = false;
//     $i++;
// }

// echo "\n";
// echo "########## Verify that the patch contains a Behat test\n";
// echo "\n";
// if (trim(shell_exec("git diff-tree --no-commit-id --name-only -r HEAD | grep -c $BEHATTESTREGEX")) >= 1) {
//     echo "Patch includes a Behat test.\n";
// }
// else {
//     # Check whether the commit message has "behatnotneeded" in it.
//     if (trim(shell_exec("git log -1 | grep -i -c $BEHATNOTNEEDED")) >= 1) {
//         echo "This patch does not include a Behat test!\n... but the patch is marked with \"$BEHATNOTNEEDED\", so we will continue.\n";
//     }
//     else {
//         gerrit_comment(
//                 "This patch does not include a Behat test (an automated test plan).\n\n"
//                     ."Please write a Behat test for it, or, if it cannot be tested in Behat or is covered by existing tests, put \"$BEHATNOTNEEDED\" in its commit message."
//         );
//         exit(1);
//     }
// }

// Create and start docker instance
$imagename = "mahara/jenkins:{$JOB_NAME}";
$containername = "container-{$JOB_NAME}";
passthru_or_die("docker build -t {$imagename} docker");

// Initialize the Mahara site
passthru("docker rm -f $containername");
$containerid = exec_or_die("docker run --name={$containername} -v {$HOME}:/var/lib/codesrc:rw {$imagename} git clone --no-hardlinks --depth 2 file:///var/lib/codesrc /var/www/mahara");
save_docker();

echo "########## Run make minaccept\n";
echo "\n";
echo "\n";
passthru_or_die(
        "docker run --rm -w /var/www/mahara $imagename make minaccept",
        "This patch did not pass the minaccept script.\n\n"
            ."Please run \"make minaccept\" in your local workspace and fix any problems it finds."
);

echo "\n";
echo "########## Build & Minify CSS\n";
echo "\n";
passthru_or_die(
        "docker exec {$containername} make",
        "This patch encountered an error while attempting to build its CSS.\n\n"
            ."This may be an error in Jenkins"
);

echo "\n";
echo "########## Run install\n";
echo "\n";
passthru_or_die(
        "docker cp docker/mahara_config.php {$containername}:/var/www/mahara/htdocs/config.php"
);
passthru_or_die(
        "docker exec"
        . " {$containername}"
        . " sudo -u www-data " . PHP_BINARY . " htdocs/admin/cli/install.php --adminpassword='password' --adminemail=never@example.com"
);
//save_docker();

// # Check if composer is not available
exec("docker exec $containername [ -f external/composer.json ]", $output, $return_var);
if ($return_var !== 0) {
    echo "No composer.json. Exiting.";
    exit(0);
}

echo "\n";
echo "########## Install composer\n";
echo "\n";
passthru_or_die(
        "docker exec"
        . " {$containername}"
        . " /bin/sh -c \""
        . " cd external;"
        . " curl -sS https://getcomposer.org/installer | php; "
        . PHP_BINARY . " composer.phar update;"
        . "\""
);
//save_docker();

echo "\n";
echo "########## Run unit tests\n";
echo "\n";
passthru_or_die(
        "docker exec"
        . " {$containername}"
        . " external/vendor/bin/phpunit htdocs/",
        "This patch caused one or more phpunit tests to fail.\n\n"
        ."Please see the console output on test.mahara.org for details, and fix any failing tests."
);


echo "\n";
echo "########## Run Behat\n";
echo "\n";

passthru_or_die(
        'docker exec'
        . " {$containername}"
        . ' test/behat/mahara_behat.sh runheadless',
        "This patch caused one or more Behat tests to fail.\n\n"
            ."Please see the console output on test.mahara.org for details, and fix any failing tests."
);

passthru('docker rm -f {$containername}');

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
    echo "$command\n";
    passthru($command, $return_var);
    if ($return_var !== 0) {
        if ($diemsg) {
            gerrit_comment($diemsg);
        }
        else {
            gerrit_comment(
                    "This patch failed attempting to run this command:\n{$command}\n\n"
                    ."This is probably an error in Jenkins. Please retrigger this patch when the problem in Jenkins has been resolved."
                    ,false
            );
        }
        log_and_die($command, $return_var);
    }
}

/**
 * Call this function to do exec() but die if the command errored out.
 * @param unknown $command
 */
function exec_or_die($command, &$output = null, &$return_var = null) {
    echo "$command\n";
    $returnstring = exec($command, $output, $return_var);
    if ($return_var !== 0) {
        gerrit_comment(
                "This patch failed attempting to run this command:\n{$command}\n\n"
                ."This is probably an error in Jenkins. Please retrigger this patch when the problem in Jenkins has been resolved."
                , false
        );
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
    echo "$command\n";
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
 * Post this message as a comment in gerrit, and optionally print it to the Jenkins console too.
 * @param string $comment (Shouldn't have a newline on the end)
 * @param boolean $printtoconsole If true, also print this message to the Jenkins console (STDOUT)
 */
function gerrit_comment($comment, $printtoconsole = true) {
    global $GERRIT_CHANGE_ID, $GERRIT_BRANCH, $GERRIT_PATCHSET_REVISION;

    if ($printtoconsole) {
        echo $comment;
        echo "\n";
    }

    $reviewinput = (object) array(
            'message' => $comment . " :)",
            'notify' => 'NONE',
    );
    $changeid = rawurlencode("mahara~{$GERRIT_BRANCH}~{$GERRIT_CHANGE_ID}");
    $revisionid = $GERRIT_PATCHSET_REVISION;
    $url = "/changes/{$changeid}/revisions/{$revisionid}/review?pp=0";
    gerrit_post($url, $reviewinput, true);
}


/**
 * Make an unauthenticated GET request to gerrit's REST service.
 *
 * @param string $relurl The relative URL of the REST service. URL query component should include 'pp=0'
 * @return mixed The json-decoded return value from Gerrit.
 */
function gerrit_get($relurl) {
    $ch = curl_init();
    if ($relurl[0] !== '/') {
        $relurl = '/' . $relurl;
    }
    curl_setopt($ch, CURLOPT_URL, 'https://reviews.mahara.org' . $relurl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    $content = curl_exec($ch);
    curl_close($ch);
    // We need to fetch the json line from the result
    $content = explode("\n", $content);
    return json_decode($content[1]);
}

/**
 * Make a POST request to gerrit's REST service.
 *
 * @param string $relurl Relative URL of the REST service. URL query component should include 'pp=0'
 * @param unknown $postobj A PHP object to include in the POST body (will be json-encoded by this function)
 * @param string boolean Whether or not to use authentication
 * @return mixed The json-decoded return value from Gerrit.
 */
function gerrit_post($relurl, $postobj, $authenticated = false) {
    global $RESTUSERNAME, $RESTPASSWORD;

    $ch = curl_init();
    if ($relurl[0] !== '/') {
        $relurl = '/' . $relurl;
    }
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    $postbody = urldecode(json_encode($postobj));
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $postbody);
    curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: application/json; charset=UTF-8'));

    if ($authenticated) {
        // Can't make an authenticated request if the usernme and password aren't provided.
        if (!$RESTUSERNAME || !$RESTPASSWORD) {
            // No need to log this because we already posted a warning about it at the top
            // of the page.
            return array();
        }
        $relurl = '/a' . $relurl;
        curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_DIGEST);
        curl_setopt($ch, CURLOPT_USERPWD, "$RESTUSERNAME:$RESTPASSWORD");
    }

    curl_setopt($ch, CURLOPT_URL, 'https://reviews.mahara.org' . $relurl);
    $content = curl_exec($ch);

    $responsecode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($responsecode !== 200) {
        echo "WARNING: Error attempting to access Gerrit REST api.\n";
        echo "URL: $relurl\n";
        echo "Response:\n";
        echo $content;
        echo "\n";
        return array();
    }

    // We need to fetch the json line from the result
    $content = explode("\n", $content);
    return json_decode($content[1]);
}

function save_docker() {
    global $containername, $imagename;
    passthru_or_die("docker commit --change='WORKDIR /var/www/mahara' --change='CMD /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf' $containername $imagename");
    passthru("docker rm -f $containername");
    passthru_or_die("docker run -d --name={$containername} {$imagename}");
    while(true) {
      exec("docker exec {$containername} sudo -u postgres psql -l", $output, $exitcode);
      if ($exitcode === 0) {
          break;
      }
      echo "waiting for postgres...\n";
      sleep(1);
    }
}