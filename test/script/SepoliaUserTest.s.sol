pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/CollateralToken.sol";
import "../src/DonationRegistry.sol";
import "../src/CustomFeeHook.sol";
import "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/src/types/PoolKey.sol";
import "@uniswap/v4-core/src/types/Currency.sol";
import "@uniswap/v4-core/src/interfaces/IHooks.sol";
import "@uniswap/v4-core/src/libraries/TickMath.sol";
import "@uniswap/v4-core/src/types/BalanceDelta.sol";

contract SepoliaUserTest is Script {
   
    address constant COLLATERAL_TOKEN = 0x4d7c87BCa5532474BFad0facfD5F48a60E0d35f2;  // From deployment
    address constant DONATION_REGISTRY = 0x81b5fbEAe765D68Df634BDE2999AA3c36D75c5A9; // From deployment
    address constant CUSTOM_FEE_HOOK = 0x8dBdeAEB418fBf5fAd09e5E14E4609B3c4b7D0C0;   // From deployment
    address constant POOL_MANAGER = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;     // Sepolia Uniswap V4

    // Test user simulation
    function run() public {
        vm.startBroadcast();

        address user = msg.sender;
        console.log("=== SEPOLIA USER TEST ===");
        console.log("Testing user:", user);
        console.log("User ETH balance:", user.balance / 1e18, "ETH");

        // Create contract instances
        CollateralToken token = CollateralToken(COLLATERAL_TOKEN);
        DonationRegistry registry = DonationRegistry(DONATION_REGISTRY);
        CustomFeeHook hook = CustomFeeHook(CUSTOM_FEE_HOOK);

        // Check initial balances
        console.log("\n=== INITIAL STATE ===");
        console.log("Token total supply:", token.totalSupply() / 1e18, "COLL");
        console.log("User token balance:", token.balanceOf(user) / 1e18, "COLL");
        console.log("User NFT balance:", registry.balanceOf(user));
        // Note: Registry doesn't expose totalSupply, so we track via user balances

        // Create pool key
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)), // ETH
            currency1: Currency.wrap(COLLATERAL_TOKEN),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(CUSTOM_FEE_HOOK)
        });

        console.log("\n=== POOL CONFIGURATION ===");
        console.log("Pool key currency0 (ETH):", Currency.unwrap(key.currency0));
        console.log("Pool key currency1 (COLL):", Currency.unwrap(key.currency1));
        console.log("Pool key fee:", key.fee);
        console.log("Pool key hooks:", address(key.hooks));

        // Check hook permissions
        console.log("\n=== HOOK VALIDATION ===");
        console.log("Hook address:", address(hook));
        console.log("Hook registry:", address(hook.registry()));
        console.log("Hook creator:", hook.creator());
        console.log("Hook has minter role:", registry.hasRole(registry.MINTER_ROLE(), address(hook)));

        // Simulate a swap (ETH for COLL tokens)
        console.log("\n=== ATTEMPTING SWAP ===");
        console.log("Simulating donation: 0.01 ETH for COLL tokens");
        
        IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
            zeroForOne: false, // ETH (currency0) for COLL (currency1)
            amountSpecified: -0.01 ether, // Exact input: spend 0.01 ETH
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(887272) - 1 // Max price (no limit)
        });

        try IPoolManager(POOL_MANAGER).swap(key, swapParams, "") {
            console.log("SWAP SUCCESSFUL!");
            
            // Check results
            uint256 nftBalanceAfter = registry.balanceOf(user);
            uint256 tokenBalanceAfter = token.balanceOf(user);
            
            console.log("\n=== RESULTS ===");
            console.log("User ETH balance after:", user.balance / 1e18, "ETH");
            console.log("User token balance after:", tokenBalanceAfter / 1e18, "COLL");
            console.log("User NFT balance after:", nftBalanceAfter);
            
            if (nftBalanceAfter > 0) {
                console.log("NFT MINTED! Token ID:", nftBalanceAfter - 1);
                console.log("NFT owner:", registry.ownerOf(nftBalanceAfter - 1));
            } else {
                console.log("No NFT minted - check hook logic");
            }
            
        } catch Error(string memory reason) {
            console.log("SWAP FAILED:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("SWAP FAILED: Low level error");
            console.logBytes(lowLevelData);
        }

        // Additional diagnostics
        console.log("\n=== DIAGNOSTICS ===");
        console.log("Pool manager address:", POOL_MANAGER);
        console.log("Hook beforeSwap enabled:", hook.getHookPermissions().beforeSwap);
        console.log("Hook afterSwap enabled:", hook.getHookPermissions().afterSwap);

        vm.stopBroadcast();
    }

    // Helper function to test hook directly
    function testHookDirectly() public {
        vm.startBroadcast();

        address user = msg.sender;
        DonationRegistry registry = DonationRegistry(DONATION_REGISTRY);
        CustomFeeHook hook = CustomFeeHook(CUSTOM_FEE_HOOK);

        console.log("\n=== DIRECT HOOK TEST ===");
        console.log("Testing hook functions directly...");

        // Create test data
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(COLLATERAL_TOKEN),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(CUSTOM_FEE_HOOK)
        });

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: false,
            amountSpecified: -0.01 ether,
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(887272) - 1
        });

        uint256 nftBefore = registry.balanceOf(user);
        console.log("NFT balance before:", nftBefore);

        try hook.afterSwap(user, key, params, BalanceDelta.wrap(0), "") {
            uint256 nftAfter = registry.balanceOf(user);
            console.log("NFT balance after:", nftAfter);
            
            if (nftAfter > nftBefore) {
                console.log("Hook working! NFT minted directly");
            } else {
                console.log("Hook didn't mint NFT - check conditions");
            }
        } catch Error(string memory reason) {
            console.log("Hook failed:", reason);
        }

        vm.stopBroadcast();
    }
}
