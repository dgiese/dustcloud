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

require __DIR__ . '/bootstrap.php';

use App\App;
use App\Utils;

Utils::includeStyleSheet();

$mysqli = App::db();
echo "<a href=\"newdevice.php\">Create new device</a><br><br>";
$res = $mysqli->query("SELECT did,name,model,mac,fw,last_contact FROM devices ORDER BY model, id ASC");

$res->data_seek(0);
echo "<table border=1>";
$first = 0;
while ($row = $res->fetch_assoc())
{
    if ($first == 0)
    {
        echo "<tr><td></td>";
        foreach ($row as $key => $value)
        {
            echo "<td>".$key."</td>";
        }
        echo "<td></td>";
        echo "</tr>";
        $first = 1;
    }
    echo "<tr>";
    echo "<td><a href=\"./show.php?did=" . $row['did'] . "\">->" . $row['name'] . "</a></td>\n";
    foreach ($row as $key => $value)
    {
        echo "<td>".$value."</td>";
    }
    $date1 = new DateTime("now");
    $date2 = new DateTime($row['last_contact']);
    $interval = $date1->diff($date2);
    if ((($date1->getTimestamp() - $date2->getTimestamp()) <= 60) && ($row['last_contact'] > 0))
    {
        $bgcolor="green";
    }
    else
    {
        $bgcolor="red";
    }
    echo "<td class=".$bgcolor.">".$interval->format('%a days %H:%I:%S ago')."</td>";
    echo "</tr>";
}
echo "</table>";
