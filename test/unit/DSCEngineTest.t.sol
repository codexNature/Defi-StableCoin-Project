// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;   

// import {Test, console2} from "forge-std/Test.sol";  // my contract
// import {DeployDSC} from "../../script/DeployDSC.s.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
// import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// import { StdCheats } from "forge-std/StdCheats.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";
// //import { MockFailedTransferFrom } from "../mocks/MockFailedTransferFrom.sol";

// contract DSCEngineTest is StdCheats, Test {
//     event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount); // if
//         // redeemFrom != redeemedTo, then it was liquidated    


//     DeployDSC deployer;
//     DecentralizedStableCoin dsc;
//     DSCEngine engine;
//     HelperConfig config;

    
//     address ethUsdPriceFeed;
//     address btcUsdPriceFeed;
//     address weth;
//     address wbtc;

//     uint256 amountCollateral = 10 ether;
//     uint256 amountToMint = 100 ether;
//     address public user = address(1);

//     address public USER = makeAddr("user");
//     uint256 public constant AMOUNT_COLLATERAL = 10 ether;
//     uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
//     uint256 public constant LIQUIDATION_THRESHOLD = 50;
//     uint256 private constant MIN_HEALTH_FACTOR = 1e18;
//     uint256 public constant AMOUNT_TO_MINT = 100 ether;

//      // Liquidation
//     address public liquidator = makeAddr("liquidator");
//     uint256 public collateralToCover = 20 ether;

//     function setUp() public {
//         deployer = new DeployDSC();
//         (dsc, engine, config) = deployer.run();
//         (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();

//         ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
//     }

//     //////////////////////
//     // Constructor Test//
//     /////////////////////

//     address[] public tokenAddresses;
//     address[] public priceFeedAddresses;

//     function testRevertIfTokenLengthDoesntMatchPriceFeed() public {
//         tokenAddresses.push(weth);
//         priceFeedAddresses.push(ethUsdPriceFeed);
//         priceFeedAddresses.push(btcUsdPriceFeed);

//         vm.expectRevert(DSCEngine.DSCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
//         new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
//     }

//     ////////////////
//     // Price Test//
//     ////////////////

//     function testGetUsdValue() public view {
//         uint256 ethAmount = 20e18;
//         //20e18 * $2000perETH = 40,000e18;
//         uint256 expectedUsd = 40000e18;
//         uint256 actualUsd = engine.getUsdValue(weth, ethAmount);
//         assertEq(expectedUsd, actualUsd);
//     }

//     function testGetTokenAmountFromUsd() public view {
//         uint256 usdAmount = 100 ether;
//         // $2,000 / ETH, $100     100/2000 = 0.05
//         uint256 expectedWeth = 0.05 ether;
//         uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);
//         assertEq(expectedWeth, actualWeth);
//     }

//     ////////////////////////////
//     // Deposite Collateral Test//
//     /////////////////////////////

//     function testRevertsIfCollateralIsZero() public {
//         vm.startPrank(USER);
//         ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

//         vm.expectRevert(DSCEngine.DSCEngine_NeedsMoreThanZero.selector);
//         engine.depositCollateral(weth, 0);
//         vm.stopPrank();
//     }

//     function testRevertsWithUnapprovaedCollateral() public {
//         ERC20Mock ranToken = new ERC20Mock(); //This line creates a new instance of a mock ERC20 token contract called ranToken. This mock token is used for testing purposes to simulate a real ERC20 token.
//         vm.startPrank(USER); //This line starts a mocking scenario using a tool or library called vm. The USER variable likely represents a user account or address within the test environment. Starting the prank scenario allows the test to simulate specific conditions or behaviors that might occur during execution.
//         vm.expectRevert(DSCEngine.DSCEngine_NotAllowedToken.selector); //This line sets up an expectation that a certain function call within the DSCEngine contract will revert (i.e., throw an error) during the test. The DSCEngine.DSCEngine_NotAllowedToken.selector likely refers to a specific function selector within the DSCEngine contract that is expected to revert if called with unapproved collateral.
//         engine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL); //This line calls a function named depositCollateral on an object or instance named engine. The function is passed the address of the ranToken contract as the collateral token and a variable named AMOUNT_COLLATERAL representing the amount of collateral to deposit. This action is part of the test scenario being evaluated.
//         vm.stopPrank(); //This line stops the mocking scenario that was started earlier using vm.startPrank(). Stopping the prank scenario indicates the end of the test scenario and allows the test to finalize and verify its results.
//     }

