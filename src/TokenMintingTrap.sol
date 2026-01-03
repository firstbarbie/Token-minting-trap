// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Trap} from "contracts/Trap.sol";
import {EventLog, EventFilter} from "contracts/libraries/Events.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
}

contract TokenMintingTrap is Trap {
    address public constant TARGET_TOKEN = 0x42f5236Efd494B97f9e64eE82062462754bFf9b4;
    uint256 public constant BLOCK_MINT_LIMIT = 1000 * 10**18;
    address public immutable targetToken = TARGET_TOKEN;
    uint256 public lastTotalSupply;
    uint256 public blockMintLimit = BLOCK_MINT_LIMIT;
    
    address[] public approvedMinters;
    
    bytes32 constant TRANSFER_EVENT_TOPIC0 = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    constructor() {
        lastTotalSupply = IERC20(TARGET_TOKEN).totalSupply();
    }


    function addApprovedMinter(address minter) external {
        approvedMinters.push(minter);
    }

    struct TrapConfig {
        uint256 lastTotalSupply;
        uint256 blockMintLimit;
        address[] approvedMinters;
    }

    function collect() external view override returns (bytes memory) {
        TrapConfig memory config = TrapConfig({
            lastTotalSupply: lastTotalSupply,
            blockMintLimit: blockMintLimit,
            approvedMinters: approvedMinters
        });
        
        return abi.encode(
            IERC20(targetToken).totalSupply(),
            getEventLogs(),
            config
        );
    }

    function shouldRespond(
        bytes[] calldata data
    ) external pure override returns (bool, bytes memory) {
        if (data.length == 0) return (false, abi.encode("No data"));

        (uint256 currentSupply, EventLog[] memory logs, TrapConfig memory config) = 
            abi.decode(data[0], (uint256, EventLog[], TrapConfig));
        
        if (currentSupply <= config.lastTotalSupply) {
            return (false, abi.encode("Supply stable"));
        }

        uint256 delta = currentSupply - config.lastTotalSupply;
        
        // 1. Rate Limit Enforcement
        if (delta > config.blockMintLimit) {
            return (true, abi.encode("Rate limit exceeded", delta));
        }

        // 2. Mint Source Verification & Silent Mint Detection
        uint256 accountedMintAmount = 0;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == TRANSFER_EVENT_TOPIC0) {
                address from = address(uint160(uint256(logs[i].topics[1])));
                if (from == address(0)) {
                    address to = address(uint160(uint256(logs[i].topics[2])));
                    uint256 amount = abi.decode(logs[i].data, (uint256));
                    
                    bool isApproved = false;
                    for (uint256 j = 0; j < config.approvedMinters.length; j++) {
                        if (config.approvedMinters[j] == to) {
                            isApproved = true;
                            break;
                        }
                    }

                    if (!isApproved) {
                        return (true, abi.encode("Unauthorized mint to", to, amount));
                    }
                    
                    accountedMintAmount += amount;
                }
            }
        }

        // 3. Silent Mint Check
        if (delta > accountedMintAmount) {
            return (true, abi.encode("Silent mint detected", delta - accountedMintAmount));
        }

        return (false, abi.encode("Valid mint"));
    }

    function syncSupply() external {
        lastTotalSupply = IERC20(targetToken).totalSupply();
    }

    function eventLogFilters() public view override returns (EventFilter[] memory) {
        EventFilter[] memory filters = new EventFilter[](1);
        filters[0] = EventFilter({
            contractAddress: targetToken,
            signature: "Transfer(address,address,uint256)"
        });
        return filters;
    }
}
