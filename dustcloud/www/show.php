<?php
# Author: Dennis Giese [dustcloud@1338-1.org]
# Copyright 2017 by Dennis Giese

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

require_once 'config.php';

// Header configuration
$refresh_seconds = isset($_GET['refresh']) ? $_GET['refresh'] : 10;
if (3 == $refresh_seconds)
{
    $refresh = 3;
}
else
{
    $refresh = 10;
}

// Build the refresh query url (removing any temporary params like cmd_res)
$query = $_GET;
unset($query['cmd_res']);
unset($query['cmd_res_detail']);
$new_query = http_build_query($query);
$refresh_url = $_SERVER['PHP_SELF']."?".$new_query;

header("Refresh: $refresh; URL=$refresh_url");
?>


<?php
    // Style sheets
    require_once 'fns.php';
    includeStyleSheet();

    // Device ID
    if (!isset($_GET['did']))
    {
        die('no did set');
    }
    else
    {
        if (false === filter_var($_GET['did'], FILTER_VALIDATE_INT))
        {
            die('You must enter a valid integer for did!');
        }
        $did = $_GET['did'];
    }

    // DB connection
    $mysqli = new MySQLi(DB_HOST, DB_USER, DB_PASS, DB_NAME);
    if ($mysqli->connect_errno)
    {
        die('Failed to connect to MySQL: ('.$mysqli->connect_errno.') '.$mysqli->connect_error);
    }

    // Commands and settings
    $cmd = isset($_POST['cmd']) ? $_POST['cmd'] : '';
    $params = isset($_POST['params']) ? $_POST['params'] : '';
    $forward_to_cloud = isset($_POST['forward_to_cloud']) ? $_POST['forward_to_cloud'] : '';
    $full_cloud_forward = isset($_POST['full_cloud_forward']) ? $_POST['full_cloud_forward'] : '';
    if ($cmd != "")
    {
        # add new cmd to cmdquere with 30 seconds expiration
        $sql = "INSERT into cmdqueue(did,method,params,expire) VALUES(".$mysqli->real_escape_string($did).",'".$mysqli->real_escape_string($cmd)."','".$mysqli->real_escape_string($params)."',DATE_ADD(NOW(), INTERVAL 30 SECOND))";
        doQueryAndReportFailure($mysqli, $sql);
    }
    if ($forward_to_cloud == "1" || $forward_to_cloud == "0")
    {
        $sql = "UPDATE devices set forward_to_cloud = '".$mysqli->real_escape_string($forward_to_cloud)."' WHERE did = '".$mysqli->real_escape_string($did)."'";
        doQueryAndReportFailure($mysqli, $sql);
    }
    if ($full_cloud_forward == "1" || $full_cloud_forward == "0")
    {
        $sql = "UPDATE devices set full_cloud_forward = '".$mysqli->real_escape_string($full_cloud_forward)."' WHERE did = '".$mysqli->real_escape_string($did)."'";
        doQueryAndReportFailure($mysqli, $sql);
    }
?>

<!-- Actual page content -->
<a href="index.php">Index</a><br>
<?php
    // Device settings
    $res = $mysqli->query("SELECT * FROM devices WHERE did = '".$mysqli->real_escape_string($did)."'");

    $res->data_seek(0);
    while ($row = $res->fetch_assoc())
    {
        $model= $row['model'];

        $name = $row['name'];
        $did = $row['did'];
        $last_contact = $row['last_contact']; ?>

        <b><?php echo $name ?> (did: <?php echo $did ?>)</b>
        <a href="showlog.php?did=<?php echo $did ?>">(recv msg log)</a>
        <a href="showcmdlog.php?did=<?php echo $did ?>">(sent cmd log)</a>
        <br />
        <?php printLastContact($last_contact) ?>
        <div class="device_info">
<?php
        foreach ($row as $key => $value)
        {
            if ($value != "")
            {
                echo "$key : $value<br>";
            }
        } ?>
        </div>
<?php
    }
?>

<form action="<?php echo htmlentities($_SERVER['PHP_SELF'])."?did=".$did; ?>" method="post">
    forward_to_cloud: <input type="submit" name="forward_to_cloud" value="1"><input type="submit" name="forward_to_cloud" value="0"><br>
    full_cloud_forward: <input type="submit" name="full_cloud_forward" value="1"><input type="submit" name="full_cloud_forward" value="0">
</form>

<hr />
<?php
    // Last client message
    $res = $mysqli->query("SELECT * FROM statuslog WHERE did = '".$did."' and direction = 'client >> dustcloud' ORDER by timestamp DESC");
    $res->data_seek(0);
    $row = $res->fetch_assoc();
    if ($row)
    {
        foreach ($row as $key => $value)
        {
            echo "$key : $value ";
            echo "<br>";
        }
    }
    else {
        echo "No communication available yet.";
    }
?>
<hr />

