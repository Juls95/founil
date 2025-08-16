pragma solidity ^0.8.22;

import "@uniswap/v4-core/contracts/hooks/IHooks.sol";
import "@uniswap/v4-core/contracts/libraries/IPoolManager.sol";
import "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/src/interfaces/IHooks.sol";
import "@uniswap/v4-core/src/types/PoolKey.sol";
import "@uniswap/v4-core/src/libraries/TickMath.sol";
import "./DonationRegistry.sol";

contract CustomFeeHook is IHooks {
    //Define the variables
    IPoolManager public immutable poolManager;
    DonationRegistry public immutable registry;
    address public immutable creator;
    PoolKey public  poolKey;

    //For Compounding, wide range.
    int24 constant COMPOUND_TICK_LOWER = -887220;
    int24 constant COMPOUND_TICK_UPPER = 887222;

    uint128 constant COMPOUND_LIQUIDITY = 1000000000000000000000000;

    uint128 constant COMPOUND_FEE = 10000;


    constructor(IPoolManager _poolManager, DonationRegistry _registry,address _creator) {
        poolManager = _poolManager;
        registry = _registry;
        creator = _creator;
    }
//Getting the permissions for the hook.
    function getHookPermissions() external pure returns (Hooks.Permissions memory) {
        return new Hooks.Permissions({
            beforeInitialize : false,
            afterInitialize : true,
            beforeAddLiquidity : false,
            afterAddLiquidity : false,
            beforeRemoveLiquidity : false,
            afterRemoveLiquidity : false,
            beforeSwap : true,
            afterSwap : true,
            beforeDonate : false,
            afterDonate : false,
            beforeSwapReturnDelta : false,
            afterSwapReturnDelta : false,
            afterAddLiquidityReturnDelta : false,
            afterRemoveLiquidityReturnDelta : false
        });
    }

    function getPoolKey() external view returns (PoolKey memory) {
        return poolKey;
    }

    function getPoolManager() external view returns (IPoolManager) {
}
}