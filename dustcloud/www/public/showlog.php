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
use App\Utils;

$perpage = 100;

$db = App::db();
$did = filter_input(INPUT_GET, 'did', FILTER_VALIDATE_INT);
$page = intval(filter_input(INPUT_GET, 'page', FILTER_VALIDATE_INT));
$limit = ($page * $perpage) . ',' . $perpage;
$statement = $db->prepare("SELECT `did` FROM `devices` WHERE `did` = ?");
Utils::dberror($statement, $db);
$statement->bind_param("s", $did);
$success = $statement->execute();
Utils::dberror($success, $statement);
$device = $statement->get_result()->fetch_assoc();
$statement->close();
if(!$device){
    $templateData = [
        'msg' => 'Device ' . $did . ' not found!',
    ];
    echo App::renderTemplate('error.twig', $templateData);
}else{
    $statement = $db->prepare("SELECT * FROM `statuslog` WHERE `did` = ? AND `direction` = 'client >> dustcloud' AND `data` NOT LIKE '%\"method\": \"_sync.gen_presigned_url\"%' ORDER BY `timestamp` DESC LIMIT " . $limit);
    Utils::dberror($statement, $db);
    $statement->bind_param("s", $did);
    $success = $statement->execute();
    Utils::dberror($success, $statement);
    $result = $statement->get_result()->fetch_all(MYSQLI_ASSOC);
    foreach($result as $key => $row){
        $result[$key]['data'] = Utils::prettyprint($row['data']);
    }
    $templateData = [
        'page' => $page,
        'device' => $device,
        'log' => $result,
        'count' => count($result),
        'perpage' => $perpage,
    ];
    echo App::renderTemplate('showlog.twig', $templateData);
}