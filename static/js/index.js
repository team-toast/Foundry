var elm_ethereum_ports = require('elm-ethereum-ports');
var clipboardLib = require('clipboard');
var networkChangeNotifier = require('./networkChangeNotifier');
var locationCheck = require('./dualLocationCheck.js');
var addFryToMetaMask = require('./addFryToMetaMask.js');
require('@metamask/legacy-web3');
 
const { web3 } = window;

import { Elm } from '../../elm/App'

//window.testStuff = secureComms.testStuff;
window.web3Connected = false;

window.addEventListener('load', function () {
    startDapp();
});

function startDapp() {
    var clipboard = new clipboardLib('.link-copy-btn');

    if (typeof web3 !== 'undefined') {
        web3.version.getNetwork(function (e, networkId) {
            var id;
            if (e) {
                console.log("Error initializing web3: " + e);
                id = 0; // 0 indicates no network set by provider
            }
            else {
                id = parseInt(networkId);
            }
            window.app = Elm.App.init({
                node: document.getElementById('elm'),
                flags: {
                    networkId: id,
                    width: window.innerWidth,
                    height: window.innerHeight,
                    nowInMillis: Date.now(),
                    maybeReferralAddressString: getReferralAddressStringFromStorageOrNull()
                }
            });

            gtagPortStuff(app);
            referrerStoragePortStuff(app);
            locationCheckPortStuff(app);
            addFryToMetaMaskStuff(app);
            twitterConversionTrackingPortStuff(app);

            web3PortStuff(app, web3);
        });
    } else {
        window.app = Elm.App.init({
            node: document.getElementById('elm'),
            flags: {
                networkId: 0, // 0 indicates no network set by provider
                width: window.innerWidth,
                height: window.innerHeight,
                nowInMillis: Date.now(),
                maybeReferralAddressString: getReferralAddressStringFromStorageOrNull()
            }
        });

        gtagPortStuff(app);
        referrerStoragePortStuff(app);
        locationCheckPortStuff(app);
        addFryToMetaMaskStuff(app);
        twitterConversionTrackingPortStuff(app);

        console.log("Web3 wallet not detected.");
    }
}

function getReferralAddressStringFromStorageOrNull() {
    if (typeof (Storage) !== "undefined") {
        return localStorage.getItem("referralAddressString");
    }
    else {
        return null;
    }
}

function gtagPortStuff(app) {
    app.ports.gTagOut.subscribe(function (data) {
        gtag('event', data.event, {
            'event_category': data.category,
            'event_label': data.label,
            'value': data.value
        });
    });
}

function referrerStoragePortStuff(app) {
    app.ports.storeReferrerAddress.subscribe(function (data) {
        if (typeof (Storage !== "undefined")) {
            localStorage.setItem("referralAddressString", data);
        }
    });
}

function locationCheckPortStuff(app) {
    app.ports.beginLocationCheck.subscribe(function (data) {
        console.log(locationCheck);
        locationCheck.dualLocationCheckWithCallback(app.ports.locationCheckResult.send);
    });
}

function addFryToMetaMaskStuff(app) {
    app.ports.addFryToMetaMask.subscribe(data => {
        console.log(addFryToMetaMask);
        addFryToMetaMask.addFryToMetaMask();
    });
}

function twitterConversionTrackingPortStuff(app) {
    app.ports.tagTwitterConversion.subscribe(function (amount) {
        console.log("got amount:" + amount);
        !function (e, t, n, s, u, a) {
            e.twq || (s = e.twq = function () {
                s.exe ? s.exe.apply(s, arguments) : s.queue.push(arguments);
            }, s.version = '1.1', s.queue = [], u = t.createElement(n), u.async = !0, u.src = '//static.ads-twitter.com/uwt.js',
                a = t.getElementsByTagName(n)[0], a.parentNode.insertBefore(u, a))
        }(window, document, 'script');
        // Insert Twitter Pixel ID and Standard Event data below
        twq('init', 'o4l06');
        twq('track', 'Purchase', {
            //required parameters
            value: str(amount),
            currency: 'USD',
            num_items: '1',
        });

    })
}

function web3PortStuff(app, web3) {
    prepareWeb3PortsPreConnect(app, web3);

    web3.eth.getAccounts(function (e, res) {
        if (res && res.length > 0) {
            connectAndPrepareRemainingWeb3Ports(app, web3);
        }
    });
}

function prepareWeb3PortsPreConnect(app, web3) {
    networkChangeNotifier.startWatching(app.ports.networkSentryPort, web3);

    app.ports.connectToWeb3.subscribe(function (data) {
        connectAndPrepareRemainingWeb3Ports(app, web3);
    });
}

function connectAndPrepareRemainingWeb3Ports(app, web3) {
    if (window.ethereum && !window.web3Connected) {
        window.web3 = new Web3(ethereum);
    }

    elm_ethereum_ports.txSentry(app.ports.txOut, app.ports.txIn, web3);
    elm_ethereum_ports.walletSentry(app.ports.walletSentryPort, web3);
    networkChangeNotifier.startWatching(app.ports.networkSentryPort, web3);

    if (window.ethereum && !window.web3Connected) {
        ethereum.enable();
        window.web3Connected = true;
    }
}
