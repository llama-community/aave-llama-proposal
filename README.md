# Llama <> AAVE Proposal

Payload and tests for the Llama <> AAVE Proposal

## Specification

This repository contains the [Payload](https://github.com/llama-community/aave-llama-proposal/blob/main/src/ProposalPayload.sol) and [Tests](https://github.com/llama-community/aave-llama-proposal/blob/main/src/test/ProposalPayload.t.sol) for the [Llama <> Aave Proposal](https://governance.aave.com/t/updated-proposal-llama-aave/9924)

The Proposal Payload does the following:

1. Transfers upfront 350,000 aUSDC ($0.35 Million) to the Llama-controlled address.
2. Transfers upfront 1,813.68 AAVE ($0.15 Million using 30 day TWAP on day of proposal) to the Llama-controlled address.
3. Creates a 12-month stream of 700,000 aUSDC ($0.7 Million) to the Llama-controlled address.
4. Creates a 12-month stream of 3,627.35 AAVE ($0.3 Million using 30 day TWAP on day of proposal) to the Llama-controlled address.

The 30 day TWAP calculation can be found [Here](https://docs.google.com/spreadsheets/d/1EiXdmLXxF-oqxOfS_AN94bpfWtPFnbwigPgiKXgXhW0/edit#gid=0)

## Installation

It requires [Foundry](https://github.com/gakonst/foundry) installed to run. You can find instructions here [Foundry installation](https://github.com/gakonst/foundry#installation).

In order to install, run the following commands:

```sh
$ git clone https://github.com/llama-community/aave-llama-proposal.git
$ cd aave-llama-proposal/
$ npm install
$ forge install
```

## Setup

Duplicate `.env.example` and rename to `.env`:

- Add a valid mainnet URL for an Ethereum JSON-RPC client for the `RPC_MAINNET_URL` variable.
- Add a valid Private Key for the `PRIVATE_KEY` variable.
- Add a valid Etherscan API Key for the `ETHERSCAN_API_KEY` variable.

### Commands

- `make build` - build the project
- `make test [optional](V={1,2,3,4,5})` - run tests (with different debug levels if provided)
- `make match MATCH=<TEST_FUNCTION_NAME> [optional](V=<{1,2,3,4,5}>)` - run matched tests (with different debug levels if provided)

### Deploy and Verify

- `make deploy-payload` - deploy and verify payload on mainnet
- `make deploy-proposal`- deploy proposal on mainnet

To confirm the deploy was successful, re-run your test suite but use the newly created contract address.
