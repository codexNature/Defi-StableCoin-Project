// SPDX-License-Identifier: MIT

// This Invariant file will have our invariants aka properties of ythe system that should always hold. 

//What are our inariants?

//1. The total supply of DSC should be less than total value of collateral. 
//2. Getter view functions should never revert. 

// pragma solidity 0.8.20;

// import { Test } from "forge-std/Test.sol";
// import { StdInvariant } from "forge-std/StdInvariant.sol";
// import { DeployDSC } from "../../../script/DeployDSC.s.sol";
// import { DSCEngine } from "../../../src/DSCEngine.sol";
// import { DecentralizedStableCoin } from "../../../src/DecentralizedStableCoin.sol";
// import { HelperConfig } from "../../../script/HelperConfig.s.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import { console } from "forge-std/Test.sol";

// contract OpenInvariantsTest is StdInvariant, Test {
//   DeployDSC deployer;
//   DSCEngine dsce;
//   DecentralizedStableCoin dsc;
//   HelperConfig config;
//   address weth;
//   address wbtc;



//     function setUp() external {
//         deployer = new DeployDSC();
//         (dsc, dsce, config) = deployer.run();
//         (,, weth, wbtc,) = config.activeNetworkConfig();
//         targetContract(address(dsce));
//     }

//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//       //get the value of all the collateral in the protocol then,
//       //compare it to all the debt(dsc)
//       uint256 totalSupply = dsc.totalSupply(); // total supply of all dsc in the world.
//       uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce)); //total amount of weth deposited into the SC.
//       uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dsce)); //total amount of wbtc Deposit into the SC.
 
//       uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
//       uint256 wbtcValue = dsce.getUsdValue(wbtc, totalWbtcDeposited);

//       //console.log("weth value: ", wethValue);
//       //console.log("wbtc value: ", wbtcValue);
//       //console.log("total supply: ", totalSupply);

//       assert(wethValue + wbtcValue >= totalSupply);
//     }
// }





// pragma solidity 0.8.20;

// import { Test } from "forge-std/Test.sol";
// import { StdInvariant } from "forge-std/StdInvariant.sol";
// import { DeployDSC } from "../../../script/DeployDSC.s.sol";
// import { DSCEngine } from "../../../src/DSCEngine.sol";
// import { DecentralizedStableCoin } from "../../../src/DecentralizedStableCoin.sol";
// import { HelperConfig } from "../../../script/HelperConfig.s.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import { console } from "forge-std/Test.sol";
// import { Handler } from "./Handler.t.sol";

// contract Invariants is StdInvariant, Test {
//   DeployDSC deployer;
//   DSCEngine dsce;
//   DecentralizedStableCoin dsc;
//   HelperConfig config;
//   address weth;
//   address wbtc;
//   Handler handler;



//     function setUp() external {
//         deployer = new DeployDSC();
//         (dsc, dsce, config) = deployer.run();
//         (,, weth, wbtc,) = config.activeNetworkConfig();
//         //targetContract(address(dsce)); //this is for open invariants
//         handler = new Handler(dsce, dsc);
//         targetContract(address(handler));
//         //do not call redeem collateral unless there is a collateral to redeem. We wanna make sure we call in sensible order.
//     }

//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//       //get the value of all the collateral in the protocol then,
//       //compare it to all the debt(dsc)
//       uint256 totalSupply = dsc.totalSupply(); // total supply of all dsc in the world.
//       uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce)); //total amount of weth deposited into the SC.
//       uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dsce)); //total amount of wbtc Deposit into the SC.
 
//       uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
//       uint256 wbtcValue = dsce.getUsdValue(wbtc, totalWbtcDeposited);

//       //console.log("weth value: ", wethValue);
//       //console.log("wbtc value: ", wbtcValue);
//       //console.log("total supply: ", totalSupply);

//       assert(wethValue + wbtcValue >= totalSupply);
//     }
// }