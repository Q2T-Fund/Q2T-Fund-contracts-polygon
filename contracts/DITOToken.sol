//SPDX-License-Identifier: MIT
pragma solidity >=0.6.10 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DiTo ERC20 AToken
 *
 * @dev Implementation of the SkillWallet token for the DistributedTown project.
 * @author DistributedTown
 */
contract DITOToken is ERC20, Ownable {
    event AddedToWhitelist(address _communityMember);
    event RemovedFromWhitelist(address _communityMember);

    mapping(address => bool) public whitelist;
    address public treasury;

    modifier onlyInWhitelist(address _recipient) {
        require(whitelist[msg.sender], "sender not in whitelist");
        require(whitelist[_recipient], "recipient not in whitelist");
        _;
    }

    constructor(uint256 initialSupply) ERC20("DiTo", "DITO") {
        whitelist[msg.sender] = true;
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Adds a community member to the whitelist, called by the join function of the Community contract
     * @param _communityMember the address of the new member of a Community to add to the whitelist
     **/
    function addToWhitelist(address _communityMember, bool _isTreasury) public onlyOwner {
        if (_isTreasury) {
            require(treasury == address(0), "treasury is already set");
            treasury = _communityMember;
        }
        whitelist[_communityMember] = true;

        emit AddedToWhitelist(_communityMember);
    }

    /**
     * @dev Removes a community member to the whitelist, called by the leave function of the Community contract
     * @param _communityMember the address of the leaving member of a Community
     **/
    function removeFromWhitelist(address _communityMember, bool _isTreasury) public onlyOwner {
        if (_isTreasury) {
            require(treasury == _communityMember, "member is not a treasury");
            treasury = address(0);
        }
        whitelist[_communityMember] = false;

        emit RemovedFromWhitelist(_communityMember);
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        onlyInWhitelist(recipient)
        returns (bool)
    {
        return super.transfer(recipient, amount);
    }

    function approve(address spender, uint256 amount)
        public
        override
        onlyInWhitelist(spender)
        returns (bool)
    {
        return super.approve(spender, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override onlyInWhitelist(recipient) returns (bool) {
        if (recipient == treasury) {
            require (msg.sender == treasury, "not sent from treasury");
        }
        return super.transferFrom(sender, recipient, amount);
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        override
        onlyInWhitelist(spender)
        returns (bool)
    {
        return super.increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        override
        onlyInWhitelist(spender)
        returns (bool)
    {
        return super.decreaseAllowance(spender, subtractedValue);
    }
}
