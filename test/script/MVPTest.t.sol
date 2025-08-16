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

    // Setup the test values
    function setUp() public {
        vm.prank(creator);
        token = new CollateralToken(1000000 ether);
        registry = new DonationRegistry(address(0));
        hook = new CustomFeeHook(IPoolManager(poolManager), registry, creator);
        //Commented is the Sepolia pool manager address.
        poolManager = IPoolManager(address(0xdead)); //IPoolManager(0xE03A1074c86CFeDd5C142C4F04F1a1536e203543);
        registry.grantRole(registry.MINTER_ROLE(), address(hook));
        key = PoolKey(Currency.wrap(address(0)), Currency.wrap(address(token)), 3000, 60, IHooks(address(hook)));
        //Mock the pool manager functions.
        vm.mockCall(address(poolManager), abi.encodeWithSelector(IPoolManager.initialize.selector), abi.encode(0));
        vm.mockCall(address(poolManager), abi.encodeWithSelector(IPoolManager.modifyLiquidity.selector), abi.encode(BalanceDelta(0,0)));
        console.log("Founder Wallet : %s, Initial Balance : %s ETH, COLL:%s", creator, creator.balance, token.balanceOf(creator));
    }

    function testMVPFlow() public {
        //1. Donor donates ETH to the pool.
        vm.deal(donor, 1 ether);
        console.log("Donor Wallet : %s, Initial Balance : %s ETH, COLL:%s", donor, donor.balance);
        //Simulate the swap.
        vm.prank(donor);
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: false,
            amountSpecified: -int256(1 ether),
            sqrtPriceLimitX96: TickMath.MAX_SQRT_RATIO - 1
        });
        //mock -1 eth to 1000 coll.
        vm.mockCall(address(poolManager), abi.encodeWithSelector(IPoolManager.swap.selector,key, params, ""), abi.encode(BalanceDelta(-int128(1 ether), int128(1000 ether))));
        //Triggers the hook
        BalanceDelta delta = poolManager.swap(key, params, "");

        console.log("Transaction: Swap Executed. Delta: amount0 %s, amount1 %s", delta.amount0(), delta.amount1());
        console.log("Hook Activation: Before Swap(fee set, compounding if fees exists)");
        console.log("Hook activation: afterSwap (NFT mint, fee split)");
        console.log("Donor balance post-swap: %s ETH, COLL: %s", donor.balance, token.balanceOf(donor));
        console.log("Founder balance post-swap: %s ETH (fee received)", creator.balance);

        uint256 nftBalance = registry.balanceOf(donor);
        console.log("Minted NFT: Balance %s", nftBalance);
        if(nftBalance > 0) {
            uint256 tokenId = 0; //Frist mint
            console.log("NFT ID: %s, Owner: %s", tokenId, registry.ownerOf(tokenId));
        }

        //Assertions NFT Minted, fees split, pool balance increased.
        assertEq(nftBalance, 1,"NFT not minted");
        assertGt(creator.balance, 0, "No fees to founder");
        assertGt(token.balanceOf(address(poolManager)), 0, "Pool balance not increased");
        assertEq(token.balanceOf(donor), 0, "Donor balance not decreased");
        assertEq(token.balanceOf(creator), 0, "Founder balance not increased");
        assertEq(token.balanceOf(address(poolManager)), 0, "Pool balance not increased");
        assertEq(token.balanceOf(address(poolManager)), 0, "Pool balance not increased");
    }
}