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

# taken from https://stackoverflow.com/a/9776726
function prettyPrint( $json )
{
    $result = '';
    $level = 0;
    $in_quotes = false;
    $in_escape = false;
    $ends_line_level = NULL;
    $json_length = strlen( $json );

    for( $i = 0; $i < $json_length; $i++ ) {
        $char = $json[$i];
        $new_line_level = NULL;
        $post = "";
        if( $ends_line_level !== NULL ) {
            $new_line_level = $ends_line_level;
            $ends_line_level = NULL;
        }
        if ( $in_escape ) {
            $in_escape = false;
        } else if( $char === '"' || $char === "'") {
            $in_quotes = !$in_quotes;
        } else if( ! $in_quotes ) {
            switch( $char ) {
                case '}': case ']':
                    $level--;
                    $ends_line_level = NULL;
                    $new_line_level = $level;
                    break;

                case '{': case '[':
                    $level++;
                case ',':
                    $ends_line_level = $level;
                    break;

                case ':':
                    $post = " ";
                    break;

                case " ": case "\t": case "\n": case "\r":
                    $char = "";
                    $ends_line_level = $new_line_level;
                    $new_line_level = NULL;
                    break;
            }
        } else if ( $char === '\\' ) {
            $in_escape = true;
        }
        if( $new_line_level !== NULL ) {
            $result .= "\n".str_repeat( "  ", $new_line_level );
        }
        $result .= $char.$post;
    }

    return $result;
}

$longlog = isset($_GET['longlog']) ? $_GET['longlog'] : '0';
if ($longlog == 0)
{
    $url1=$_SERVER['REQUEST_URI'];
    header("Refresh: 30; URL=$url1"); ### Be carefull, may contain some security risk
}

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
echo "<a href=\"index.php\">Index</a><br>";
$res = $mysqli->query("SELECT * FROM devices WHERE did = '".$did."'");

$res->data_seek(0);
while ($row = $res->fetch_assoc()) {
    echo "<a href=\"./show.php?did=" . $row['did'] . "\">" . $row['name'] . "(did:" . $row['did'] . ")</a><br>Last contact: " . $row['last_contact'];
	$date1 = new DateTime("now");
	$date2 = new DateTime($row['last_contact']);
	$interval = $date1->diff($date2);
	echo " (".$interval->format('%a days %H:%I:%S ago').")";
	echo "<br>\n";
}
echo "<a href=\"".$url1."&longlog=1\">2000 messages without refresh</a><br>";
echo "<hr>";
if ($longlog == 1)
{
	$res = $mysqli->query("SELECT * FROM statuslog WHERE did = '".$did."' ORDER by id DESC LIMIT 2000");
}else
{
	$res = $mysqli->query("SELECT * FROM statuslog WHERE did = '".$did."' ORDER by id DESC LIMIT 100");
}
$res->data_seek(0);
while ($row = $res->fetch_assoc())
{
		foreach ($row as $key => $value)
	{
	    if ($key == "data")
	    {
	        $value = prettyPrint( $value );
	        echo "$key : <pre>$value</pre>";
	    }else
	    {
		    echo "$key : $value ";
		    echo "<br>";
	    }
	}
	echo "<hr>";
}
?>