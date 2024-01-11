# AaveV3 Liquidation


### installing  libraries
```
    forge install OpenZeppelin/openzeppelin-contracts --no-commit
    forge install aave/protocol-v2 --no-commit   
    forge install Uniswap/v3-core --no-commit     
    forge install Uniswap/v3-periphery --no-commit     

```

### Deploy contract locally from a fork url 

run : 
````
anvil --fork-url $POLYGON_RPC_URL
````

then :
    
````
make deploy
````

for testing from polygon fork in one command you need to do this : 

```
 source .env 
 ```
 then
```
forge test --fork-url $POLYGON_RPC_URL -vvvv --mt <name-of-test-fonction>

```
equivalent to : 
```
  make test ARGS="--network polygon" // not implemented yet
``````


forge verify-contract --chain-id 42161  --watch --verifier etherscan --api-key $ARBITRUMSCAN_API_KEY 0x936ee132A0A00c374Ac03dd71eB55a7C02b3CFFe AaveV2Liquidation --constructor-args $(cast abi-encode "constructor(address,address,address)" 0xC894efbF31c71336F0C9eA2c8DC485f7eB2A8ac5 0x794a61358D6845594F94dc1DB02A252b5b4814aD 0xE592427A0AEce92De3Edee1F18E0157C05861564)    


