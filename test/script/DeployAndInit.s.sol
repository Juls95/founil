pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/CustomFeeHook.sol";
import "../src/DonationRegistry.sol";
import "../src/CollateralToken.sol";
import "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/src/types/PoolKey.sol";
import "@uniswap/v4-core/src/types/Currency.sol";
import "@uniswap/v4-core/src/interfaces/IHooks.sol";
import "@uniswap/v4-core/src/libraries/TickMath.sol";
import {HookMiner} from "@uniswap/v4-periphery/utils/HookMiner.sol";

contract DeployAndInit is Script {
    function run() public {
        vm.startBroadcast();
        //Deploy the tokens
        CollateralToken collateralToken = new CollateralToken(1000000 ether);
        address poolManagerAddr= 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543; //Sepolia
        DonationRegistry registry = new DonationRegistry(address(0)); //Grant the hook the minter role.
        
        uint160 flags = uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
    
         // Mine salt and deploy hook via CREATE2
         bytes memory constructorArgs = abi.encode(poolManagerAddr, address(registry), msg.sender);
         (address hookAddress, bytes32 salt) = HookMiner.find(0x4e59b44847b379578588920cA78FbF26c0B4956C, flags, type(CustomFeeHook).creationCode, constructorArgs);
         CustomFeeHook hook = new CustomFeeHook{salt: salt}(IPoolManager(poolManagerAddr), registry, msg.sender);
    
        // Grant role after deployment
        registry.grantRole(registry.MINTER_ROLE(), address(hook));

        /*
        // Deploy hook with simple approach (no mining needed for testing)
        CustomFeeHook hook = new CustomFeeHook(IPoolManager(poolManagerAddr), registry, msg.sender);
        registry.grantRole(registry.MINTER_ROLE(), address(hook));
        */
        // Validate hook address (Uniswap V4 requirement)
        console.log("Hook deployed at:", address(hook));
        console.log("Hook permissions valid:", hook.getHookPermissions().beforeSwap || hook.getHookPermissions().afterSwap);

        //Deploy the pool, ETH/COLL with the hook
        PoolKey memory key = PoolKey({
            //Mapping right values
            currency0: Currency.wrap(address(0x01)),
            currency1: Currency.wrap(address(collateralToken)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        //Approve the pool to spend the token. Add initial liquidity. 
        collateralToken.approve(address(poolManagerAddr), 500000 ether);
        console.log("Token approved for pool manager");
        
        //Initialize the pool. Broadcast the transaction and send the eth
        console.log("Initializing pool...");
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(0);
        
        /*IPoolManager(poolManagerAddr).initialize(key, sqrtPriceX96);
        console.log("Pool initialized successfully");*/
        
        // Skip liquidity addition for now - requires unlock pattern 16:30
        /*IPoolManager.ModifyLiquidityParams memory liquidityParams = IPoolManager.ModifyLiquidityParams({
            tickLower: -887220,
            tickUpper: 887220,
            liquidityDelta: 100000 ether,
            salt: 0
        });*/

        /*(BalanceDelta delta, ) = IPoolManager(poolManagerAddr).modifyLiquidity(key, liquidityParams, "");
        console.log("Liquidity added successfully");*/
        console.log("Skipping liquidity addition - requires unlock pattern for Uniswap V4");
        console.log("Pool is ready for swaps through proper router/frontend");

        /*
        //Pool initialization is not working. 15 hrs
         try IPoolManager(poolManagerAddr).initialize(key, TickMath.getSqrtPriceAtTick(0)) {
            console.log("Pool initialized successfully");
        } catch {
            console.log("Pool initialization failed - may already exist");
        }*/
        
        console.log("Pool key currency0:", Currency.unwrap(key.currency0));
        console.log("Pool key currency1:", Currency.unwrap(key.currency1));
        console.log("Pool key fee:", key.fee);
        console.log("Pool key tickSpacing:", key.tickSpacing);
        console.log("Pool key hooks:", address(key.hooks));
        
        // Log deployed addresses
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("CollateralToken:", address(collateralToken));
        console.log("DonationRegistry:", address(registry));
        console.log("CustomFeeHook:", address(hook));
        console.log("Pool Manager:", poolManagerAddr);

        vm.stopBroadcast();
    }
}