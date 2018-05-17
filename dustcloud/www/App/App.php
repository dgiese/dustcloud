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
    public static function config ($key) {
        return self::getInstance()->config[$key];
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
            $conf = App::config("mysql");
            self::getInstance()->db = new Db($conf["host"], $conf["username"], $conf["password"], $conf["database"]);
        }
        return self::getInstance()->db->getInstance();
    }
    
    public static function renderTemplate ($file, $data = [], $stopExecution = true) {
        $loader = new Twig_Loader_Filesystem(APP_ROOT . DIRECTORY_SEPARATOR . App::config("twig.templates"));
        $twig = new Twig_Environment($loader, array(
            'cache' => APP_ROOT . DIRECTORY_SEPARATOR . App::config("twig.cache"),
        ));

        echo $twig->render($file, $data);
        
        if ($stopExecution) {
            exit;
        }
    }
}
