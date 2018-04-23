<?php

error_reporting(E_ALL);
ini_set('display_errors', 1);

require __DIR__ . '/vendor/autoload.php';

$config = require dirname(__FILE__) . '/conf.php';

App\App::setConfig($config);
unset($config);
