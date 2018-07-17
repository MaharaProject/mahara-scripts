<?php

/**
 * Using php to do the json_decode / checking of patch status
 * as it is easier than trying to get bash to do it
 */

$jenkins_run_number = $argv[2];
$jenkins_field = $argv[3];
$ch = curl_init();
if ($jenkins_field == 'num') {
    $url = 'https://test.mahara.org/job/mahara-gerrit-multi/' . $jenkins_run_number . '/api/json?pretty=true';
}
if ($jenkins_field == 'features') {
    $url = 'https://test.mahara.org/job/mahara-gerrit-multi/' . $jenkins_run_number . '/console';
}
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
$content = curl_exec($ch);
curl_close($ch);
// We need to fetch the json line from the result
if ($jenkins_field == 'num') {
    $content = json_decode($content);
}

// Now get some info
if (!empty($content)) {
    // Get run gerrit patch number
    if ($jenkins_field == 'num' && !empty($gerrit = $content->actions[5]->parameters[4]->value)) {
       echo $gerrit;
       exit;
    }
    // Get failed features
    if ($jenkins_field == 'features') {
       $features = array();
       if (preg_match_all("/Scenario.*?mahara-gerrit-multi.*?\/test\/behat\/features\/.*?\/(.*?)\.feature/", $content, $matches)) {
           foreach ($matches[1] as $match) {
               $features[] = $match;
           }
           $feature = implode(',', $features);
           echo $feature;
           exit;
       }
       echo 0;
    }
    echo 0;
}
else {
   echo 0;
}
