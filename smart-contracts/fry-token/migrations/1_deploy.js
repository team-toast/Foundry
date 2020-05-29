var FRY = artifacts.require("FRY");
var FakeDAI = artifacts.require("FakeDAI");

module.exports = function(deployer) {
    deployer.deploy(FRY, "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1","0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1","0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1");
    deployer.deploy(FakeDAI, "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1");
}