<?php
switch(filter_input(INPUT_GET, 'action', FILTER_SANITIZE_STRING)){
    case 'last_contact':
        $result = lastContact();
        break;
    case 'map':
        readfile('demo/map.json');
        die();
        break;
    case 'device':
        $cmd = filter_input(INPUT_POST, 'cmd', FILTER_SANITIZE_STRING);
        switch($cmd){
            case 'get_status':
                readfile('demo/status.json');
                die();
            case 'miIO.info':
                readfile('demo/miio.json');
                die();
        }
        $result = [
            'error' => 0,
            'data' => [
                'status' => 'ok',
                'message' => 'demo',
            ],
            'html' => 'demo',
        ];
        break;
    default:
        header('Bad Request', true, 400);
        $result = ['error' => 400, 'data' => 'Bad Request'];
}
echo json_encode($result);