<?php
    require_once 'config.php';
    require_once 'fns.php';

    if (!isset($_GET['cmd']) OR !isset($_GET['did']))
    {
	die('parameter error');
    }
    else
    {
        $mysqli = new MySQLi(DB_HOST, DB_USER, DB_PASS, DB_NAME);
        if ($mysqli->connect_errno)
        {
           die('Failed to connect to MySQL: ('.$mysqli->connect_errno.') '.$mysqli->connect_error);
        }

        if (false === filter_var($_GET['did'], FILTER_VALIDATE_INT))
        {
            die('You must enter a valid integer for did!');
        }
        $did = $_GET['did'];

        if($_GET['cmd'] == "last_contact")
        {
            $res = $mysqli->query("SELECT * FROM devices WHERE did = '".$mysqli->real_escape_string($did)."'");
            $res->data_seek(0);
            $row = $res->fetch_assoc();
            printLastContact($row['last_contact']);
        }
    }
?>
