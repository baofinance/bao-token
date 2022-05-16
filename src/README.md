# Bao Finance DAO contracts

All contract sources are within this directory.

## Subdirectories

* [`burners`](burners): Contracts used to convert admin fees into 3CRV prior to distribution to the DAO.
* [`gauges`](gauges): Contracts used for measuring provided liquidity.
* [`testing`](testing): Contracts used exclusively for testing. Not considered to be a core part of this project.
* [`vests`](vests): Contracts for vesting CRV.

## Contracts

* [`BAOv2`](BAOv2.sol): Bao Token (BAO), an [ERC20](https://eips.ethereum.org/EIPS/eip-20) with piecewise-linear mining supply
* [`GaugeController`](GaugeController.vy): Controls liquidity gauges and the issuance of CRV through the liquidity gauges
* [`LiquidityGauge`](LiquidityGauge.vy): Measures the amount of liquidity provided by each user
* [`Minter`](Minter.vy): Token minting contract used for issuing new BAO
* [`PoolProxy`](PoolProxy.vy): StableSwap pool proxy contract for interactions between the DAO and pool contracts
* [`VestingEscrow`](VestingEscrow.vy): Vests BAO tokens for multiple addresses over multiple vesting periods
* [`VestingEscrowFactory`](VestingEscrowFactory.vy): Factory to store BAO and deploy many simplified vesting contracts
* [`VestingEscrowSimple`](VestingEscrowSimple.vy): Simplified vesting contract that holds BAO for a single address
* [`VotingEscrow`](VotingEscrow.vy): Vesting contract for locking BAO to participate in DAO governance
