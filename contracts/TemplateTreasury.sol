//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/token/ERC721/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TemplateTreasury is IERC721Metadata, ERC721 {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    event TreasuryFunded (
        uint256 _id,
        uint256 _amount
    );

    event TreasuryFundsAdded (
        uint256 _id,
        uint256 _amount,
        uint256 _newFund
    );

    event TreasuryBurnt (
        uint256 _id,
        uint256 _finalFund
    );

    Counters.Counter private treasuryCounter;
    address public q2t;
    mapping (uint256 => uint256) public funds;

    constructor() ERC721("TemplateTreasury", "TMPL") {
        q2t = msg.sender;
        treasuryCounter.increment(); //start ids with 1
    }

    function mint(uint256 _amount) public returns (uint256) {
        require(msg.sender == q2t, "Only Q2T can mint");
        require(_amount > 0, "Amount cant be 0");
        
        uint256 newId = treasuryCounter.current();
        treasuryCounter.increment();

        //probably use _safeMint here
        _mint(q2t, newId);
        funds[newId] = _amount;

        emit TreasuryFunded(newId, _amount);

        return newId;
    }

    function addFunds(uint256 _id, uint256 _amount) public {
        require(msg.sender == q2t, "Only Q2T can add funds");
        require(_exists(_id), "Token doesn't exist");
        require(_amount > 0, "Amount cant be 0");
        
        funds[_id] = funds[_id].add(_amount);

        emit TreasuryFundsAdded(_id, _amount, funds[_id]);
    }

    function burn(uint256 _id) public {
        require(msg.sender == q2t, "Only Q2T can burn treasury");

        uint256 fund = funds[_id];

        _burn(_id);

        emit TreasuryBurnt(_id, fund);
    }
}