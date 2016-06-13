// Write your Javascript code.
var map;
var infowindow;
var searchCircle;
var geocoder;
var position;

function initMap() {
    var mapProp = {
        //center: position,
        center: { lat: -34.9835, lng: 138.1415 },
        zoom: 8,
        mapTypeId: google.maps.MapTypeId.ROADMAP
    };
    map = new google.maps.Map(document.getElementById("googleMap"), mapProp);
}

function findSharedImages(lat, lng) {
    infowindow.close();
    $.getJSON('../Query/Geo?lat=' + lat + '&lng=' + lng + '&distance=' + Math.round(searchCircle.radius) + 'm&options=' + $("#ChosenOptions").val(), function (data) {
        google.maps.Map.prototype.clearMarkers = function () {
            for (var i = 0; i < this.markers.length; i++) {
                this.markers[i].setMap(null);
            }
            //this.markers = new Array();
        };
        gmarkers = [];
        $.each(data, function (i, item) {
            //console.log("lat:" + item.lat + " lng:" + item.lng + "body:"+item.body);
            var marker = new google.maps.Marker({
                position: { lat: item.lat, lng: item.lng },
                map: map,
                icon: "~/images/icon46.png", //baseUrl +   http://maps.google.com/mapfiles/kml/pal4/icon46.png "http://maps.google.com/mapfiles/marker_purple.png",
                //shape: shape,
                body: item.body,
                id: item.id
                //,zIndex: beach[3]
            });

            google.maps.event.addListener(marker, 'click', function () {
                infowindow.setContent('<a title="navigate to file details" href="@Url.ContentAbsUrl("~/")Query/Details/?schema=shared&itemId=' + marker.id + '&queryId=0">Details:' + marker.id + '</a><br/>'
                    + marker.body);
                infowindow.open(map, marker);
            });
            gmarkers.push(marker);
        });
        var markerCluster = new MarkerClusterer(map, gmarkers);
    });
    event.preventDefault();
}

function LoadInitialPosition(position) {
    infowindow = new google.maps.InfoWindow({
        content: '<div id="infocontent" >You are here.<br/>Drag marker where you need.<br/><button type="button" onclick="findSharedImages(' + position.lat().toFixed(6) + ',' + position.lng().toFixed(6) + ')">Find here</button></div>'
    });

    var mapProp = {
        center: position,
        zoom: 8,
        mapTypeId: google.maps.MapTypeId.ROADMAP
    };
    map = new google.maps.Map(document.getElementById("googleMap"), mapProp);

    /*var marker = new google.maps.Marker({
        map: map,
        draggable: true,
        position: position,
        animation: google.maps.Animation.DROP, //DROP|BOUNCE
        icon: "http://maps.google.com/mapfiles/marker_green.png", //http://kml4earth.appspot.com/icons.html
        title: 'Click me!'
    });*/

    searchCircle = new google.maps.Circle({
        strokeColor: '#FF0000',
        strokeOpacity: 0.8,
        strokeWeight: 2,
        fillColor: '#FF0000',
        fillOpacity: 0.05,
        map: map,
        center: position,
        radius: 20000, //position.coords.accuracy * 200,
        draggable: true,
        geodesic: true,
        editable: true
    });

    //map.addListener('zoom_changed', function () {
    //    //infowindow.setContent('Zoom: ' + map.getZoom());
    //    searchCircle.setRadius((20 - map.getZoom()) * 2000);
    //    console.log(map.getZoom() + " " + searchCircle.radius);
    //});

    //var bounds = new google.maps.LatLngBounds(
    //      new google.maps.LatLng(position.lat - 10, position.lng - 10),
    //      new google.maps.LatLng(position.lat + 1, position.lng + 1)
    //  );
    //var rectangle = new google.maps.Rectangle({
    //    bounds: bounds,
    //    editable: true,
    //    draggable: true,
    //    geodesic: true
    //});

    //var panorama = new google.maps.StreetViewPanorama(document.getElementById("infocontent"), {
    //    navigationControl: true,
    //    navigationControlOptions: { style: google.maps.NavigationControlStyle.ANDROID },
    //    enableCloseButton: false,
    //    addressControl: false,
    //    linksControl: false
    //});
    //panorama.bindTo("position", marker);

    //var panorama = new google.maps.StreetViewPanorama(
    //    document.getElementById('infocontent'), {
    //        position: marker.position,
    //        pov: {
    //            heading: 34,
    //            pitch: 10
    //    }
    //});
    //map.setStreetView(panorama);
    google.maps.event.addListener(searchCircle, 'click', function (ev) {
        if (infowindow != null) {
            infowindow.setPosition(searchCircle.center) //ev.latLng
            infowindow.open(map, searchCircle);
        }
        //panorama.open();
    });

    google.maps.event.addListener(searchCircle, 'dragend', function (ev) {
        //var position = searchCircle.getPosition();
        //searchCircle.center = position;
        var position = searchCircle.center;
        infowindow.setPosition(position); //ev.latLng
        geocoder.geocode({ 'latLng': position }, function (results, status) {
            var searchText = "Latitide: " + position.lat().toFixed(6) + "<br/>Longitude: " + position.lng().toFixed(6) + '<br/>Radius=' + Math.round(searchCircle.radius/1000) +'km';
            if (status == google.maps.GeocoderStatus.OK) {
                if (results[0]) {
                    searchText += "<br/>Address: " + results[0].formatted_address;
                    searchText += "<br/><button type='button' onclick='findSharedImages(" + position.lat().toFixed(6) + "," + position.lng().toFixed(6) + ")'>Find here</button>";
                    infowindow.setContent(searchText);
                };
            }
        });
    });
}

