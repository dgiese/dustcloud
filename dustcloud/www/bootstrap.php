<?php

require __DIR__ . '/vendor/autoload.php';

define('APP_ROOT', __DIR__ . DIRECTORY_SEPARATOR);
$config = parse_ini_file(__DIR__ . '/../config.ini', true);


if($config['web']['debug']){
    error_reporting(E_ALL);
    ini_set('display_errors', 1);   
}

App\App::setConfig($config);
unset($config);