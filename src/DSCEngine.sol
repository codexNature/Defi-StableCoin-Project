// SPDX-License-Identifier: MIT



/*1. (Relative Stability) Anchored or Pegged to $1:00
   1. We use Chainlink Price feed to peg
   2. Set a function to exchange ETH & BTC -> $$$ equivalent. 
2. Stability Mechanism (Minting): Algorithmic (Decentralized)
      1. People can only mint the stablecoin with enough collateral (coded)
3. Collateral: Exogenous (Crypto)
     1. ETH
     2. BTC*/

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin.
// Exogeneous collateral is collateral that originates from outside the protocol. I.e pegged with USD.
// Endogenous collateral is collateral that originates from inside the protocol. I.e collateral was created with the sole purpose of being a collateral.
// Algoritmically stable: When a stablecoin is described as "algorithmically stable," it means that its stability is maintained through the use of algorithms, rather than relying on traditional methods such as holding reserves of fiat currency. Algorithmically stable stablecoins typically utilize complex mathematical formulas, algorithms, and smart contract mechanisms to regulate their supply and demand dynamics, thereby ensuring that their value remains relatively stable against a chosen reference asset, such as the US dollar.

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

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "./libraries/OracleLib.sol";

/**
 * @title DSCEngine
 * @author Olusola Jaiyeola
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg.
 * This stablecoin has the properties:
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algoritmically
 *
 * - It is similar to DAI if DAI had no governace, no fees, and was only backed bt WETh and WBTC.
 *
 * Our DSC system should always be over collaateralized. At no point, should the value of all collateral <= the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the DSC System. It handles all the logic for minting and redeeming DSC, as well as depositing & withdrawing collateral.
 * @notice This contract is VERY loosely based on the MakerDAO DSS (DAI) system.
 */
