<?php

$cfg = new stdClass();

$branch = 'master';

// database connection details
$cfg->dbtype   = 'postgres';
$cfg->dbhost   = 'localhost';
$cfg->dbuser   = 'maharauser';
$cfg->dbname   = 'mahara';
$cfg->dbpass   = 'kupuhipa';

$cfg->dataroot = "/var/lib/dataroot/mahara";

$cfg->sendemail = false;
$cfg->sendallemailto = 'never@example.com';

$cfg->productionmode = false;
$cfg->perftofoot = true;

// Behat config
$cfg->dbprefix = 'a234567890123456789'; // Check for dbprefix problems
$cfg->wwwroot = "http://127.0.0.1";
$cfg->behat_dbprefix = 'behat_'; // must not empty
$cfg->behat_dataroot = "/var/lib/dataroot/mahara/behat";
$cfg->behat_wwwroot = "http://localhost:8000";

