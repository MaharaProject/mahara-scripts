<?php

// Ensure a file exists on disk for everything in a mahara db.
// Requires a flv file called junk.flv

define('INTERNAL', 1);
define('PUBLIC', 1);
define('MENUITEM', '');
define('HOME', 1);
require('init.php');

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

$files = array();

$records = get_records_sql_array('
    SELECT f.*, a.artefacttype
    FROM {artefact_file_files} f JOIN {artefact} a ON f.artefact = a.id',
    null
);

db_begin();

foreach ($records as $r) {
    $filetype = isset($samples[$r->filetype]) ? $r->filetype : 'application/octet-stream';

    if ($r->artefacttype == 'profileicon') {
        $dir = get_config('dataroot') . 'artefact/file/profileicons/originals/' . ($r->artefact % 256);
        check_dir_exists($dir);
        file_put_contents($dir . '/' . $r->artefact, $samples[$filetype]);
        execute_sql(
            "UPDATE {artefact_file_files} SET size = ?, fileid = ?, filetype = ? WHERE artefact = ?",
            array(filesize($dir . '/' . $r->artefact), $r->artefact, $filetype, $r->artefact)
        );
        continue;
    }

    if (isset($files[$filetype])) {
        execute_sql(
            "UPDATE {artefact_file_files} SET size = ?, fileid = ?, filetype = ? WHERE artefact = ?",
            array($files[$filetype]->size, $files[$filetype]->fileid, $filetype, $r->artefact)
        );
    }
    else {
        $dir = get_config('dataroot') . 'artefact/file/originals/' . ($r->fileid % 256);
        check_dir_exists($dir);
        file_put_contents($dir . '/' . $r->fileid, $samples[$filetype]);
        $r->filetype = $filetype;
        $r->size = filesize($dir . '/' . $r->fileid);
        execute_sql(
            "UPDATE {artefact_file_files} SET size = ?, filetype = ? WHERE artefact = ?",
            array($r->size, $filetype, $r->artefact)
        );
        $files[$filetype] = $r;
    }
}

db_commit();

set_config('samplefiles', 1);
