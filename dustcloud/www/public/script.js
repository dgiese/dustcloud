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

const mapsize = {x: 2048, y: 2048};
const mapfactor = 2;
var mapTimer;
function startMapAjax(){
    mapTimer = window.setInterval(mapAjax, 5000);
    mapAjax();
}

var routeTimer;
var latestRouteTs = 0;
var prevDrawingPos = {x: false, y: false};
var mapCanvas;
var mapCanvasContext;
function startRouteAjax(){
    mapCanvas = document.querySelector('#mapcanvas');
    mapCanvasContext = mapCanvas.getContext('2d');
    
    routeTimer = window.setInterval(routeAjax, 1000);
    routeAjax(true);
}

function routeAjax(full = false){
    var xhr = new XMLHttpRequest();
    xhr.open('POST', 'api.php?action=' + (full ? 'full' : '') + 'route&did=' + did);
    xhr.responseType = 'json';
    xhr.send();
    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            if(xhr.status === 200){
                if(xhr.response && xhr.response.data.length > 0){
                    if(parseInt(xhr.response.reset) > latestRouteTs){
                        console.log('reset');
                        mapCanvasContext.clearRect(0, 0, mapsize.x, mapsize.y);
                        latestRouteTs = xhr.response.reset;
                        routeAjax(true);
                    }else{
                        drawRoute(xhr.response.data);
                    }
                }
            }
        }
    };
}

function drawRoute(data){
    mapCanvasContext.beginPath();
    var found = false;
    for (let i = 0; i < data.length; i++) {
        const element = data[i];
        // *20 for correct scaling; y/x swapped +/- 512 for shifting to correct position
        const x = mapsize.x/2 + (element.y * 20 * mapfactor);
        const y = mapsize.y/2 - (element.x * 20 * mapfactor);
        if(parseInt(element.t) > latestRouteTs){
            if(found === false && prevDrawingPos.x === false && prevDrawingPos.y === false){
                mapCanvasContext.moveTo(x, y);
                found = true;
            }else if(found === false){
                mapCanvasContext.moveTo(prevDrawingPos.x, prevDrawingPos.y);
                mapCanvasContext.lineTo(x, y);
                found = true;
            }else{
                mapCanvasContext.lineTo(x, y);
                found = true;
            }
        }
        prevDrawingPos.x = x;
        prevDrawingPos.y = y;
    }

    mapCanvasContext.strokeStyle = "red";
    mapCanvasContext.lineWidth = 2;
    mapCanvasContext.stroke();
    latestRouteTs = parseInt(data[data.length - 1].t);
}

function mapAjax(){
    var img = document.querySelector('div.map img');
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
                status.style = 'display: block';
                if(xhr.status !== 0){
                    stopMapAjax();
                    alert("Error: " + xhr.status + ": " + xhr.statusText);
                }
            }else if(!xhr.response || xhr.response.error > 0){
                img.src = 'about:blank';
                status.innerText = 'No map available';
                status.style = 'display: block';
                if(xhr.response.data != "No map available"){
                    stopMapAjax();
                    alert("Error: " + xhr.response.error + ": " + xhr.response.data);
                }
            }else{
                status.innerText = '';
                status.style = 'display: none';
                img.src = 'data:image/png;base64,' + xhr.response.data.imagedata;
            }
        }
    };
}
function stopMapAjax(){
    clearInterval(mapTimer);
}

var statusTimer;
function startStatusAjax(){
    statusTimer = window.setInterval(statusAjax, 1000);
    statusAjax();
}
function statusAjax(){
    var container = document.querySelector('div.content.status .statuswrapper');
    var xhr = new XMLHttpRequest();
    xhr.open('POST', 'api.php?action=status&did=' + did);
    xhr.responseType = 'json';
    xhr.send();
    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            if(xhr.status !== 200){
                container.innerHTML = "";
                if(xhr.status !== 0){
                    stopMapAjax();
                    alert("Error: " + xhr.status + ": " + xhr.statusText);
                }
            }else if(!xhr.response || xhr.response.error > 0){
                container.innerHTML = "";
            }else{
                container.innerHTML = xhr.response.html;
            }
        }
    };
}

var dragStarted = false
var offset =   {x: (mapsize.x/-4), y: (mapsize.y/-4)};
var startPos = {x: (mapsize.x/-4), y: (mapsize.y/-4)};
function initMapDrag(){
    var element = document.querySelector('div.map');

    if(parseInt(localStorage.mapPosX)){
        startPos.x = parseInt(localStorage.mapPosX);
        offset.x = parseInt(localStorage.mapPosX);
    }
    if(parseInt(localStorage.mapPosY)){
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
    document.addEventListener('mouseup', moveEnd);

    element.addEventListener('touchstart', function(downevent){
        dragStarted = true;
        document.addEventListener('touchmove', move);
    });
    document.addEventListener('touchend', moveEnd);
    
    function moveEnd(event){
        document.removeEventListener('mousemove', move);
        document.removeEventListener('touchmove', move);
        if(startPos.x === offset.x && startPos.y === offset.y && dragStarted === true){
            console.log('set marker');
        }
        dragStarted = false;
        startPos.x = offset.x;
        startPos.y = offset.y;
        localStorage.mapPosX = parseInt(offset.x);
        localStorage.mapPosY = parseInt(offset.y);
    };

    function move(event){
        if(dragStarted){
            offset.x += event.movementX;
            offset.y += event.movementY;
            offset.x = (offset.x > 0) ? 0 : offset.x;
            offset.y = (offset.y > 0) ? 0 : offset.y;
            offset.x = (offset.x < (mapsize.x/-2)) ? (mapsize.x/-2) : offset.x;
            offset.y = (offset.y < (mapsize.y/-2)) ? (mapsize.x/-2) : offset.y;
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
