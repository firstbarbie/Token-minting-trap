// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice A "silent" mint that increases supply without emitting a Transfer event.
    /// @dev Used to test the Silent Mint Trap detection.
    function silentMint(address to, uint256 amount) external {
        _mintSilent(to, amount);
    }

    // Standard ERC20 _mint emits an event. This internal override skips it.
    function _mintSilent(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        // Direct storage manipulation to skip event emission
        // This is a simplified version of _update for PoC purposes
        uint256 currentSupply = totalSupply();
        uint256 newSupply = currentSupply + value;
        
        assembly {
            // Simplified: Write to totalSupply storage slot
            // slot for _totalSupply is often 2 in standard ERC20 but varies.
            // In OpenZeppelin v5, we should use the internal functions if possible
            // or just use a custom variable.
        }
        
        // Let's just use a custom variable for PoC if needed, but standard OZ uses storage.
        // For simplicity, let's just use a mapping and supply variable.
    }
}

contract SimpleMockToken {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function silentMint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        // NO EVENT EMITTED
    }
}
