require("babel-core/register");
require("babel-polyfill");
require("jquery");

var commonModule = (function() {
    var pub ={};

    class Result {
        constructor(value, error) {
            this.__value = value;
            this.__error = error;
        }
        static Error(error) {
            return Result.of(null, error);
        }
        static of(valueToBox, error) {
            return new Result(valueToBox, error);
        }
        flatMap(fn) {
            if (this.isError()) return Result.Error(this.__error);
            const r = fn(this.__value);
    
            return r.isError() ?
                Result.Error(r.__error) :
                Result.of(r.__value);
        }
        getOrElse(elseVal) {
            return this.isError() ? elseVal : this.__value;
        }
        getOrEmptyArray() {
            return this.getOrElse([]);
        }
        getOrNull() {
            return this.getOrElse(null);
        }
        getError() {
            return this.__error == "" ? { message: "Unknown" } : this.__error;
        }
        getErrorMessage() {
            return { ErrorMessage: this.getError().message }
        }
        isError() {
            return this.__error != null;
        }
        map(fn) {
            return this.isError() ?
                Result.of(null, this.__error) :
                Result.of(fn(this.__value));
        }
    }

    function haversine(point1, point2) {
        toRad = (value) => value * Math.PI / 180;

        var R = 6371; // earth radius in km
        var dLat = toRad(point2.lat - point1.lat);
        var dLon = toRad(point2.lng - point1.lng);
        var lat1 = toRad(point1.lat);
        var lat2 = toRad(point2.lat);

        var a =
            Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.sin(dLon / 2) * Math.sin(dLon / 2) *
            Math.cos(lat1) * Math.cos(lat2);

        var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    function getJsonPromise(url) {
        return new Promise((resolve, reject) => {
            var rej = (a, b, c) => { reject(c); };
            var result = $.get(url, "json").then(resolve, rej);
        });
    }

    function getLocationPromise() {
        return new Promise((resolve, reject) => {
            if (navigator.geolocation)
                navigator.geolocation.getCurrentPosition(resolve, reject);
        });
    }

    async function monadPromise(promise) {
        return await promise.then(result => Result.of(result)).catch(error => Result.Error(error));
    }

    async function beginDualLocationCheck() {
        // fire off the request to ipgelocation.io so long
        var ipResponseTask = getJsonPromise("https://api.ipgeolocation.io/ipgeo?apiKey=0a44cf721e614b2ba440943b51d9a235");

        // get the browser's location, and fire off a look up for the country code 
        var position = await monadPromise(getLocationPromise());
        if (position.isError())
            return position.getErrorMessage();
        var reverseGeoResponseTask = monadPromise(getJsonPromise("https://geocode.xyz/" + position.getOrNull().coords.latitude + "," + position.getOrNull().coords.longitude + "?json=1&auth=933556588498608367442x4952"));

        // now wait for the responses
        var ipResponse = await monadPromise(ipResponseTask);
        if (ipResponse.isError())
            return ipResponse.getErrorMessage();
        //console.log(ipResponse);
        var reverseGeoResponse = await reverseGeoResponseTask;
        if (reverseGeoResponse.isError())
            return reverseGeoResponse.getErrorMessage();
        //console.log(reverseGeoResponse);

        // calculate the results
        var ipLoc = {
            lat: ipResponse.getOrNull().latitude,
            lng: ipResponse.getOrNull().longitude,
            country: ipResponse.getOrNull().country_code2
        };
        //console.log(ipLoc);

        var geoLoc = {
            lat: position.getOrNull().coords.latitude,
            lng: position.getOrNull().coords.longitude,
            country: reverseGeoResponse.getOrNull().prov,
            acc: position.getOrNull().coords.accuracy
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

    pub.dualLocationCheckWithCallback = async function (callback) {
        callback(await beginDualLocationCheck());
    }

    return pub;
})();

module.exports = commonModule;