# Decentralized Stablecoin Protocol (DSC)

A minimal, governance-free, overcollateralized stablecoin protocol pegged to USD.
Inspired by DAI, designed for simplicity and safety.


## Overview

* **Stablecoin:** DSC (USD-pegged)
* **Collateral:** WETH, WBTC
* **Collateralization:** 200% minimum
* **Design goal:** Always overcollateralized, no governance, no fees


## Core Invariants

* Total collateral value ≥ total DSC supply
* Users with debt must maintain **health factor ≥ 1**
* Liquidations must **improve** the user’s health factor


## Collateral Model

* Users deposit WETH/WBTC to mint DSC
* For every $1 DSC minted, ≥ $2 collateral is required
* Positions below the threshold are liquidatable

## Oracle Model

* Uses **Chainlink USD price feeds**
* Prices older than **3 hours** are considered stale

If prices become stale, the protocol **freezes**:

* ❌ Minting
* ❌ Redeeming
* ❌ Liquidations

This is intentional to avoid using incorrect prices.

## Liquidations

* Triggered when health factor < 1
* Anyone can liquidate by repaying DSC
* Liquidator receives collateral + **10% bonus**
* Partial liquidations are supported
* Liquidations revert if they don’t improve health factor

## Known Limitations

* Fully dependent on Chainlink oracles
* Only WETH and WBTC supported
* No governance, upgrades, or emergency shutdown
* No fees, insurance fund, or peg-defense mechanisms
* Vulnerable to extreme fast market crashes
* **Unaudited — for educational use only**

## Quick Start

```sh
forge build
forge test
```

## Deployment

Deploy to Sepolia:

```sh
make deploy ARGS="--network sepolia"
```

## Disclaimer

This protocol is **experimental and unaudited**.
Do not use with real funds.


