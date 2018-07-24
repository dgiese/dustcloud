<?php

require __DIR__ . '/vendor/autoload.php';

$config = require __DIR__ . '/conf.php';

if($config['debug']){
    error_reporting(E_ALL);
    ini_set('display_errors', 1);   
}

App\App::setConfig($config);
unset($config);