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
        //Calculate the fees - simplified for now
        int128 amount0 = delta.amount0();
        // Just mint NFT and return
        return (CustomFeeHook.afterSwap.selector, 0);   
    }

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