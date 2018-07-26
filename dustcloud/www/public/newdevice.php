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

$did = filter_input(INPUT_GET, 'did', FILTER_VALIDATE_INT);
$isSave = filter_input(INPUT_POST, 'save', FILTER_VALIDATE_BOOLEAN);
$isDelete = filter_input(INPUT_POST, 'delete', FILTER_VALIDATE_INT);
$result = [];

if($isDelete === 1){
	deleteConfirmation($did);
}elseif($isDelete === 2){
	delete($did);
}elseif($isSave){
	save($did);
}elseif(!empty($did)){
	showEdit($did);
}else{
	echo App::renderTemplate('newdevice.twig', []);
}

function deleteConfirmation($did){
	$templateData = [
		'msg' => 'delete the Device ' . $did,
	];
	echo App::renderTemplate('confirm.twig', $templateData);
}
function delete($did){
	$db = App::db();
	$statement = $db->prepare("DELETE FROM `devices` WHERE `did` = ?");
	Utils::dberror($statement, $db);
	$statement->bind_param("s", $did);
	$success = $statement->execute();
	if(!$success){
		$msg = 'MySQL Error: ' . $statement->errno . ': ' . $statement->error;
		echo App::renderTemplate('newdevice.twig', ['msgs' => [$msg], 'device' => _getDeviceFromDb($did)]);
	}else{
		$statement->close();

		$templateData = [
			'msg' => 'Device ' . $did . ' successfully deleted.',
		];
		echo App::renderTemplate('success.twig', $templateData);
	}
}

function save($did){
	$db = App::db();
	$msgs = [];
	$enckey = filter_input(INPUT_POST, 'enckey', FILTER_VALIDATE_REGEXP, array('options' => array('regexp' => "/^[a-zA-Z0-9]+$/")));
	$name = filter_input(INPUT_POST, 'name', FILTER_SANITIZE_STRING);
	$forward_to_cloud = intval(filter_input(INPUT_POST, 'forward_to_cloud', FILTER_SANITIZE_NUMBER_INT));
	$full_cloud_forward = intval(filter_input(INPUT_POST, 'full_cloud_forward', FILTER_SANITIZE_NUMBER_INT));
	if(!$did){ // new device
		$did = filter_input(INPUT_POST, 'did', FILTER_VALIDATE_INT);
		if(!$did){
			$msgs[] = 'You must enter a valid integer for did!';
		}
		$statement = $db->prepare("INSERT INTO `devices` (`name`, `enckey`, `forward_to_cloud`, `full_cloud_forward`, `did`) VALUES ( ?, ?, ?, ?, ?)");
	}else{
		$statement = $db->prepare("UPDATE `devices` SET `name` = ?, `enckey` = ?, `forward_to_cloud` = ?, `full_cloud_forward` = ? WHERE `did` = ?");
	}
	if(!$statement){
		$msgs[] = 'MySQL Error: ' . $db->errno . ': ' . $db->error;
	}
	if(!$enckey){
		$msgs[] = 'You must enter an alphanum string for enckey!';
	}
	if(count($msgs) === 0){
		$statement->bind_param("ssdds", $name, $enckey, $forward_to_cloud, $full_cloud_forward, $did);
		$success = $statement->execute();
		if(!$success){
			$msg = 'MySQL Error: ' . $statement->errno . ': ' . $statement->error;
			echo App::renderTemplate('newdevice.twig', ['msgs' => [$msg], 'device' => _getDeviceFromGlobals()]);
		}else{
			$msg = 'Device Saved';
			echo App::renderTemplate('success.twig', ['msg' => $msg]);
		}
	}else{
		echo App::renderTemplate('newdevice.twig', ['msgs' => $msgs, 'device' => _getDeviceFromGlobals()]);
	}
	if($statement){
		$statement->close();
	}
}

function showEdit($did){
	$db = App::db();
	$device = _getDeviceFromDb($did);
	if(!$result){
		$templateData = [
			'msg' => 'Device ' . $did . ' not found!',
		];
		echo App::renderTemplate('error.twig', $templateData);
	}else{
		$templateData = [
			'device' => $result
		];
		echo App::renderTemplate('newdevice.twig', $templateData);
	}
}

function _getDeviceFromDb($did){
	$db = App::db();
	$statement = $db->prepare("SELECT `did`, `name`, `enckey`, `forward_to_cloud`, `full_cloud_forward` FROM `devices` WHERE `did` = ?");
	Utils::dberror($statement, $db);
	$statement->bind_param("s", $did);
	$success = $statement->execute();
	Utils::dberror($success, $statement);
	$result = $statement->get_result()->fetch_assoc();
	$statement->close();
	return $result;
}

function _getDeviceFromGlobals(){
	$device = [
		'did' => filter_input(INPUT_GET, 'did', FILTER_SANITIZE_STRING),
		'enckey' => filter_input(INPUT_POST, 'enckey', FILTER_SANITIZE_STRING),
		'name' => filter_input(INPUT_POST, 'name', FILTER_SANITIZE_STRING),
	];
	if(!$device['did']){
		filter_input(INPUT_POST, 'did', FILTER_SANITIZE_STRING);
	}
	return $device;
}