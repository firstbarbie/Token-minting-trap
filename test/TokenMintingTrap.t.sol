// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {TokenMintingTrap} from "../src/TokenMintingTrap.sol";
import {SimpleMockToken} from "./MockToken.sol";
import {EventLog} from "contracts/libraries/Events.sol";

contract TokenMintingTrapTest is Test {
    TokenMintingTrap public trap;
    SimpleMockToken public token;
    
    address public approvedMinter = address(0x123);
    address public maliciousActor = address(0x666);
    uint256 public limit = 1000e18;

    function setUp() public {
        token = new SimpleMockToken("TrapToken", "TT");
        // Etch the mock token at the hardcoded TARGET_TOKEN address for tests
        vm.etch(0x42f5236Efd494B97f9e64eE82062462754bFf9b4, address(token).code);
        token = SimpleMockToken(0x42f5236Efd494B97f9e64eE82062462754bFf9b4);
        
        trap = new TokenMintingTrap();
        trap.addApprovedMinter(approvedMinter);
    }


    function _prepareData(uint256 supply, EventLog[] memory logs) internal view returns (bytes[] memory) {
        address[] memory minters = new address[](1);
        minters[0] = approvedMinter;
        
        TokenMintingTrap.TrapConfig memory config = TokenMintingTrap.TrapConfig({
            lastTotalSupply: trap.lastTotalSupply(),
            blockMintLimit: trap.blockMintLimit(),
            approvedMinters: minters
        });
        
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encode(supply, logs, config);
        return data;
    }

    function test_ValidMint() public {
        token.mint(approvedMinter, 500e18);
        
        EventLog[] memory logs = new EventLog[](1);
        bytes32[] memory topics = new bytes32[](3);
        topics[0] = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
        topics[1] = bytes32(uint256(0));
        topics[2] = bytes32(uint256(uint160(approvedMinter)));
        logs[0] = EventLog({
            emitter: address(token),
            topics: topics,
            data: abi.encode(500e18)
        });
        
        bytes[] memory data = _prepareData(token.totalSupply(), logs);
        
        (bool shouldRespond, bytes memory response) = trap.shouldRespond(data);
        assertFalse(shouldRespond, "Should not respond to valid mint");
        console2.log("Response:", string(response));
    }

    function test_UnauthorizedMinter() public {
        token.mint(maliciousActor, 500e18);
        
        EventLog[] memory logs = new EventLog[](1);
        bytes32[] memory topics = new bytes32[](3);
        topics[0] = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
        topics[1] = bytes32(uint256(0));
        topics[2] = bytes32(uint256(uint160(maliciousActor)));
        logs[0] = EventLog({
            emitter: address(token),
            topics: topics,
            data: abi.encode(500e18)
        });
        
        bytes[] memory data = _prepareData(token.totalSupply(), logs);
        
        (bool shouldRespond, bytes memory response) = trap.shouldRespond(data);
        assertTrue(shouldRespond, "Should respond to unauthorized mint");
        console2.log("Unauthorized Response:", string(response));
    }

    function test_RateLimitExceeded() public {
        token.mint(approvedMinter, 1500e18);
        
        EventLog[] memory logs = new EventLog[](0); // Doesn't matter for rate limit
        bytes[] memory data = _prepareData(token.totalSupply(), logs);
        
        (bool shouldRespond, ) = trap.shouldRespond(data);
        assertTrue(shouldRespond, "Should respond to rate limit breach");
    }

    function test_SilentMint() public {
        token.silentMint(approvedMinter, 500e18);
        
        EventLog[] memory logs = new EventLog[](0);
        bytes[] memory data = _prepareData(token.totalSupply(), logs);
        
        (bool shouldRespond, bytes memory response) = trap.shouldRespond(data);
        assertTrue(shouldRespond, "Should respond to silent mint");
        console2.log("Silent Mint Response:", string(response));
    }
}
