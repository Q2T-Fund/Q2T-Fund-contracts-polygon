//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./gsn/BaseRelayRecipient.sol";

import "./ILendingPoolAddressesProvider.sol";
import "./ILendingPool.sol";
import "./IAToken.sol";
import "./IFiatTokenV2.sol";
import "./ICommunityTreasury.sol";

import "./DITOToken.sol";
import "./WadRayMath.sol";

/**
 * @title DistributedTown Community
 *
 * @dev Implementation of the Community concept in the scope of the DistributedTown project
 * @author DistributedTown
 */
contract Community is BaseRelayRecipient, Ownable {
    string public override versionRecipient = "2.0.0";

    using SafeMath for uint256;
    using WadRayMath for uint256;

    struct UsdcData {
        uint256 validAfter;
        uint256 validBefore;
        bytes32 nonce;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /**
     * @dev emitted when a member is added
     * @param _member the user which just joined the community
     * @param _transferredTokens the amount of transferred dito tokens on join
     **/
    event MemberAdded(address _member, uint256 _transferredTokens);
    /**
     * @dev emitted when a member leaves the community
     * @param _member the user which just left the community
     **/
    event MemberRemoved(address _member);

    //Aave Lending Pool Addresses Provider address
    address public constant LENDING_POOL_AP = 0x88757f2f99175387aB4C6a4b3067c77A695b0349; //kovan
    uint256 public constant INIT_TOKENS = 96000;
    
    // The address of the DITOToken ERC20 contract
    DITOToken public tokens;

    string public name;
    mapping(address => bool) public enabledMembers;
    uint256 public numberOfMembers;
    mapping(string => address) public depositableCurrenciesContracts;
    mapping(string => address) public depositableACurrenciesContracts;
    string[] public depositableCurrencies;
    ICommunityTreasury public communityTreasury;
    address public gigManager;

    modifier onlyEnabledCurrency(string memory _currency) {
        require(
            depositableCurrenciesContracts[_currency] != address(0),
            "The currency passed as an argument is not enabled, sorry!"
        );
        _;
    }

    // Get the forwarder address for the network
    // you are using from
    // https://docs.opengsn.org/gsn-provider/networks.html
    // 0x25CEd1955423BA34332Ec1B60154967750a0297D is ropsten's one
    constructor(string memory _name, address _forwarder) public {
        name = _name;
        trustedForwarder = _forwarder;
        gigManager = _msgSender();

        tokens = new DITOToken(INIT_TOKENS.mul(1e18));

        depositableCurrencies.push("DAI");
        depositableCurrencies.push("USDC");

        //kovan
        depositableCurrenciesContracts["DAI"] = address(
            0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD
        );
        depositableCurrenciesContracts["USDC"] = address(
            0xe22da380ee6B445bb8273C81944ADEB6E8450422
        );

        depositableACurrenciesContracts["DAI"] = address(
            0xdCf0aF9e59C002FA3AA091a46196b37530FD48a8
        );
    }

    function setTreasury(address _treasury) public onlyOwner {
        require(_treasury != address(0), "Cannot set treasury to 0");
        
        if (address(communityTreasury) != address(0)) {
            _leave(address(communityTreasury));
        }
        communityTreasury = ICommunityTreasury(_treasury);
        _join(address(_treasury), 2000);
    }

    /**
     * @dev makes the calling user join the community if required conditions are met
     * @param _amountOfDITOToRedeem the amount of dito tokens for which this user is eligible
     **/
     function join(uint256 _amountOfDITOToRedeem) public {
         _join(_msgSender(), _amountOfDITOToRedeem);
     }

    function _join(address _member, uint256 _amountOfDITOToRedeem) internal {
        require(address(communityTreasury) != address(0), "Community treasury is not set");
        require(numberOfMembers < 25, "There are already 24 members, sorry!"); //1st member is community treasure so there can actually be 25 members
        require(enabledMembers[_member] == false, "You already joined!");

        enabledMembers[_member] = true;
        numberOfMembers = numberOfMembers.add(1);
        tokens.addToWhitelist(_member);

        tokens.transfer(_member, _amountOfDITOToRedeem.mul(1e18));

        emit MemberAdded(_member, _amountOfDITOToRedeem);
    }

    /**
     * @dev makes the calling user leave the community if required conditions are met
     **/
    function leave() public {
        _leave(_msgSender());
    }

    function _leave(address _member) private {
        require(enabledMembers[_member] == true, "You didn't even join!");

        enabledMembers[_member] = false;
        numberOfMembers = numberOfMembers.sub(1);

        // leaving user must first give allowance
        // then can call this
        tokens.transferFrom(
            _member,
            address(this),
            tokens.balanceOf(_member)
        );

        tokens.removeFromWhitelist(_member);

        emit MemberRemoved(_member);
    }

    /**
     * @dev makes the calling user deposit funds in the community if required conditions are met
     * @param _amount number of currency which the user wants to deposit
     * @param _currency currency the user wants to deposit (as of now only DAI and USDC)
     * @param _optionalSignatureInfo abiEncoded data in order to make USDC2 gasless transactions
     **/
    function deposit(
        uint256 _amount,
        string memory _currency,
        bytes memory _optionalSignatureInfo
    ) public onlyEnabledCurrency(_currency) {
        address msgSender = _msgSender();
        require(
            enabledMembers[msgSender] == true,
            "You can't deposit if you're not part of the community!"
        );

        address currencyAddress = address(
            depositableCurrenciesContracts[_currency]
        );
        IERC20 currency = IERC20(currencyAddress);
        require(
            currency.balanceOf(msgSender) >= _amount.mul(1e18),
            "You don't have enough funds to invest."
        );

        bytes32 currencyStringHash = keccak256(bytes(_currency));

        if (currencyStringHash == keccak256(bytes("DAI"))) {
            currency.transferFrom(msgSender, address(this), _amount.mul(1e18));
        } else if (currencyStringHash == keccak256(bytes("USDC"))) {
            UsdcData memory usdcData;
            (
                usdcData.validAfter,
                usdcData.validBefore,
                usdcData.nonce,
                usdcData.v,
                usdcData.r,
                usdcData.s
            ) = abi.decode(
                _optionalSignatureInfo,
                (uint256, uint256, bytes32, uint8, bytes32, bytes32)
            );

            IFiatTokenV2 usdcv2 = IFiatTokenV2(currencyAddress);

            usdcv2.transferWithAuthorization(
                msgSender,
                address(this),
                _amount.mul(1e6),
                usdcData.validAfter,
                usdcData.validBefore,
                usdcData.nonce,
                usdcData.v,
                usdcData.r,
                usdcData.s
            );
        }
    }

    /**
     * @dev makes the calling user lend funds that are in the community contract into Aave if required conditions are met
     * @param _amount number of currency which the user wants to lend
     * @param _currency currency the user wants to deposit (as of now only DAI)
     **/
    function invest(uint256 _amount, string memory _currency)
        public
        onlyEnabledCurrency(_currency)
    {
        require(
            enabledMembers[_msgSender()] == true,
            "You can't invest if you're not part of the community!"
        );
        require(
            keccak256(bytes(_currency)) != keccak256(bytes("USDC")),
            "Gasless USDC is not implemented in Aave yet"
        );

        address currencyAddress = address(
            depositableCurrenciesContracts[_currency]
        );
        IERC20 currency = IERC20(currencyAddress);

        // Transfer currency
        require(
            currency.balanceOf(address(this)) >= _amount.mul(1e18),
            "Amount to invest cannot be higher than deposited amount."
        );

        // Retrieve LendingPool address provide
        ILendingPoolAddressesProvider provider = ILendingPoolAddressesProvider(
            address(LENDING_POOL_AP)
        ); // Ropsten address, for other addresses: https://docs.aave.com/developers/developing-on-aave/deployed-contract-instances
        ILendingPool lendingPool = ILendingPool(provider.getLendingPool());

        uint256 amount = SafeMath.mul(10000000,1e18);
        uint16 referral = 0;

        // Approve LendingPool contract to move your DAI
        currency.approve(address(lendingPool), amount);

        // Deposit _amount DAI
        lendingPool.deposit(currencyAddress, _amount.mul(1e18), msg.sender, referral);
    }

    /**
     * @dev Returns the balance invested by the contract in Aave (invested + interest) and the APY
     * @return investedBalance the aDai balance of the contract
     * @return investedTokenAPY the median APY of invested balance
     **/
    function getInvestedBalanceInfo()
        public
        view
        returns (uint256 investedBalance, uint256 investedTokenAPY)
    {
        address aDaiAddress = address(depositableACurrenciesContracts["DAI"]); // Ropsten aDAI

        // Client has to convert to balanceOf / 1e18
        uint256 _investedBalance = IAToken(aDaiAddress).balanceOf(
            address(this)
        );

        address daiAddress = address(depositableCurrenciesContracts["DAI"]);

        // Retrieve LendingPool address
        ILendingPoolAddressesProvider provider = ILendingPoolAddressesProvider(
            address(LENDING_POOL_AP)
        ); // Ropsten address, for other addresses: https://docs.aave.com/developers/developing-on-aave/deployed-contract-instances
        ILendingPool lendingPool = ILendingPool(provider.getLendingPool());

        // Client has to convert to balanceOf / 1e27
        uint256 daiLiquidityRate= lendingPool.getReserveData(daiAddress).currentLiquidityRate;

        return (_investedBalance, daiLiquidityRate);
    }

    /**
     * @dev makes the calling user withdraw funds that are in Aave back into the community contract if required conditions are met
     * @param _amount amount of currency which the user wants to withdraw
     * @param _currency currency the user wants to deposit (as of now only DAI)
     **/
    function withdrawFromInvestment(uint256 _amount, string memory _currency)
        public
        onlyEnabledCurrency(_currency)
    {
        require(
            enabledMembers[_msgSender()] == true,
            "You can't withdraw investment if you're not part of the community!"
        );
        require(
            keccak256(bytes(_currency)) != keccak256(bytes("USDC")),
            "Gasless USDC is not implemented in Aave yet"
        );

        // Retrieve CurrencyAddress
        address currencyAddress = address(
            depositableCurrenciesContracts[_currency]
        );
        
        // Retrieve LendingPool address provide
        ILendingPoolAddressesProvider provider = ILendingPoolAddressesProvider(
            address(LENDING_POOL_AP)
        ); // Ropsten address, for other addresses: https://docs.aave.com/developers/developing-on-aave/deployed-contract-instances
        ILendingPool lendingPool = ILendingPool(provider.getLendingPool());

        //TODO: update the check for V2 protocol
        /*if (aCurrency.isTransferAllowed(address(this), _amount.mul(1e18)) == false)
            revert(
                "Can't withdraw from investment, probably not enough liquidity on Aave."
            );*/

        // Redeems _amount aCurrency
        lendingPool.withdraw(currencyAddress, _amount.mul(1e18), msg.sender);
    }

    function completeGig(uint256 _amount) public {
        require(_msgSender() == gigManager, "Only gig manager can complete gig");

        tokens.transfer(address(communityTreasury), _amount.mul(1e18));
        communityTreasury.completeGig(_amount);   
    }

    

    function _msgSender() internal view override(Context, BaseRelayRecipient) returns (address payable) {
        return BaseRelayRecipient._msgSender();
    }

    function _msgData() internal view override(Context, BaseRelayRecipient) returns (bytes memory) {
        return BaseRelayRecipient._msgData();
    } 
}
