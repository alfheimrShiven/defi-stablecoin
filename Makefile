anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1
test :; forge test

NETWORK_ARGS := --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

# BasicNft Commands
deploy:
	@forge script script/DeployDSC.s.sol:DeployDSC $(NETWORK_ARGS)

