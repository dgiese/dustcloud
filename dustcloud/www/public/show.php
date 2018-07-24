<?php
# Author: Thomas Tsiakalakis [mail@tsia.de]
# Copyright 2018 by Thomas Tsiakalakis

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

require __DIR__ . '/../bootstrap.php';
use App\App;

$db = App::db();
$did = filter_input(INPUT_GET, 'did', FILTER_VALIDATE_INT);
$statement = $db->prepare("SELECT * FROM `devices` WHERE `did` = ?");
$statement->bind_param("s", $did);
$statement->execute();
$result = $statement->get_result()->fetch_assoc();
$statement->close();
if(!$result){
    $templateData = [
        'msg' => 'Device ' . $did . ' not found!',
    ];
    echo App::renderTemplate('error.twig', $templateData);
}else{
    $statement = $db->prepare("SELECT `data` FROM `statuslog` WHERE `did` = ? AND `direction` = 'client >> dustcloud' ORDER BY `timestamp` DESC LIMIT 0,1");
    $statement->bind_param("s", $did);
    $statement->execute();
    $statusresult = $statement->get_result()->fetch_assoc();
    $statement->close();

    $templateData = [
        'device' => $result,
        'status' => $statusresult,
    ];
    echo App::renderTemplate('show.twig', $templateData);
}