//     modifier depositedCollateral() {
//         vm.startPrank(USER);
//         ERC20Mock(weth).approve(address(engine), amountCollateral);
//         engine.depositCollateral(weth, amountCollateral);
//         vm.stopPrank();
//         _;
//     }

//     modifier liquidated() {
//         vm.startPrank(USER);
//         ERC20Mock(weth).approve(address(engine), amountCollateral);
//         engine.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
//         vm.stopPrank();
//         int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18

//         MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
//         uint256 userHealthFactor = engine.getHealthFactor(user);

//         ERC20Mock(weth).mint(liquidator, collateralToCover);

//         vm.startPrank(liquidator);
//         ERC20Mock(weth).approve(address(engine), collateralToCover);
//         engine.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint);
//         dsc.approve(address(engine), amountToMint);
//         engine.liquidate(weth, user, amountToMint); // We are covering their whole debt
//         vm.stopPrank();
//         _;
//     }




//     function testCanDepositCollateralAndGetAccount() public depositedCollateral {
//         (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);

//         uint256 expectedTotalDscMinted = 0;
//         uint256 expectedDeositAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);
//         assertEq(totalDscMinted, expectedTotalDscMinted);
//         assertEq(AMOUNT_COLLATERAL, expectedDeositAmount);
//     }

//     ///////////////////////////////////////
//     // depositCollateralAndMintDsc Tests //
//     ///////////////////////////////////////

//     function testRevertsIfMintedDscBreaksHealthFactor() public {
//         (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
//         amountToMint = (amountCollateral * (uint256(price) * engine.getAdditionalFeedPrecision())) / engine.getPrecision();
//         vm.startPrank(USER);
//         ERC20Mock(weth).approve(address(engine), amountCollateral);

//         uint256 expectedHealthFactor =
//             engine.calculateHealthFactor(amountToMint, engine.getUsdValue(weth, amountCollateral));
//         vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
//         engine.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
//         vm.stopPrank();
//     }  ///////////////////////////////////////////////////////////////////////////////////////

//     //  modifier depositedCollateralAndMintedDsc() {
//     //     vm.startPrank(USER);
//     //     ERC20Mock(weth).approve(address(engine), amountCollateral);
//     //     engine.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
//     //     vm.stopPrank();
//     //     _;
//     // }

//     modifier depositedCollateralAndMintedDsc() {
//         vm.startPrank(USER);
//         ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
//         engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
//         vm.stopPrank();
//         _;
//     }



//     function testCanMintWithDepositedCollateral() public depositedCollateralAndMintedDsc {
//         uint256 userBalance = dsc.balanceOf(user);
//         assertEq(userBalance, amountToMint);
//     }


//       ///////////////////////////////////
//     // View & Pure Function Tests //
//     //////////////////////////////////
//     function testGetCollateralTokenPriceFeed() public view {
//         address priceFeed = engine.getCollateralTokenPriceFeed(weth);
//         assertEq(priceFeed, ethUsdPriceFeed);
//     }
    
//      function testGetLiquidationThreshold() public view {
//         uint256 liquidationThreshold = engine.getLiquidationThreshold();
//         assertEq(liquidationThreshold, LIQUIDATION_THRESHOLD);
//     }

//     function testgetMinHealthFactor() public view {
//         uint256 minHealthFactor = engine.getMinHealthFactor();
//         assertEq(minHealthFactor, MIN_HEALTH_FACTOR);
//     }

//     function testGetCollateralBalanceOfUser() public {
//         vm.startPrank(USER);
//         ERC20Mock(weth).approve(address(engine), amountCollateral);
//         engine.depositCollateral(weth, amountCollateral);
//         vm.stopPrank();
//         uint256 collateralBalance = engine.getCollateralBalanceOfUser(USER, weth);
//         assertEq(collateralBalance, amountCollateral);
//     }

//     function testRevertIfTransferFailsWithoutMock() public {
//         // Arrange - Setup
//         vm.prank(USER);
//         IERC20 mockDsc = IERC20(address(0x456));
//         tokenAddresses = [address(mockDsc)];
//         priceFeedAddresses = [ethUsdPriceFeed];
//         DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(0x789));

//         // Arrange - User
//         vm.startPrank(USER);
//         mockDsc.transferFrom(user, address(this), amountCollateral);

//         // Assert / Act
//         vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
//         mockDsce.depositCollateral(address(mockDsc), amountCollateral);
//         vm.stopPrank();
//     }

