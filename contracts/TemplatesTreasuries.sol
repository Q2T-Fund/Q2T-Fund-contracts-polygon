//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./DataTypes.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TemplatesTreasuries is ERC1155 {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    event TreasuryMinted (
        DataTypes.Template _template,
        uint256 _amount
    );

    event TreasuryFundsAdded (
        DataTypes.Template _template,
        uint256 _amount,
        uint256 _newFund
    );

    event TreasuryBurnt (
        DataTypes.Template _template,
        uint256 _finalFund
    );

    mapping(DataTypes.Template => Counters.Counter) private treasuryCounters;
    address public q2t;
    mapping (uint8 => uint256[]) public funds;

    constructor(string memory _uri) ERC1155(_uri) {
        q2t = msg.sender;
    }

    function mint(DataTypes.Template _template, uint256 _amount) public {
        require(msg.sender == q2t, "Only Q2T can mint");
        require(_amount > 0, "Amount cant be 0");
        require(balanceOf(q2t, uint256(_template)) == 0, "Template already has token");

        _mint(q2t, uint256(_template), 1, "");
        funds[uint8(_template)].push(_amount);

        emit TreasuryMinted(_template, _amount);
    }

    function addFunds(DataTypes.Template _template, uint256 _amount) public {
        require(msg.sender == q2t, "Only Q2T can add funds");
        require(balanceOf(q2t, uint256(_template)) == 1, "Template token not minted");
        require(_amount > 0, "Amount cant be 0");

        uint256 currentId = funds[uint8(_template)].length - 1;
        
        funds[uint8(_template)][currentId] = funds[uint8(_template)][currentId].add(_amount);

        emit TreasuryFundsAdded(_template, _amount, funds[uint8(_template)][currentId]);
    }

    function burn(DataTypes.Template _template) public {
        require(msg.sender == q2t, "Only Q2T can burn treasury");
        require(balanceOf(q2t, uint256(_template)) == 1, "Template token not minted");

        uint256 fund = funds[uint8(_template)][funds[uint8(_template)].length - 1];

        _burn(q2t, uint256(_template), 1);

        emit TreasuryBurnt(_template, fund);
    }

    function getCurrentFund(DataTypes.Template _template) public view returns (uint256) {
        if (balanceOf(q2t, uint256(_template)) == 0) {
            return 0;
        }
        
        return funds[uint8(_template)][funds[uint8(_template)].length - 1];
    }
}