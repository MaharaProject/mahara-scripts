<?php

/**
 * Using php to do the json_decode / checking of patch status
 * as it is easier than trying to get bash to do it
 *
 * to call this file via bash do something like:
 *
 *    outcome=`php gerrit_query.php -- $patchnum ref`
 *    if [ "$outcome" != "0" ]; then
 *         git fetch https://reviews.mahara.org/mahara $outcome && git checkout FETCH_HEAD
 *    fi
 *
 * where $patchnum = id of gerrit patch, eg 1234
 * It should return the related ref path
 */

$gerrit_patch_number = $argv[2];
$gerrit_field = $argv[3];
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, 'https://reviews.mahara.org/changes/?q=' . $gerrit_patch_number . '&o=LABELS&o=CURRENT_REVISION&o=CURRENT_COMMIT&pp=0');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
$content = curl_exec($ch);
curl_close($ch);
// We need to fetch the json line from the result
$content = explode("\n", $content);
$content = json_decode($content[1]);

// Now check to see if anyone has rejected this
if (!empty($content[0])) {
    // Doublecheck to see if this has already been merged
    if ($content[0]->status == 'MERGED') {
       echo 0;
       exit;
    }
    if (empty($content[0]->current_revision)) {
        echo 0;
        exit;
    }
    if (!empty($gerrit_field)) {
        $info = '';
        switch ($gerrit_field) {
         case 'ref':
            $info = $content[0]->revisions->{$content[0]->current_revision}->ref;
            break;
         default:
            $info = 0;
        }
        echo $info;
        exit;
    }
    echo 0;
}
else {
   echo 0;
}