<!-- Predefined commands -->
<?php
$cmd_res_request_failure = "RequestFailure";
$cmd_res_command_failure = "CommandFailure";
$cmd_res_request_success = "Success";
?>
<script>
function on_request_state_change() {
    if (this.readyState == 1) {
            // request is starting, show loader
            document.getElementById("loader").style.display = 'block';
        }

        if (this.readyState == 4) {
            // request is done, hide loader and process result
            document.getElementById("loader").style.display = 'none';
            var searchParams = new URLSearchParams(window.location.search);
            if (this.status == 200) {
                try {
                    command_result = JSON.parse(this.responseText);
                    if (command_result.success) {
                        cmd_res_detail = JSON.stringify({
                            id: command_result.id,
                            cmd: command_result.cmd
                        });
                        // command sent to device
                        searchParams.set('cmd_res','<?php echo $cmd_res_request_success; ?>')
                        searchParams.set('cmd_res_detail', cmd_res_detail)
                    } 
                    else {
                        // failed to send command to device
                        searchParams.set('cmd_res','<?php echo $cmd_res_command_failure; ?>')
                        searchParams.set('cmd_res_detail', command_result.reason)
                    }
                } catch(e) {
                    console.log(e);
                    searchParams.set('cmd_res','Exception processing result')
                    searchParams.set('cmd_res_detail', e.toString())
                }
            }
            else {
                searchParams.set('cmd_res','<?php echo $cmd_res_request_failure; ?>')
            }
            // reload page with command result to present it to the user
            window.location.search = searchParams.toString();
        }
}

function send_request(formData) {
    var xmlhttp = new XMLHttpRequest();
    xmlhttp.onreadystatechange = on_request_state_change;
    xmlhttp.open("POST", "<?php echo htmlentities(CMD_SERVER)."run_command?did=".$did; ?>", true);
    xmlhttp.send(formData);
}

function send_command(cmd) {
    var formData = new FormData();
    formData.set("cmd", cmd);
    send_request(formData);
}

function send_form(form_element) {
    var formData = new FormData(form_element);
    send_request(formData);
}

function get_map()
{
    var xmlhttp = new XMLHttpRequest();
    xmlhttp.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
            map_result = JSON.parse(this.responseText);
            if (map_result.success) {
                map_data = map_result.imagedata
                document.getElementById('map').src = "data:image/png;base64,"+map_data
            }
            setTimeout(get_map, 4000);
        }
    };
    xmlhttp.open("POST", "<?php echo htmlentities(CMD_SERVER)."get_map?did=".$did; ?>", true);
    xmlhttp.send();
}
get_map();
</script>
<form>
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="miIO.info"><br>
    VACUUM:
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="get_status">
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="app_start">
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="app_stop">
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="app_pause">
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="app_spot">
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="app_charge">
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="app_rc_start">
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="app_rc_end">
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="find_me">
    <br>
    VACUUM:
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="get_log_upload_status">
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="get_consumable">
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="get_map_v1">
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="get_clean_summary">
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="get_timer">
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="get_dnd_timer">
    <input type="button" onClick="javascript:send_command(this.value);" name="cmd" value="get_custom_mode">
    <br>
</form>
<!-- Custom commands -->
<form>
    Method: <input type="input" name="cmd" value="get_status">
    Params: <input type="input" name="params" size="100" value="">
    <input type="button" onClick="javascript:send_form(this.parentNode);" value="send command">
</form>

<?php
    // OTA command
    $options = "";
    $res = $mysqli->query("SELECT * FROM ota WHERE model = '".$mysqli->real_escape_string($model)."'");

    $res->data_seek(0);
    while ($row = $res->fetch_assoc())
    {
        $select_param= htmlentities("{'proc': 'dnld install', 'app_url': '".$row['url']."', 'file_md5': '".$row['md5']."', 'install': '1', 'mode': 'normal'}");
        $options .= "<option value=\"".$select_param."\">".$row['version']." ".$row['model']." ".$row['filename']."</option>";
    }
?>

<form>
    Method: miIO.ota <input type="hidden" name="cmd" value="miIO.ota">
    Params: 
    <select name="params">
        <option value="">Select...</option>
        <?php echo $options;?>
    </select>
    <input type="button" onClick="javascript:send_form(this.parentNode);" value="send command">
</form>

<hr />
<div id="loader" class="loader" style="display:none"></div>
<?php 
if (isset($_GET['cmd_res']))
{
    $command_result = $_GET['cmd_res'];
    $command_result_text = "Unknown result";
    $command_result_text_detail = "";
    $command_result_class = "";

    if ($command_result == $cmd_res_request_failure) {
        $command_result_text = "Request to command server failed. Check your configuration!";
        $command_result_class = "red";
    }
    else if ($command_result == $cmd_res_command_failure) {
        $command_result_text = "Failed to send command to device!";
        $command_result_class = "red";
    }
    else if ($command_result == $cmd_res_request_success) {
        $command_result_text = "Successful!";
        $command_result_class = "green";
    }
    else {
        $command_result_text = $command_result;
    }

    if (isset($_GET['cmd_res_detail']))
    {
        $command_result_text_detail = "(".$_GET['cmd_res_detail'].")";
    }
?>
    <div class="command_result ">
        Result for last command: 
        <span class="result_value <?php echo $command_result_class; ?>"><?php echo $command_result_text; ?></span>
        <span class="result_value_detail"><?php echo $command_result_text_detail; ?></span>
    </div>
<?php
}
?>
<img id="map"></img>