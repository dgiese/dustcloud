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
    $statement = $db->prepare("SELECT `data` FROM `statuslog` WHERE `did` = ? AND `direction` = 'client >> dustcloud' AND `data` NOT LIKE '%\"method\": \"_sync.gen_presigned_url\"%' ORDER BY `timestamp` DESC LIMIT 0,1");
    Utils::dberror($statement, $db);
    $statement->bind_param("s", $did);
    $success = $statement->execute();
    Utils::dberror($success, $statement);
    $statusresult = $statement->get_result()->fetch_assoc();
    $statement->close();
    $dataobject = json_decode($statusresult['data'], true);
    $statusresult['data'] = Utils::prettyprint($statusresult['data']);
    $result['forward_to_cloud'] = Utils::yesno($result['forward_to_cloud']);
    $result['full_cloud_forward'] = Utils::yesno($result['full_cloud_forward']);

    $statement = $db->prepare("SELECT `data` FROM `statuslog` WHERE `did` = ? AND `direction` = 'client << dustcloud (cmd)' ORDER BY `timestamp` DESC LIMIT 0,1");
    Utils::dberror($statement, $db);
    $statement->bind_param("s", $did);
    $success = $statement->execute();
    Utils::dberror($success, $statement);
    $cmdresult = $statement->get_result()->fetch_assoc();
    $cmdresult['data'] = json_decode($cmdresult['data'], true);
    $statement->close();
    
    $dataToRender = (array_key_exists('params', $dataobject) ? $dataobject['params'] : $dataobject['result']);
    $command = (array_key_exists('method', $dataobject) && (substr($dataobject['method'], 0, 6) === 'event.' || $dataobject['method'] === '_otc.info')) ? $dataobject['method'] : $cmdresult['data']['method'];

    $templateData = [
        'device' => $result,
        'status' => $statusresult,
        'lastcmd' => $cmdresult['data']['method'],
        'commands' => commands(),
        'html' => Utils::render_apiresponse($dataToRender, $command),
    ];
    echo App::renderTemplate('show.twig', $templateData);
}


function commands(){
    return [
        '_custom' => 'custom command',
        'miIO.info' => 'miIO Info',
        'find_me' => 'find me',
        'app_charge' => 'go back to dock',
        'app_start' => 'start cleaning',
        'app_stop' => 'stop cleaning',
        'app_pause' => 'pause cleaning',
        'app_spot' => 'start spot cleaning',
        'get_status' => 'get status',
        'get_consumable' => 'get consumables',
        'get_clean_summary' => 'get clean summary',
        'get_clean_record' => 'get clean record',
        'get_timer' => 'get timers',
        'get_dnd_timer' => 'get DND timer',
        'get_custom_mode' => 'get custom mode',
        'get_map_v1' => 'get map v1',
        'set_custom_mode' => 'set custom mode',
    ];
}