// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EasyPosm} from "./utils/EasyPosm.sol";
import {Fixtures} from "./utils/Fixtures.sol";
import {RewardsHook} from "../src/RewardsHook.sol";
import {ERC20Gauge} from "../src/ERC20Gauge.sol";
import {TKAI} from "../src/TKAI.sol";

contract PointsHookTest is Test, Fixtures {
    using EasyPosm for IPositionManager;
    using StateLibrary for IPoolManager;

    RewardsHook hook;
    ERC20Gauge gauge;
    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        deployAndApprovePosm(manager);

        gauge = new ERC20Gauge("TKAI Rewards", "TKAIR",  address(this), address(this), IERC20(Currency.unwrap(currency0)), IERC20(Currency.unwrap(currency1)), 1, 24 * 60 * 60);

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG) ^
                (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(manager, gauge); //Add all the necessary constructor arguments from the hook
        deployCodeTo("RewardsHook.sol:RewardsHook", constructorArgs, flags);
        hook = RewardsHook(flags);
        gauge = hook.gauge();

        // Create the pool
        key = PoolKey(
            currency0,
            currency1,
            3000,
            60,
            IHooks(hook)
        );
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1);

        // Provide full-range liquidity to the pool
        tickLower = TickMath.minUsableTick(key.tickSpacing);
        tickUpper = TickMath.maxUsableTick(key.tickSpacing);

        deal(address(this), 200 ether);

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                SQRT_PRICE_1_1,
                TickMath.getSqrtPriceAtTick(tickLower),
                TickMath.getSqrtPriceAtTick(tickUpper),
                uint128(100e18)
            );

        (tokenId, ) = posm.mint(
            key,
            tickLower,
            tickUpper,
            100e18,
            amount0 + 1,
            amount1 + 1,
            address(this),
            block.timestamp,
            hook.getHookData(address(this))
        );
    }

    function test_RewardsHook_Liquidity() public {
      uint256 startingPoints = gauge.balanceOf(address(this));

      console2.log("startingPoints", startingPoints);

      uint128 liqToAdd = 100e18;

      (uint256 amount0, uint256 amount1) = LiquidityAmounts
          .getAmountsForLiquidity(
              SQRT_PRICE_1_1,
              TickMath.getSqrtPriceAtTick(tickLower),
              TickMath.getSqrtPriceAtTick(tickUpper),
              liqToAdd
          );

      posm.mint(
          key,
          tickLower,
          tickUpper,
          liqToAdd,
          amount0 + 1,
          amount1 + 1,
          address(this),
          block.timestamp,
          hook.getHookData(address(this))
      );

      uint256 endingPoints = gauge.balanceOf(address(this));

      console2.log("endingPoints", endingPoints);

      skip(100 * 60 * 60);

      uint256 earned0 = gauge.earned(0);
      uint256 earned1 = gauge.earned(1);
      uint256 earned2 = gauge.earned(2);

      console2.log("earned0", earned0);
      console2.log("earned1", earned1);
      console2.log("earned2", earned2);

      ERC20Gauge.Lock[] memory locks = gauge.locksForAddress(address(this));
      for (uint256 i = 0; i < locks.length; i++) {
          console.log("amount", locks[i].amount);
          console.log("shares", locks[i].shares);
          console.log("boostingFactor", locks[i].boostingFactor);
          console.log("lockTime", locks[i].lockTime);
          console.log("unlockTime", locks[i].unlockTime);
      }
    }
}