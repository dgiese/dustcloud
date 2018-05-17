<?php
    require __DIR__ . '/bootstrap.php';
    use App\App;
    use App\Utils;

    if (!isset($_GET['cmd']) OR !isset($_GET['did']))
    {
	die('parameter error');
    }
    else
    {
        $db = App::db();

        if (false === filter_var($_GET['did'], FILTER_VALIDATE_INT))
        {
            die('You must enter a valid integer for did!');
        }
        $did = $_GET['did'];

        if($_GET['cmd'] == "last_contact")
        {
            $res = $db->query("SELECT * FROM devices WHERE did = '".$db->real_escape_string($did)."'");
            $res->data_seek(0);
            $row = $res->fetch_assoc();
            Utils::printLastContact($row['last_contact']);
        }
    }
?>
