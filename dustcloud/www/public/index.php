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
$result = $db->query("SELECT `did`, `name`, `model`, `mac`, `fw`, `last_contact` FROM `devices` ORDER BY `model`, `id` ASC");

$data = [
    'devices' => [],
];

while($row = $result->fetch_assoc()){
    $lastContact = Utils::formatLastContact($row['last_contact']);
    $data['devices'][] = array_merge($row, $lastContact);
}

echo App::renderTemplate('index.twig', $data);