//     function testRevertsIfCollateralZero() public {
//         vm.startPrank(USER);
//         ERC20Mock(weth).approve(address(engine), amountCollateral);

//         vm.expectRevert(DSCEngine.DSCEngine_NeedsMoreThanZero.selector);
//         engine.depositCollateral(weth, 0);
//         vm.stopPrank();
//     }

//     function testCanDepositCollateralWithoutMinting() public depositedCollateral {
//         uint256 userBalance = dsc.balanceOf(user);
//         assertEq(userBalance, 0);
//     }

//     function testLiquidationPrecision() public view{
//         uint256 expectedLiquidationPrecision = 100;
//         uint256 actualLiquidationPrecision = engine.getLiquidationPrecision();
//         assertEq(actualLiquidationPrecision, expectedLiquidationPrecision);
//     }

//     function testGetDsc() public view{
//         address dscAddress = engine.getDsc();
//         assertEq(dscAddress, address(dsc));
//     }

//     function testGetAccountCollateralValue() public {
//         vm.startPrank(USER);
//         ERC20Mock(weth).approve(address(engine), amountCollateral);
//         engine.depositCollateral(weth, amountCollateral);
//         vm.stopPrank();
//         uint256 collateralValue = engine.getAccountCollateralValue(user);
//         uint256 expectedCollateralValue = engine.getUsdValue(weth, amountCollateral);
//         assertEq(collateralValue, expectedCollateralValue);
//     }    ///////////////////////////////////////////////////////////////////////////////////////


//      ///////////////////////////////////
//     // mintDsc Tests //
//     ///////////////////////////////////
//      // This test needs it's own custom setup
//     function testRevertsIfMintFails() public {
//         // Arrange - Setup
//         //MockFailedMintDSC mockDsc = new MockFailedMintDSC();
//         tokenAddresses = [weth];
//         priceFeedAddresses = [ethUsdPriceFeed];
//         address owner = msg.sender;
//         vm.prank(owner);
//         DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeedAddresses, owner);
//         //engine.transferOwnership(address(mockDsce));
//         // Arrange - User
//         vm.startPrank(USER);
//         ERC20Mock(weth).approve(address(mockDsce), amountCollateral);

//         vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
//         mockDsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
//         vm.stopPrank();
//     }    

//     function testRevertsIfMintAmountIsZero() public {
//         vm.startPrank(USER);
//         ERC20Mock(weth).approve(address(engine), amountCollateral);
//         engine.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
//         vm.expectRevert(DSCEngine.DSCEngine_NeedsMoreThanZero.selector);
//         engine.mintDsc(0);
//         vm.stopPrank();
//     }

//     function testRevertsIfMintAmountBreaksHealthFactor() public depositedCollateral {
//         // 0xe580cc6100000000000000000000000000000000000000000000000006f05b59d3b20000
//         // 0xe580cc6100000000000000000000000000000000000000000000003635c9adc5dea00000
//         (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
//         amountToMint = (amountCollateral * (uint256(price) * engine.getAdditionalFeedPrecision())) / engine.getPrecision();

//         vm.startPrank(USER);
//         uint256 expectedHealthFactor =
//             engine.calculateHealthFactor(amountToMint, engine.getUsdValue(weth, amountCollateral));
//         vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
//         engine.mintDsc(amountToMint);
//         vm.stopPrank();
//     }

//     function testCanMintDsc() public depositedCollateral {
//         vm.prank(user);
//         engine.mintDsc(amountToMint);

//         uint256 userBalance = dsc.balanceOf(user);
//         assertEq(userBalance, amountToMint);
//     }

//      ///////////////////////////////////
//     // burnDsc Tests //
//     ///////////////////////////////////

//     function testRevertsIfBurnAmountIsZero() public {
//         vm.startPrank(USER);
//         ERC20Mock(weth).approve(address(engine), amountCollateral);
//         engine.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
//         vm.expectRevert(DSCEngine.DSCEngine_NeedsMoreThanZero.selector);
//         engine.burnDsc(0);
//         vm.stopPrank();
//     }

//     function testCantBurnMoreThanUserHas() public {
//         vm.prank(USER);
//         vm.expectRevert();
//         engine.burnDsc(1);
//     }

//     function testCanBurnDsc() public depositedCollateralAndMintedDsc {
//         vm.startPrank(USER);
//         dsc.approve(address(engine), amountToMint);
//         engine.burnDsc(amountToMint);
//         vm.stopPrank();

