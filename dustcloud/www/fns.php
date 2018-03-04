<?php

function hex2str($hex)
{
    $str = '';
    for ($i = 0; $i < strlen($hex); $i += 2)
    {
        $str .= chr(hexdec(substr($hex, $i, 2)));
    }

    return $str;
}

function doQueryAndReportFailure($db, $query)
{
    $res = $db->query($query);
    if (!$res)
    {
        echo "<p>There was an error in query: $query</p>";
        echo $db->error;
    }
}

function includeStyleSheet()
{
    echo '<link rel="stylesheet" href="style.css" type="text/css" />';
}

function printLastContact($last_contact_str)
{
    $last_contact_date = new DateTime($last_contact_str);
    $now = new DateTime("now");
    $interval_seconds = $now->getTimestamp() - $last_contact_date->getTimestamp();
    $interval = $now->diff($last_contact_date);
    if ($interval_seconds <= 60 && $last_contact_date > 0)
    {
        $interval_class = "green";
    }
    else
    {
        $interval_class = "red";
    }

    echo 'Last contact: '.$last_contact_str.' <span class="'.$interval_class.'">('.$interval->format('%a days %H:%I:%S ago').')</span><br />';
}

# taken from https://stackoverflow.com/a/9776726
function prettyPrint($json)
{
    $result = '';
    $level = 0;
    $in_quotes = false;
    $in_escape = false;
    $ends_line_level = null;
    $json_length = strlen($json);

    for ($i = 0; $i < $json_length; $i++)
    {
        $char = $json[$i];
        $new_line_level = null;
        $post = "";
        if ($ends_line_level !== null)
        {
            $new_line_level = $ends_line_level;
            $ends_line_level = null;
        }
        if ($in_escape)
        {
            $in_escape = false;
        }
        elseif ($char === '"' || $char === "'")
        {
            $in_quotes = !$in_quotes;
        }
        elseif (! $in_quotes)
        {
            switch ($char) {
                case '}': case ']':
                    $level--;
                    $ends_line_level = null;
                    $new_line_level = $level;
                    break;

                case '{': case '[':
                    $level++;
                    // no break
                case ',':
                    $ends_line_level = $level;
                    break;

                case ':':
                    $post = " ";
                    break;

                case " ": case "\t": case "\n": case "\r":
                    $char = "";
                    $ends_line_level = $new_line_level;
                    $new_line_level = null;
                    break;
            }
        }
        elseif ($char === '\\')
        {
            $in_escape = true;
        }
        if ($new_line_level !== null)
        {
            $result .= "\n".str_repeat("  ", $new_line_level);
        }
        $result .= $char.$post;
    }

    return $result;
}