contract DSCEngine is
    ReentrancyGuard //patrick edited
{
    ///////////////////
    // Errors
    ///////////////////

    error DSCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine_NeedsMoreThanZero();
    error DSCEngine_NotAllowedToken(address token);
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactorValue);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();

    ///////////////////
    // Types
    ///////////////////
    using OracleLib for AggregatorV3Interface;

    ///////////////////
    // State Variables
    ///////////////////
    DecentralizedStableCoin private immutable i_dsc;

    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_BONUS = 10; // This means you get assets at a 10% discount when liquidating
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant FEED_PRECISION = 1e8;

    /// @dev Mapping of token address to price feed address
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    /// @dev Amount of collateral deposited by user
    mapping(address user => mapping(address collateralToken => uint256 amount)) private s_collateralDeposited;
    /// @dev Amount of DSC minted by user
    mapping(address user => uint256 amount) private s_DSCMinted;
    /// @dev If we know exactly how many tokens we have, we could make this immutable!
    address[] private s_collateralTokens;

    ///////////////////
    // Events
    ///////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount); // if
        // redeemFrom != redeemedTo, then it was liquidated

    ///////////////////
    // Modifiers
    ///////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine_NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine_NotAllowedToken(token);
        }
        _;
    }

    ///////////////////
    // Functions
    ///////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        // These feeds will be the USD pairs
        // For example ETH / USD or MKR / USD
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ///////////////////
    // External Functions
    ///////////////////
    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     * @param amountDscToMint: The amount of DSC you want to mint
     * @notice This function will deposit your collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     * @param amountDscToBurn: The amount of DSC you want to burn
     * @notice This function will withdraw your collateral and burn DSC in one transaction
     */
    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
    {
        _burnDsc(amountDscToBurn, msg.sender, msg.sender);
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're redeeming
     * @param amountCollateral: The amount of collateral you're redeeming
     * @notice This function will redeem your collateral.
     * @notice If you have DSC minted, you will not be able to redeem until you burn your DSC
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
     * @notice careful! You'll burn your DSC here! Make sure you want to do this...
     * @dev you might want to use this if you're nervous you might get liquidated and want to just burn
     * you DSC but keep your collateral in.
     */
    function burnDsc(uint256 amount) external moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender); // I don't think this would ever hit...
    }

    /*
     * @param collateral: The ERC20 token address of the collateral you're using to make the protocol solvent again.
     * This is collateral that you're going to take from the user who is insolvent.
     * In return, you have to burn your DSC to pay off their debt, but you don't pay off your own.
     * @param user: The user who is insolvent. They have to have a _healthFactor below MIN_HEALTH_FACTOR
     * @param debtToCover: The amount of DSC you want to burn to cover the user's debt.
     *
     * @notice: You can partially liquidate a user.
     * @notice: You will get a 10% LIQUIDATION_BONUS for taking the users funds.
    * @notice: This function working assumes that the protocol will be roughly 150% overcollateralized in order for this
    to work.
    * @notice: A known bug would be if the protocol was only 100% collateralized, we wouldn't be able to liquidate
    anyone.
     * For example, if the price of the collateral plummeted before anyone could be liquidated.
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }
        // If covering 100 DSC, we need to $100 of collateral
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        // And give them a 10% bonus
        // So we are giving the liquidator $110 of WETH for 100 DSC
        // We should implement a feature to liquidate in the event the protocol is insolvent
        // And sweep extra amounts into a treasury
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        // Burn DSC equal to debtToCover
        // Figure out how much collateral to recover based on how much burnt
        _redeemCollateral(collateral, tokenAmountFromDebtCovered + bonusCollateral, user, msg.sender);
        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        // This conditional should never hit, but just in case
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        revertIfHealthFactorIsBroken(msg.sender);
    }

    ///////////////////
    // Public Functions
    ///////////////////
    /*
     * @param amountDscToMint: The amount of DSC you want to mint
     * You can only mint DSC if you hav enough collateral
     */
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);

        if (minted != true) {
            revert DSCEngine__MintFailed();
        }
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    ///////////////////
    // Private Functions
    ///////////////////
    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;

        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        // This conditional is hypothetically unreachable
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }

    //////////////////////////////
    // Private & Internal View & Pure Functions
    //////////////////////////////

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]); //This line declares a variable priceFeed of type AggregatorV3Interface. It initializes this variable by accessing the address stored in the s_priceFeeds mapping using the token as the key. The AggregatorV3Interface is a contract interface that provides functions to interact with price feed contracts, typically used to get price information from decentralized oracles.
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData(); //This line calls the (swapped latestRoundData for staleCheckLatestRoundData in OracleLib) function of the priceFeed contract, passing the amount parameter. It retrieves the latest price data for the specified token from the price feed. The returned value price is an integer representing the price of the token in USD.
        //         //If ETH = $1,000
        //         //The returned value from CL will be 1,000 * 1e8.
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION; //This line calculates the USD value of the specified token amount. It multiplies the price by ADDITIONAL_FEED_PRECISION (a constant) to account for additional precision provided by the price feed. Then, it multiplies the result by the token amount and divides by PRECISION (another constant) to adjust for the precision of the token amount. The final result is returned as a uint256 value representing the USD value of the token amount.
    }

    function _calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    // External & Public View & Pure Functions
    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    function calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(user);
    }

    function _getUsdValue(
        address token,
        uint256 amount // in WEI
    ) external view returns (uint256) {
        return getUsdValue(token, amount);
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 index = 0; index < s_collateralTokens.length; index++) {
            address token = s_collateralTokens[index];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        //         //Price of ETH(token)
        //         //$/ETH ETh ?? dollar per ETH how do we get the ETH.
        //         //$2000/ETH. $1000 = 0.5ETH
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        //         //i.e ($10e18 * 1e18) / ($2000e8 * 1e10)
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getDsc() external view returns (address) {
        return address(i_dsc);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }
}

// contract DSCEngine2 is ReentrancyGuard {  //my contract
//     //////////
//     //Errors//
//     //////////
//     error DSCEngine_NeedsMoreThanZero();
//     error DSCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength();
//     error DSCEngine_NotAllowedToken();
//     error DSCEngine__TransferFailed();
//     error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
//     error DSCEngine__MintFailed();
//     error DSCEngine__HealthFactorOk();
//     error DSCEngine__HealthFactorNoImproved();

//     //////////////////
//     //State Variables//
//     //////////////////
//     uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
//     uint256 private constant PRECISION = 1e18;
//     uint256 private constant LIQUIDATION_THRESHOLD = 50; //this means must be 200% overcollateralized.
//     uint256 private constant LIQUIDATION_PRECISION = 100;
//     uint256 private constant MIN_HEALTH_FACTOR = 1e18;
//     uint256 private constant LIQUIDATION_BONUS = 10; //this means a 10% bonus

