//SPDX-License-Identifier: MIT
pragma solidity >=0.6.10 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DiTo IERC20 AToken
 *
 * @dev Interface for SkillWallet token for the DistributedTown project.
 * @author DistributedTown
 */
interface IDITOToken is IERC20 {
    event AddedToWhitelist(address _communityMember);
    event RemovedFromWhitelist(address _communityMember);
        /**
     * @dev Adds a community member to the whitelist, called by the join function of the Community contract
     * @param _communityMember the address of the new member of a Community to add to the whitelist
     **/
    function addToWhitelist(address _communityMember) external;

    /**
     * @dev Removes a community member to the whitelist, called by the leave function of the Community contract
     * @param _communityMember the address of the leaving member of a Community
     **/
    function removeFromWhitelist(address _communityMember) external;

    function transfer(address recipient, uint256 amount) external override returns (bool);

    function approve(address spender, uint256 amount) external override returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool);

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
}
