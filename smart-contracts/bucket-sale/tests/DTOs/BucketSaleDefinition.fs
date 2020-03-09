namespace Foundry.Contracts.BucketSale.ContractDefinition

open System
open System.Threading.Tasks
open System.Collections.Generic
open System.Numerics
open Nethereum.Hex.HexTypes
open Nethereum.ABI.FunctionEncoding.Attributes
open Nethereum.Web3
open Nethereum.RPC.Eth.DTOs
open Nethereum.Contracts.CQS
open Nethereum.Contracts
open System.Threading

    
    
    type BucketSaleDeployment(byteCode: string) =
        inherit ContractDeploymentMessage(byteCode)
        
        static let BYTECODE = "0x608060405234801561001057600080fd5b506040516117af3803806117af833981810160405260e081101561003357600080fd5b810190808051906020019092919080519060200190929190805190602001909291908051906020019092919080519060200190929190805190602001909291908051906020019092919050505086600360006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055508560048190555084600581905550836006819055508260078190555081600960006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555080600a60006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055505050505050505061163a806101756000396000f3fe608060405234801561001057600080fd5b5060043610610133576000357c01000000000000000000000000000000000000000000000000000000009004806397b2fd45116100bf578063c2f5673e1161008e578063c2f5673e1461041e578063c4aaeb1a1461043c578063cbc431991461045a578063cff40759146104d2578063f838b8251461052057610133565b806397b2fd45146103485780639b51fb0d146103a0578063a03effd1146103e2578063b80777ea1461040057610133565b80634f127aae116101065780634f127aae1461022057806360e6a4401461023e57806361d027b31461028857806389ce96c6146102d25780639361265f146102f057610133565b80633261933d1461013857806342f2b6ec1461015657806347e3baaa146101b85780634b42442e14610202575b600080fd5b610140610589565b6040518082815260200191505060405180910390f35b6101a26004803603604081101561016c57600080fd5b8101908080359060200190929190803573ffffffffffffffffffffffffffffffffffffffff1690602001909291905050506105a6565b6040518082815260200191505060405180910390f35b6101c061064a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b61020a610670565b6040518082815260200191505060405180910390f35b610228610676565b6040518082815260200191505060405180910390f35b6102466106ad565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b6102906106d3565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b6102da6106f9565b6040518082815260200191505060405180910390f35b6103326004803603602081101561030657600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff1690602001909291905050506106ff565b6040518082815260200191505060405180910390f35b61038a6004803603602081101561035e57600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff1690602001909291905050506107e5565b6040518082815260200191505060405180910390f35b6103cc600480360360208110156103b657600080fd5b81019080803590602001909291905050506107fd565b6040518082815260200191505060405180910390f35b6103ea61081b565b6040518082815260200191505060405180910390f35b610408610821565b6040518082815260200191505060405180910390f35b610426610829565b6040518082815260200191505060405180910390f35b61044461082f565b6040518082815260200191505060405180910390f35b6104d06004803603608081101561047057600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff1690602001909291908035906020019092919080359060200190929190803573ffffffffffffffffffffffffffffffffffffffff169060200190929190505050610835565b005b61051e600480360360408110156104e857600080fd5b8101908080359060200190929190803573ffffffffffffffffffffffffffffffffffffffff169060200190929190505050610cec565b005b61056c6004803603604081101561053657600080fd5b8101908080359060200190929190803573ffffffffffffffffffffffffffffffffffffffff169060200190929190505050611082565b604051808381526020018281526020019250505060405180910390f35b60006105a1600a6103e86110b390919063ffffffff16565b905090565b600080600080858152602001908152602001600020905060006001600086815260200190815260200160002060008573ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000209050610640826000015461063283600001546006546110b390919063ffffffff16565b61113990919063ffffffff16565b9250505092915050565b600a60009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b60085481565b60006106a860055461069a60045461068c610821565b61118390919063ffffffff16565b61113990919063ffffffff16565b905090565b600960009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b600360009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b60065481565b60008073ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff16141561073e57600090506107e0565b600061079a670de0b6b3a7640000600260008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000205461113990919063ffffffff16565b905060006107c66107b7600a6103e86110b390919063ffffffff16565b836111cd90919063ffffffff16565b905060006107d7620186a083611255565b90508093505050505b919050565b60026020528060005260406000206000915090505481565b60006020528060005260406000206000915090508060000154905081565b60045481565b600042905090565b60075481565b60055481565b61084083858461126e565b61089282600260008473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020546111cd90919063ffffffff16565b600260008373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020819055506000600a60009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166323b872dd33600360009054906101000a900473ffffffffffffffffffffffffffffffffffffffff16866040518463ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401808473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020018373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020018281526020019350505050602060405180830381600087803b1580156109f257600080fd5b505af1158015610a06573d6000803e3d6000fd5b505050506040513d6020811015610a1c57600080fd5b8101908080519060200190929190505050905080610aa2576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260158152602001807f656e746572207472616e73666572206661696c6564000000000000000000000081525060200191505060405180910390fd5b600073ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff1614610c31576000610b07620186a0610af9610aea610589565b876110b390919063ffffffff16565b61113990919063ffffffff16565b90506000610b3b620186a0610b2d610b1e876106ff565b886110b390919063ffffffff16565b61113990919063ffffffff16565b9050610b5b610b546001886111cd90919063ffffffff16565b888461126e565b610b79610b726001886111cd90919063ffffffff16565b858361126e565b8373ffffffffffffffffffffffffffffffffffffffff168773ffffffffffffffffffffffffffffffffffffffff167f161e0456cd3270520befa83f5fdd74084ad38cd70a096dcf24ccf7edc368b04f3389898787604051808673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020018581526020018481526020018381526020018281526020019550505050505060405180910390a35050610ce5565b600073ffffffffffffffffffffffffffffffffffffffff168573ffffffffffffffffffffffffffffffffffffffff167f161e0456cd3270520befa83f5fdd74084ad38cd70a096dcf24ccf7edc368b04f338787600080604051808673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020018581526020018481526020018381526020018281526020019550505050505060405180910390a35b5050505050565b610cf4610676565b8210610d4b576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260248152602001806115bf6024913960400191505060405180910390fd5b60006001600084815260200190815260200160002060008373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002090506000816000015411610dfc576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260238152602001806115e36023913960400191505060405180910390fd5b6000816001015414610e76576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260118152602001807f616c72656164792077697468647261776e00000000000000000000000000000081525060200191505060405180910390fd5b610e8083836105a6565b8160010181905550610ea181600101546008546111cd90919063ffffffff16565b6008819055506000600960009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166340c10f198484600101546040518363ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401808373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200182815260200192505050602060405180830381600087803b158015610f7257600080fd5b505af1158015610f86573d6000803e3d6000fd5b505050506040513d6020811015610f9c57600080fd5b8101908080519060200190929190505050905080611022576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260148152602001807f65786974207472616e73666572206661696c656400000000000000000000000081525060200191505060405180910390fd5b8273ffffffffffffffffffffffffffffffffffffffff167f0808b45a422e0acd47a625c74fff3eb8d6d4dd063e0845deb1e57581c27b32f5858460010154604051808381526020018281526020019250505060405180910390a250505050565b6001602052816000526040600020602052806000526040600020600091509150508060000154908060010154905082565b6000808314156110c65760009050611133565b60008284029050828482816110d757fe5b041461112e576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252602181526020018061157b6021913960400191505060405180910390fd5b809150505b92915050565b600061117b83836040518060400160405280601a81526020017f536166654d6174683a206469766973696f6e206279207a65726f0000000000008152506113f4565b905092915050565b60006111c583836040518060400160405280601e81526020017f536166654d6174683a207375627472616374696f6e206f766572666c6f7700008152506114ba565b905092915050565b60008082840190508381101561124b576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601b8152602001807f536166654d6174683a206164646974696f6e206f766572666c6f77000000000081525060200191505060405180910390fd5b8091505092915050565b60008183106112645781611266565b825b905092915050565b611276610676565b8310156112eb576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260198152602001807f63616e6e6f7420656e7465722070617374206275636b6574730000000000000081525060200191505060405180910390fd5b6007548310611345576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252602381526020018061159c6023913960400191505060405180910390fd5b60006001600085815260200190815260200160002060008473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002090506113b08282600001546111cd90919063ffffffff16565b8160000181905550600080600086815260200190815260200160002090506113e58382600001546111cd90919063ffffffff16565b81600001819055505050505050565b600080831182906114a0576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825283818151815260200191508051906020019080838360005b8381101561146557808201518184015260208101905061144a565b50505050905090810190601f1680156114925780820380516001836020036101000a031916815260200191505b509250505060405180910390fd5b5060008385816114ac57fe5b049050809150509392505050565b6000838311158290611567576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825283818151815260200191508051906020019080838360005b8381101561152c578082015181840152602081019050611511565b50505050905090810190601f1680156115595780820380516001836020036101000a031916815260200191505b509250505060405180910390fd5b506000838503905080915050939250505056fe536166654d6174683a206d756c7469706c69636174696f6e206f766572666c6f77696e76616c6964206275636b65742069642d2d7061737420656e64206f662073616c6563616e206f6e6c7920657869742066726f6d20636f6e636c75646564206275636b65747363616e27742074616b65206f757420696620796f75206469646e27742070757420696ea265627a7a7231582028b1e411419c619046109b16cc1484d6814ffb558739df25e32af6dd1433c05e64736f6c63430005100032"
        
        new() = BucketSaleDeployment(BYTECODE)
        
            [<Parameter("address", "_treasury", 1)>]
            member val public Treasury = Unchecked.defaultof<string> with get, set
            [<Parameter("uint256", "_startOfSale", 2)>]
            member val public StartOfSale = Unchecked.defaultof<BigInteger> with get, set
            [<Parameter("uint256", "_bucketPeriod", 3)>]
            member val public BucketPeriod = Unchecked.defaultof<BigInteger> with get, set
            [<Parameter("uint256", "_bucketSupply", 4)>]
            member val public BucketSupply = Unchecked.defaultof<BigInteger> with get, set
            [<Parameter("uint256", "_bucketCount", 5)>]
            member val public BucketCount = Unchecked.defaultof<BigInteger> with get, set
            [<Parameter("address", "_tokenOnSale", 6)>]
            member val public TokenOnSale = Unchecked.defaultof<string> with get, set
            [<Parameter("address", "_tokenSoldFor", 7)>]
            member val public TokenSoldFor = Unchecked.defaultof<string> with get, set
        
    
    [<Function("bucketCount", "uint256")>]
    type BucketCountFunction() = 
        inherit FunctionMessage()
    

        
    
    [<Function("bucketPeriod", "uint256")>]
    type BucketPeriodFunction() = 
        inherit FunctionMessage()
    

        
    
    [<Function("bucketSupply", "uint256")>]
    type BucketSupplyFunction() = 
        inherit FunctionMessage()
    

        
    
    [<Function("buckets", "uint256")>]
    type BucketsFunction() = 
        inherit FunctionMessage()
    
            [<Parameter("uint256", "", 1)>]
            member val public ReturnValue1 = Unchecked.defaultof<BigInteger> with get, set
        
                
    [<FunctionOutput>]
    type BuysOutputDTO() =
        inherit FunctionOuputDTO() 
            [<Parameter("uint256", "valueEntered", 1)>]
            member val public ValueEntered = Unchecked.defaultof<BigInteger> with get, set
            [<Parameter("uint256", "buyerTokensExited", 2)>]
            member val public BuyerTokensExited = Unchecked.defaultof<BigInteger> with get, set


    [<Function("buys", typeof<BuysOutputDTO>)>]
    type BuysFunction() = 
        inherit FunctionMessage()
    
            [<Parameter("uint256", "", 1)>]
            member val public ReturnValue1 = Unchecked.defaultof<BigInteger> with get, set
            [<Parameter("address", "", 2)>]
            member val public ReturnValue2 = Unchecked.defaultof<string> with get, set
        
    
    [<Function("referredTotal", "uint256")>]
    type ReferredTotalFunction() = 
        inherit FunctionMessage()
    
            [<Parameter("address", "", 1)>]
            member val public ReturnValue1 = Unchecked.defaultof<string> with get, set
        
    
    [<Function("startOfSale", "uint256")>]
    type StartOfSaleFunction() = 
        inherit FunctionMessage()
    

        
    
    [<Function("tokenOnSale", "address")>]
    type TokenOnSaleFunction() = 
        inherit FunctionMessage()
    

        
    
    [<Function("tokenSoldFor", "address")>]
    type TokenSoldForFunction() = 
        inherit FunctionMessage()
    

        
    
    [<Function("totalExitedTokens", "uint256")>]
    type TotalExitedTokensFunction() = 
        inherit FunctionMessage()
    

        
    
    [<Function("treasury", "address")>]
    type TreasuryFunction() = 
        inherit FunctionMessage()
    

        
    
    [<Function("timestamp", "uint256")>]
    type TimestampFunction() = 
        inherit FunctionMessage()
    

        
    
    [<Function("currentBucket", "uint256")>]
    type CurrentBucketFunction() = 
        inherit FunctionMessage()
    

        
    
    [<Function("enter")>]
    type EnterFunction() = 
        inherit FunctionMessage()
    
            [<Parameter("address", "_buyer", 1)>]
            member val public Buyer = Unchecked.defaultof<string> with get, set
            [<Parameter("uint256", "_bucketId", 2)>]
            member val public BucketId = Unchecked.defaultof<BigInteger> with get, set
            [<Parameter("uint256", "_amount", 3)>]
            member val public Amount = Unchecked.defaultof<BigInteger> with get, set
            [<Parameter("address", "_referrer", 4)>]
            member val public Referrer = Unchecked.defaultof<string> with get, set
        
    
    [<Function("exit")>]
    type ExitFunction() = 
        inherit FunctionMessage()
    
            [<Parameter("uint256", "_bucketId", 1)>]
            member val public BucketId = Unchecked.defaultof<BigInteger> with get, set
            [<Parameter("address", "_buyer", 2)>]
            member val public Buyer = Unchecked.defaultof<string> with get, set
        
    
    [<Function("buyerReferralRewardPerc", "uint256")>]
    type BuyerReferralRewardPercFunction() = 
        inherit FunctionMessage()
    

        
    
    [<Function("referrerReferralRewardPerc", "uint256")>]
    type ReferrerReferralRewardPercFunction() = 
        inherit FunctionMessage()
    
            [<Parameter("address", "_referrerAddress", 1)>]
            member val public ReferrerAddress = Unchecked.defaultof<string> with get, set
        
    
    [<Function("calculateExitableTokens", "uint256")>]
    type CalculateExitableTokensFunction() = 
        inherit FunctionMessage()
    
            [<Parameter("uint256", "_bucketId", 1)>]
            member val public BucketId = Unchecked.defaultof<BigInteger> with get, set
            [<Parameter("address", "_buyer", 2)>]
            member val public Buyer = Unchecked.defaultof<string> with get, set
        
    
    [<Event("Entered")>]
    type EnteredEventDTO() =
        inherit EventDTO()
            [<Parameter("address", "_sender", 1, false )>]
            member val Sender = Unchecked.defaultof<string> with get, set
            [<Parameter("uint256", "_bucketId", 2, false )>]
            member val BucketId = Unchecked.defaultof<BigInteger> with get, set
            [<Parameter("address", "_buyer", 3, true )>]
            member val Buyer = Unchecked.defaultof<string> with get, set
            [<Parameter("uint256", "_valueEntered", 4, false )>]
            member val ValueEntered = Unchecked.defaultof<BigInteger> with get, set
            [<Parameter("uint256", "_buyerReferralReward", 5, false )>]
            member val BuyerReferralReward = Unchecked.defaultof<BigInteger> with get, set
            [<Parameter("address", "_referrer", 6, true )>]
            member val Referrer = Unchecked.defaultof<string> with get, set
            [<Parameter("uint256", "_referrerReferralReward", 7, false )>]
            member val ReferrerReferralReward = Unchecked.defaultof<BigInteger> with get, set
        
    
    [<Event("Exited")>]
    type ExitedEventDTO() =
        inherit EventDTO()
            [<Parameter("uint256", "_bucketId", 1, false )>]
            member val BucketId = Unchecked.defaultof<BigInteger> with get, set
            [<Parameter("address", "_buyer", 2, true )>]
            member val Buyer = Unchecked.defaultof<string> with get, set
            [<Parameter("uint256", "_tokensExited", 3, false )>]
            member val TokensExited = Unchecked.defaultof<BigInteger> with get, set
        
    
    [<FunctionOutput>]
    type BucketCountOutputDTO() =
        inherit FunctionOuputDTO() 
            [<Parameter("uint256", "", 1)>]
            member val public ReturnValue1 = Unchecked.defaultof<BigInteger> with get, set
        
    
    [<FunctionOutput>]
    type BucketPeriodOutputDTO() =
        inherit FunctionOuputDTO() 
            [<Parameter("uint256", "", 1)>]
            member val public ReturnValue1 = Unchecked.defaultof<BigInteger> with get, set
        
    
    [<FunctionOutput>]
    type BucketSupplyOutputDTO() =
        inherit FunctionOuputDTO() 
            [<Parameter("uint256", "", 1)>]
            member val public ReturnValue1 = Unchecked.defaultof<BigInteger> with get, set
        
    
    [<FunctionOutput>]
    type BucketsOutputDTO() =
        inherit FunctionOuputDTO() 
            [<Parameter("uint256", "totalValueEntered", 1)>]
            member val public TotalValueEntered = Unchecked.defaultof<BigInteger> with get, set
        
    
    [<FunctionOutput>]
    type ReferredTotalOutputDTO() =
        inherit FunctionOuputDTO() 
            [<Parameter("uint256", "", 1)>]
            member val public ReturnValue1 = Unchecked.defaultof<BigInteger> with get, set
        
    
    [<FunctionOutput>]
    type StartOfSaleOutputDTO() =
        inherit FunctionOuputDTO() 
            [<Parameter("uint256", "", 1)>]
            member val public ReturnValue1 = Unchecked.defaultof<BigInteger> with get, set
        
    
    [<FunctionOutput>]
    type TokenOnSaleOutputDTO() =
        inherit FunctionOuputDTO() 
            [<Parameter("address", "", 1)>]
            member val public ReturnValue1 = Unchecked.defaultof<string> with get, set
        
    
    [<FunctionOutput>]
    type TokenSoldForOutputDTO() =
        inherit FunctionOuputDTO() 
            [<Parameter("address", "", 1)>]
            member val public ReturnValue1 = Unchecked.defaultof<string> with get, set
        
    
    [<FunctionOutput>]
    type TotalExitedTokensOutputDTO() =
        inherit FunctionOuputDTO() 
            [<Parameter("uint256", "", 1)>]
            member val public ReturnValue1 = Unchecked.defaultof<BigInteger> with get, set
        
    
    [<FunctionOutput>]
    type TreasuryOutputDTO() =
        inherit FunctionOuputDTO() 
            [<Parameter("address", "", 1)>]
            member val public ReturnValue1 = Unchecked.defaultof<string> with get, set
        
    
    [<FunctionOutput>]
    type TimestampOutputDTO() =
        inherit FunctionOuputDTO() 
            [<Parameter("uint256", "_now", 1)>]
            member val public Now = Unchecked.defaultof<BigInteger> with get, set
        
    
    [<FunctionOutput>]
    type CurrentBucketOutputDTO() =
        inherit FunctionOuputDTO() 
            [<Parameter("uint256", "", 1)>]
            member val public ReturnValue1 = Unchecked.defaultof<BigInteger> with get, set
        
    
    
    
    
    
    [<FunctionOutput>]
    type BuyerReferralRewardPercOutputDTO() =
        inherit FunctionOuputDTO() 
            [<Parameter("uint256", "", 1)>]
            member val public ReturnValue1 = Unchecked.defaultof<BigInteger> with get, set
        
    
    [<FunctionOutput>]
    type ReferrerReferralRewardPercOutputDTO() =
        inherit FunctionOuputDTO() 
            [<Parameter("uint256", "", 1)>]
            member val public ReturnValue1 = Unchecked.defaultof<BigInteger> with get, set
        
    
    [<FunctionOutput>]
    type CalculateExitableTokensOutputDTO() =
        inherit FunctionOuputDTO() 
            [<Parameter("uint256", "", 1)>]
            member val public ReturnValue1 = Unchecked.defaultof<BigInteger> with get, set
    

