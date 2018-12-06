<?php

namespace App;

class App {
    private $config = [];
    private $db = null;

    private static $instance = null;

    private static function getInstance () {
        if (empty(self::$instance)) {
            self::$instance = new App();
        }
        return self::$instance;
    }

    /**
     * Recovers a config entry
     * @param string $key
     * @return mixed
     */
    public static function config ($key, $default = null, $section = 'web') {
        $config = self::getInstance()->config;
        if(!array_key_exists($section, $config)){
            return $default;
        }
        if(!array_key_exists($key, $config[$section])){
            return $default;
        }
        return $config[$section][$key];
    }

    /**
     * Sets app's config
     * @param array $config
     */
    public static function setConfig (array $config) {
        self::getInstance()->config = $config;
    }

    public static function db () {
        if (self::getInstance()->db === null) {
            self::getInstance()->db = new Db(App::config('host', null, 'mysql'), App::config('username', null, 'mysql'), App::config('password', null, 'mysql'), App::config('database', null, 'mysql'));
        }
        return self::getInstance()->db->getInstance();
    }
    
    public static function renderTemplate ($file, $data = []) {
        $loader = new \Twig_Loader_Filesystem(APP_ROOT . App::config('twig.templates', 'templates'));
        $twig = new \Twig_Environment($loader, array(
            'debug' => App::config('debug', true),
            'cache' => APP_ROOT . App::config('twig.cache', 'cache'),
        ));

        return $twig->render($file, $data);
    }
}
