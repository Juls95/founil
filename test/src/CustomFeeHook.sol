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

    function afterInitialize(
        address,
        PoolKey calldata key,
        uint160,
        int24
    ) external returns (bytes24) {
        poolKey = key;
        return customFeeHook.afterInitialize.selector;
    }

    function beforeSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    ) external returns (bytes4, int24, uint24) {
        //Auto Compund Fees
        (uint256 amount0, uint256 amount1) = poolManager.collectFees(poolKey, address(this), type(uint128).max, type(uint128).max);
        if (amount0 > 0 || amount1 > 0) {
            CurrencyLibrary.transfer(poolkey.currency0,address(poolManager),amount0);
            CurrencyLibrary.transfer(poolkey.currency1,address(poolManager),amount1);
            poolManager.modifyLiquidity(poolKey, poolManager.modifyLiquidityParams  ({
                tickLower : COMPOUND_TICK_LOWER,
                tickUpper : COMPOUND_TICK_UPPER,
                liquidityDelta : int256(LiquidityAmounts.getLiquidityForAmounts(
                    poolKey.tickSpacing,
                    poolKey.token0,
                    poolKey.token1,
                    amount0,
                    amount1
                ))            }),"");
        }
        return (customFeeHook.beforeSwap.selector, 0, 1000);
    }

    function afterSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    ) external returns (bytes4, int24, uint24) {
        return (customFeeHook.afterSwap.selector, 0, 1000);
    }
    }

    function getPoolKey() external view returns (PoolKey memory) {
        return poolKey;
    }

    function getPoolManager() external view returns (IPoolManager) {
}
}