# DeFi Stablecoin 🪙

## Find it on Sepolia TestNet
[DSCEngine](https://sepolia.etherscan.io/address/0x5678fa43373cd45fbdea3b3e2df255e9c14a30e6)

[Decentralised StableCoin](https://sepolia.etherscan.io/address/0xfd3b402f5ad4b92e2e97581c04f0aecc94e52a0c)

# About

This project is meant to be a stablecoin where users can deposit WETH and WBTC in exchange for a token that will be pegged to the USD.

# Protocol

1. #### Pegged to US Dollar:
   The stablecoin follows Relative Stability by being Pegged or Anchored to the US Dollar. (1 DSC = $1)
   
2. #### Collateral:
   Users will be able to mint DSC only after depositing a collateral.
   1.  Collateral Type: Exogenous (Crypto): wETH, wBTC
   2.  The protocol will be over-collaterised with a 200% margin i.e. to mint $100 worth of DSC, one has to deposit atleast $200 worth of collateral.
   
3. #### Liquidation: 
   Incase a user becomes undercollaterised, they can be liquidated by other users. The liquidator can partially or completely liquidate a bad user and will earn 10% on the the debt he decides covers, for the undercollaterised user. This bonus is to the incentive for liquidators to keep the protocol healthy and over-collaterised.

4. #### Protocol Collapse: 
   Incase the protocol becomes undercollaterised due to a drastic drop in value of the underlying collateral, a case where the total minted value is more than the total collateral value of the protocol, the protocol will trigger the `collapseDsc()` sequence, where in, it will auto-redeem all deposited collateral followed by burning all minted coins of all users and render itself collapsed!


# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

## Quickstart

```
git clone https://github.com/alfheimrShiven/defi-stablecoin.git
cd defi-stablecoin
make start
```

# Usage

## Start a local node

```
make anvil
```

## Deploy

This will default to your local node which is running the Anvil chain. You need to have it running in another terminal in order for it to deploy.

```
make deploy
```

## Deploy - Other Network

[See below](#deployment-to-a-testnet-or-mainnet)

## Testing

We talk about 4 test tiers in the video. 

1. Unit
2. Integration
3. Forked
4. Staging

In this repo we cover #1 and Fuzzing test. 

```
forge test
```

### Test Coverage

```
forge coverage
```

and for coverage based testing: 

```
forge coverage --report debug
```

# Deployment to a testnet or mainnet

1. Setup environment variables

You'll want to set your `SEPOLIA_RPC_URL` and `SEPOLIA_PRIVATE_KEY` as environment variables. You can add them to a `.env` file.

- `SEPOLIA_PRIVATE_KEY`: The private key of your account (like from [metamask](https://metamask.io/)). **NOTE:** FOR DEVELOPMENT, PLEASE USE A KEY THAT DOESN'T HAVE ANY REAL FUNDS ASSOCIATED WITH IT.
  - You can [learn how to export it here](https://metamask.zendesk.com/hc/en-us/articles/360015289632-How-to-Export-an-Account-Private-Key).
- `SEPOLIA_RPC_URL`: This is url of the sepolia testnet node you're working with. You can get setup with one for free from [Alchemy](https://alchemy.com/?a=673c802981)

Optionally, add your `ETHERSCAN_API_KEY` if you want to verify your contract on [Etherscan](https://etherscan.io/).

1. Get testnet ETH

Head over to [faucets.chain.link](https://faucets.chain.link/) and get some testnet ETH. You should see the ETH show up in your metamask.

2. Deploy

```
make deploy ARGS="--network sepolia"
```

## Scripts

Instead of scripts, we can directly use the `cast` command to interact with the contract. 

For example, on Sepolia:

1. Get some WETH 

```
cast send 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 "deposit()" --value 0.1ether --rpc-url $SEPOLIA_RPC_URL --private-key $SEPOLIA_PRIVATE_KEY
```

2. Approve the WETH

```
cast send 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 "approve(address,uint256)" 0x091EA0838eBD5b7ddA2F2A641B068d6D59639b98 1000000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $SEPOLIA_PRIVATE_KEY
```

3. Deposit and Mint DSC

```
cast send 0x091EA0838eBD5b7ddA2F2A641B068d6D59639b98 "depositCollateralAndMintDsc(address,uint256,uint256)" 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 100000000000000000 10000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $SEPOLIA_PRIVATE_KEY
```

## Estimate gas

You can estimate how much gas things cost by running:

```
forge snapshot
```

And you'll see an output file called `.gas-snapshot`

# Formatting


To run code formatting:
```
forge fmt
```


# Thank you!

If you appreciated this, feel free to follow me:

[**Github**](https://github.com/alfheimrShiven)

[![Shivens LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/shivends/)

[![Shivens Twitter](https://img.shields.io/badge/Twitter-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://twitter.com/shiven_alfheimr)
