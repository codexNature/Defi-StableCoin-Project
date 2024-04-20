// SPDX-License-Identifier: MIT

// This Invariant file will have our invariants aka properties of ythe system that should always hold. 

//What are our inariants?

//1. The total supply of DSC should be less than total value of collateral. 
//2. Getter view functions should never revert. 

pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { DeployDSC } from "../../script/DeployDSC.s.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { DecentralizedStableCoin } from "../../src/DecentralizedStableCoin.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { console } from "forge-std/Test.sol";
import { Handler } from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
  //DeployDSC deployer;
  DSCEngine dsce;
  DecentralizedStableCoin dsc;
  HelperConfig config;
  address weth;
  address wbtc;
  address token;
  address public user = address(1);
  Handler handler;



    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        //targetContract(address(dsce));
        handler = new Handler(dsce, dsc);
        targetContract(address(handler));
    }

    //  function setUp() external {
    //     DeployDSC deployer = new DeployDSC();
    //     (dsc, dsce, helperConfig) = deployer.run();
    //     (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();
    //     handler = new StopOnRevertHandler(dsce, dsc);
    //     targetContract(address(handler));
    //     // targetContract(address(ethUsdPriceFeed)); Why can't we just do this?
    // }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
      //get the value of all the collateral in the protocol then,
      //compare it to all the debt(dsc)
      uint256 totalSupply = dsc.totalSupply(); // total supply of all dsc in the world.
      uint256 totalWethDeposited = ERC20Mock(weth).balanceOf(address(dsce)); //total amount of weth deposited into the SC.
      uint256 totalWbtcDeposited = ERC20Mock(wbtc).balanceOf(address(dsce)); //total amount of wbtc Deposit into the SC.
 
      uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
      uint256 wbtcValue = dsce.getUsdValue(wbtc, totalWbtcDeposited);

      console.log("weth value: ", wethValue);
      console.log("wbtc value: ", wbtcValue);
      console.log("total supply: ", totalSupply);
      console.log("Times mint called: ", handler.timesMintIsCalled());

      assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersShouldNotRevert() public view {
      dsce.getLiquidationBonus();
      dsce.getPrecision();
      //dsce.getAccountCollateralValue();
      //dsce.getAccountInformation(user);
      dsce.getAdditionalFeedPrecision();
    //dsce.getCollateralBalanceOfUser();
     //dsce.getCollateralTokenPriceFeed();
      dsce.getCollateralTokens();
      dsce.getDsc();
      //dsce.getHealthFactor(user);
      dsce.getLiquidationPrecision();
      dsce.getLiquidationThreshold();
      dsce.getMinHealthFactor();
      //dsce.getTokenAmountFromUsd();
    }
}