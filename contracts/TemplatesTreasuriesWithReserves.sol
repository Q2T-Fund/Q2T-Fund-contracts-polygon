//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./TemplatesTreasuries.sol";

contract TemplatesTreasuriesWithReserves is TemplatesTreasuries {
    using SafeMath for uint256;

    event TreasuryReservesMinted (
        DataTypes.Template _template,
        uint256 _amount
    );

    event TreasuryReservesFundsAdded (
        DataTypes.Template _template,
        uint256 _amount,
        uint256 _newFund
    );

    constructor(string memory _uri) TemplatesTreasuries(_uri) { }

    function addReserves(DataTypes.Template _template, uint256 _amount) public {
        require(msg.sender == q2t, "Only Q2T can add funds");
        require(_amount > 0, "Amount cant be 0");

        uint8 id = getTemplateReservesTokenId(_template);

        if(balanceOf(q2t, uint256(id)) == 0) {
            _mint(q2t, uint256(id), 1, "");
            funds[id].push(_amount);

            emit TreasuryReservesMinted(_template, _amount);
        } else {
            funds[id][0] = funds[id][0].add(_amount);

            emit TreasuryFundsAdded(_template, _amount, funds[id][0]);
        }
    }

    function useReserves(DataTypes.Template _template) public returns (uint256) {
        require(msg.sender == q2t, "Only Q2T can get funds");
        require(balanceOf(q2t, uint256(_template)) == 1, "Template token not minted");

        uint8 id = getTemplateReservesTokenId(_template);

        uint256 halfReserve = funds[id][0].div(2);
        funds[id][0] = funds[id][0].sub(halfReserve);

        return halfReserve;
    }

    function getTemplateReservesTokenId(DataTypes.Template _template) public pure returns (uint8) {
        uint8[3] memory templateReservesIds = [3, 4, 5];

        return templateReservesIds[uint256(_template)];
    }

    function getCurrentReserve(DataTypes.Template _template) public view returns (uint256) {
        return funds[getTemplateReservesTokenId(_template)][0];
    }
}