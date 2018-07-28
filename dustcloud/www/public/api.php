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
    $statement->bind_param('sss', $did, $cmd, strval($postdata));
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
    $statement = $db->prepare("SELECT `data` FROM `statuslog` WHERE `did` = ? AND `direction` = 'client >> dustcloud' ORDER BY `timestamp` DESC LIMIT 0,1");
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
        'html' => (array_key_exists('result', $data) ? render_apiresponse($data['result']) : ''),
    ];
}


function render_apiresponse($data){
    $cmd = filter_input(INPUT_POST, 'cmd', FILTER_SANITIZE_STRING);
    $result = [];
    switch ($cmd) {
        case 'miIO.info':
            $result = [
                [
                    'key' => 'AP BSSID',
                    'value' => $data['ap']['bssid'],
                ],[
                    'key' => 'AP SSID',
                    'value' => $data['ap']['ssid'],
                ],[
                    'key' => 'AP RSSI',
                    'value' => $data['ap']['rssi'] . 'dBm',
                ],[
                    'key' => ' ',
                    'value' => '&nbsp;',
                ],[
                    'key' => 'firmware version',
                    'value' => $data['fw_ver'],
                ],[
                    'key' => 'hardware version',
                    'value' => $data['hw_ver'],
                ],[
                    'key' => 'uptime',
                    'value' => number_format($data['life'] / 3600, 1) . 'h',
                ],[
                    'key' => 'mac address',
                    'value' => $data['mac'],
                ],[
                    'key' => 'model',
                    'value' => $data['model'],
                ],[
                    'key' => ' ',
                    'value' => '&nbsp;',
                ],[
                    'key' => 'local ip',
                    'value' => $data['netif']['localIp'],
                ],[
                    'key' => 'gateway',
                    'value' => $data['netif']['gw'],
                ],[
                    'key' => 'netmask',
                    'value' => $data['netif']['mask'],
                ],
            ];
            break;
        case 'get_status':
            $result = [
                [
                    'key' => 'error',
                    'value' => errorcodes($data[0]['error_code'])
                ],[
                    'key' => 'status',
                    'value' => statuscodes($data[0]['state'])
                ],[
                    'key' => 'clean area',
                    'value' => number_format($data[0]['clean_area'] / 1000000, 1) . 'm<sup>2</sup>'
                ],[
                    'key' => 'cleaning',
                    'value' => Utils::yesno($data[0]['in_cleaning'])
                ],[
                    'key' => 'DND enabled',
                    'value' => Utils::yesno($data[0]['dnd_enabled'])
                ],[
                    'key' => 'battery',
                    'value' => $data[0]['battery'] . '%',
                ],[
                    'key' => 'clean time',
                    'value' => number_format($data[0]['clean_time'] / 60, 0) . 'min',
                ],[
                    'key' => 'fan power',
                    'value' => $data[0]['fan_power'] . '%'
                ],
            ];
            break;
        case 'get_consumable':
            $result = [
                [
                    'key' => 'main brush used',
                    'value' => number_format($data[0]['main_brush_work_time'] / 3600, 1) . 'h'
                ],[
                    'key' => 'main brush remaining',
                    'value' => number_format((1080000 - $data[0]['main_brush_work_time']) / 3600, 1) . 'h'
                ],[
                    'key' => 'side brush used',
                    'value' => number_format($data[0]['side_brush_work_time'] / 3600, 1) . 'h'
                ],[
                    'key' => 'side brush remaining',
                    'value' => number_format((720000 - $data[0]['side_brush_work_time']) / 3600, 1) . 'h'
                ],[
                    'key' => 'filter used',
                    'value' => number_format($data[0]['filter_work_time'] / 3600, 1) . 'h'
                ],[
                    'key' => 'filter remaining',
                    'value' => number_format((540000 - $data[0]['filter_work_time']) / 3600, 1) . 'h'
                ],[
                    'key' => 'sensor used',
                    'value' => number_format($data[0]['sensor_dirty_time'] / 3600, 1) . 'h'
                ],[
                    'key' => 'sensor remaining',
                    'value' => number_format((216000 - $data[0]['sensor_dirty_time']) / 3600, 1) . 'h'
                ],
            ];
            break;
        case 'get_clean_summary':
            $result = [
                [
                    'key' => 'total duration',
                    'value' => number_format($data[0] / 3600, 1) . 'h'
                ],[
                    'key' => 'total area',
                    'value' => number_format($data[1] / 1000000, 1) . 'm<sup>2</sup>'
                ],[
                    'key' => 'number of runs',
                    'value' => $data[2]
                ],[
                    'key' => 'cleaning runs',
                    'value' => implode('<br>', array_map(function($n){ return date('c', $n); }, $data[3]))
                ],
            ];
            break;
        case 'get_timer':
            foreach($data as $item){
                $result[] = [
                    'key' => 'id',
                    'value' => $item[0],
                ];
                $result[] = [
                    'key' => 'date',
                    'value' => date('c', $item[0] / 1000),
                ];
                $result[] = [
                    'key' => 'enabled',
                    'value' => Utils::yesno($item[1] === 'on'),
                ];
                $result[] = [
                    'key' => 'time',
                    'value' => $item[2][0],
                ];
                $result[] = [
                    'key' => 'action',
                    'value' => $item[2][1][0] . '(' . $item[2][1][1] . ')',
                ];
                $result[] = [
                    'key' => ' ',
                    'value' => '&nbsp;',
                ];
            }
            break;
        case 'get_dnd_timer':
            $result = [
                [
                    'key' => 'start',
                    'value' => $data[0]['start_hour'] . ':' . str_pad($data[0]['start_minute'], 2, '0', STR_PAD_LEFT),
                ],[
                    'key' => 'end',
                    'value' => $data[0]['end_hour'] . ':' . str_pad($data[0]['end_minute'], 2, '0', STR_PAD_LEFT),
                ],[
                    'key' => 'enabled',
                    'value' => Utils::yesno($data[0]['enabled']),
                ],
            ];
            break;
        case 'get_custom_mode':
            $result = [
                [
                    'key' => 'fan power',
                    'value' => $data[0] . '%',
                ],
            ];
            break;
        case 'get_map_v1':
        case 'app_start':
        case 'app_stop':
        case 'app_pause':
        case 'app_charge':
        case 'app_spot':
        case 'find_me':
            $result = [
                [
                    'key' => 'result',
                    'value' => $data[0],
                ],
            ];
            break;
        case 'get_clean_record':
            $result = [
                [
                    'key' => 'start',
                    'value' => date('c', $data[0][0]),
                ],[
                    'key' => 'finish',
                    'value' => date('c', $data[0][1]),
                ],[
                    'key' => 'duraion',
                    'value' => number_format($data[0][2] / 60, 0) . 'min',
                ],[
                    'key' => 'area',
                    'value' => number_format($data[0][3] / 1000000, 1) . 'm<sup>2</sup>',
                ],[
                    'key' => 'error',
                    'value' => errorcodes($data[0][4]),
                ],[
                    'key' => 'completed',
                    'value' => Utils::yesno($data[0][5]),
                ],
            ];
            break;
    }
    return App::renderTemplate('_result.twig', ['result' => $result]);
}

