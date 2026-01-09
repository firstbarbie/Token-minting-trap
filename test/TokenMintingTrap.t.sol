// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {TokenMintingTrap} from "../src/TokenMintingTrap.sol";
import {SimpleMockToken} from "./MockToken.sol";
import {EventLog} from "contracts/libraries/Events.sol";

contract TokenMintingTrapTest is Test {
    TokenMintingTrap public trap;
    SimpleMockToken public token;

    address public approvedRecipient = address(0x123);
    address public anotherApprovedRecipient = address(0x456);
    address public maliciousActor = address(0x666);


    function setUp() public {
        trap = new TokenMintingTrap();
        token = new SimpleMockToken("TrapToken", "TT");
        // Etch the mock token at the hardcoded TARGET_TOKEN address for tests
        vm.etch(trap.targetToken(), address(token).code);
        token = SimpleMockToken(trap.targetToken());

        trap.addApprovedRecipient(approvedRecipient);
        trap.addApprovedRecipient(anotherApprovedRecipient);
    }

    function _prepareData(
        uint256 prevSupply,
        uint256 currentSupply,
        EventLog[] memory logs
    ) internal view returns (bytes[] memory) {
        bytes[] memory data = new bytes[](2);

        // Current block data
        data[0] = abi.encode(
            currentSupply,
            logs,
            trap.getApprovedRecipients(),
            trap.blockMintLimit()
        );

        // Previous block data (logs don't matter here for the current tests)
        EventLog[] memory emptyLogs;
        data[1] = abi.encode(
            prevSupply,
            emptyLogs,
            trap.getApprovedRecipients(),
            trap.blockMintLimit()
        );

        return data;
    }

    function _createMintLog(address to, uint256 amount) internal view returns (EventLog memory) {
        bytes32[] memory topics = new bytes32[](3);
        topics[0] = keccak256("Transfer(address,address,uint256)");
        topics[1] = bytes32(uint256(0));
        topics[2] = bytes32(uint256(uint160(to)));
        return EventLog({
            emitter: address(token),
            topics: topics,
            data: abi.encode(amount)
        });
    }

    function test_NoMints() public {
        uint256 initialSupply = token.totalSupply();
        uint256 newSupply = token.totalSupply();

        EventLog[] memory logs = new EventLog[](0);

        bytes[] memory data = _prepareData(initialSupply, newSupply, logs);

        (bool shouldRespond, bytes memory response) = trap.shouldRespond(data);
        assertFalse(shouldRespond, "Should not respond when no mints occur");
        console2.logBytes(response);
    }

    function test_NotEnoughData() public {
        uint256 initialSupply = token.totalSupply();
        uint256 mintAmount = 500e18;
        token.mint(approvedRecipient, mintAmount);
        uint256 newSupply = token.totalSupply();

        EventLog[] memory logs = new EventLog[](1);
        logs[0] = _createMintLog(approvedRecipient, mintAmount);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encode(
            newSupply,
            logs,
            trap.getApprovedRecipients(),
            trap.blockMintLimit()
        );

        (bool shouldRespond, bytes memory response) = trap.shouldRespond(data);
        assertFalse(shouldRespond, "Should not respond with insufficient data");
        (string memory reason) = abi.decode(response, (string));
        assertEq(reason, "Not enough data to compare blocks");
    }

    function test_ValidMint() public {
        uint256 initialSupply = token.totalSupply();
        uint256 mintAmount = 500e18;
        token.mint(approvedRecipient, mintAmount);
        uint256 newSupply = token.totalSupply();

        EventLog[] memory logs = new EventLog[](1);
        logs[0] = _createMintLog(approvedRecipient, mintAmount);

        bytes[] memory data = _prepareData(initialSupply, newSupply, logs);

        (bool shouldRespond, bytes memory response) = trap.shouldRespond(data);
        assertFalse(shouldRespond, "Should not respond to valid mint");
        console2.logBytes(response);
    }
    
    function test_UnauthorizedRecipient() public {
        uint256 initialSupply = token.totalSupply();
        uint256 mintAmount = 500e18;
        token.mint(maliciousActor, mintAmount);
        uint256 newSupply = token.totalSupply();

        EventLog[] memory logs = new EventLog[](1);
        logs[0] = _createMintLog(maliciousActor, mintAmount);
        
        bytes[] memory data = _prepareData(initialSupply, newSupply, logs);
        
        (bool shouldRespond, bytes memory response) = trap.shouldRespond(data);
        assertTrue(shouldRespond, "Should respond to unauthorized mint");
        
        (string memory reason, address to, uint256 amount) = abi.decode(response, (string, address, uint256));
        assertEq(reason, "Unauthorized mint to");
        assertEq(to, maliciousActor);
        assertEq(amount, mintAmount);
    }

    function test_RateLimitExceeded() public {
        uint256 initialSupply = token.totalSupply();
        uint256 mintAmount1 = 600e18;
        uint256 mintAmount2 = 500e18;
        token.mint(approvedRecipient, mintAmount1);
        token.mint(anotherApprovedRecipient, mintAmount2);
        uint256 newSupply = token.totalSupply();

        EventLog[] memory logs = new EventLog[](2);
        logs[0] = _createMintLog(approvedRecipient, mintAmount1);
        logs[1] = _createMintLog(anotherApprovedRecipient, mintAmount2);
        
        bytes[] memory data = _prepareData(initialSupply, newSupply, logs);
        
        (bool shouldRespond, bytes memory response) = trap.shouldRespond(data);
        assertTrue(shouldRespond, "Should respond to rate limit breach");

        (string memory reason, uint256 totalMint) = abi.decode(response, (string, uint256));
        assertEq(reason, "Rate limit exceeded");
        assertEq(totalMint, mintAmount1 + mintAmount2);
    }

    function test_SilentSupplyChange() public {
        uint256 initialSupply = token.totalSupply();
        uint256 mintAmount = 100e18;
        token.mint(approvedRecipient, mintAmount);

        // Simulate a silent mint by manually increasing supply in the test
        uint256 silentAmount = 500e18;
        token.silentMint(address(0), silentAmount); // silent mint to nobody, just to bump supply
        uint256 newSupply = token.totalSupply();
        
        EventLog[] memory logs = new EventLog[](1);
        logs[0] = _createMintLog(approvedRecipient, mintAmount);
        
        bytes[] memory data = _prepareData(initialSupply, newSupply, logs);
        
        (bool shouldRespond, bytes memory response) = trap.shouldRespond(data);
        assertTrue(shouldRespond, "Should respond to silent mint");
        
        (string memory reason, int256 silentDelta) = abi.decode(response, (string, int256));
        assertEq(reason, "Silent supply change detected");
        assertEq(silentDelta, int256(silentAmount));
    }

    function test_BurnEventsAreHandled() public {
        uint256 initialSupply = 1000e18;
        token.mint(address(this), initialSupply); // Start with some supply
        
        uint256 mintAmount = 200e18;
        uint256 burnAmount = 150e18;

        token.mint(approvedRecipient, mintAmount);
        token.burn(address(this), burnAmount);
        
        uint256 newSupply = token.totalSupply();

        EventLog[] memory logs = new EventLog[](2);
        logs[0] = _createMintLog(approvedRecipient, mintAmount);
        
        // Create Burn Log
        bytes32[] memory burnTopics = new bytes32[](3);
        burnTopics[0] = keccak256("Transfer(address,address,uint256)");
        burnTopics[1] = bytes32(uint256(uint160(address(this))));
        burnTopics[2] = bytes32(uint256(0));
        logs[1] = EventLog({
            emitter: address(token),
            topics: burnTopics,
            data: abi.encode(burnAmount)
        });
        
        bytes[] memory data = _prepareData(initialSupply, newSupply, logs);
        
        (bool shouldRespond, bytes memory response) = trap.shouldRespond(data);
        assertFalse(shouldRespond, "Should not respond when mints and burns are balanced and valid");
        console2.logBytes(response);
    }

    function test_RespondFunctionEmitsEvent() public {
        bytes memory incident = abi.encode("Test incident");
        vm.expectEmit(true, true, true, true);
        emit TokenMintingTrap.TrapResponse(incident);
        trap.respond(incident);
    }
}
