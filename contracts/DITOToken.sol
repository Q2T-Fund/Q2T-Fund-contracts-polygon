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

    modifier onlyInWhitelist() {
        require(whitelist[msg.sender], "");
        _;
    }

    constructor(uint256 initialSupply) public ERC20("DiTo", "DITO") {
        whitelist[msg.sender] = true;
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Adds a community member to the whitelist, called by the join function of the Community contract
     * @param _communityMember the address of the new member of a Community to add to the whitelist
     **/
    function addToWhitelist(address _communityMember) public onlyOwner {
        whitelist[_communityMember] = true;

        emit AddedToWhitelist(_communityMember);
    }

    /**
     * @dev Removes a community member to the whitelist, called by the leave function of the Community contract
     * @param _communityMember the address of the leaving member of a Community
     **/
    function removeFromWhitelist(address _communityMember) public onlyOwner {
        whitelist[_communityMember] = false;

        emit RemovedFromWhitelist(_communityMember);
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        onlyInWhitelist
        returns (bool)
    {
        return super.transfer(recipient, amount);
    }

    function approve(address spender, uint256 amount)
        public
        override
        onlyInWhitelist
        returns (bool)
    {
        return super.approve(spender, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override onlyInWhitelist returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        override
        onlyInWhitelist
        returns (bool)
    {
        return super.increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        override
        onlyInWhitelist
        returns (bool)
    {
        return super.decreaseAllowance(spender, subtractedValue);
    }
}
