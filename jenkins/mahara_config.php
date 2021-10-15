<?php

$JOBNAME = getenv('MULTI_JOB_NAME');

$cfg = new stdClass();

$branch = 'main';

// database connection details
$cfg->dbtype   = 'postgres';
$cfg->dbhost   = 'localhost';
$cfg->dbuser   = 'jenkins';
$cfg->dbname   = $JOBNAME;
$cfg->dbpass   = 'Sei2ZaRi';

$cfg->dataroot = "/var/lib/jenkins/mahara/sitedata/{$JOBNAME}";

$cfg->sendemail = false;
$cfg->sendallemailto = 'never@example.com';

$cfg->productionmode = false;
$cfg->perftofoot = true;

// Behat config
$cfg->dbprefix = 'a234567890123456789'; // Check for dbprefix problems
$cfg->wwwroot = "http://127.0.0.1";
$cfg->behat_dbprefix = 'behat_'; // must not empty
$cfg->behat_dataroot = "/var/lib/jenkins/mahara/sitedata/behat_{$JOBNAME}";

$PHP_PORT = getenv("PHP_PORT");
$cfg->behat_wwwroot = "http://localhost:${PHP_PORT}";

$SELENIUM_PORT = getenv("SELENIUM_PORT");
$cfg->behat_selenium2 = "http://127.0.0.1:${SELENIUM_PORT}/wd/hub";