//     mapping(address token => address priceFeed) private s_priceFeeds; // normally it should be like tokenToPriceFeed but since we are using chainlink priceFeed hence s_priceFeeds. Token address is mapped to the pricefeed address.
//     //the line of code is defining a private mapping named s_priceFeeds that associates token addresses with corresponding priceFeed addresses. It's used to keep track of which price feed contract is associated with each token contract within the contract it's defined in.
//     mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited; // this line of code creates a private mapping called s_collateralDeposited that tracks the amounts of different tokens deposited as collateral by each user. It's a nested mapping where the outer mapping uses user addresses as keys, and the inner mapping associates token addresses with the corresponding amounts of collateral deposited.
//     mapping(address user => uint256 amountDscMinted) private s_DSCMinted; //Keep track of the amount minted by who. This line of code is creating a storage space called s_DSCMinted that keeps track of how much of a digital currency called "DSC" has been minted for each user
//     address[] private s_collateralTokens;

//     DecentralizedStableCoin private immutable i_dsc;

//     //////////////////
//     //Events//
//     //////////////////
//     event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
//     event CollateralRedeemed(
//         address indexed redeemedFrom, address indexed redeemedto, address indexed token, uint256 amount
//     );

//     ////////////////
//     // Modifiers ///
//     ////////////////
//     modifier moreThanZero(uint256 amount) {
//         //This line defines a modifier called moreThanZero. A modifier is a special type of function in Solidity that can modify the behavior of other functions. This modifier takes a parameter amount of type uint256,
//         if (amount == 0) {
//             //This line checks if the amount parameter is equal to zero. In other words, it's checking if the value passed to the amount parameter is zero
//             revert DSCEngine_NeedsMoreThanZero(); //If the amount is indeed zero, this line triggers a revert operation. Revert is a way to revert the state of a transaction, effectively canceling it. In this case, if the amount is zero, it means that the condition of the modifier is not met, so the transaction is reverted with an error message that says "DSCEngine_NeedsMoreThanZero".
//         }
//         _; //This line is a placeholder that indicates where the modified function's body will be placed. The underscore _ represents the modified function's body. In other words, this line allows the code inside the function that uses this modifier to be executed if the condition specified in the modifier is met.
//     }

//     modifier isAllowedToken(address token) {
//         //This line declares a modifier named isAllowedToken.
//         if (s_priceFeeds[token] == address(0)) {
//             //Inside the modifier, it checks if the value stored in the s_priceFeeds mapping for the given token address is equal to address(0). In simpler terms, it's checking if there is a valid price feed contract stored for the given token address.
//             revert DSCEngine_NotAllowedToken(); // If the condition inside the if statement is true (meaning there is no valid price feed contract for the token), it immediately stops the function execution and reverts any changes made so far. It also emits an error message indicating that the token is not allowed
//         }
//         _;
//     }

//     ////////////////
//     // Functions ///
//     ////////////////
//     constructor(
//         address[] memory tokenAddresses,
//         address[] memory priceFeedAddresses,
//         address dscAddress // It takes three parameters: tokenAddresses, priceFeedAddresses, and dscAddress, which are arrays of addresses representing token addresses, price feed addresses, and the address of a Decentralized Stablecoin (DSC) contract, respectively.
//     ) {
//         //Backed by USD backed Pricefeed.
//         if (tokenAddresses.length != priceFeedAddresses.length) {
//             revert DSCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength(); //This line checks if the length of the tokenAddresses array is not equal to the length of the priceFeedAddresses array. If they are not the same length, it reverts the transaction with an error message indicating that the token addresses and price feed addresses must be of the same length.
//         }
//         for (uint256 i = 0; i < tokenAddresses.length; i++) {
//             s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
//             s_collateralTokens.push(tokenAddresses[i]); //This line starts a loop that iterates over each element of the tokenAddresses array. For each iteration, it assigns the corresponding element from the priceFeedAddresses array to the s_priceFeeds mapping, using the current token address as the key. It also adds the current token address to the s_collateralTokens array.
//         }
//         i_dsc = DecentralizedStableCoin(dscAddress); //This line initializes a contract-level variable called i_dsc with an instance of the DecentralizedStableCoin contract, using the address provided in the dscAddress parameter. This allows the current contract to interact with the DecentralizedStableCoin contract.
//     }

