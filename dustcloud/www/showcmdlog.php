<?php
# Author: Dennis Giese [dustcloud@1338-1.org]
# Copyright 2017 by Dennis Giese

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

$url1=$_SERVER['REQUEST_URI'];
header("Refresh: 30; URL=$url1"); ### Be carefull, may contain some security risk

// Style sheets
require __DIR__ . '/bootstrap.php';

use App\App;
use App\Utils;

if (!isset($_GET['did']))
{
    die("no did set");
}
else
{
    if (filter_var($_GET['did'], FILTER_VALIDATE_INT) === false)
    {
        die('You must enter a valid integer for did!');
    }
    $did = $_GET['did'];
}

$mysqli = App::db();

echo "<a href=\"index.php\">Index</a><br>";
$res = $mysqli->query("SELECT * FROM devices WHERE did = '".$did."'");

$res->data_seek(0);
while ($row = $res->fetch_assoc())
{
    echo "<a href=\"./show.php?did=" . $row['did'] . "\">" . $row['name'] . "(did:" . $row['did'] . ")</a><br>";

    Utils::printLastContact($row['last_contact']);
}
echo "<hr>";
$res = $mysqli->query("SELECT * FROM cmdqueue WHERE did = '".$did."' ORDER BY CMDID DESC LIMIT 100");
$res->data_seek(0);
while ($row = $res->fetch_assoc())
{
    foreach ($row as $key => $value)
    {
        echo "$key : $value ";
        echo "<br>";
    }
    echo "<hr>";
}

echo "<hr>";
