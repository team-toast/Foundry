require("babel-core/register");
require("babel-polyfill");
require("jquery");

var commonModule = (function() {
    var pub ={};

    const tokenAddress = '0x6c972b70c533E2E045F333Ee28b9fFb8D717bE69';
    const tokenSymbol = 'FRY';
    const tokenDecimals = 18;
    const tokenImage = 'https://foundrydao.com/common-assets/img/fry-icon.png';

    pub.addFryToMetaMask = () =>
    {
        ethereum.sendAsync(
            {
                method: 'wallet_watchAsset',
                params: {
                    type: 'ERC20',
                    options: {
                        address: tokenAddress,
                        symbol: tokenSymbol,
                        decimals: tokenDecimals,
                        image: tokenImage,
                    },
                },
                id: 1,
            },
            (err, added) => {
                if (added) {
                    console.log('FRY token added to wallet');
                } else {
                    console.log('FRY token not added to wallet');
                }
            }
        );
    }

    return pub;
})();

module.exports = commonModule;