//     //////////////// //////
//     // External Functions //
//     //////////////// ///////

//     /**
//      *
//      * @param tokenCollateralAddress The address of the token to deposit as collateral.
//      * @param amountCollateral  The amount of collateral to deposite
//      * @param amountDscToMint  The amount of decentralized stablecoin to mint.
//      * @notice this function will deposit your collateral and mint DSC in one transaction
//      */
//     function depositCollateralAndMintDsc(
//         address tokenCollateralAddress,
//         uint256 amountCollateral,
//         uint256 amountDscToMint
//     ) external {
//         depositCollateral(tokenCollateralAddress, amountCollateral);
//         mintDsc(amountDscToMint);
//     }

//     /**
//      * @notice follows CEI [checks effects interactions]
//      * @param tokenCollateralAddress The address of the token to deposit as collateral
//      * @param amountCollateral The amount of collateral to deposit
//      */
//     function depositCollateral(
//         //This line declares a function named depositCollateral. Functions in Solidity are blocks of code that can be called to perform specific tasks.
//         address tokenCollateralAddress,
//         uint256 amountCollateral //This line specifies the parameters that the depositCollateral function expects to receive when it's called. It expects an address parameter called tokenCollateralAddress, which represents the address of the token being deposited as collateral, and a uint256 parameter called amountCollateral, which represents the amount of collateral being deposited.
//     )
//         public
//         moreThanZero(amountCollateral) //This is a modifier applied to the function. Modifiers are pieces of code that can change the behavior of functions. In this case, moreThanZero is a modifier that checks whether the amountCollateral parameter is greater than zero before allowing the function to be executed. If the condition is not met, the function will not be executed.
//         isAllowedToken(tokenCollateralAddress) //This modifier checks whether the tokenCollateralAddress parameter corresponds to an allowed token. It verifies whether the token being used as collateral is permitted by the contract.
//         nonReentrant
//     {
//         s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral; //This line updates the mapping s_collateralDeposited to record the amount of collateral deposited by the caller (msg.sender) for the specified tokenCollateralAddress. It adds the amountCollateral to the existing balance of collateral deposited by the caller for that particular token.
//         emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral); //This line emits an event named CollateralDeposited, indicating that a deposit of collateral has occurred. It includes the address of the depositor (msg.sender), the address of the collateral token, and the amount of collateral deposited as parameters of the event.
//         bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral); //This line attempts to transfer the deposited collateral from the caller (msg.sender) to the contract address (address(this)) using the ERC20 transferFrom function. It creates a boolean variable success to capture whether the transfer was successful.
//         if (!success) {
//             revert DSCEngine__TransferFailed(); //This line checks if the collateral transfer was unsuccessful (i.e., if success is false). If the transfer fails, it reverts the transaction and emits the DSCEngine__TransferFailed error. This ensures that the deposit transaction is reverted if the collateral transfer fails, maintaining the integrity of the deposit process.
//         }
//     }

//     /**
//      * @param tokenCollateralAddress The collateral address to redeem
//      * @param amountCollateral The amount of collateral to redeem
//      * @param amountDscToBurn The amount of Dsc to burn
//      * @notice This function burns DSC and reddems underlying collateral in one transaction.
//      */
//     function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
//         external
//     {
//         burnDsc(amountDscToBurn);
//         redeemCollateral(tokenCollateralAddress, amountCollateral);
//         //redeemcollateral function already checks health factor.
//     }

