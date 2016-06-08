<?php

echo "\n";
echo "########## Install composer\n";
echo "\n";
chdir('external');
passthru_or_die("curl -sS https://getcomposer.org/installer | php");
passthru_or_die(PHP_BINARY . ' composer.phar update');
chdir('..');

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