function statuscodes($i) {
    $map = [
        1 => 'Starting',
        2 => 'Charger disconnected',
        3 => 'Idle',
        4 => 'Remote control active',
        5 => 'Cleaning',
        6 => 'Returning home',
        7 => 'Manual mode',
        8 => 'Charging',
        9 => 'Charging problem',
        10 => 'Paused',
        11 => 'Spot cleaning',
        12 => 'Error',
        13 => 'Shutting down',
        14 => 'Updating',
        15 => 'Docking',
        16 => 'Going to target',
        17 => 'Zoned cleaning',
    ];
    return $map[$i];
}
function errorcodes($i) {
    $map = [
        0 => 'No error',
        1 => 'Laser distance sensor error',
        2 => 'Collision sensor error',
        3 => 'Wheels on top of void, move robot',
        4 => 'Clean hovering sensors, move robot',
        5 => 'Clean main brush',
        6 => 'Clean side brush',
        7 => 'Main wheel stuck?',
        8 => 'Device stuck, clean area',
        9 => 'Dust collector missing',
        10 => 'Clean filter',
        11 => 'Stuck in magnetic barrier',
        12 => 'Low battery',
        13 => 'Charging fault',
        14 => 'Battery fault',
        15 => 'Wall sensors dirty, wipe them',
        16 => 'Place me on flat surface',
        17 => 'Side brushes problem, reboot me',
        18 => 'Suction fan problem',
        19 => 'Unpowered charging station',
    ];
    return $map[$i];
}
