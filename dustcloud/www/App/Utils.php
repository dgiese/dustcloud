<?php
namespace App;
use \Datetime;

class Utils {

	public static function dbError($statement, $db){
		if($statement === false){
            header('Error', true, 500);
			$msg = 'MySQL Error: ' . $db->errno . ': ' . $db->error;
			echo App::renderTemplate('error.twig', ['msg' => $msg]);
			die();
		}
	}

	public static function yesno($i) {
		if($i == 1){
			return 'yes';
		}
		return 'no';
	}

	public static function formatLastContact($lastContact){
		$now = new \DateTime('now');
		if($lastContact === '0000-00-00 00:00:00'){
			$lastContact = null;
		}
		$result = [
			'last_contact' => $lastContact,
		];
		$lastContact = new \DateTime($lastContact);
		$timerange = date_diff($lastContact, $now);
		$format = self::getTimerangeFormat($timerange);
		$seconds = $now->getTimestamp() - $lastContact->getTimestamp();
		$result['timerange'] = $timerange->format($format);
		$result['timerange_seconds'] = $seconds;
		$result['is_online'] = $seconds <= 60;
		return $result;
	}

	public static function getTimerangeFormat($timerange){
		$values = [
			'y' => 'Year',
			'm' => 'Month',
			'd' => 'Day',
			'h' => 'Hour',
			'i' => 'Minute',
		];
		$format = [];

		foreach($values as $k => $v){
			$f = "%$k $v";
			if($timerange->$k > 1){
				$f .= 's';
			}
			if($timerange->$k >= 1){
				$format[] = $f;
			}
		}
		
		$f = '%s Second';
		if($timerange->s != 1){
			$f .= 's';
		}
		$format[] = $f;

		return implode(' ', $format);
	}

	public static function hex2str($hex)
	{
			$str = '';
			for ($i = 0; $i < strlen($hex); $i += 2)
			{
					$str .= chr(hexdec(substr($hex, $i, 2)));
			}

			return $str;
	}

	public static function printLastContact($last_contact_str)
	{
			$last_contact_date = new DateTime($last_contact_str);
			$now = new DateTime("now");
			$interval_seconds = $now->getTimestamp() - $last_contact_date->getTimestamp();
			$interval = $now->diff($last_contact_date);
			if ($interval_seconds <= 60)
			{
					$interval_class = "green";
			}
			else
			{
					$interval_class = "red";
			}

			echo 'Last contact: '.$last_contact_str.' <span class="'.$interval_class.'">('.$interval->format('%a days %H:%I:%S ago').')</span><br />';
	}

	public static function prettyPrint($json)
	{
        return json_encode(json_decode($json), JSON_PRETTY_PRINT);
	}


	public static function render_apiresponse($data, $cmd)
	{
		$result = [];
		switch ($cmd) {
			case 'miIO.info':
			case '_otc.info':
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
			case 'event.status':
				$result = [
					[
						'key' => 'error',
						'value' => self::errorcodes($data[0]['error_code'])
					],[
						'key' => 'status',
						'value' => self::statuscodes($data[0]['state'])
					],[
						'key' => 'clean area',
						'value' => number_format($data[0]['clean_area'] / 1000000, 1) . 'm<sup>2</sup>'
					],[
						'key' => 'cleaning',
						'value' => self::yesno($data[0]['in_cleaning'])
					],[
						'key' => 'DND enabled',
						'value' => self::yesno($data[0]['dnd_enabled'])
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
						'value' => self::yesno($item[1] === 'on'),
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
						'value' => self::yesno($data[0]['enabled']),
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
						'value' => self::errorcodes($data[0][4]),
					],[
						'key' => 'completed',
						'value' => self::yesno($data[0][5]),
					],
				];
				break;
		}

		return App::renderTemplate('_result.twig', ['result' => $result]);
	}

	public static function statuscodes($i) {
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
	public static function errorcodes($i) {
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

}
