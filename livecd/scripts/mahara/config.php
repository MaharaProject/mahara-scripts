<?php
$cfg = new StdClass;

$branch = 'master';

// database connection details
// valid values for dbtype are 'postgres8' and 'mysql5'
$cfg->dbtype   = 'postgres';
$cfg->dbhost   = 'localhost';
$cfg->dbport = 5434;
$cfg->dbuser   = 'maharauser';
$cfg->dbname   = "mahara-$branch";
$cfg->dbpass   = 'mahara';
$cfg->dbprefix = '';

$cfg->wwwroot = 'http://localhost/';
$cfg->dataroot = "/var/lib/maharadata/$branch";

$cfg->showloginsideblock = true;

$cfg->sendemail = false;
// $cfg->sendallemailto = 'youremailhere';

$cfg->productionmode = true;

// The following values are to put errors on the screen

$cfg->log_dbg_targets     = LOG_TARGET_SCREEN | LOG_TARGET_ERRORLOG;
$cfg->log_info_targets    = LOG_TARGET_SCREEN | LOG_TARGET_ERRORLOG;
$cfg->log_warn_targets    = LOG_TARGET_SCREEN | LOG_TARGET_ERRORLOG;
$cfg->log_environ_targets = LOG_TARGET_SCREEN | LOG_TARGET_ERRORLOG;

$cfg->urlsecret = null;

$cfg->renamecopies = false;

$cfg->perftofoot = false;
$cfg->passwordsaltmain = '12345678901234567890';
$cfg->cleanurls = false;
$cfg->sitethemeprefs = true;
$cfg->skins = true;
$cfg->probationenabled = true;
$cfg->probationstartingpoints = 2;
