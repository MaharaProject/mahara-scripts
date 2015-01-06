<?php

$JOBNAME = basename(dirname(dirname(__DIR__)));

$cfg = new stdClass();

$branch = 'master';

// database connection details
$cfg->dbtype   = 'postgres';
$cfg->dbhost   = 'localhost';
$cfg->dbuser   = 'jenkins';
$cfg->dbname   = $JOBNAME;
$cfg->dbpass   = 'huds13!';

$cfg->dataroot = "/var/lib/jenkins/sitedata/{$JOBNAME}";

$cfg->sendemail = true;
$cfg->sendallemailto = 'never@example.com';

$cfg->productionmode = false;
$cfg->perftofoot = true;

// Behat config
$cfg->dbprefix = ''; // Behat complains without this
$cfg->wwwroot = "http://127.0.0.1/{$JOBNAME}";
$cfg->behat_dbprefix = 'behat_'; // must not empty
$cfg->behat_dataroot = "/var/lib/jenkins/sitedata/behat_{$JOBNAME}";
$cfg->behat_wwwroot = "http://{$JOBNAME}.localhost:8000";

unset($JOBNAME);
