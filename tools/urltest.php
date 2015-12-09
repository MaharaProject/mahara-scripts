<?php
/**
 * This is a (very minimal) command-line script to help search the Mahara
 * code base for broken URLs.
 */

/**
 * Part 1: Run this to locate files with URLs in them. Pipe those to a CSV file.
 */

// $dir = '../test';
// exec('find ' . $dir . ' -type f -exec grep -PHIon \'https?://([a-z]+\.)?mahara.org([^\s"]+)\' {} \;', $results);

// foreach ($results as $match) {
//     list($file, $line, $url) = explode(':', $match, 3);
//     echo csvescape($file) . ',' . csvescape($line) . ',' . csvescape($url) . "\n";
// }

// function csvescape($string) {
//     return '"' . str_replace('"', '""', $string) . '"';
// }

/**
 * Part 2: Manually check the URLs in the CSV file and clean up any that have
 * formatting on them still (like '; on the end). Finding these automatically
 * would require parsing every type of language in Mahara, so it's easier to
 * just look at them manually. Also look for \' and \" to replace them with
 * ' and "
 */



/**
 * Part 3: Pipe in the cleaned CSV file. The script will now check every
 * URL to make sure it's valid.
 */

$filename = 'urls-cleaned.csv';
$lines = file($filename, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
$urlschecked = array();
foreach ($lines as $line) {
    // This might not work, depending on how fancy the CSV-export in your
    // spreadsheet is.
    list($file, $line, $url) = explode(',', $line);

    if (isset($urlschecked[$url])) {
        $status = $urlschecked[$url];
    }
    else {
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_HEADER, 1);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 1);
        curl_exec($ch);
        $status = curl_getinfo($ch);
        curl_close($ch);
        $status = $status['http_code'];

        $urlschecked[$url] = $status;
    }

    if ($status != 200) {
        echo "$file : $line : $url : STATUS $status\n";
    }
}