//     //To redeem collateral
//     //1. Health factor must be over 1 After collateral pulled
//     // DRY: Don't repeat yourself.
//     function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
//         public
//         moreThanZero(amountCollateral)
//         nonReentrant //This line defines a function named redeemCollateral. It takes two parameters: tokenCollateralAddress, which is the address of the collateral token being redeemed, and amountCollateral, which is the amount of collateral being redeemed. The function is marked as public, meaning it can be called from outside the contract. It also has two modifiers: moreThanZero and nonReentrant, which impose additional conditions on the function's execution.
//     {
//         /*s_collateralDeposited[msg.sender][tokenCollateralAddress] -= amountCollateral; //This line decreases the amount of collateral deposited by the caller (msg.sender) for the specified tokenCollateralAddress by the amountCollateral. It updates the state variable s_collateralDeposited to reflect the reduced amount of collateral held by the caller.
//         emit CollateralRedeemed(msg.sender, tokenCollateralAddress, amountCollateral); //This line emits an event named CollateralRedeemed, indicating that collateral has been redeemed. It includes information about the caller (msg.sender), the tokenCollateralAddress, and the amountCollateral that was redeemed. This event can be listened to by external parties to track transactions involving the redemption of collateral.
//         bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral); //This line attempts to transfer the redeemed collateral (amountCollateral) back to the caller (msg.sender). It uses the transfer function of the ERC20 token contract associated with the specified tokenCollateralAddress. The result of the transfer operation is stored in a boolean variable named success.
//         if (!success) {
//             revert DSCEngine__TransferFailed(); //This line checks if the collateral transfer was successful. If the transfer fails (i.e., success is false), the function reverts execution and throws an error using the DSCEngine__TransferFailed error message. This ensures that the collateral redemption process is halted if the transfer operation encounters an error.
//         }*/

//         _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
//         _revertIfHealthFactorIsBroken(msg.sender); //This line calls an internal function _revertIfHealthFactorIsBroken to check if the health factor of the caller (msg.sender) is broken after redeeming collateral. This function likely assesses the borrower's financial health and ensures that they still meet certain criteria or maintain a minimum level of collateralization to prevent the system from becoming undercollateralized or insolvent.
//     }
//     //
//     //Threshold is $150
//     // $100 ETH Collateral ->
//     //0$ DSC
//     //Undercollateralized

//     //I.ll pay back back the $50 DSC -> get all your collateral;
//     //74ERB
//     // -$50
//     // -$24

//     /**
//      * @notice follows CEI
//      * @param amountDscToMint The amount of DecentralizedStableCoin to mint.
//      * @notice They must have more collateral value than the minimum threshold
//      */
//     // Check if the collateral value is greater than the DSC amount. It will involve Price feeds, values etc.
//     // Deposit $200 Eth and Mint $50 DSC.
//     function mintDsc(uint256 amountDscToMint)
//         public //  This declares a function named mintDsc that anyone can call from outside the contract (external). It takes one input parameter, amountDscToMint, which represents the amount of DSC (whatever DSC represents) to mint
//         moreThanZero(amountDscToMint) //This is a modifier (a condition that must be met) that ensures the amountDscToMint parameter is greater than zero. If this condition is not met, the function will not execute.
//         nonReentrant
//     {
//         //This is another modifier that prevents reentrancy attacks. It ensures that the function cannot be called recursively (repeatedly) from within itself or from another contract while it is still executing. This helps prevent potential security vulnerabilities.
//         s_DSCMinted[msg.sender] += amountDscToMint; //This line increases the amount of DSC that has been minted for the caller (the address that initiated the function call) by the amountDscToMint value. It's like saying, "Add the amountDscToMint to the total amount of DSC that has been minted for the person who called this function.
//         // Check if they mint more than thier ETH or BTC collateral value i.e thet have $100 ETH/BTC but try to mint $150 DSC.
//         _revertIfHealthFactorIsBroken(msg.sender); //This line calls another function named revertIfHeathFactorIsBroken and passes the caller's address (msg.sender) as an argument. It's like saying, "Check if there's a problem with the health factor for the person who called this function. If there is, revert the transaction and undo any changes made." This function likely performs some validation or checks to ensure that the health factor is within acceptable limits before allowing the minting of DSC.
//         bool minted = i_dsc.mint(msg.sender, amountDscToMint);
//         if (!minted) {
//             revert DSCEngine__MintFailed();
//         }
//     }

//     //Do we need to check if this breaks health factor.
//     function burnDsc(uint256 amount) public moreThanZero(amount) {
//         _burnDsc(amount, msg.sender, msg.sender);
//         _revertIfHealthFactorIsBroken(msg.sender); //I do not think this will ever hit.
//     }

//     //If we do start nearing undercollateralization, we need someone to liquidate positions.
//     //We need to make sure we liquidate people's position if the price of thier collateral crashes, i.e price of Etn goes way lower than collateralized DSC.
//     //$100 ETH used to back $50 DSC.
//     // The worth of $100ETH falls to $20 still backing $50 DSC we gotta liquidate.

