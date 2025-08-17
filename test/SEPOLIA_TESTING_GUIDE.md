# 🧪 Sepolia Testing Guide

## 📋 Your Deployed Contracts

Update these addresses in the testing files with your actual deployed contracts:

```solidity
// From your deployment logs:
COLLATERAL_TOKEN = "0x23038b5f0111025EeDB586fC910b1d4B7Fe6ab51"
DONATION_REGISTRY = "0x72EF52c5d99F4e8a0aeF3d89e6ea87cA7c8e1A3F" 
CUSTOM_FEE_HOOK = "0x81b5fbEAe765D68Df634BDE2999AA3c36D75c5A9"
POOL_MANAGER = "0xE03A1074c86CFeDd5C142C4F04F1a1536e203543"
```

## 🔧 Testing Methods

### Method 1: Forge Script Testing

Test the complete flow using Forge scripts on Sepolia:

```bash
# Test the main user flow
forge script script/SepoliaUserTest.s.sol:SepoliaUserTest \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast

# Test hook directly
forge script script/SepoliaUserTest.s.sol:SepoliaUserTest \
  --sig "testHookDirectly()" \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Method 2: Frontend Testing

1. **Open the HTML file**: `test/sepolia-test.html` in your browser
2. **Update contract addresses** in the JavaScript section
3. **Connect MetaMask** to Sepolia testnet
4. **Test the complete user flow** through the interface

### Method 3: Manual Verification

Check your contracts on Sepolia Etherscan:

```bash
# Verify contract deployment
cast call $COLLATERAL_TOKEN "totalSupply()" --rpc-url $SEPOLIA_RPC_URL

# Check NFT registry
cast call $DONATION_REGISTRY "totalSupply()" --rpc-url $SEPOLIA_RPC_URL

# Verify hook permissions
cast call $DONATION_REGISTRY "hasRole(bytes32,address)" \
  0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6 \
  $CUSTOM_FEE_HOOK \
  --rpc-url $SEPOLIA_RPC_URL
```

## 🧪 Test Scenarios

### Scenario 1: Basic Flow Test
1. **Connect wallet** to Sepolia
2. **Check initial balances** (ETH, COLL, NFTs)
3. **Perform donation** (0.01 ETH → COLL + NFT)
4. **Verify results**:
   - ETH balance decreased
   - COLL tokens received  
   - NFT minted (if swap successful)

### Scenario 2: Hook Functionality Test
1. **Direct hook testing** (bypass pool manager)
2. **Verify NFT minting** works independently
3. **Check fee calculation** logic

### Scenario 3: Contract Verification
1. **Verify all contracts** deployed correctly
2. **Check permissions** (hook has minter role)
3. **Validate pool configuration**

## 📊 Expected Results

### ✅ Successful Test:
- User loses ~0.01 ETH (+ gas)
- User receives COLL tokens
- **NFT is minted** to user's address
- Transaction appears on Sepolia Etherscan

### 🔍 Debug Information:
- Pool manager calls hook automatically
- Hook checks `zeroForOne: false` 
- NFT minted in `afterSwap` function
- Fees distributed to creator

## 🚨 Common Issues & Solutions

### Issue 1: "ManagerLocked" Error
- **Cause**: Trying to call pool manager directly
- **Solution**: Use proper router or frontend interface

### Issue 2: No NFT Minted
- **Check**: Hook has minter role
- **Check**: Swap direction (`zeroForOne: false`)
- **Check**: Hook permissions enabled

### Issue 3: Swap Reverts
- **Check**: Pool has liquidity
- **Check**: Sufficient ETH balance
- **Check**: Correct pool parameters

## 🎯 Success Criteria

Your test is successful when:
1. ✅ **Contracts deployed** and verified on Sepolia
2. ✅ **User can perform swap** (ETH → COLL)
3. ✅ **NFT is minted** during swap
4. ✅ **Hook functions execute** correctly
5. ✅ **Fees are distributed** as expected

## 🔗 Etherscan Links

Monitor your contracts on Sepolia:
- **CollateralToken**: https://sepolia.etherscan.io/address/0x23038b5f0111025EeDB586fC910b1d4B7Fe6ab51
- **DonationRegistry**: https://sepolia.etherscan.io/address/0x72EF52c5d99F4e8a0aeF3d89e6ea87cA7c8e1A3F
- **CustomFeeHook**: https://sepolia.etherscan.io/address/0x81b5fbEAe765D68Df634BDE2999AA3c36D75c5A9

## 📞 Need Help?

If tests fail:
1. Check the **deployment logs** for any issues
2. Verify **contract addresses** are correct
3. Ensure **Sepolia ETH** balance for gas
4. Check **pool initialization** status

Happy Testing! 🚀
