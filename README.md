# Token Minting Trap

This repository contains a **Token Minting Trap**, a stateless smart contract designed to monitor and respond to token minting events on the Ethereum blockchain. It leverages the **Drosera Protocol** for decentralized incident response, providing an automated mechanism to detect and mitigate unauthorized or anomalous token minting activities.

## What it Does

The core component is the `TokenMintingTrap.sol` smart contract, which acts as a "trap" within the Drosera network. This contract is configured to:
- Monitor a specific token contract for `Transfer` events.
- Perform stateless, block-by-block analysis of token supply changes.
- Trigger an alert and response action via the Drosera Protocol if predefined conditions are met.

The project includes a **Drosera Operator Node** that actively listens for events from the deployed `TokenMintingTrap` contract and executes the configured response actions.

## How it Works

1.  **Stateless Smart Contract (`TokenMintingTrap.sol`):** This Solidity contract is deployed on the Ethereum blockchain. It is designed to be stateless, meaning it does not rely on storing data from previous blocks. Instead, it receives historical data from the Drosera node with each call.
2.  **Data Collection (`collect`):** In each block, the `collect` function gathers the token's total supply, all `Transfer` events, and the trap's current configuration (like the list of approved mint recipients).
3.  **Cross-Block Analysis (`shouldRespond`):** The Drosera node calls the `shouldRespond` function with data collected from both the current and the previous block. The contract then compares these two snapshots to detect anomalies.
4.  **Drosera Protocol Integration:** If an anomaly is detected, `shouldRespond` returns `true` along with encoded incident details. The Drosera network then initiates a response.
5.  **Incident Response (`respond`):** The Drosera network calls the `respond(bytes)` function on the trap contract, passing the incident details. This function emits an on-chain `TrapResponse` event, creating a permanent record of the incident.
6.  **Foundry Development Environment:** The smart contracts are developed and tested using Foundry, a fast and powerful toolkit for Ethereum application development.

### Checks Performed

The trap performs the following three checks in every block:
1.  **Mint Rate-Limiting:** It calculates the total amount of tokens minted in the current block (by summing all `Transfer` events from the zero address) and triggers if this amount exceeds a predefined `BLOCK_MINT_LIMIT`.
2.  **Unauthorized Mint Recipient:** For every mint event, it verifies that the recipient of the new tokens is on a configurable whitelist of `approvedRecipients`. If a mint occurs to an address not on this list, the trap is triggered.
3.  **Silent Supply Change:** It compares the actual change in the token's `totalSupply` between the current and previous block with the expected change calculated from the sum of all mint and burn events in the current block. If the numbers don't match, it indicates a "silent" supply modification (one that occurred without a corresponding `Transfer` event), and the trap is triggered.

## Project Structure

-   `src/TokenMintingTrap.sol`: The main stateless smart contract implementing the token minting trap logic.
-   `test/TokenMintingTrap.t.sol`: Foundry tests for the smart contract, covering all detection scenarios.
-   `test/MockToken.sol`: A simple mock ERC20 token used for testing purposes.
-   `drosera.toml`: Configuration for the Drosera Protocol, defining the trap's target contract, response function (`respond(bytes)`), and other parameters.
-   `docker-compose.yaml`: Configuration for deploying the Drosera Operator Node using Docker.
-   `.env`: Environment variables for the Dockerized Drosera Operator, including private keys and RPC URLs.
-   `lib/`: Contains external smart contract libraries (`forge-std`, `openzeppelin-contracts`, etc.).
-   `script/`: Foundry scripts for deployment and other on-chain interactions.

## Setup and Deployment

### Prerequisites

-   [Docker](https://docs.docker.com/get-docker/)
-   [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Running the Drosera Operator (Docker Compose)

1.  **Configure Environment Variables:**
    Create a `.env` file in the root directory and populate it with your Ethereum private key and VPS IP:
    ```
    ETH_PRIVATE_KEY=your_private_key_here
    VPS_IP=your_vps_public_ip
    ```
    *Ensure your `ETH_PRIVATE_KEY` corresponds to an account with funds on the appropriate network.*

2.  **Start the Operator:**
    ```bash
    docker compose up -d
    ```
    This will pull the `drosera-network/drosera-operator` Docker image and start the node in detached mode.

3.  **Monitor Logs:**
    To view the operator's real-time logs:
    ```bash
    docker compose logs -f
    ```

### Smart Contract Development (Foundry)

-   **Build Contracts:**
    ```bash
    forge build
    ```
-   **Run Tests:**
    ```bash
    forge test
    ```
-   **Deploy Contracts:**
    (Example - adjust script path and parameters as needed)
    ```bash
    forge script script/Deploy.s.sol:DeployScript --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
    ```