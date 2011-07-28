<?php

// Ensure a file exists on disk for everything in a mahara db.
// Requires a flv file called junk.flv

define('INTERNAL', 1);
define('PUBLIC', 1);
define('MENUITEM', '');
define('HOME', 1);
require('init.php');
raise_memory_limit('512M');
set_time_limit(300);

if (get_config('samplefiles')) {
    exit;
}

$samples = array(
    'image/bmp' => base64_decode('Qk06AAAAAAAAADYAAAAoAAAAAQAAAAEAAAABACAAAAAAAAQAAAASCwAAEgsAAAAAAAAAAAAAAAAA
/w=='),
    'image/gif' => base64_decode('R0lGODlhMgAyAPAAAAAAAAAAACH5BAAAAAAALAAAAAAyADIAAAIzhI+py+0Po5y02ouz3rz7D4bi
SJbmiabqyrbuC8fyTNf2jef6zvf+DwwKh8Si8YhMKicFADs='),
    'image/jpeg' => base64_decode('/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAUDBAQEAwUEBAQFBQUGBwwIBwcHBw8LCwkMEQ8SEhEP
ERETFhwXExQaFRERGCEYGh0dHx8fExciJCIeJBweHx7/wAALCAAyADIBAREA/8QAFQABAQAAAAAA
AAAAAAAAAAAAAAj/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AIyAAAAAAAAAAAAAAAAf
/9k='),
    'image/png' => base64_decode('iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAIAAACRXR/mAAAAHklEQVRYhe3BMQEAAADCoPVPbQhf
oAAAAAAAAAD4DR1+AAGgmQaxAAAAAElFTkSuQmCC'),
    'text/html' => 'te<b>xt/h</b>tml',
    'text/plain' => 'text/plain',
    'video/x-flv' => file_get_contents(get_config('docroot') . 'junk.flv'),
    'application/octet-stream' => '??',
);

$profileicons = get_records_sql_array("
    SELECT f.*, a.artefacttype
    FROM {artefact_file_files} f JOIN {artefact} a ON f.artefact = a.id
    WHERE a.artefacttype = 'profileicon'",
    null
);

db_begin();

foreach ($profileicons as $r) {
    $filetype = isset($samples[$r->filetype]) ? $r->filetype : 'application/octet-stream';
    $dir = get_config('dataroot') . 'artefact/file/profileicons/originals/' . ($r->artefact % 256);
    check_dir_exists($dir);
    $file = $dir . '/' . $r->artefact;
    if (!file_exists($file)) {
        file_put_contents($dir . '/' . $r->artefact, $samples[$filetype]);
        execute_sql(
            "UPDATE {artefact_file_files} SET size = ?, fileid = ?, filetype = ? WHERE artefact = ?",
            array(filesize($dir . '/' . $r->artefact), $r->artefact, $filetype, $r->artefact)
        );
    }
}

safe_require('artefact', 'file');

$files = array();
$ids = array();

foreach ($samples as $k => $v) {
    $n = 'a.' . get_random_key();
    $fn = "/tmp/$n";
    file_put_contents($fn, $v);
    $d = (object) array('title' => $n, 'owner' => $USER->get('id'), 'filetype' => $k);
    $id = ArtefactTypeFile::save_file($fn, $d, $USER, true);
    $ids[$id] = $id;
    $files[$k] = artefact_instance_from_id($id);
}

$records = get_records_sql_array("
    SELECT f.*, a.artefacttype
    FROM {artefact_file_files} f JOIN {artefact} a ON f.artefact = a.id
    WHERE a.artefacttype != 'profileicon' AND NOT a.id IN (" . join(',', $ids) . ')',
    null
);

foreach ($samples as $k => $v) {
    execute_sql("
        UPDATE {artefact_file_files} SET size = ?, fileid = ? WHERE filetype = ?",
        array($files[$k]->get('size'), $files[$k]->get('fileid'), $k)
    );
}

db_commit();

set_config('samplefiles', 1);
