// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IAaveEcosystemReserveController} from "./external/aave/IAaveEcosystemReserveController.sol";
import {IStreamable} from "./external/aave/IStreamable.sol";

/**
 * @title Llama <> AAVE Proposal
 * @author Llama
 * @notice Payload to execute the Llama <> AAVE Proposal
 * Governance Forum Post: https://governance.aave.com/t/updated-proposal-llama-aave/9924
 * Snapshot:
 */
contract ProposalPayload {
    /********************************
     *   CONSTANTS AND IMMUTABLES   *
     ********************************/

    IAaveEcosystemReserveController public constant AAVE_ECOSYSTEM_RESERVE_CONTROLLER =
        IAaveEcosystemReserveController(0x3d569673dAa0575c936c7c67c4E6AedA69CC630C);

    IStreamable public constant ECOSYSTEM_RESERVE_V2_IMPL = IStreamable(0x1aa435ed226014407Fa6b889e9d06c02B1a12AF3);

    address public constant AAVE_MAINNET_RESERVE_FACTOR = 0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c;
    address public constant AAVE_ECOSYSTEM_RESERVE = 0x25F2226B597E8F9514B3F68F00f494cF4f286491;
    address public constant LLAMA_TREASURY = 0xA519a7cE7B24333055781133B13532AEabfAC81b;

    address public constant AUSDC_TOKEN = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
    address public constant AAVE_TOKEN = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;

    // 500,000 aUSDC = $0.5 Million
    uint256 public constant AUSDC_UPFRONT_AMOUNT = 500000e6; // 500,000 aUSDC

    // TODO: Figure out why we need the additional amount for streaming
    // ~700,000 aUSDC (A bit more for the streaming requirements) = $0.7 million
    uint256 public constant AUSDC_STREAM_AMOUNT = 700000e6;
    // ~3'480 AAVE (A bit more for the streaming requirements) = $0.3 Million using 30 day TWAP on day of proposal
    uint256 public constant AAVE_STREAM_AMOUNT = 3480e18;
    // 12 months of 30 days
    uint256 public constant STREAMS_DURATION = 360 days; // 12 months of 30 days

    /*****************
     *   FUNCTIONS   *
     *****************/

    /// @notice The AAVE governance executor calls this function to implement the proposal.
    function execute() external {
        // Transfer of the upfront payment: $0.5 million in aUSDC
        AAVE_ECOSYSTEM_RESERVE_CONTROLLER.transfer(
            AAVE_MAINNET_RESERVE_FACTOR,
            AUSDC_TOKEN,
            LLAMA_TREASURY,
            AUSDC_UPFRONT_AMOUNT
        );

        // TODO: Implement streaming of aUSDC and AAVE over 12 months
        // TODO: Figure out if and how to implement the stream cancel ability after 6 months here
    }
}