//         uint256 userBalance = dsc.balanceOf(user);
//         assertEq(userBalance, 0);
//     }

//     ///////////////////////////////////
//     // redeemCollateral Tests //
//     //////////////////////////////////

//     // this test needs it's own setup
//     /*  // Arrange - Setup
//         address owner = msg.sender;
//         vm.prank(owner);
//         //MockFailedTransfer mockDsc = new MockFailedTransfer();
//         tokenAddresses = [address()];
//         priceFeedAddresses = [ethUsdPriceFeed];
//         vm.prank(owner);
//         DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address());
//         mockDsce.mint(user, amountCollateral);

//         vm.prank(owner);
//         mockDsce.transferOwnership(address(mockDsce));
//         // Arrange - User
//         vm.startPrank(user);
//         ERC20Mock(address()).approve(address(mockDsce), amountCollateral);
//         // Act / Assert
//         mockDsce.depositCollateral(address(mockDsce), amountCollateral);
//         vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
//         mockDsce.redeemCollateral(address(mockDsce), amountCollateral);
//         vm.stopPrank();
//     }
//     */

//    function testRevertsIfRedeemAmountIsZero() public {
//         vm.startPrank(USER);
//         ERC20Mock(weth).approve(address(engine), amountCollateral);
//         engine.redeemCollateralForDsc(weth, amountCollateral, amountToMint);
//         vm.expectRevert(DSCEngine.DSCEngine_NeedsMoreThanZero.selector);
//         engine.redeemCollateral(weth, 0);
//         vm.stopPrank();
//     }

//      function testCanRedeemCollateral() public depositedCollateral {
//         vm.startPrank(USER);
//         engine.redeemCollateral(weth, amountCollateral);
//         uint256 userBalance = ERC20Mock(weth).balanceOf(user);
//         assertEq(userBalance, amountCollateral);
//         vm.stopPrank();
//     }


//     ////////////////////////
//     // healthFactor Tests //
//     ////////////////////////
    

//     function testProperlyReportsHealthFactor() public depositedCollateralAndMintedDsc {
//         uint256 expectedHealthFactor = 100 ether;
//         uint256 healthFactor = engine.getHealthFactor(user);
//         // $100 minted with $20,000 collateral at 50% liquidation threshold
//         // means that we must have $200 collatareral at all times.
//         // 20,000 * 0.5 = 10,000
//         // 10,000 / 100 = 100 health factor
//         assertEq(healthFactor, expectedHealthFactor);
//     }

//     function testHealthFactorCanGoBelowOne() public depositedCollateralAndMintedDsc {
//         int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
//         // Rememeber, we need $200 at all times if we have $100 of debt

//         MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);

//         uint256 userHealthFactor = engine.getHealthFactor(user);
//         // 180*50 (LIQUIDATION_THRESHOLD) / 100 (LIQUIDATION_PRECISION) / 100 (PRECISION) = 90 / 100 (totalDscMinted) =
//         // 0.9
//         assert(userHealthFactor == 0.9 ether);
//     }

//     function testCanDepositedCollateralAndGetAccountInfo() public depositedCollateral {
//         (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
//         uint256 expectedDepositedAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);
//         assertEq(totalDscMinted, 0);
//         assertEq(expectedDepositedAmount, AMOUNT_COLLATERAL);
//         console2.log("collateral Value in USD: ", collateralValueInUsd);
//         console2.log("expected Deposited Amount: ", expectedDepositedAmount);
//         // console2.log("usdAmountInWei: ", usdAmountInWei);
//         // console2.log("price: ", price);
//     }


//     ////////////////////////
//     // Liquidation Tests //
//     ////////////////////////

//      function testUserHasNoMoreDebt() public liquidated {
//         (uint256 userDscMinted,) = engine.getAccountInformation(USER);
//         assertEq(userDscMinted, 0);
//     }

// }




import { DeployDSC } from "../../script/DeployDSC.s.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { DecentralizedStableCoin } from "../../src/DecentralizedStableCoin.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol"; //Updated mock location;
//import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";
import { MockMoreDebtDSC } from "../mocks/MockMoreDebtDSC.sol";
import { MockFailedMintDSC } from "../mocks/MockFailedMintDSC.sol";
import { MockFailedTransferFrom } from "../mocks/MockFailedTransferFrom.sol";
import { MockFailedTransfer } from "../mocks/MockFailedTransfer.sol";
import { Test, console } from "forge-std/Test.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

