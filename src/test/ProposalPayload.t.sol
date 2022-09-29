// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

// testing libraries
import "@forge-std/Test.sol";

// contract dependencies
import {AaveV2Ethereum} from "@aave-address-book/AaveV2Ethereum.sol";
import {IAaveGovernanceV2} from "../external/aave/IAaveGovernanceV2.sol";
import {IStreamable} from "../external/aave/IStreamable.sol";
import {ProposalPayload} from "../ProposalPayload.sol";
import {DeployMainnetProposal} from "../../script/DeployMainnetProposal.s.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract ProposalPayloadTest is Test {
    IAaveGovernanceV2 private aaveGovernanceV2 = IAaveGovernanceV2(0xEC568fffba86c094cf06b22134B23074DFE2252c);
    IERC20 public constant AUSDC = IERC20(0xBcca60bB61934080951369a648Fb03DF4F96263C);
    IERC20 public constant AAVE = IERC20(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);

    address public immutable AAVE_MAINNET_RESERVE_FACTOR = AaveV2Ethereum.COLLECTOR;
    address public constant AAVE_ECOSYSTEM_RESERVE = 0x25F2226B597E8F9514B3F68F00f494cF4f286491;
    address public constant LLAMA_RECIPIENT = 0xb428C6812E53F843185986472bb7c1E25632e0f7;

    IStreamable public immutable STREAMABLE_AAVE_MAINNET_RESERVE_FACTOR = IStreamable(AaveV2Ethereum.COLLECTOR);
    IStreamable public constant STREAMABLE_AAVE_ECOSYSTEM_RESERVE = IStreamable(AAVE_ECOSYSTEM_RESERVE);

    uint256 public constant AUSDC_UPFRONT_AMOUNT = 350000e6;
    uint256 public constant AAVE_UPFRONT_AMOUNT = 181368e16;
    uint256 public constant AUSDC_STREAM_AMOUNT = 700026624000;
    uint256 public constant AAVE_STREAM_AMOUNT = 3627350000000007552000;
    uint256 public constant STREAMS_DURATION = 360 days;

    address[] private aaveWhales;

    address private proposalPayloadAddress;

    uint256 private proposalId;

    function setUp() public {
        // To fork at a specific block: vm.createSelectFork(vm.rpcUrl("mainnet", BLOCK_NUMBER));
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        // aave whales may need to be updated based on the block being used
        // these are sometimes exchange accounts or whale who move their funds

        // select large holders here: https://etherscan.io/token/0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9#balances
        aaveWhales.push(0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8);
        aaveWhales.push(0x26a78D5b6d7a7acEEDD1e6eE3229b372A624d8b7);
        aaveWhales.push(0x2FAF487A4414Fe77e2327F0bf4AE2a264a776AD2);

        // create proposal is configured to deploy a Payload contract and call execute() as a delegatecall
        // most proposals can use this format - you likely will not have to update this
        _createProposal();

        // these are generic steps for all proposals - no updates required
        _voteOnProposal();
        _skipVotingPeriod();
        _queueProposal();
        _skipQueuePeriod();
    }

    function testSetup() public {
        IAaveGovernanceV2.ProposalWithoutVotes memory proposal = aaveGovernanceV2.getProposalById(proposalId);
        assertEq(proposalPayloadAddress, proposal.targets[0], "TARGET_IS_NOT_PAYLOAD");

        IAaveGovernanceV2.ProposalState state = aaveGovernanceV2.getProposalState(proposalId);
        assertEq(uint256(state), uint256(IAaveGovernanceV2.ProposalState.Queued), "PROPOSAL_NOT_IN_EXPECTED_STATE");
    }

    function testExecute() public {
        uint256 initialMainnetReserveFactorAusdcBalance = AUSDC.balanceOf(AAVE_MAINNET_RESERVE_FACTOR);
        uint256 initialLlamaAusdcBalance = AUSDC.balanceOf(LLAMA_RECIPIENT);
        uint256 initialEcosystemReserveAaveBalance = AAVE.balanceOf(AAVE_ECOSYSTEM_RESERVE);
        uint256 initialLlamaAaveBalance = AAVE.balanceOf(LLAMA_RECIPIENT);

        // Capturing next Stream IDs before proposal is executed
        uint256 nextMainnetReserveFactorStreamID = STREAMABLE_AAVE_MAINNET_RESERVE_FACTOR.getNextStreamId();
        uint256 nextEcosystemReserveStreamID = STREAMABLE_AAVE_ECOSYSTEM_RESERVE.getNextStreamId();

        _executeProposal();

        // Checking upfront aUSDC payment of $0.35 million
        // Compensating for +1/-1 precision issues when rounding, mainly on aTokens
        assertApproxEqAbs(
            initialMainnetReserveFactorAusdcBalance - AUSDC_UPFRONT_AMOUNT,
            AUSDC.balanceOf(AAVE_MAINNET_RESERVE_FACTOR),
            1
        );
        assertApproxEqAbs(initialLlamaAusdcBalance + AUSDC_UPFRONT_AMOUNT, AUSDC.balanceOf(LLAMA_RECIPIENT), 1);
        // Checking upfront AAVE payment of $0.15 million
        assertEq(initialEcosystemReserveAaveBalance - AAVE_UPFRONT_AMOUNT, AAVE.balanceOf(AAVE_ECOSYSTEM_RESERVE));
        assertEq(initialLlamaAaveBalance + AAVE_UPFRONT_AMOUNT, AAVE.balanceOf(LLAMA_RECIPIENT));

        // Checking if the streams have been created properly
        // aUSDC stream
        (
            address senderAusdc,
            address recipientAusdc,
            uint256 depositAusdc,
            address tokenAddressAusdc,
            uint256 startTimeAusdc,
            uint256 stopTimeAusdc,
            uint256 remainingBalanceAusdc,
            uint256 ratePerSecondAusdc
        ) = STREAMABLE_AAVE_MAINNET_RESERVE_FACTOR.getStream(nextMainnetReserveFactorStreamID);

        assertEq(senderAusdc, AAVE_MAINNET_RESERVE_FACTOR);
        assertEq(recipientAusdc, LLAMA_RECIPIENT);
        assertEq(depositAusdc, AUSDC_STREAM_AMOUNT);
        assertEq(tokenAddressAusdc, address(AUSDC));
        assertEq(stopTimeAusdc - startTimeAusdc, STREAMS_DURATION);
        assertEq(remainingBalanceAusdc, AUSDC_STREAM_AMOUNT);

        // AAVE stream
        (
            address senderAave,
            address recipientAave,
            uint256 depositAave,
            address tokenAddressAave,
            uint256 startTimeAave,
            uint256 stopTimeAave,
            uint256 remainingBalanceAave,
            uint256 ratePerSecondAave
        ) = STREAMABLE_AAVE_ECOSYSTEM_RESERVE.getStream(nextEcosystemReserveStreamID);

        assertEq(senderAave, AAVE_ECOSYSTEM_RESERVE);
        assertEq(recipientAave, LLAMA_RECIPIENT);
        assertEq(depositAave, AAVE_STREAM_AMOUNT);
        assertEq(tokenAddressAave, address(AAVE));
        assertEq(stopTimeAave - startTimeAave, STREAMS_DURATION);
        assertEq(remainingBalanceAave, AAVE_STREAM_AMOUNT);

        // Checking if Llama can withdraw from streams
        vm.startPrank(LLAMA_RECIPIENT);
        // Checking Llama withdrawal every 30 days over 12 month period
        for (uint256 i = 0; i < 12; i++) {
            vm.warp(block.timestamp + 30 days);

            uint256 currentAusdcLlamaBalance = AUSDC.balanceOf(LLAMA_RECIPIENT);
            uint256 currentAaveLlamaBalance = AAVE.balanceOf(LLAMA_RECIPIENT);
            uint256 currentAusdcLlamaStreamBalance = STREAMABLE_AAVE_MAINNET_RESERVE_FACTOR.balanceOf(
                nextMainnetReserveFactorStreamID,
                LLAMA_RECIPIENT
            );
            uint256 currentAaveLlamaStreamBalance = STREAMABLE_AAVE_ECOSYSTEM_RESERVE.balanceOf(
                nextEcosystemReserveStreamID,
                LLAMA_RECIPIENT
            );

            STREAMABLE_AAVE_MAINNET_RESERVE_FACTOR.withdrawFromStream(
                nextMainnetReserveFactorStreamID,
                currentAusdcLlamaStreamBalance
            );

            STREAMABLE_AAVE_ECOSYSTEM_RESERVE.withdrawFromStream(
                nextEcosystemReserveStreamID,
                currentAaveLlamaStreamBalance
            );

            // Compensating for +1/-1 precision issues when rounding, mainly on aTokens
            // Checking aUSDC stream amount
            assertApproxEqAbs(
                AUSDC.balanceOf(LLAMA_RECIPIENT),
                currentAusdcLlamaBalance + currentAusdcLlamaStreamBalance,
                1
            );
            assertApproxEqAbs(
                AUSDC.balanceOf(LLAMA_RECIPIENT),
                currentAusdcLlamaBalance + (ratePerSecondAusdc * 30 days),
                1
            );
            // Checking AAVE stream amount
            assertEq(AAVE.balanceOf(LLAMA_RECIPIENT), currentAaveLlamaBalance + currentAaveLlamaStreamBalance);
            assertEq(AAVE.balanceOf(LLAMA_RECIPIENT), currentAaveLlamaBalance + (ratePerSecondAave * 30 days));
        }
        vm.stopPrank();
    }

    function _executeProposal() public {
        // execute proposal
        aaveGovernanceV2.execute(proposalId);

        // confirm state after
        IAaveGovernanceV2.ProposalState state = aaveGovernanceV2.getProposalState(proposalId);
        assertEq(uint256(state), uint256(IAaveGovernanceV2.ProposalState.Executed), "PROPOSAL_NOT_IN_EXPECTED_STATE");
    }

    /*******************************************************************************/
    /******************     Aave Gov Process - Create Proposal     *****************/
    /*******************************************************************************/

    function _createProposal() public {
        ProposalPayload proposalPayload = new ProposalPayload();
        proposalPayloadAddress = address(proposalPayload);

        vm.prank(aaveWhales[0]);
        proposalId = DeployMainnetProposal._deployMainnetProposal(
            proposalPayloadAddress,
            0x344d3181f08b3186228b93bac0005a3a961238164b8b06cbb5f0428a9180b8a7 // TODO: Replace with actual IPFS Hash
        );
    }

    /*******************************************************************************/
    /***************     Aave Gov Process - No Updates Required      ***************/
    /*******************************************************************************/

    function _voteOnProposal() public {
        IAaveGovernanceV2.ProposalWithoutVotes memory proposal = aaveGovernanceV2.getProposalById(proposalId);
        vm.roll(proposal.startBlock + 1);
        for (uint256 i; i < aaveWhales.length; i++) {
            vm.prank(aaveWhales[i]);
            aaveGovernanceV2.submitVote(proposalId, true);
        }
    }

    function _skipVotingPeriod() public {
        IAaveGovernanceV2.ProposalWithoutVotes memory proposal = aaveGovernanceV2.getProposalById(proposalId);
        vm.roll(proposal.endBlock + 1);
    }

    function _queueProposal() public {
        aaveGovernanceV2.queue(proposalId);
    }

    function _skipQueuePeriod() public {
        IAaveGovernanceV2.ProposalWithoutVotes memory proposal = aaveGovernanceV2.getProposalById(proposalId);
        vm.warp(proposal.executionTime + 1);
    }
}
