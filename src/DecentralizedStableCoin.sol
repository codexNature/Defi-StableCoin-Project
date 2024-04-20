// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin.
// Exogeneous collateral is collateral that originates from outside the protocol. I.e pegged with USD.
// Endogenous collateral is collateral that originates from inside the protocol. I.e collateral was created with the sole purpose of being a collateral.

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.20;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title DecentralizedStableCoin
 * @author Olusola Jaiyeola
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 *
 * This is the contract meant to be goverend by DSCEngine. This contract is just the ERC20 implementation of our stablecoin syatem.
 */

contract DecentralizedStableCoin is
    Ownable,
    ERC20Burnable //This line declares a new smart contract named DecentralizedStableCoin. It indicates that the contract inherits functionality from two other contracts: Ownable and ERC20Burnable.
{
    //Error    These lines define custom errors that the contract can revert to if certain conditions are not met during execution.
    error DecentralizedStableCoin_MustBeMoreThanZero();
    error DecentralizedStableCoin_BurnAmountExceedsBalance();
    error DecentralizedStableCoin_NotZeroAddress();

    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {} //This line defines the constructor function for the contract. The constructor initializes the contract with the name "DecentralizedStableCoin" and the symbol "DSC". Additionally, it ensures that the contract is owned by the account that deploys it (msg.sender) by calling the constructor of the Ownable contract.

    function burn(uint _amount) public override onlyOwner {
        //This line declares a function named burn that allows the owner of the contract to burn a specified amount of tokens. The override keyword indicates that this function overrides the burn function inherited from the ERC20Burnable contract. The onlyOwner modifier restricts the function to be callable only by the owner of the contract.
        uint256 balance = balanceOf(msg.sender); //This line retrieves the balance of the owner (the account that deployed the contract) by calling the balanceOf function inherited from the ERC20 contract. It assigns the balance to a variable named balance.
        if (_amount <= 0) {
            revert DecentralizedStableCoin_MustBeMoreThanZero(); //This line checks if the amount specified for burning is less than or equal to zero. If it is, the contract reverts execution and triggers the DecentralizedStableCoin_MustBeMoreThanZero error.
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin_BurnAmountExceedsBalance(); //This line checks if the amount specified for burning exceeds the balance of the owner. If it does, the contract reverts execution and triggers the DecentralizedStableCoin_BurnAmountExceedsBalance error.
        }
        super.burn(_amount); // This line calls the burn function inherited from the ERC20Burnable contract to burn the specified amount of tokens. The super keyword is used to access and call functions from the parent contract.
    }

    function mint(
        //This line declares a function named mint that allows the contract owner to create new tokens and give them to a specific address.
        address _to, //It takes two parameters: _to, which represents the address where the new tokens will be sent
        uint256 _amount //and _amount, which represents the number of tokens to be created
    ) external onlyOwner returns (bool) {
        //The function is marked as external, meaning it can be called from outside the contract. Additionally, it includes a modifier onlyOwner, which restricts the function to be called only by the contract owner. It returns a boolean value indicating whether the minting process was successful
        if (_to == address(0)) {
            revert DecentralizedStableCoin_NotZeroAddress(); //This line checks if the address _to is equal to address(0), which represents the Ethereum null address. If _to is indeed the null address, the function reverts the transaction with an error message DecentralizedStableCoin_NotZeroAddress(). This ensures that tokens cannot be minted to the null address, preventing the loss of tokens.
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin_MustBeMoreThanZero(); //This line checks if the _amount of tokens to be minted is less than or equal to zero. If _amount is zero or negative, the function reverts the transaction with an error message DecentralizedStableCoin_MustBeMoreThanZero(). This ensures that only a positive amount of tokens can be minted.
        }
        _mint(_to, _amount); //This line calls the internal _mint function to create new tokens and assign them to the specified recipient address _to. The _mint function is responsible for actually creating the tokens and updating the token balances.
        return true; //This line indicates that the minting process was successful. Since the function is declared as view, it cannot actually perform the minting operation but can only perform checks and return a result. Therefore, it always returns true to indicate that the checks passed successfully.
    }
}
