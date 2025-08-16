pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CollateralToken.sol";
import "../src/DonationRegistry.sol";
import "../src/CustomFeeHook.sol";
import "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/src/types/PoolKey.sol";
import "@uniswap/v4-core/src/types/Currency.sol";

contract MVPTest is Test {
    CollateralToken token;
    DonationRegistry registry;
    CustomFeeHook hook;
    IPoolManager poolManager;
    address creator = address(1);
    address donor = address(2);
    PoolKey key;

    function setUp() public {
        vm.prank(creator);
        token = new CollateralToken(1000000 ether);
        registry = new DonationRegistry(address(0));
        hook = new CustomFeeHook(IPoolManager(poolManager), registry, creator);
        //Commented is the Sepolia pool manager address.
        poolManager = IPoolManager(address(0xdead)); //IPoolManager(0xE03A1074c86CFeDd5C142C4F04F1a1536e203543);
        registry.grantRole(registry.MINTER_ROLE(), address(hook));
        key = PoolKey(Currency.wrap(address(0)), Currency.wrap(address(token)), 3000, 60, IHooks(address(hook)));
    }

    function testMVPFlow() public {
        //1. Donor donates ETH to the pool.
        vm.deal(donor, 1 ether);
        //Simulate the swap.
        vm.prank(donor);
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: false,
            amountSpecified: -int256(1 ether),
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
        });
        //Assertions NFT Minted, fees split, pool balance increased.
        assertEq(registry.balanceOf(donor), 1);
    }
}