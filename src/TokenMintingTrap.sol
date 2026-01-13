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
    uint256 public constant MAX_APPROVED_RECIPIENTS = 50;

    address public immutable targetToken = TARGET_TOKEN;
    uint256 public blockMintLimit = BLOCK_MINT_LIMIT;
    address public owner;
    
    address[] public approvedRecipients;

    event TrapResponse(bytes incidentDetails);

    bytes32 constant TRANSFER_EVENT_TOPIC0 = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function getApprovedRecipients() external view returns (address[] memory) {
        return approvedRecipients;
    }

    function addApprovedRecipient(address recipient) external onlyOwner {
        require(approvedRecipients.length < MAX_APPROVED_RECIPIENTS, "Approved recipients list is full");
        approvedRecipients.push(recipient);
    }

    function removeApprovedRecipient(address recipient) external onlyOwner {
        for (uint i = 0; i < approvedRecipients.length; i++) {
            if (approvedRecipients[i] == recipient) {
                if (i != approvedRecipients.length - 1) {
                    approvedRecipients[i] = approvedRecipients[approvedRecipients.length - 1];
                }
                approvedRecipients.pop();
                return;
            }
        }
    }



    function collect() external view override returns (bytes memory) {
        return abi.encode(
            IERC20(targetToken).totalSupply(),
            getEventLogs(),
            approvedRecipients,
            blockMintLimit
        );
    }

    function _parseCollectData(bytes calldata data) internal pure returns (uint256, EventLog[] memory, address[] memory, uint256) {
        return abi.decode(data, (uint256, EventLog[], address[], uint256));
    }

    function shouldRespond(
        bytes[] calldata data
    ) external pure override returns (bool, bytes memory) {
        if (data.length < 2 || data[0].length == 0 || data[1].length == 0) {
            return (false, bytes(""));
        }

        (uint256 currentSupply, EventLog[] memory logs, address[] memory _approvedRecipients, uint256 _blockMintLimit) = 
            _parseCollectData(data[0]);
        
        (uint256 previousSupply, , , ) = _parseCollectData(data[1]);

        uint256 mintedFromLogs = 0;
        uint256 burnedFromLogs = 0;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == TRANSFER_EVENT_TOPIC0) {
                address from = address(uint160(uint256(logs[i].topics[1])));
                address to = address(uint160(uint256(logs[i].topics[2])));
                uint256 amount = abi.decode(logs[i].data, (uint256));

                if (from == address(0)) { // Mint
                    mintedFromLogs += amount;

                    bool isApproved = false;
                    for (uint256 j = 0; j < _approvedRecipients.length; j++) {
                        if (_approvedRecipients[j] == to) {
                            isApproved = true;
                            break;
                        }
                    }
                    if (!isApproved) {
                        return (true, abi.encode("Unauthorized mint to", to, amount));
                    }
                } else if (to == address(0)) { // Burn
                    burnedFromLogs += amount;
                }
            }
        }

        // 1. Rate Limit Enforcement
        if (mintedFromLogs > _blockMintLimit) {
            return (true, abi.encode("Rate limit exceeded", mintedFromLogs));
        }

        // 2. Silent Mint/Burn/Supply Change Check
        // Using int256 to handle potential burns making supply decrease
        int256 actualDelta = int256(currentSupply) - int256(previousSupply);
        int256 expectedDelta = int256(mintedFromLogs) - int256(burnedFromLogs);

        if (actualDelta != expectedDelta) {
            return (true, abi.encode("Silent supply change detected", actualDelta - expectedDelta));
        }

        return (false, abi.encode("No anomalies detected"));
    }

    // New response function to be called by the Drosera node
    function respond(bytes memory incidentDetails) public {
        emit TrapResponse(incidentDetails);
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
