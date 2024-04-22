### **Decentralized Stable Coin (DSC)**

Overview

The Decentralized Stable Coin (DSC) is a smart contract system designed to facilitate the creation and management of a stablecoin pegged to a fiat currency. This system allows users to mint and burn DSC tokens, ensuring stability and security within the ecosystem.
Features
1. ERC20 Compatibility: DSC is fully compliant with the ERC20 standard, ensuring interoperability with other Ethereum-based tokens and decentralized applications (DApps).
2. Minting and Burning: Authorized users can mint new DSC tokens by depositing collateral, and burn existing tokens to redeem the underlying collateral.
3. Ownership Control: The contract owner has exclusive control over minting and burning operations, ensuring proper governance and security.
Error Handling: The contract includes custom error messages to provide clear feedback in case of invalid transactions or operations.







1. (Relative Stability) Anchored or Pegged to $1:00
   1. We use Chainlink Price feed to peg
   2. Set a function to exchange ETH & BTC -> $$$ equivalent. 
2. Stability Mechanism (Minting): Algorithmic (Decentralized)
      1. People can only mint the stablecoin with enough collateral (coded)
3. Collateral: Exogenous (Crypto)
     1. ETH
     2. BTC