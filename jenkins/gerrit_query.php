<?php

/**
 * Using php to do the json_decode / checking of patch status
 * as it is easier than trying to get bash to do it
 */

$git_commit_id = $argv[2];
$first_commit = $argv[3];
$gerrit_branch = $argv[4];
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, 'https://reviews.mahara.org/changes/?q=' . $git_commit_id . '&o=LABELS&o=CURRENT_REVISION&pp=0');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
$content = curl_exec($ch);
curl_close($ch);
// We need to fetch the json line from the result
$content = explode("\n", $content);
$content = json_decode($content[1]);
// Find the array hash that relates to this check
$k = 0;
foreach ($content as $key => $item) {
    if ($item->branch == $gerrit_branch) {
        $k = $key;
    }
}
// Doublecheck to see if this has already been merged
if ($content[$k]->status == 'MERGED') {
    echo 2;
    exit;
}

if ($content[$k]->status == 'ABANDONED') {
    echo 4;
    exit;
}

// Check that the patch we are testing is the latest (current) patchset in series
if ($content[$k]->current_revision != $git_commit_id) {
    echo 3;
    exit;
}

// Now check to see if anyone has rejected this.
// We don't want to reject the patch if auto test has failed as we are re-testing now
// but we do want to reject patch if the parent has failed auto test.
if (!empty($first_commit) && empty($content[$k]->labels->{'Verified'}->rejected) &&
    empty($content[$k]->labels->{'Code-Review'}->rejected)) {
    echo 0;
}
else if (empty($content[$k]->labels->{'Verified'}->rejected) &&
    empty($content[$k]->labels->{'Code-Review'}->rejected) &&
    empty($content[$k]->labels->{'Automated-Tests'}->rejected)) {
    echo 0;
}
else {
    echo 1;
}
?>