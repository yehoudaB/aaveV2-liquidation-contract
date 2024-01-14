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


forge verify-contract --chain-id 137  --watch --verifier etherscan --api-key $POLYSCAN_API_KEY 0x81Ae7A73AB76c1AEDE748c6c9bC139e2032551e5 AaveV2Liquidation --constructor-args $(cast abi-encode "constructor(address,address,address)" 0x9945852318056dC9EbAfdC3caC70d05e0fBa00F7 0xd05e3E715d945B59290df0ae8eF85c1BdB684744 0xE592427A0AEce92De3Edee1F18E0157C05861564)    


