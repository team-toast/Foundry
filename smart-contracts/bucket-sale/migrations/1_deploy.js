var BucketSale = artifacts.require("BucketSale");
var Scripts = artifacts.require("Scripts");

module.exports = function(deployer) {
    deployer.deploy(Scripts);

    var timestampNow = Math.floor (Date.now() / 1000);
    var sevenHours = 60*60*7;
    var supply50k = 50000 * (10^18);
    FRYAddress = "0x67B5656d60a809915323Bf2C40A8bEF15A152e3e";
    fakeDAIAddress = "0x2612Af3A521c2df9EAF28422Ca335b04AdF3ac66";
    deployer.deploy(BucketSale, "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1", timestampNow, sevenHours, supply50k, 1200, FRYAddress, fakeDAIAddress);
}