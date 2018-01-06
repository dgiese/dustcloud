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


function hex2str($hex) {
    $str = '';
    for($i=0;$i<strlen($hex);$i+=2) $str .= chr(hexdec(substr($hex,$i,2)));
    return $str;
}

    $url1=$_SERVER['REQUEST_URI'];
	$r = isset($_POST['r']) ? $_POST['r'] : '10';
	if ($r == 3 )
	{
		$refresh = 3;
	}elseif ($r == 120 )
	{
		$refresh = 120;
	}
	else
	{
		$refresh = 10;
	}
    header("Refresh: $refresh; URL=$url1");

if (!isset($_GET['did']))
{
	die("no did set");
}else{
	if (filter_var($_GET['did'], FILTER_VALIDATE_INT) === false) {
		die('You must enter a valid integer for did!');
	}
	$did = $_GET['did'];
}

require_once 'config.php';
$mysqli = new MySQLi(DB_HOST, DB_USER, DB_PASS, DB_NAME);
if ($mysqli->connect_errno) {
    echo "Failed to connect to MySQL: (" . $mysqli->connect_errno . ") " . $mysqli->connect_error;
}

$cmd= isset($_POST['cmd']) ? $_POST['cmd'] : '';
$params = isset($_POST['params']) ? $_POST['params'] : '';
$forward_to_cloud=isset($_POST['forward_to_cloud']) ? $_POST['forward_to_cloud'] : '';
$full_cloud_forward=isset($_POST['full_cloud_forward']) ? $_POST['full_cloud_forward'] : '';
if ($did != "")
{
	if ($cmd != "")
	{
		# add new cmd to cmdquere with 15 seconds expiration
		$sql = "INSERT into cmdqueue(did,method,params,expire) VALUES(".$mysqli->real_escape_string($did).",'".$mysqli->real_escape_string($cmd)."','".$mysqli->real_escape_string($params)."',DATE_ADD(NOW(), INTERVAL 15 SECOND))";
		$res = $mysqli->query($sql);
		if (!$res) {
			echo "<p>There was an error in query: $sql</p>";
			echo $mysqli->error;
		}
	}
	if ($forward_to_cloud == "1" || $forward_to_cloud == "0")
	{
		$sql = "UPDATE devices set forward_to_cloud = '".$mysqli->real_escape_string($forward_to_cloud)."' WHERE did = '".$mysqli->real_escape_string($did)."'";
		$res = $mysqli->query($sql);
		if (!$res) {
		echo "<p>There was an error in query: $sql</p>";
		echo $mysqli->error;
		}
	}
	if ($full_cloud_forward == "1" || $full_cloud_forward == "0")
	{
		$sql = "UPDATE devices set full_cloud_forward = '".$mysqli->real_escape_string($full_cloud_forward)."' WHERE did = '".$mysqli->real_escape_string($did)."'";
		$res = $mysqli->query($sql);
		if (!$res) {
			echo "<p>There was an error in query: $sql</p>";
			echo $mysqli->error;
		}
	}	
}


echo "<a href=\"index.php\">Index</a><br>";
$res = $mysqli->query("SELECT * FROM devices WHERE did = '".$mysqli->real_escape_string($did)."'");

$res->data_seek(0);
while ($row = $res->fetch_assoc()) {
	$model= $row['model'];
    echo "<b>" . $row['name'] . "(did:" . $row['did'] . ")</b>"
		."<a href=\"./showlog.php?did=" . $row['did'] . "\">(recv msg log)</a>"
		."<a href=\"./showcmdlog.php?did=" . $row['did'] . "\"> (sent cmd log)</a>"
		."<br>Last contact: " . $row['last_contact'];
	$date1 = new DateTime("now");
	$date2 = new DateTime($row['last_contact']);
	$interval = $date1->diff($date2);
	echo " (".$interval->format('%a days %H:%I:%S ago').")";
	
	echo "<br>\n";
	foreach ($row as $key => $value)
	{
		if ($value != "")
		{
			echo "$key : $value ";	
			echo "<br>";
		}
	}
}
?>
<form action="<?php echo htmlentities($_SERVER['PHP_SELF'])."?did=".$did; ?>" method="post">
forward_to_cloud: <input type="submit" name="forward_to_cloud" value="1"><input type="submit" name="forward_to_cloud" value="0"><br>
full_cloud_forward: <input type="submit" name="full_cloud_forward" value="1"><input type="submit" name="full_cloud_forward" value="0">
</form>
<?php
echo "<hr>";
$res = $mysqli->query("SELECT * FROM statuslog WHERE did = '".$did."' and direction = 'from_client' ORDER by timestamp DESC");
$res->data_seek(0);
$row = $res->fetch_assoc();
		foreach ($row as $key => $value)
	{
		echo "$key : $value ";	
		echo "<br>";
	}


echo "<hr>";
?>
<form action="<?php echo htmlentities($_SERVER['PHP_SELF'])."?did=".$did."&r=3"; ?>" method="post">
<input type="submit" name="cmd" value="miIO.info"><br>
VACUUM:
<input type="submit" name="cmd" value="get_status">
<input type="submit" name="cmd" value="app_start">
<input type="submit" name="cmd" value="app_stop">
<input type="submit" name="cmd" value="app_pause">
<input type="submit" name="cmd" value="app_spot">
<input type="submit" name="cmd" value="app_charge">
<input type="submit" name="cmd" value="app_rc_start">
<input type="submit" name="cmd" value="app_rc_end">
<input type="submit" name="cmd" value="find_me"><br>
VACUUM:
<input type="submit" name="cmd" value="get_log_upload_status">
<input type="submit" name="cmd" value="get_consumable">
<input type="submit" name="cmd" value="get_map_v1">
<input type="submit" name="cmd" value="get_clean_summary">
<input type="submit" name="cmd" value="get_timer">
<input type="submit" name="cmd" value="get_dnd_timer">
<input type="submit" name="cmd" value="get_custom_mode">
<br>
<form action="<?php echo htmlentities($_SERVER['PHP_SELF'])."?did=".$did; ?>" method="post">
Method: <input type="input" name="cmd" value="get_status">
Params: <input type="input" name="params" size="100" value="">
<input type="submit" name="submit" value="send command">
</form>
<?php
$options = "";
$res = $mysqli->query("SELECT * FROM ota WHERE model = '".$mysqli->real_escape_string($model)."'");



$res->data_seek(0);
while ($row = $res->fetch_assoc()) {
	$select_param= htmlentities("{'proc': 'dnld install', 'app_url': '".$row['url']."', 'file_md5': '".$row['md5']."', 'install': '1', 'mode': 'normal'}");
	$options .= "<option value=\"".$select_param."\">".$row['version']." ".$row['model']." ".$row['filename']."</option>";
}
?>
<form action="<?php echo htmlentities($_SERVER['PHP_SELF'])."?did=".$did; ?>" method="post">
Method: miIO.ota <input type="hidden" name="cmd" value="miIO.ota">
Params: 
<select name="params">
	  <option value="">Select...</option>
	  <?php echo $options;?>
	</select>
<input type="submit" name="submit" value="send command">
</form>