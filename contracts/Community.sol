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
import "./CommunityTreasury.sol";
import "./GigsRegistry.sol";
import {DataTypes} from './DataTypes.sol';

import "./DITOToken.sol";
//import "./WadRayMath.sol";

/**
 * @title DistributedTown Community
 *
 * @dev Implementation of the Community concept in the scope of the DistributedTown project
 * @author DistributedTown
 */
contract Community is BaseRelayRecipient, Ownable {
    string public override versionRecipient = "2.0.0";

    using SafeMath for uint256;
    //using WadRayMath for uint256;

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
    event IdSet(uint256 _id);
    event TreasurySet(address _treasury);

    uint256 public constant INIT_TOKENS = 96000;
    
    // The address of the DITOToken ERC20 contract
    DITOToken public tokens;

    uint256 public id;
    bool idSet;
    DataTypes.CommunityTemplate public template;
    mapping(address => bool) public enabledMembers;
    uint256 public numberOfMembers;
    mapping(string => address) public depositableCurrenciesContracts;
    string[] public depositableCurrencies;
    CommunityTreasury public communityTreasury;
    GigsRegistry public gigsRegistry;
    ILendingPoolAddressesProvider public lendingPoolAP;

    // Get the forwarder address for the network
    // you are using from
    // https://docs.opengsn.org/gsn-provider/networks.html
    // 0x25CEd1955423BA34332Ec1B60154967750a0297D is ropsten's one
    constructor(
        DataTypes.CommunityTemplate _template, 
        address _dai,
        address _usdc,
        address _lendingPoolAP, 
        address _forwarder
    ) {
        idSet = false;
        template = _template;
        trustedForwarder = _forwarder;
        lendingPoolAP = ILendingPoolAddressesProvider(_lendingPoolAP);

        tokens = new DITOToken(INIT_TOKENS.mul(1e18));
        communityTreasury = new CommunityTreasury(
            template, 
            address(tokens),
            msg.sender,
            _dai,
            _usdc,
            _lendingPoolAP
        );

        _join(address(communityTreasury), 2000, true);
        communityTreasury.approveCommunity();

        depositableCurrencies.push("DAI");
        depositableCurrencies.push("USDC");

        depositableCurrenciesContracts["DAI"] = _dai;
        depositableCurrenciesContracts["USDC"] = _usdc;
    }

    function createGigsRegistry() public onlyOwner returns(address) {
        require(address(gigsRegistry) == address(0), "already created");

        gigsRegistry = new GigsRegistry();

        return address(gigsRegistry);
    }

    function setId(uint256 _id) public {
        require(msg.sender == address(communityTreasury), "not treasury");
        require(!idSet, "already set");

        id = _id;
        idSet = true;

        emit IdSet(_id);
    }

    function setTreasury(address _treasury) public onlyOwner {
        require(!idSet, "already set");
        require(_treasury != address(0), "treasury addr 0");
        
        if (address(communityTreasury) != address(0)) {
            _leave(address(communityTreasury), true);
        }
        communityTreasury = CommunityTreasury(_treasury);
        _join(address(_treasury), 2000, true);

        emit TreasurySet(_treasury);
    }

    function setTreasuryDAO(address _dao) public onlyOwner {
        communityTreasury.setTreasuryDAO(_dao);
    }
    
    /*function setCommunity(address _community) public onlyOwner {
        communityTreasury.setCommunity(_community);
    }*/

    /**
     * @dev makes the calling user join the community if required conditions are met
     * @param _amountOfDITOToRedeem the amount of dito tokens for which this user is eligible
     **/
     function join(uint256 _amountOfDITOToRedeem) public {
         _join(_msgSender(), _amountOfDITOToRedeem, false);
     }

    function _join(address _member, uint256 _amountOfDITOToRedeem, bool _isTreasury) internal {
        require(address(communityTreasury) != address(0), "treasury not set");
        require(numberOfMembers < 25, "community full"); //1st member is community treasure so there can actually be 25 members
        require(enabledMembers[_member] == false, "already member");

        enabledMembers[_member] = true;
        numberOfMembers = numberOfMembers.add(1);
        tokens.addToWhitelist(_member, _isTreasury);

        tokens.transfer(_member, _amountOfDITOToRedeem.mul(1e18));

        emit MemberAdded(_member, _amountOfDITOToRedeem);
    }

    /**
     * @dev makes the calling user leave the community if required conditions are met
     **/
    function leave() public {
        _leave(_msgSender(), false);
    }

    function _leave(address _member, bool _isTreasury) private {
        _onlyMember(_member);

        enabledMembers[_member] = false;
        numberOfMembers = numberOfMembers.sub(1);

        // leaving user must first give allowance
        // then can call this
        tokens.transferFrom(
            _member,
            address(this),
            tokens.balanceOf(_member)
        );

        tokens.removeFromWhitelist(_member, _isTreasury);

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
    ) public {
        address msgSender = _msgSender();
        _onlyMember(_msgSender());
        _onlyEnabledCurrency(_currency);

        address currencyAddress = address(
            depositableCurrenciesContracts[_currency]
        );
        IERC20 currency = IERC20(currencyAddress);
        require(
            currency.balanceOf(msgSender) >= _amount.mul(1e18),
            "no funds"
        );

        bytes32 currencyStringHash = keccak256(bytes(_currency));

        if (currencyStringHash == keccak256(bytes("DAI"))) {
            currency.transferFrom(msgSender, address(this), _amount.mul(1e18));
        } else if (currencyStringHash == keccak256(bytes("USDC"))) {
            DataTypes.UsdcData memory usdcData;
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

            //IFiatTokenV2 usdcv2 = IFiatTokenV2(currencyAddress);

            IFiatTokenV2(currencyAddress).transferWithAuthorization(
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
    {
        _onlyMember(_msgSender());
        _onlyEnabledCurrency(_currency);

        require(
            keccak256(bytes(_currency)) != keccak256(bytes("USDC")),
            "no gaslss USDC"
        );

        address currencyAddress = address(
            depositableCurrenciesContracts[_currency]
        );
        IERC20 currency = IERC20(currencyAddress);

        // Transfer currency
        require(
            currency.balanceOf(address(this)) >= _amount.mul(1e18),
            "no deposit"
        );

        //ILendingPool lendingPool = ILendingPool(lendingPoolAP.getLendingPool());

        //uint256 amount = SafeMath.mul(10000000,1e18);
        //uint16 referral = 0;

        // Approve LendingPool contract to move your DAI
        //currency.approve(address(lendingPool), type(uint256).max);

        // Deposit _amount DAI
        ILendingPool(lendingPoolAP.getLendingPool()).deposit(currencyAddress, _amount.mul(1e18), msg.sender, 0);
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
        //address aDaiAddress = address(depositableACurrenciesContracts["DAI"]); // Ropsten aDAI

        

        //address daiAddress = address(depositableCurrenciesContracts["DAI"]);

        ILendingPool lendingPool = ILendingPool(lendingPoolAP.getLendingPool());

        // Client has to convert to balanceOf / 1e18
        /*uint256 _investedBalance = IAToken(
                lendingPool.getReserveData(depositableACurrenciesContracts["DAI"]).aTokenAddress
            ).balanceOf(
                address(this)
        );

        // Client has to convert to balanceOf / 1e27
        uint256 daiLiquidityRate= lendingPool.getReserveData(
            depositableCurrenciesContracts["DAI"]
        ).currentLiquidityRate;*/

        return (
            IAToken(
                lendingPool.getReserveData(depositableCurrenciesContracts["DAI"]).aTokenAddress
            ).balanceOf(
                address(this)
            ), 
            lendingPool.getReserveData(
                depositableCurrenciesContracts["DAI"]
            ).currentLiquidityRate
        );
    }

    /**
     * @dev makes the calling user withdraw funds that are in Aave back into the community contract if required conditions are met
     * @param _amount amount of currency which the user wants to withdraw
     * @param _currency currency the user wants to deposit (as of now only DAI)
     **/
    function withdrawFromInvestment(uint256 _amount, string memory _currency)
        public
    {
        _onlyEnabledCurrency(_currency);
        _onlyMember(_msgSender());

        require(
            keccak256(bytes(_currency)) != keccak256(bytes("USDC")),
            "no gasless USDC"
        );

        // Retrieve CurrencyAddress
        /*address currencyAddress = address(
            depositableCurrenciesContracts[_currency]
        );*/
        
        //ILendingPool lendingPool = ILendingPool(lendingPoolAP.getLendingPool());

        //TODO: update the check for V2 protocol
        /*if (aCurrency.isTransferAllowed(address(this), _amount.mul(1e18)) == false)
            revert(
                "Can't withdraw from investment, probably not enough liquidity on Aave."
            );*/

        // Redeems _amount aCurrency
        ILendingPool(lendingPoolAP.getLendingPool()).withdraw(
            depositableCurrenciesContracts[_currency], 
            _amount.mul(1e18), 
            msg.sender
        );
    }

    function completeGig(uint256 _amount, address _project) public {
        require(_msgSender() == address(gigsRegistry), "not gig registry");

        if(_project != address(0)) {
            tokens.approve(address(communityTreasury), _amount.mul(1e18));
            communityTreasury.completeMilestone(_amount, _project);   
        }
    }

    

    function _msgSender() internal view override(Context, BaseRelayRecipient) returns (address payable) {
        return BaseRelayRecipient._msgSender();
    }

    function _msgData() internal view override(Context, BaseRelayRecipient) returns (bytes memory) {
        return BaseRelayRecipient._msgData();
    }

    function _onlyMember(address _member) internal view {
        require(
            enabledMembers[_member] == true,
            "not member"
        );
    }

    function _onlyEnabledCurrency(string memory _currency) internal view {
        require(
            depositableCurrenciesContracts[_currency] != address(0),
            "not supported currency"
        );
    }
}
