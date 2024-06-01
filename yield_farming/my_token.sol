// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor() ERC20("Me", "M") {
        _mint(msg.sender, 1000 ether);
    }

    function mint() external {
        _mint(msg.sender, 100 ether);
    }
}
