<?php

require __DIR__ . '/vendor/autoload.php';

define('APP_ROOT', __DIR__ . DIRECTORY_SEPARATOR);

$configfile = __DIR__ . '/../config.ini';
if(!file_exists($configfile) || !is_readable($configfile)){
    die('could not open config.ini');
}

$config = parse_ini_file($configfile, true);

if(!array_key_exists('web', $config) || !array_key_exists('mysql', $config)){
    die('config.ini is invalid.');
}

if(array_key_exists('debug', $config['web']) && $config['web']['debug']){
    error_reporting(E_ALL);
    ini_set('display_errors', 1);   
}

App\App::setConfig($config);
unset($config);
unset($configfile);