//     //If $100 ETH collateral has gone down to $75 ETH collaterla backing $59 DSC.
//     // Liqudator takes $75 Eth and burns off $59 DSC.

//     //If a user is almost undercollateralized, we will pay you to liqudate them.

//     /**
//      * @param collateral The ERC20 collateral address to liquidate.
//      * @param user The user who has broken the health factor. Thier Health Factor should be below Min_Helth_Factor.
//      * @param debtToCover The amount of Dsc you want to improve the users health facytor.
//      * @notice You can partially liquidate a user.
//      * @notice You will get a liquidateiion bonus for taking the users funds.
//      * @notice This function working assumes the protocol will be roughly 200% overcollateralized in order for this to work.
//      * @notice A known bug will be if the protocols were 100% or less collateralized, then we wouldn't be able to incentivice the liquidators. i.e if price of collateral plummeted before anyone could be liquidated.
//      */
//     function liquidate(address collateral, address user, uint256 debtToCover)
//         external
//         moreThanZero(debtToCover)
//         nonReentrant
//     {
//         // we need to check health factor of the user.
//         uint256 startingUserHealthFactor = _healthFactor(user);
//         if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
//             revert DSCEngine__HealthFactorOk();
//         }
//         //We want to burn thier DSC debt and take thier collateral.
//         // Bad User has $140ETH to cover $100 DSC Health fact is below 1 in this scenario.
//         //debtToCover = $100 DSC
//         //$100 of DSC ==
//         //0.05 ETH
//         uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
//         //And we give them a 10% bonus
//         // So we are giving the liquidator $110 of WETH for $100 DSC.
//         //We should implement a feature to liquidate in the event the protocol is insolvent
//         // And sweep extra amount into a treasury

//         // 0.05 ETH * 0.1 = 0.005 ETH.
//         uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
//         uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered * bonusCollateral;
//         _redeemCollateral(user, totalCollateralToRedeem, collateral, msg.sender);
//         //We need to burn the DSC
//         _burnDsc(debtToCover, user, msg.sender);

//         uint256 endingUserHealthFactor = _healthFactor(user);
//         if (endingUserHealthFactor <= startingUserHealthFactor) {
//             revert DSCEngine__HealthFactorNoImproved();
//         }
//         _revertIfHealthFactorIsBroken(msg.sender);
//     }

//     function getHealthFactor() external {}

//     //////////////// ////////////////
//     // Private & Internal Functions //
//     //////////////// /////////////////

//     /**
//      * @dev Low-level internal function, do not call unless the function calling it is checking for health factor if broken
//      */
//     function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
//         s_DSCMinted[onBehalfOf] -= amountDscToBurn;
//         bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
//         if (!success) {
//             revert DSCEngine__TransferFailed();
//         }
//         i_dsc.burn(amountDscToBurn);
//     }

//     //Below function is just like redeemCollateral function above but with thus someone can liquidate address from then to another address to. It will allow for a third part(Liqudator) to tranfser from bad user address to liquidator address. Also has the msg.sender hard coded in.
//     function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
//         private
//     {
//         s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
//         emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
//         bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral); //This line attempts to transfer the redeemed collateral (amountCollateral) back to the caller (msg.sender). It uses the transfer function of the ERC20 token contract associated with the specified tokenCollateralAddress. The result of the transfer operation is stored in a boolean variable named success.
//         if (!success) {
//             revert DSCEngine__TransferFailed(); //This line checks if the collateral transfer was successful. If the transfer fails (i.e., success is false), the function reverts execution and throws an error using the DSCEngine__TransferFailed error message. This ensures that the collateral redemption process is halted if the transfer operation encounters an error.
//         }
//     }
//     //This function takes a user's address as input, retrieves the total amount of DSC minted for that user, and calculates the value of their collateral in US dollars, returning these values as output.

