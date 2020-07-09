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
        // get the browser's location
        var position = await monadPromise(getLocationPromise());
        if (position.isError())
            return position.getErrorMessage();

        // ask our service for the country codes
        var countryResponse = await monadPromise(getJsonPromise("https://personal-rxyx.outsystemscloud.com/SaleFeedbackUI/rest/General/CountryLookup?lat=" + position.getOrNull().coords.latitude + "&long=" + position.getOrNull().coords.longitude))
        if (countryResponse.isError())
            return countryResponse.getErrorMessage();

        console.log("country response:", countryResponse.getOrNull());

        // calculate the results
        var ipLoc = {
            country: countryResponse.getOrNull().IPCountryCode
        };
        console.log("fetched IP location: ", ipLoc);

        var geoLoc = {
            lat: position.getOrNull().coords.latitude,
            lng: position.getOrNull().coords.longitude,
            country: countryResponse.getOrNull().LocationCoutryCode,
            acc: position.getOrNull().coords.accuracy
        };
        console.log("geo location: ", geoLoc);

        var result = {
            ipLocation: ipLoc,
            geoLocation: geoLoc,
            countryMatches: ipLoc.country == geoLoc.country,
            ipCountry: ipLoc.country,
            geoCountry: geoLoc.country,
            errorMessage: countryResponse.getOrNull().ErrorMessage
        };
        console.log("result: ", result);

        return result;
    }

    pub.dualLocationCheckWithCallback = async function (callback) {
        callback(await beginDualLocationCheck());
    }

    return pub;
})();

module.exports = commonModule;