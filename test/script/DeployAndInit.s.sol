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

contract DeployAndInit is Script {
    function run() public {
        vm.startBroadcast();

        //Deploy the tokens
        CollateralToken collateralToken = new CollateralToken(1000000 ether);
        address poolManagerAddr= 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543; //Sepolia
        DonationRegistry registry = new DonationRegistry(address(0)); //Grant the hook the minter role.
        CustomFeeHook hook = new CustomFeeHook(IPoolManager(poolManagerAddr), registry, msg.sender);
        registry.grantRole(registry.MINTER_ROLE(), address(hook));

        //Deploy the pool, ETH/COLL with the hook
        PoolKey memory key = PoolKey({
            //Mapping right values
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(collateralToken)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        //Approve the pool to spend the token. Add initial liquidity. 
        collateralToken.approve(address(poolManagerAddr), 500000 ether);
        //Initialize the pool. Broadcast the transaction and send the eth
        IPoolManager(poolManagerAddr).initialize(key, TickMath.getSqrtPriceAtTick(0));

        vm.stopBroadcast();
    }
}