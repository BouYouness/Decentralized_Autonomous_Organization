// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/ERC20.sol";

contract DAOToken is ERC20{
    address public admin;

    constructor(uint256 initialSupply) ERC20("DAO Token", "DAO"){
       _mint(msg.sender, initialSupply);
       admin = msg.sender;
    }

    function mint(address to, uint256 amount) external{
       require(msg.sender == admin);
       _mint(to, amount);
    }

    function burn(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount);
        _burn(msg.sender,amount);
    }
}
