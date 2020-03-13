
// goal:
// find both the ip location and the geolocation of the browser and verify they are in the same county

function haversine(point1, point2) {
    toRad = (value) => value * Math.PI / 180;

    var R = 6371; // earth radius in km
    var dLat = toRad(point2.lat - point1.lat);
    var dLon = toRad(point2.lng - point1.lng);
    var lat1 = toRad(point1.lat);
    var lat2 = toRad(point2.lat);

    var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.sin(dLon / 2) * Math.sin(dLon / 2) *
        Math.cos(lat1) * Math.cos(lat2);

    var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

function getJsonPromise(url) {
    return new Promise((resolve, reject) => {
        $.get(url, "json", (response) => resolve(response));
    });
}

function getLocationPromise() {
    return new Promise((resolve, reject) => {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(resolve, reject);
        } else {
            reject();
        }
    });
}

async function duelLocationCheck() {
    // fire off the request to ipgelocation.io so long
    var ipResponseTask = getJsonPromise("https://api.ipgeolocation.io/ipgeo?apiKey=0a44cf721e614b2ba440943b51d9a235");

    // get the browser's location, and fire off a look up for the country code 
    var position = await getLocationPromise();
    var reverseGeoResponseTask = getJsonPromise("https://geocode.xyz/" + position.coords.latitude + "," + position.coords.longitude + "?json=1&auth=933556588498608367442x4952");

    // now wait for the responses
    var ipResponse = await ipResponseTask;
    //console.log(ipResponse);
    var reverseGeoResponse = await reverseGeoResponseTask;
    //console.log(reverseGeoResponse);

    // calculate the results
    var ipLoc = {
        lat: ipResponse.latitude,
        lng: ipResponse.longitude,
        country: ipResponse.country_code2
    };
    //console.log(ipLoc);

    var geoLoc = {
        lat: position.coords.latitude,
        lng: position.coords.longitude,
        country: reverseGeoResponse.prov,
        acc: position.coords.accuracy
    };
    //console.log(geoLoc);

    var distance = haversine(geoLoc, ipLoc);
    var result = {
        ipLocation: ipLoc,
        geoLocation: geoLoc,
        kmDistance: distance,
        countryMatches: ipLoc.country == geoLoc.country,
        country: ipLoc.country == geoLoc.country ? ipLoc.country : "invalid"
    };
    //console.log(result);

    return result;
}

async function displayResults() {
    var result = await duelLocationCheck();
    $("#json").html(JSON.stringify(result, null, 4));
    console.log(result);
}