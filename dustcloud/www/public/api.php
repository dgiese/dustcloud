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
ini_set('display_errors', 0);
ini_set('log_errors', 1);

use App\App;
use App\Utils;

header('Content-Type: application/json');
if(App::config('demo', false)){
    require_once 'api_demo.php';
    die();
}

switch(filter_input(INPUT_GET, 'action', FILTER_SANITIZE_STRING)){
    case 'last_contact':
        $result = lastContact();
        break;
    case 'map':
        $result = apicall('get_map');
        break;
    case 'route':
        $result = getRoute();
        break;
    case 'fullroute':
        $result = getRoute(true);
        break;
    case 'status':
        $result = lastStatus();
        break;
    case 'device':
        $cmd = filter_input(INPUT_POST, 'cmd', FILTER_SANITIZE_STRING);
        $params = filter_input(INPUT_POST, 'params', FILTER_SANITIZE_STRING);
        $postdata = 'cmd=' . urlencode($cmd);
        if($params){
            $postdata .= '&params=' . urlencode($params);
        }
        $result = apicall('run_command', $postdata);
        if($result['error'] === 0){
            $result = apiresponse();
        }
        break;
    default:
        header('Bad Request', true, 400);
        $result = ['error' => 400, 'data' => 'Bad Request'];
}
echo json_encode($result);

function lastContact(){
    $db = App::db();
    $did = filter_input(INPUT_GET, 'did', FILTER_VALIDATE_INT);
    $statement = $db->prepare("SELECT `last_contact` FROM `devices` WHERE `did` = ?");
    Utils::dberror($statement, $db);
    $statement->bind_param("s", $did);
    $success = $statement->execute();
    Utils::dberror($success, $statement);
    $result = $statement->get_result()->fetch_assoc();
    $statement->close();
    if(!$result){
        header('Not Found', true, 404);
        return ['error' => 404, 'data' => 'device not found'];
    }else{
        $lastContact = Utils::formatLastContact($result['last_contact']);
        return ['error' => 0, 'data' => $lastContact];
    }
}

function lastStatus(){
    $db = App::db();
    $did = filter_input(INPUT_GET, 'did', FILTER_VALIDATE_INT);
    $statement = $db->prepare("SELECT `data` FROM `statuslog` WHERE `did` = ? AND `data` LIKE '%\"method\": \"event.status\"%' ORDER BY `timestamp` DESC LIMIT 0,1");
    Utils::dberror($statement, $db);
    $statement->bind_param("s", $did);
    $success = $statement->execute();
    Utils::dberror($success, $statement);
    $result = $statement->get_result()->fetch_assoc();
    $statement->close();
    if(!$result){
        header('Not Found', true, 404);
        return ['error' => 404, 'data' => 'device not found'];
    }else{
        $data = json_decode($result['data'], true);
        return [
            'error' => 0,
            'data' => ['result' => $data['params']],
            'html' => (array_key_exists('params', $data) ? Utils::render_apiresponse($data['params'], 'get_status') : ''),
        ];
    }
}

function getRoute($full = false){
    $did = filter_input(INPUT_GET, 'did', FILTER_VALIDATE_INT);
    $all = $full ? '/all' : '';
    $url = 'http://localhost:' . App::config('cloudserver.mapport', 8080) . '/' . $did;
    $result = json_decode(file_get_contents($url . $all));
    if(empty($result) && $all === '/all'){
        $result = json_decode(file_get_contents('http://localhost:82/' . $did . '/prev'), true);
    }
    return $result;
}

function apicall($cmd, $postdata = null){
    $db = App::db();
    
    $curl = curl_init();
    $url = trim(App::config('cmd.server', 'http://localhost:1121'), '/') . '/' . $cmd . '?';

    foreach($_GET as $k => $v){
        if($k !== 'cmd' && $k !== 'action'){
            $url .= $k . '=' . urlencode($v) . '&';
        }
    }

    $did = filter_input(INPUT_GET, 'did', FILTER_VALIDATE_INT);
    $sql = "INSERT INTO `cmdqueue` (`did`, `method`, `params`, `expire`) VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 30 SECOND))";
    $statement = $db->prepare($sql);
    Utils::dberror($statement, $db);
    $postdata = strval($postdata);
    $statement->bind_param('sss', $did, $cmd, $postdata);
    $success = $statement->execute();
    Utils::dberror($success, $statement);

    curl_setopt($curl, CURLOPT_URL, $url);
    curl_setopt($curl, CURLOPT_HEADER, 0);
    curl_setopt($curl, CURLOPT_POST, 1);
    if($postdata){
        curl_setopt($curl, CURLOPT_POSTFIELDS, $postdata);
    }
    curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($curl, CURLOPT_TIMEOUT, 10);
    $output = curl_exec($curl);
    curl_close($curl);
    $json = json_decode($output, true);
    if(!$json){
        header('Error', true, 500);
        return ['error' => 500, 'data' => $output];
    }


    if(!$json['success']){
        if($cmd !== "get_map" && $json['reason']['data'] !== "No map available"){
            header('Error', true, 500);
        }
        return ['error' => 500, 'data' => $json['reason']];
    }

    unset($json['success']);

    return ['error' => 0, 'data' => $json];
}

function apiresponse(){
    $db = App::db();
    $did = filter_input(INPUT_GET, 'did', FILTER_VALIDATE_INT);
    $cmd = filter_input(INPUT_POST, 'cmd', FILTER_SANITIZE_STRING);
    $statement = $db->prepare("SELECT `data` FROM `statuslog` WHERE `did` = ? AND `direction` = 'client >> dustcloud' AND `data` NOT LIKE '%\"method\": \"_sync.gen_presigned_url\"%' ORDER BY `timestamp` DESC LIMIT 0,1");
    Utils::dberror($statement, $db);
    $statement->bind_param("s", $did);
    $success = $statement->execute();
    Utils::dberror($statement, $statement);
    $response = $statement->get_result()->fetch_assoc();
    $statement->close();
    $data = json_decode(str_replace("'", '"', $response['data']), true);
    return [
        'error' => 0,
        'data' => $data,
        'html' => (array_key_exists('result', $data) ? Utils::render_apiresponse($data['result'], $cmd) : ''),
    ];
}