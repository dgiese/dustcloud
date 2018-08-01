"use strict";

var lastContactTimer;
function startLastContactAjax(){
    lastContactTimer = window.setInterval(lastContactAjax, 1000);
    lastContactAjax();
}
function lastContactAjax(){
    var xhr = new XMLHttpRequest();
    xhr.open('GET', 'api.php?action=last_contact&did=' + did);
    xhr.responseType = 'json';
    xhr.send();
    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            if(xhr.status !== 200){
                if(xhr.status !== 0){
                    stopLastContactAjax();
                    alert("Error: " + xhr.status + ": " + xhr.statusText);
                }
            }else if(xhr.response.error > 0){
                stopLastContactAjax();
                alert("Error: " + xhr.response.error + ": " + xhr.response.data);
            }else{
                var element = document.querySelector('span.last_contact')
                if(xhr.response.data.last_contact){
                    element.innerText = xhr.response.data.last_contact + " (" + xhr.response.data.timerange + ")";
                    if(xhr.response.data.is_online){
                        element.classList.remove('offline');
                        element.classList.add('online');
                    }else{
                        element.classList.remove('online');
                        element.classList.add('offline');
                    }
                }else{
                    element.innerText = "never";
                }
            }
        }
    };
}
function stopLastContactAjax(){
    clearInterval(lastContactTimer);
}

var mapTimer;
function startMapAjax(){
    mapTimer = window.setInterval(mapAjax, 5000);
    mapAjax();
}
function mapAjax(){
    var img = document.querySelector('img.map');
    var status = document.querySelector('.mapwrapper p');
    var xhr = new XMLHttpRequest();
    xhr.open('POST', 'api.php?action=map&did=' + did);
    xhr.responseType = 'json';
    xhr.send();
    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            if(xhr.status !== 200){
                img.src = 'about:blank';
                status.innerText = 'No map available';
                if(xhr.status !== 0){
                    stopMapAjax();
                    alert("Error: " + xhr.status + ": " + xhr.statusText);
                }
            }else if(!xhr.response || xhr.response.error > 0){
                img.src = 'about:blank';
                status.innerText = 'No map available';
                if(xhr.response.data != "No map available"){
                    stopMapAjax();
                    alert("Error: " + xhr.response.error + ": " + xhr.response.data);
                }
            }else{
                status.innerText = '';
                img.src = 'data:image/png;base64,' + xhr.response.data.imagedata;
            }
        }
    };
}
function stopMapAjax(){
    clearInterval(mapTimer);
}

var dragStarted = false
var offset = {x: -512, y: -512};
var startPos = {x: -512, y: -512};
function initMapDrag(){
    var element = document.querySelector('img.map');

    if(parseInt(localStorage.mapPosX)){
        startPos.x = parseInt(localStorage.mapPosX);
        offset.x = parseInt(localStorage.mapPosX);
    }
    if(localStorage.mapPosY){
        startPos.y = parseInt(localStorage.mapPosY);
        offset.y = parseInt(localStorage.mapPosY);
    }
    element.style = 'transform: translate(' + offset.x + 'px, ' + offset.y + 'px)';

    element.addEventListener('dragstart', function(dragevent){
        dragevent.preventDefault();
    });
    element.addEventListener('mousedown', function(downevent){
        dragStarted = true;
        document.addEventListener('mousemove', move);

    });
    document.addEventListener('mouseup', function(event){
        document.removeEventListener('mousemove', move)
        if(startPos.x === offset.x && startPos.y === offset.y && dragStarted === true){
            console.log('set marker');
        }
        dragStarted = false;
        startPos.x = offset.x;
        startPos.y = offset.y;
        localStorage.mapPosX = offset.x;
        localStorage.mapPosY = offset.y;
    });

    function move(event){
        if(dragStarted){
            offset.x += event.movementX;
            offset.y += event.movementY;
            offset.x = (offset.x > 0) ? 0 : offset.x;
            offset.y = (offset.y > 0) ? 0 : offset.y;
            offset.x = (offset.x < -1024) ? -1024 : offset.x;
            offset.y = (offset.y < -1024) ? -1024 : offset.y;
            element.style = 'transform: translate(' + offset.x + 'px, ' + offset.y + 'px)';
        }
    }
}

function initControls(){
    changeCmdDropdown();
    document.querySelector('.controls select.cmd').addEventListener('change', changeCmdDropdown);
    document.querySelector('.controls button').addEventListener('click', function(){
        var loader = document.querySelector('#loader');
        loader.style = 'visibility: visible';
        var inputs = document.querySelector('.controls input, .controls select, .controls.button');
        for (let i = 0; i < inputs.length; i++) {
            inputs[i].setAttribute('disabled', 'disabled');
        }
        var cmd = document.querySelector('.controls select').value;
        var params = getCmdParams(cmd);
        if(cmd === '_custom'){
            cmd = document.querySelector('.controls .inputs._custom input[name="cmd"]').value;
        }

        var xhr = new XMLHttpRequest();
        xhr.open('POST', 'api.php?action=device&did=' + did);
        xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        xhr.responseType = 'json';
        var postdata = 'cmd=' + encodeURIComponent(cmd) + '&params=' + encodeURIComponent(params);
        console.log(postdata);
        xhr.send(postdata);
        xhr.onreadystatechange = function () {
            if (xhr.readyState === 4) {
                loader.style = 'visibility: hidden';
                for (let i = 0; i < inputs.length; i++) {
                    inputs[i].removeAttribute('disabled');
                }
                if(xhr.status !== 200 && xhr.response === null){
                    if(xhr.status !== 0){
                        alert("Error: " + xhr.status + ": " + xhr.statusText);
                    }
                }else if(xhr.response.error > 0){
                    alert("Error: " + xhr.response.error + ": " + xhr.response.data);
                    document.querySelector('.controls pre').innerHTML = '&nbsp;'
                    document.querySelector('.controls .result').innerHTML = '';
                }else{
                    console.log(xhr.response.data);
                    document.querySelector('.controls pre').innerText = JSON.stringify(xhr.response.data, null, 4);
                    document.querySelector('.controls .result').innerHTML = xhr.response.html;
                }
            }
        };
    });
}

function getCmdParams(cmd){
    var inputElements = document.querySelectorAll('.controls .inputs.' + cmd + ' input, .controls .inputs.' + cmd + ' select');
    var inputs = {};
    for (let i = 0; i < inputElements.length; i++) {
        inputs[inputElements[i].name] = inputElements[i];
    }
    console.log(inputs);
    switch (cmd) {
        case '_custom':
                return inputs.params.value;
        case 'get_clean_record':
        case 'set_custom_mode':
                return JSON.stringify([ parseInt(inputElements[0].value) ]);
            break;
        default:
                return "";
            break;
    }
}

function changeCmdDropdown(){
    var value = document.querySelector('.controls select.cmd').value;
    var inputs = document.querySelectorAll('.controls .inputs');
    for (let i = 0; i < inputs.length; i++) {
        if(inputs[i].classList.contains(value)){
            inputs[i].style = 'display: block';
        }else{
            inputs[i].style = 'display: none';
        }
    }
}
