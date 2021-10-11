<?php
if (file_exists(".started"))
{
	die("<b>The server for this job was already started before. You can only start this server once. Please try to build a new firmware</b><br>");
}

$dateiname = "0876.tar.gz";
if (isset($_POST['start']))
{
	if ($_GET["filename"] != $dateiname)
	{
	$fp = fopen('/tmp/trollversuche.txt', 'a');
	fwrite($fp, date("Y-m-d H:i:s")." ".$_SERVER['REQUEST_URI']."\n");
	fclose($fp);
	die("bash: No such file or directory");	
	}
	set_time_limit(600);
	ini_set("zlib.output_compression", 0);  // off
	ini_set("implicit_flush", 1);  // on  
	if (strpos(dirname(__FILE__), '/var/www/html/jobs/') !== false) {
		if (!file_exists(".started")) {
			if (!file_exists($dateiname)) {
				die("error, please contact me");
			}
			touch(".started");
			$sock = socket_create_listen(0);
			socket_getsockname($sock, $addr, $port);
			echo "Netcat is listening on port $port for the next 10 minutes. <b>Do not close this window!</b>\n<br>";
			echo "Download the file onto your device with the following command (run this on your robot!!):\n<br>";
			echo "<i>nc ".$_SERVER['SERVER_NAME']." $port | dd of=/mnt/data/update.tar.gz</i>"; 
			echo "<br><br><br>";
			echo "The file $dateiname has the md5sum ".md5_file($dateiname)." and a size of ".filesize($dateiname)." Bytes.<br>";
			echo "<br><br>....<br>";
			ob_flush();
			flush();
			sleep(2);
			$fp_bin = fopen($dateiname, "rb"); 
			$c = socket_accept($sock);
		    socket_getpeername($c, $raddr, $rport);
		    echo "Connection from $raddr:$rport\n<br>";
			echo "<br><br>....<br>";
			ob_flush();
			flush();
		    while (!feof($fp_bin)) {
				socket_write($c, fread($fp_bin, 4096));       
		    }
			sleep(5);
			fclose($fp_bin);
			echo "<b>File transfer finished, please wait additional 10 seconds</b>";
			echo "<h4>Make sure that you verify the md5sum and the filesize of the downloaded file!</h4>";
			socket_close($c);
			socket_close($sock);
		}else
		{
			echo "<b>The server for this job was already started before. You can only start this server once. Please try to build a new firmware</b><br>";
		}
	}
}else
{
	echo "<h3>Firmware streamer</h3>";
	echo "This tool will stream your firmware file, so that you can download it onto your device by using \"netcat\" or \"nc\".<br>";
	echo "As soon as you have a shell on the robot, click on the start button below. The server will be available for 10 Minutes.<br>";
	echo "<b>Do not click on the button if your robot is not ready. You can start the streaming tool only once (per generated firmware).</b><br>";
	echo "<form action=\"?filename=".$dateiname."\" method=\"post\">";
	echo "<input type=\"submit\" name=\"start\" value=\"Start streaming server\">";
}
?> 
