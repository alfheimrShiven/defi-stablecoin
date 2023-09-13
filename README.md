1. Relative Stability: Pegged or Anchored -> $1.00
   1. Use Chainlink Price feed.
   2. Exchange ETH/BTC <-> $$$

2. Stability Mechanism (Minting): Algorithmic (Decentralized)
   1. People will only be able to mint stable coin only with enough collatoral (200%) (will be coded)

3. Collateral Type: Exogenous (Crypto)
   1. wETH
   2. wBTC

4. Incase a user becomes undercollaterised, they can be liquidated by other users.
   1. The liquidator will earn 10% of the debtToCover (the debt of the undercollaterised user he's liquidating) as a liquidation bonus.

5. Incase the protocol becomes undercollaterised due to a drastic drop in the underlying collateral value wherein dscMinted > collateralValue, the protocol should auto-redeem all users collateral, burn all minted coins and render itself collapsed!