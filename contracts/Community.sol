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

import "./IDITOToken.sol";
import "./WadRayMath.sol";

/**
 * @title DistributedTown Community
 *
 * @dev Implementation of the Community concept in the scope of the DistributedTown project
 * @author DistributedTown
 */
contract Community is BaseRelayRecipient {
    string public override versionRecipient = "2.0.0";

    using SafeMath for uint256;
    using WadRayMath for uint256;

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
    address public constant LENDING_POOL_AP=0x88757f2f99175387aB4C6a4b3067c77A695b0349; //kovan
    
    // The address of the DITOToken ERC20 contract
    IDITOToken public tokens;

    mapping(address => bool) public enabledMembers;
    uint256 public numberOfMembers;
    mapping(string => address) public depositableCurrenciesContracts;
    mapping(string => address) public depositableACurrenciesContracts;
    string[] public depositableCurrencies;

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
    constructor(address _forwarder, address _token) public {
        trustedForwarder = _forwarder;

        tokens = IDITOToken(_token);

        depositableCurrencies.push("DAI");
        depositableCurrencies.push("USDC");

        depositableCurrenciesContracts["DAI"] = address(
            0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108
        );
        depositableCurrenciesContracts["USDC"] = address(
            0x07865c6E87B9F70255377e024ace6630C1Eaa37F
        );

        depositableACurrenciesContracts["DAI"] = address(
            0xcB1Fe6F440c49E9290c3eb7f158534c2dC374201
        );
    }

    /**
     * @dev makes the calling user join the community if required conditions are met
     * @param _amountOfDITOToRedeem the amount of dito tokens for which this user is eligible
     **/
    function join(uint256 _amountOfDITOToRedeem) public {
        require(numberOfMembers < 24, "There are already 24 members, sorry!");
        require(enabledMembers[_msgSender()] == false, "You already joined!");

        enabledMembers[_msgSender()] = true;
        numberOfMembers = numberOfMembers.add(1);
        tokens.addToWhitelist(_msgSender());

        tokens.transfer(_msgSender(), _amountOfDITOToRedeem.mul(1e18));

        emit MemberAdded(_msgSender(), _amountOfDITOToRedeem);
    }

    /**
     * @dev makes the calling user leave the community if required conditions are met
     **/
    function leave() public {
        require(enabledMembers[_msgSender()] == true, "You didn't even join!");

        enabledMembers[_msgSender()] = false;
        numberOfMembers = numberOfMembers.sub(1);

        // leaving user must first give allowance
        // then can call this
        tokens.transferFrom(
            _msgSender(),
            address(this),
            tokens.balanceOf(_msgSender())
        );

        tokens.removeFromWhitelist(_msgSender());

        emit MemberRemoved(_msgSender());
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
        require(
            enabledMembers[_msgSender()] == true,
            "You can't deposit if you're not part of the community!"
        );

        address currencyAddress = address(
            depositableCurrenciesContracts[_currency]
        );
        IERC20 currency = IERC20(currencyAddress);
        require(
            currency.balanceOf(_msgSender()) <= _amount.mul(1e18),
            "You don't have enough funds to invest."
        );

        bytes32 currencyStringHash = keccak256(bytes(_currency));
        uint256 amount = _amount * 1e18;

        if (currencyStringHash == keccak256(bytes("DAI"))) {
            currency.transferFrom(_msgSender(), address(this), amount);
        } else if (currencyStringHash == keccak256(bytes("USDC"))) {
            (
                uint256 _validAfter,
                uint256 _validBefore,
                bytes32 _nonce,
                uint8 _v,
                bytes32 _r,
                bytes32 _s
            ) = abi.decode(
                _optionalSignatureInfo,
                (uint256, uint256, bytes32, uint8, bytes32, bytes32)
            );

            amount = _amount.mul(1e6);

            IFiatTokenV2 usdcv2 = IFiatTokenV2(currencyAddress);

            usdcv2.transferWithAuthorization(
                _msgSender(),
                address(this),
                amount,
                _validAfter,
                _validBefore,
                _nonce,
                _v,
                _r,
                _s
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
            currency.balanceOf(address(this)) <= _amount.mul(1e18),
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
}
