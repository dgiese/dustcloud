<?php

ini_set('display_errors', 1);
error_reporting(E_ALL & ~E_NOTICE);

define('APP_ROOT', __DIR__ . DIRECTORY_SEPARATOR);

return [
    "mysql" => [
        'host' => 'localhost',
        'database' => 'dustcloud',
        'username' => 'user123',
        'password' => '',
    ],
    'cmd.server' => 'http://localhost:1121/'
    'debug' => true,
];
