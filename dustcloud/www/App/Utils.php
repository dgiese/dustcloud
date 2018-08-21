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
}
