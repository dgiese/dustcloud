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
                stopLastContactAjax();
                alert("Error: " + xhr.status + ": " + xhr.statusText);
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
    var xhr = new XMLHttpRequest();
    xhr.open('POST', 'api.php?action=map&did=' + did);
    xhr.responseType = 'json';
    xhr.send();
    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            if(xhr.status !== 200){
                stopMapAjax();
                alert("Error: " + xhr.status + ": " + xhr.statusText);
            }else if(xhr.response.error > 0){
                stopMapAjax();
                alert("Error: " + xhr.response.error + ": " + xhr.response.data);
            }else{
                var element = document.querySelector('img.map');
                element.src = 'data:image/png;base64,' + xhr.response.data.imagedata;
            }
        }
    };
}
function stopMapAjax(){
    clearInterval(mapTimer);
}

var dragStarted = false
var offset = {x: -256, y: -256};
var startPos = {x: -256, y: -256};
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
    console.log(startPos);
    console.log(offset);
    element.style = 'transform: translate(' + offset.x + 'px, ' + offset.y + 'px)';

    element.addEventListener('dragstart', function(dragevent){
        dragevent.preventDefault();
    });
    element.addEventListener('mousedown', function(downevent){
        dragStarted = true;
        document.addEventListener('mousemove', move);

    });
    document.addEventListener('mouseup', function(event){
        dragStarted = false;
        document.removeEventListener('mousemove', move)
        if(startPos.x === offset.x && startPos.y === offset.y){
            console.log('set marker');
        }
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
            offset.x = (offset.x < -512) ? -512 : offset.x;
            offset.y = (offset.y < -512) ? -512 : offset.y;
            element.style = 'transform: translate(' + offset.x + 'px, ' + offset.y + 'px)';
        }
    }
}

function initControls(){
    document.querySelector('.controls button').addEventListener('click', function(){
        var loader = document.querySelector('#loader');
        loader.style = 'visibility: visible';
        var button = document.querySelector('.controls button');
        button.setAttribute('disabled', 'disabled');
        var dropdown = document.querySelector('.controls select');
        dropdown.setAttribute('disabled', 'disabled');
        var cmd = document.querySelector('.controls select').value;
        var xhr = new XMLHttpRequest();
        xhr.open('POST', 'api.php?action=device&did=' + did);
        xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        xhr.responseType = 'json';
        xhr.send('cmd=' + cmd);
        xhr.onreadystatechange = function () {
            if (xhr.readyState === 4) {
                loader.style = 'visibility: hidden';
                button.removeAttribute('disabled');
                dropdown.removeAttribute('disabled');
                if(xhr.status !== 200){
                    alert("Error: " + xhr.status + ": " + xhr.statusText);
                }else if(xhr.response === null || xhr.response.error > 0){
                    alert("Error: " + xhr.response.error + ": " + xhr.response.data);
                    document.querySelector('.controls pre').innerHTML = '&nbsp;'
                    document.querySelector('.controls .result').innerHTML = '';
                }else{
                    console.log(xhr.response.data);
                    document.querySelector('.controls pre').innerText = JSON.stringify(xhr.response.data);
                    document.querySelector('.controls .result').innerHTML = xhr.response.html;
                }
            }
        };
    });
}