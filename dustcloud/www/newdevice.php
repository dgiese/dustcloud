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

require_once 'config.php';
$mysqli = new MySQLi(DB_HOST, DB_USER, DB_PASS, DB_NAME);
if ($mysqli->connect_errno) {
    echo "Failed to connect to MySQL: (" . $mysqli->connect_errno . ") " . $mysqli->connect_error;
}

$did= isset($_POST['did']) ? $_POST['did'] : '';
$enckey= isset($_POST['enckey']) ? $_POST['enckey'] : '';
$name= isset($_POST['name']) ? $_POST['name'] : '';

if ($did != "")
{
	if (filter_var($did, FILTER_VALIDATE_INT) === false) {
		die('You must enter a valid integer for did!');
	}
	if ($enckey != "")
	{
		if (filter_var($enckey, FILTER_VALIDATE_REGEXP, array('options' => array('regexp' => "/^[a-zA-Z0-9]+$/")))  === false) {
			die('You must enter an alphanum string for enckey!');
		}
		$sql = "INSERT into devices(did,enckey,name) VALUES(".$mysqli->real_escape_string($did).",'".$mysqli->real_escape_string($enckey)."','".$mysqli->real_escape_string($name)."')";
		$res = $mysqli->query($sql);
		if (!$res) {
			echo "<p>There was an error in query: $sql</p>";
			echo $mysqli->error;
		}
	}
}

echo "<a href=\"index.php\">Index</a><br>";

?>
<form action="<?php echo htmlentities($_SERVER['PHP_SELF']); ?>" method="post">
did: <input type="input" name="did" size="10"><br>
enckey: <input type="input" name="enckey" size="16" value=""><br>
name: <input type="input" name="name" size="20" value=""><br>
<input type="submit" name="submit" value="send command">
</form>