//     function _getAccountInformation(
//         address user //This line defines a function called _getAccountInformation that takes an address named user as input. The purpose of this function is to retrieve information about a specific user's account.
//     )
//         private
//         view
//         returns (
//             uint256 totalDscMinted,
//             uint256 collateralValueInUsd //This line specifies the types of data that the function will return. It indicates that the function will return two unsigned integer values: totalDscMinted and collateralValueInUsd.
//         )
//     {
//         totalDscMinted = s_DSCMinted[user]; //This line assigns the value of s_DSCMinted[user] to the variable totalDscMinted. It retrieves the total amount of a specific digital currency (DSC) that has been minted for the given user.
//         collateralValueInUsd = getAccountCollateralValue(user); //getAccountCollateralValue(user);: This line assigns the value returned by the getAccountCollateralValue function to the variable collateralValueInUsd. This function calculates the value of collateral held by the user in US dollars.
//     }

//     //The underscore in front tells us it is a Private function.

//     /**
//      * Returns how close to liquidation a user is.
//      * If a user goes below 1, then they can get liquidated.
//      *
//      */
//     function _healthFactor(address user) private view returns (uint256) {
//         //we need to get total DSC minted and
//         // total collateral value to determine thier health factor.
//         // make sure the Collateral value is greater than the total DSC minted.
//         (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user); //This line calls another function called _getAccountInformation and assigns the returned values to two variables: totalDscMinted and collateralValueInUsd. The _getAccountInformation function likely retrieves data about a user's account, such as the total amount of a certain token minted and the total value of collateral held in USD.
//         if (totalDscMinted == 0) return type(uint256).max;
//         uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION; //This line calculates the collateral value adjusted for a liquidation threshold. It multiplies the collateralValueInUsd by a constant called LIQUIDATION_THRESHOLD and divides the result by another constant called LIQUIDATION_PRECISION. This adjustment is likely used to determine whether a user's account is at risk of being liquidated.
//         // $1000 ETH * 50 = 50,000 / 100 = 500
//         // 1000 * 50 = 50,000 / 100 = (500 / 100) > 1

//         // $150 ETH / 100 DSC = 1.5
//         // 150 * 50 = 7500 / 100 = (75 / 100) < 1

//         return _calculateHealthFactor((collateralAdjustedForThreshold * PRECISION / totalDscMinted), totalDscMinted); //This line calculates the health factor of the user's account. It multiplies the adjusted collateral value by a constant called PRECISION and then divides the result by the total amount of tokens minted by the user (totalDscMinted). The health factor represents the ratio of collateral value to debt, indicating the financial health of the user's account. Higher values indicate healthier accounts, while lower values may indicate accounts at risk of liquidation.
//     }

//     function _calculateHealthFactor(
//         uint256 totalDscMinted,
//         uint256 collateralValueInUsd
//     )
//         internal
//         pure
//         returns (uint256)
//     {
//         //if (totalDscMinted == 0) return type(uint256).max;
//         uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
//         return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
//     }

//     // function _healthFactor(address _user) internal view returns (uint256 health_factor) {
//     //     (uint256 total_DSC_minted, uint256 collateral_value_in_USD) = _get_account_information(_user);
//     //     // console2.log("the total collateral value in USD is: ", collateral_value_in_USD);
//     //     // console2.log("the total DSC minted is: ", total_DSC_minted);
//     //     if (totalDscMinted== 0) return type(uint256).max;
//     //     uint256 collateralAdjustedForThreshold =
//     //         (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_THRESHOLD_DIVIDER;
//     //     // console2.log("the collateral amount for threshold is: ", collateral_amount_for_threshold);
//     //     health_factor = collateral_amount_for_threshold  / total_DSC_minted;
//     //     // console2.log("the calculated health factor is: ", health_factor);
//     //     return health_factor;
//     // }

//      /*function _calculateHealthFactor(
//         uint256 totalDscMinted,
//         uint256 collateralValueInUsd
//     )
//         internal
//         pure
//         returns (uint256)
//     {
//         if (totalDscMinted == 0) return type(uint256).max;
//         uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
//         return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
//     }*/

//     // Check health factor (do they have enough collateral?)
//     // Revert if they do not have enough collateral.
//     function _revertIfHealthFactorIsBroken(address user) internal view {
//         uint256 userHealthFactor = _healthFactor(user);
//         if (userHealthFactor < MIN_HEALTH_FACTOR) {
//             revert DSCEngine__BreaksHealthFactor(userHealthFactor);
//         }
//     }

//     //////////////// //////////////////////
//     // Public & External view Functions //
//     //////////////// //////////////////////

