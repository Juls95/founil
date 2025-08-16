pragma solidity ^0.8.22;

import "@uniswap/v4-core/src/interfaces/IHooks.sol";
import "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/src/types/PoolKey.sol";
import "@uniswap/v4-core/src/libraries/TickMath.sol";
import "@uniswap/v4-core/src/libraries/Hooks.sol";
import "@uniswap/v4-core/src/types/Currency.sol";
import "@uniswap/v4-core/src/types/BalanceDelta.sol";
import "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import "@uniswap/v4-periphery/libraries/LiquidityAmounts.sol";

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
        return Hooks.Permissions({
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
    ) external returns (bytes4) {
        poolKey = key;
        return CustomFeeHook.afterInitialize.selector;
    }

    function beforeSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    ) external returns (bytes4, BeforeSwapDelta, uint24) {
        // Simple fee collection - just return default values
        return (CustomFeeHook.beforeSwap.selector, BeforeSwapDelta.wrap(0), 1000);
    }
    /* Complex way for the fee collection. Commented for now. 09:24 am
    ) external returns (bytes4, int24, uint24) {
        //Auto Compound Fees
        (uint256 amount0, uint256 amount1) = poolManager.collectFees(poolKey, address(this), type(uint128).max, type(uint128).max);
        if (amount0 > 0 || amount1 > 0) {
            CurrencyLibrary.transfer(poolKey.currency0, address(poolManager), amount0);
            CurrencyLibrary.transfer(poolKey.currency1, address(poolManager), amount1);
            poolManager.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
                tickLower: COMPOUND_TICK_LOWER,
                tickUpper: COMPOUND_TICK_UPPER,
                liquidityDelta: int256(LiquidityAmounts.getLiquidityForAmounts(
                    poolKey.tickSpacing,
                    poolKey.token0,
                    poolKey.token1,
                    amount0,
                    amount1 
                ))
            }), "");
        }
        return (customFeeHook.beforeSwap.selector, 0, 1000);
    */ 

    function afterSwap(
        address sender,
        PoolKey calldata,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) external returns (bytes4, int128) {
        if(!params.zeroForOne) {
            //MINT NFT
            registry.safeMint(sender);
        }
        
        // Calculate fees from the swap delta
        // Fee is 0.1% (1000 basis points = 100%)
        uint256 feeBasisPoints = 100; // 0.1%
        
        // Determine which token was swapped in (negative delta means tokens were taken from user)
        if (delta.amount0() < 0) {
            // User swapped token0 for token1
            uint256 swapAmount = uint256(uint128(-delta.amount0()));
            uint256 feeAmount = (swapAmount * feeBasisPoints) / 10000;
            uint256 toCreator = feeAmount / 2; // 50% to creator
            uint256 toPool = feeAmount - toCreator; // 50% to pool
            
            // Transfer fees to creator
            if (toCreator > 0) {
                CurrencyLibrary.transfer(poolKey.currency0, creator, toCreator);
            }
            
            // Add remaining fees to pool liquidity
            if (toPool > 0) {
                IPoolManager.ModifyLiquidityParams memory liqParams = IPoolManager.ModifyLiquidityParams({
                    tickLower: COMPOUND_TICK_LOWER,
                    tickUpper: COMPOUND_TICK_UPPER,
                    liquidityDelta: int256(uint128(LiquidityAmounts.getLiquidityForAmounts(
                        uint160(poolKey.tickSpacing),
                        uint160(Currency.unwrap(poolKey.currency0)),
                        uint160(Currency.unwrap(poolKey.currency1)),
                        toPool,
                        0
                    )))
                });
                poolManager.modifyLiquidity(poolKey, liqParams, "");
            }
        } else if (delta.amount1() < 0) {
            // User swapped token1 for token0
            uint256 swapAmount = uint256(uint128(-delta.amount1()));
            uint256 feeAmount = (swapAmount * feeBasisPoints) / 10000;
            uint256 toCreator = feeAmount / 2; // 50% to creator
            uint256 toPool = feeAmount - toCreator; // 50% to pool
            
            // Transfer fees to creator
            if (toCreator > 0) {
                CurrencyLibrary.transfer(poolKey.currency1, creator, toCreator);
            }
            
            // Add remaining fees to pool liquidity
            if (toPool > 0) {
                IPoolManager.ModifyLiquidityParams memory liqParams = IPoolManager.ModifyLiquidityParams({
                    tickLower: COMPOUND_TICK_LOWER,
                    tickUpper: COMPOUND_TICK_UPPER,
                    liquidityDelta: int256(uint128(LiquidityAmounts.getLiquidityForAmounts(
                        uint160(poolKey.tickSpacing),
                        uint160(Currency.unwrap(poolKey.currency0)),
                        uint160(Currency.unwrap(poolKey.currency1)),
                        0,
                        toPool
                    )))
                });
                poolManager.modifyLiquidity(poolKey, liqParams, "");
            }
        }
        
        return (CustomFeeHook.afterSwap.selector, 0);   
    }
    /*//Calculate the fees. Simplified for now. 09:25
        uint256 hookFee = delta.amount0 / 10; // 10% fee
        uint256 toCreator = hookFee / 2;
        uint256 toPool = hookFee - toCreator;
        //Transfer the fees to the pool.
        if(toPool > 0) {
            poolManager.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
                tickLower: COMPOUND_TICK_LOWER,
                tickUpper: COMPOUND_TICK_UPPER,
                liquidityDelta: int256(LiquidityAmounts.getLiquidityForAmounts(
                    poolKey.tickSpacing,
                    poolKey.token0,
                    poolKey.token1,
                    toPool,
                    toPool
                ))
            }), "");
        }
        return (customFeeHook.afterSwap.selector, delta);  
    */ 

    // Required interface implementations
    function beforeInitialize(address, PoolKey calldata, uint160) external pure returns (bytes4) {
        revert("Not implemented");
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        revert("Not implemented");
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        revert("Not implemented");
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        revert("Not implemented");
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        revert("Not implemented");
    }

    function beforeDonate(
        address,
        PoolKey calldata,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        revert("Not implemented");
    }

    function afterDonate(
        address,
        PoolKey calldata,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        revert("Not implemented");
    }

    function getPoolKey() external view returns (PoolKey memory) {
        return poolKey;
    }

    function getPoolManager() external view returns (IPoolManager) {
        return poolManager;
    }
}