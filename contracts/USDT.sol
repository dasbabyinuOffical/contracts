// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20 {
    uint256 constant initialSupply = 1000*1e18;
    constructor() ERC20("Gold", "GLD") {
        _mint(msg.sender, initialSupply);
    }
}