//     function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
//         //Price of ETH(token)
//         //$/ETH ETh ?? dollar per ETH how do we get the ETH.
//         //$2000/ETH. $1000 = 0.5ETH
//         AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
//         (, int256 price,,,) = priceFeed.latestRoundData();
//         //i.e ($10e18 * 1e18) / ($2000e8 * 1e10)
//         return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
//     }

//     function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
//         //loop through each collateral token, get the amount they have depositedc, and map it to the price, to get the USD value.
//         for (uint256 i = 0; i < s_collateralTokens.length; i++) {
//             //This line starts a loop that iterates through each collateral token. It initializes a variable i to zero and continues the loop as long as i is less than the length of the s_collateralTokens array.
//             address token = s_collateralTokens[i]; //Inside the loop, this line assigns the current collateral token at index i to the variable token. This token represents the type of collateral being examined in the current iteration of the loop.
//             uint256 amount = s_collateralDeposited[user][token]; //This line retrieves the amount of the current collateral token (token) that the specified user has deposited. It looks up this information from a mapping called s_collateralDeposited, which maps user addresses to token addresses and their corresponding deposited amounts.
//             totalCollateralValueInUsd += getUsdValue(token, amount); //This line calculates the USD value of the current collateral token (token) deposited by the user (user). It calls a function named getUsdValue, passing in the token address (token) and the deposited amount (amount) as parameters. The USD value returned by this function is added to the totalCollateralValueInUsd.
//         }
//         return totalCollateralValueInUsd; //Finally, this line returns the total collateral value in USD calculated during the loop. It's the sum of the USD values of all collateral tokens deposited by the user.
//     }

//     function getUsdValue(address token, uint256 amount) public view returns (uint256) {
//         AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]); //This line declares a variable priceFeed of type AggregatorV3Interface. It initializes this variable by accessing the address stored in the s_priceFeeds mapping using the token as the key. The AggregatorV3Interface is a contract interface that provides functions to interact with price feed contracts, typically used to get price information from decentralized oracles.
//         (, int256 price,,,) = priceFeed.latestRoundData(); //This line calls the latestRoundData function of the priceFeed contract, passing the amount parameter. It retrieves the latest price data for the specified token from the price feed. The returned value price is an integer representing the price of the token in USD.
//         //If ETH = $1,000
//         //The returned value from CL will be 1,000 * 1e8.
//         return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION; //This line calculates the USD value of the specified token amount. It multiplies the price by ADDITIONAL_FEED_PRECISION (a constant) to account for additional precision provided by the price feed. Then, it multiplies the result by the token amount and divides by PRECISION (another constant) to adjust for the precision of the token amount. The final result is returned as a uint256 value representing the USD value of the token amount.
//     }

//     function calculateHealthFactor(
//         uint256 totalDscMinted,
//         uint256 collateralValueInUsd
//     )
//         external
//         pure
//         returns (uint256)
//     {
//         return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
//     }

//     function getAccountInformation(address user)
//         external
//         view
//         returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
//     {
//         (totalDscMinted, collateralValueInUsd) = _getAccountInformation(user);
//     }

//      function getAdditionalFeedPrecision() external pure returns (uint256) {
//         return ADDITIONAL_FEED_PRECISION;
//     }

//     function getPrecision() external pure returns (uint256) {
//         return PRECISION;
//     }

//     function getHealthFactor(address user) external view returns (uint256) {
//         return _healthFactor(user);
//     }

//     function getCollateralTokenPriceFeed(address token) external view returns (address) {
//         return s_priceFeeds[token];
//     }

//     function getLiquidationThreshold() external pure returns (uint256) {
//         return LIQUIDATION_THRESHOLD;
//     }

//     function getMinHealthFactor() external pure returns (uint256) {
//         return MIN_HEALTH_FACTOR;
//     }

//     function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
//         return s_collateralDeposited[user][token];
//     }

//     function getLiquidationPrecision() external pure returns (uint256) {
//         return LIQUIDATION_PRECISION;
//     }

//     function getDsc() external view returns (address) {
//         return address(i_dsc);
//     }

//     function getLiquidationBonus() external pure returns (uint256) {
//         return LIQUIDATION_BONUS;
//     }

//     function getCollateralTokens() external view returns (address[] memory) {
//         return s_collateralTokens;
//     }
// }
