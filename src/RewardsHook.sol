// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ERC20Gauge} from "./ERC20Gauge.sol";

contract RewardsHook is BaseHook, Ownable {
    ERC20Gauge private _gauge;

    event GaugeUpdated(ERC20Gauge gauge);

    error GaugeInvalidAddress();

    constructor(IPoolManager _poolManager, ERC20Gauge gauge) BaseHook(_poolManager) Ownable(msg.sender) {
        _gauge = gauge;

        if (_gauge == ERC20Gauge(address(0)))
            revert GaugeInvalidAddress();
    }

    function setGauge(ERC20Gauge gauge) external onlyOwner {
        _gauge = gauge;

        if (gauge == ERC20Gauge(address(0)))
            revert GaugeInvalidAddress();

        emit GaugeUpdated(gauge);
    }

    function gauge() external view returns (ERC20Gauge) {
        return _gauge;
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, BalanceDelta) {
        IERC20 stakingToken = ERC20Gauge(_gauge).stakingToken();
        
        if (Currency.unwrap(key.currency0) != address(stakingToken)) {
            return (BaseHook.afterAddLiquidity.selector, delta);
        }

        address user = parseHookData(hookData);

        uint256 stakingTokenAmount = uint256(int256(-delta.amount1()));

        _gauge.deposit(user, stakingTokenAmount);

        return (BaseHook.afterAddLiquidity.selector, delta);
    }

    function getHookData(address user) public pure returns (bytes memory) {
        return abi.encode(user);
    }

    function parseHookData(bytes calldata data) public pure returns (address user) {
        return abi.decode(data, (address));
    }
}