contract DSCEngineTest is StdCheats, Test {
    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount); // if
        // redeemFrom != redeemedTo, then it was liquidated

    DSCEngine public dsce;
    DecentralizedStableCoin public dsc;
    HelperConfig public helperConfig;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;
    address public user = address(1);

    address public USER = makeAddr("user");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant AMOUNT_TO_MINT = 100 ether;

    // Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dsce, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, deployerKey) = helperConfig.activeNetworkConfig();
        if (block.chainid == 31_337) {
            vm.deal(user, STARTING_USER_BALANCE);
        }
        // Should we put our integration tests here?
        // else {
        //     user = vm.addr(deployerKey);
        //     ERC20Mock mockErc = new ERC20Mock("MOCK", "MOCK", user, 100e18);
        //     MockV3Aggregator aggregatorMock = new MockV3Aggregator(
        //         helperConfig.DECIMALS(),
        //         helperConfig.ETH_USD_PRICE()
        //     );
        //     vm.etch(weth, address(mockErc).code);
        //     vm.etch(wbtc, address(mockErc).code);
        //     vm.etch(ethUsdPriceFeed, address(aggregatorMock).code);
        //     vm.etch(btcUsdPriceFeed, address(aggregatorMock).code);
        // }
        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_USER_BALANCE);
    }

    ///////////////////////
    // Constructor Tests //
    ///////////////////////
    address[] public tokenAddresses;
    address[] public feedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        feedAddresses.push(ethUsdPriceFeed);
        feedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, feedAddresses, address(dsc));
    }

    //////////////////
    // Price Tests //
    //////////////////

    function testGetTokenAmountFromUsd() public view { //i fixed this by adjustung ETH_USD_PRICE to $2000 baing 2000/100 = 0.05 linked to MockV3Aggregator linked to getTokenAmountFromUsd in DSCEngine.
        // If we want $100 of WETH @ $2000/WETH, that would be 0.05 WETH
        uint256 expectedWeth = 0.05 ether;
        uint256 amountWeth = dsce.getTokenAmountFromUsd(weth, 100 ether);
        assertEq(expectedWeth, amountWeth);
    }

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        // 15e18 ETH * $2000/ETH = $30,000e18
        uint256 expectedUsd = 30_000e18;
        uint256 usdValue = dsce.getUsdValue(weth, ethAmount);
        assertEq(usdValue, expectedUsd);
    }

    ///////////////////////////////////////
    // depositCollateral Tests //
    ///////////////////////////////////////

    // this test needs it's own setup
    // function testRevertsIfTransferFromFails() public {
    //     // Arrange - Setup
    //     address owner = msg.sender;
    //     vm.prank(owner);
    //     MockFailedTransferFrom mockDsc = new MockFailedTransferFrom();
    //     tokenAddresses = [address(mockDsc)];
    //     feedAddresses = [ethUsdPriceFeed];
    //     vm.prank(owner);
    //     DSCEngine mockDsce = new DSCEngine(tokenAddresses, feedAddresses, address(mockDsc));
    //     mockDsc.mint(user, amountCollateral);

    //     vm.prank(owner);
    //     mockDsc.transferOwnership(address(mockDsce));
    //     // Arrange - User
    //     vm.startPrank(user);
    //     ERC20Mock(address(mockDsc)).approve(address(mockDsce), amountCollateral);
    //     // Act / Assert
    //     vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
    //     mockDsce.depositCollateral(address(mockDsc), amountCollateral);
    //     vm.stopPrank();
    // }

    function testRevertsIfCollateralZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);

        vm.expectRevert(DSCEngine.DSCEngine_NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock randToken = new ERC20Mock(); //new ERC20Mock("RAN", "RAN", user, 100e18)
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine_NotAllowedToken.selector, address(randToken)));
        dsce.depositCollateral(address(randToken), amountCollateral);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralWithoutMinting() public depositedCollateral {
        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
    }

    function testCanDepositedCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(user);
        uint256 expectedDepositedAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, 0);
        assertEq(expectedDepositedAmount, amountCollateral);
    }

    ///////////////////////////////////////
    // depositCollateralAndMintDsc Tests //
    ///////////////////////////////////////

    function testRevertsIfMintedDscBreaksHealthFactor() public {
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint = (amountCollateral * (uint256(price) * dsce.getAdditionalFeedPrecision())) / dsce.getPrecision();
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);

        uint256 expectedHealthFactor =
            dsce.calculateHealthFactor(amountToMint, dsce.getUsdValue(weth, amountCollateral));
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();
    }

    modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedCollateral() public depositedCollateralAndMintedDsc {
        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    ///////////////////////////////////
    // mintDsc Tests //
    ///////////////////////////////////
    // This test needs it's own custom setup
    // function testRevertsIfMintFails() public {
    //     // Arrange - Setup
    //     MockFailedMintDSC mockDsc = new MockFailedMintDSC();
    //     tokenAddresses = [weth];
    //     feedAddresses = [ethUsdPriceFeed];
    //     address owner = msg.sender;
    //     vm.prank(USER);
    //     DSCEngine mockDsce = new DSCEngine(tokenAddresses, feedAddresses, address(mockDsc));
    //     mockDsc.transferOwnership(address(mockDsce));
    //     // Arrange - User
    //     vm.startPrank(owner);
    //     ERC20Mock(weth).approve(address(mockDsce), AMOUNT_COLLATERAL);

    //     vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
    //     mockDsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMint);
    //     vm.stopPrank();
    // }

    function testRevertsIfMintFails() public {
        // Arrange - Setup
        MockFailedMintDSC mockDsc = new MockFailedMintDSC();
        tokenAddresses = [weth];
        feedAddresses = [ethUsdPriceFeed];
        //address owner = msg.sender;
        vm.prank(user);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, feedAddresses, address(mockDsc));
        vm.prank(mockDsc.owner());
        mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(mockDsce), AMOUNT_COLLATERAL);

            vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
            mockDsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMint);
            vm.stopPrank();
        }


    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.expectRevert(DSCEngine.DSCEngine_NeedsMoreThanZero.selector);
        dsce.mintDsc(0);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountBreaksHealthFactor() public depositedCollateral {
        // 0xe580cc6100000000000000000000000000000000000000000000000006f05b59d3b20000
        // 0xe580cc6100000000000000000000000000000000000000000000003635c9adc5dea00000
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint = (amountCollateral * (uint256(price) * dsce.getAdditionalFeedPrecision())) / dsce.getPrecision();

        vm.startPrank(user);
        uint256 expectedHealthFactor =
            dsce.calculateHealthFactor(amountToMint, dsce.getUsdValue(weth, amountCollateral));
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        dsce.mintDsc(amountToMint);
        vm.stopPrank();
    }

    function testCanMintDsc() public depositedCollateral {
        vm.prank(user);
        dsce.mintDsc(amountToMint);

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    ///////////////////////////////////
    // burnDsc Tests //
    ///////////////////////////////////

    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.expectRevert(DSCEngine.DSCEngine_NeedsMoreThanZero.selector);
        dsce.burnDsc(0);
        vm.stopPrank();
    }

    function testCantBurnMoreThanUserHas() public {
        vm.prank(user);
        vm.expectRevert();
        dsce.burnDsc(1);
    }

    function testCanBurnDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(user);
        dsc.approve(address(dsce), amountToMint);
        dsce.burnDsc(amountToMint);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ///////////////////////////////////
    // redeemCollateral Tests //
    //////////////////////////////////

    // this test needs it's own setup
    // function testRevertsIfTransferFails() public {
    //     // Arrange - Setup
    //     address owner = msg.sender;
    //     vm.prank(owner);
    //     MockFailedTransfer mockDsc = new MockFailedTransfer();
    //     tokenAddresses = [address(mockDsc)];
    //     feedAddresses = [ethUsdPriceFeed];
    //     vm.prank(owner);
    //     DSCEngine mockDsce = new DSCEngine(tokenAddresses, feedAddresses, address(mockDsc));
    //     mockDsc.mint(user, amountCollateral);

    //     vm.prank(owner);
    //     mockDsc.transferOwnership(address(mockDsce));
    //     // Arrange - User
    //     vm.startPrank(user);
    //     ERC20Mock(address(mockDsc)).approve(address(mockDsce), amountCollateral);
    //     // Act / Assert
    //     mockDsce.depositCollateral(address(mockDsc), amountCollateral);
    //     vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
    //     mockDsce.redeemCollateral(address(mockDsc), amountCollateral);
    //     vm.stopPrank();
    // }

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.expectRevert(DSCEngine.DSCEngine_NeedsMoreThanZero.selector);
        dsce.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositedCollateral {
        vm.startPrank(user);
        dsce.redeemCollateral(weth, amountCollateral);
        uint256 userBalance = ERC20Mock(weth).balanceOf(user);
        assertEq(userBalance, amountCollateral);
        vm.stopPrank();
    }

    function testEmitCollateralRedeemedWithCorrectArgs() public depositedCollateral {
        vm.expectEmit(true, true, true, true, address(dsce));
        emit CollateralRedeemed(user, user, weth, amountCollateral);
        vm.startPrank(user);
        dsce.redeemCollateral(weth, amountCollateral);
        vm.stopPrank();
    }
    ///////////////////////////////////
    // redeemCollateralForDsc Tests //
    //////////////////////////////////

    function testMustRedeemMoreThanZero() public depositedCollateralAndMintedDsc {
        vm.startPrank(user);
        dsc.approve(address(dsce), amountToMint);
        vm.expectRevert(DSCEngine.DSCEngine_NeedsMoreThanZero.selector);
        dsce.redeemCollateralForDsc(weth, 0, amountToMint);
        vm.stopPrank();
    }

    function testCanRedeemDepositedCollateral() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        dsc.approve(address(dsce), amountToMint);
        dsce.redeemCollateralForDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ////////////////////////
    // healthFactor Tests //
    ////////////////////////

    // function testProperlyReportsHealthFactor() public depositedCollateralAndMintedDsc {
    //     uint256 expectedHealthFactor = 100;
    //     uint256 healthFactor = dsce.getHealthFactor(USER);
    //     // $100 minted with $20,000 collateral at 50% liquidation threshold
    //     // means that we must have $200 collatareral at all times.
    //     // 20,000 * 0.5 = 10,000
    //     // 10,000 / 100 = 100 health factor
    //     assertEq(healthFactor, expectedHealthFactor);
    // }

    function testHealthFactorCanGoBelowOne() public depositedCollateralAndMintedDsc {
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        // Rememeber, we need $200 at all times if we have $100 of debt

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);

        uint256 userHealthFactor = dsce.getHealthFactor(user);
        // 180*50 (LIQUIDATION_THRESHOLD) / 100 (LIQUIDATION_PRECISION) / 100 (PRECISION) = 90 / 100 (totalDscMinted) =
        // 0.9
        assert(userHealthFactor == 0.9 ether);
    }

    ///////////////////////
    // Liquidation Tests //
    ///////////////////////

    // This test needs it's own setup
    // function testMustImproveHealthFactorOnLiquidation() public {
    //     // Arrange - Setup
    //     MockMoreDebtDSC mockDsc = new MockMoreDebtDSC(ethUsdPriceFeed);
    //     tokenAddresses = [weth];
    //     feedAddresses = [ethUsdPriceFeed];
    //     address owner = msg.sender;
    //     vm.prank(owner);
    //     DSCEngine mockDsce = new DSCEngine(tokenAddresses, feedAddresses, address(mockDsc));
    //     mockDsc.transferOwnership(address(mockDsce));
    //     // Arrange - User
    //     vm.startPrank(user);
    //     ERC20Mock(weth).approve(address(mockDsce), amountCollateral);
    //     mockDsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
    //     vm.stopPrank();

    //     // Arrange - Liquidator
    //     collateralToCover = 1 ether;
    //     ERC20Mock(weth).mint(liquidator, collateralToCover);

    //     vm.startPrank(liquidator);
    //     ERC20Mock(weth).approve(address(mockDsce), collateralToCover);
    //     uint256 debtToCover = 10 ether;
    //     mockDsce.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint);
    //     mockDsc.approve(address(mockDsce), debtToCover);
    //     // Act
    //     int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
    //     MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
    //     // Act/Assert
    //     vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
    //     mockDsce.liquidate(weth, user, debtToCover);
    //     vm.stopPrank();
    // }

    function testCantLiquidateGoodHealthFactor() public depositedCollateralAndMintedDsc {
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dsce), collateralToCover);
        dsce.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint);
        dsc.approve(address(dsce), amountToMint);

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dsce.liquidate(weth, user, amountToMint);
        vm.stopPrank();
    }

    modifier liquidated() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = dsce.getHealthFactor(user);

        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dsce), collateralToCover);
        dsce.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint);
        dsc.approve(address(dsce), amountToMint);
        dsce.liquidate(weth, user, amountToMint); // We are covering their whole debt
        vm.stopPrank();
        _;
    }

    function testLiquidationPayoutIsCorrect() public liquidated {
        uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        uint256 expectedWeth = dsce.getTokenAmountFromUsd(weth, amountToMint)
            + (dsce.getTokenAmountFromUsd(weth, amountToMint) / dsce.getLiquidationBonus());
        uint256 hardCodedExpected = 6_111_111_111_111_111_110;
        assertEq(liquidatorWethBalance, hardCodedExpected);
        assertEq(liquidatorWethBalance, expectedWeth);
    }

    function testUserStillHasSomeEthAfterLiquidation() public liquidated {
        // Get how much WETH the user lost
        uint256 amountLiquidated = dsce.getTokenAmountFromUsd(weth, amountToMint)
            + (dsce.getTokenAmountFromUsd(weth, amountToMint) / dsce.getLiquidationBonus());

        uint256 usdAmountLiquidated = dsce.getUsdValue(weth, amountLiquidated);
        uint256 expectedUserCollateralValueInUsd = dsce.getUsdValue(weth, amountCollateral) - (usdAmountLiquidated);

        (, uint256 userCollateralValueInUsd) = dsce.getAccountInformation(user);
        uint256 hardCodedExpectedValue = 70_000_000_000_000_000_020;
        assertEq(userCollateralValueInUsd, expectedUserCollateralValueInUsd);
        assertEq(userCollateralValueInUsd, hardCodedExpectedValue);
    }

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        (uint256 liquidatorDscMinted,) = dsce.getAccountInformation(liquidator);
        assertEq(liquidatorDscMinted, amountToMint);
    }

    function testUserHasNoMoreDebt() public liquidated {
        (uint256 userDscMinted,) = dsce.getAccountInformation(user);
        assertEq(userDscMinted, 0);
    }

    ///////////////////////////////////
    // View & Pure Function Tests //
    //////////////////////////////////
    function testGetCollateralTokenPriceFeed() public view {
        address priceFeed = dsce.getCollateralTokenPriceFeed(weth);
        assertEq(priceFeed, ethUsdPriceFeed);
    }

    function testGetCollateralTokens() public view {
        address[] memory collateralTokens = dsce.getCollateralTokens();
        assertEq(collateralTokens[0], weth);
    }

    function testGetMinHealthFactor() public view {
        uint256 minHealthFactor = dsce.getMinHealthFactor();
        assertEq(minHealthFactor, MIN_HEALTH_FACTOR);
    }

    function testGetLiquidationThreshold() public view {
        uint256 liquidationThreshold = dsce.getLiquidationThreshold();
        assertEq(liquidationThreshold, LIQUIDATION_THRESHOLD);
    }

    function testGetAccountCollateralValueFromInformation() public depositedCollateral {
        (, uint256 collateralValue) = dsce.getAccountInformation(user);
        uint256 expectedCollateralValue = dsce.getUsdValue(weth, amountCollateral);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetCollateralBalanceOfUser() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        uint256 collateralBalance = dsce.getCollateralBalanceOfUser(user, weth);
        assertEq(collateralBalance, amountCollateral);
    }

    function testGetAccountCollateralValue() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        uint256 collateralValue = dsce.getAccountCollateralValue(user);
        uint256 expectedCollateralValue = dsce.getUsdValue(weth, amountCollateral);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetDsc() public view {
        address dscAddress = dsce.getDsc();
        assertEq(dscAddress, address(dsc));
    }

    function testLiquidationPrecision() public view{
        uint256 expectedLiquidationPrecision = 100;
        uint256 actualLiquidationPrecision = dsce.getLiquidationPrecision();
        assertEq(actualLiquidationPrecision, expectedLiquidationPrecision);
    }

    // How do we adjust our invariant tests for this?
    // function testInvariantBreaks() public depositedCollateralAndMintedDsc {
    //     MockV3Aggregator(ethUsdPriceFeed).updateAnswer(0);

    //     uint256 totalSupply = dsc.totalSupply();
    //     uint256 wethDeposted = ERC20Mock(weth).balanceOf(address(dsce));
    //     uint256 wbtcDeposited = ERC20Mock(wbtc).balanceOf(address(dsce));

    //     uint256 wethValue = dsce.getUsdValue(weth, wethDeposted);
    //     uint256 wbtcValue = dsce.getUsdValue(wbtc, wbtcDeposited);

    //     console.log("wethValue: %s", wethValue);
    //     console.log("wbtcValue: %s", wbtcValue);
    //     console.log("totalSupply: %s", totalSupply);

    //     assert(wethValue + wbtcValue >= totalSupply);
    // }
}