<?php

namespace App;

 class DB {
    /**
     * @var \MySQLi
     */
    private $connection = null;

    public function __construct ($host, $user, $password, $dbname) {
        self::$connection = new \MySQLi($host, $user, $password, $dbname);

        if (self::$connection->connect_errno) {
            throw new \Exception("Failed to connect to MySQL: (" . self::$connection->connect_errno . ") " . self::$connection->connect_error);
        }
    }

    public function getInstance () {
        return self::$connection;
    }

    /**
    * param $query string
    */
    public function query ($query) {
        return $this->getInstance()->query($query);
    }

    public function insert ($query) {
        $res = $this->query($query);
        if (!$res) {
            echo "<p>There was an error in query: $query</p>";
            echo $db->error;
            return false;
        }
        return true;
    }

    public function real_escape_string ($str) {
        return $this->getInstance()->real_escape_string($str);
    }
}