$(document).ready(function () {
    $('#QueryLabel').hide();
    $('#QueryTerm').show();
    $('#QueryTerm').focus();
    $('#QueryTerm').on({
        change: function () {
            //console.log('address is changed');
            if (typeof map != 'undefined')
            {
                if (map != null && geocoder != null) {
                    if ($(this).val() != "") {
                        geocoder.geocode({ 'address': $(this).val() }, function (results, status) {
                            if (status == google.maps.GeocoderStatus.OK) {
                                //console.log('address is ok');
                                if (results[0]) {
                                    LoadInitialPosition(new google.maps.LatLng(results[0].geometry.location.lat(), results[0].geometry.location.lng()));
                                }
                            }
                        });
                    }
                }
            }
        }/*, --autocomplete
        input: function () {
        }*/
    });

    $("#MapsTab").click(function () {
        if (map == null) {

            //var gmarkers = [];
            geocoder = new google.maps.Geocoder();
            /*var imageFlag = {
                url: baseUrl + 'Content/Images/star-on.png',
                // This marker is 20 pixels wide by 32 pixels high.
                size: new google.maps.Size(20, 32)//,
                // The origin for this image is (0, 0).
                //origin: new google.maps.Point(0, 0),
                // The anchor for this image is the base of the flagpole at (0, 32).
                //anchor: new google.maps.Point(0, 32)
            };*/
            geocoder.geocode({ 'address': $('#QueryTerm').val() }, function (results, status) {
                if (status == google.maps.GeocoderStatus.OK) {
                    //console.log('address is ok');
                    if (results[0]) {
                        LoadInitialPosition(new google.maps.LatLng(results[0].geometry.location.lat(), results[0].geometry.location.lng()));
                    }
                    else if (navigator && navigator.geolocation) {
                        navigator.geolocation.getCurrentPosition(function (position) {
                            LoadInitialPosition(new google.maps.LatLng(position.coords.latitude, position.coords.longitude));
                        });
                    }
                    else {
                        console.log("Geolocation is not supported/allowed by this browser.");
                    };
                }
                else if (navigator && navigator.geolocation) {
                    //console.log('address is not ok');
                    navigator.geolocation.getCurrentPosition(function (position) {
                        LoadInitialPosition(new google.maps.LatLng(position.coords.latitude, position.coords.longitude));
                    });
                }
                else {
                    console.log("Geolocation is not supported/allowed by this browser.");
                };
            });


            //google.maps.event.addDomListener(window, 'load', initialize);

            /*$("#btnFindSharedImages").click(function (event) {
                event.preventDefault();
                console.log("btnFindSharedImages pressed");
                var position = marker.getPosition();
                var searchText = "Latitide: " + position.lat().toFixed(6) + "<br/>Longitude: " + position.lng().toFixed(6);
                console.log(searchText);
                $('#QueryTerm').val(searchText);
            });*/

        }
    });

    //setTimeout(function () {
    //    initMap();
    //}, 0);

    //$(".card").flip({
    //    axis: 'y',
    //    trigger: "click"
    //});

    //$("#card").flip({
    //    trigger: 'manual'
    //});

    //$("#flip-btn").click(function () {
    //    $("#card").flip(true);
    //});

    //$("#unflip-btn").click(function () {
    //    $("#card").flip(false);
    //});
});
