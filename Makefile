-include .env

all: clean remove install update build

# Clean the repo
clean :;
	@forge clean

# Remove modules
remove :;
	@rm -rf .gitmodules && \
	rm -rf .git/modules/* && \
	rm -rf lib && touch .gitmodules

# Install dependencies
install :;
	@forge install foundry-rs/forge-std@master --no-commit && \
	forge install openzeppelin/openzeppelin-contracts@master --no-commit

# Update dependencies
update :;
	@forge update

# Build the project
build :;
	@forge build

# Format code
format:
	@forge fmt

# Lint code
lint:
	@forge fmt --check

# Run tests
tests :;
	@forge test -vvv

# Run slither static analysis
slither :;
	@slither ./src

documentation: clean build
	@npx foundry-docgen -o docs

# Deploy a local blockchain
anvil :;
	@anvil -m 'test test test test test test test test test test test junk'

# This is the private key of account from the mnemonic from the "make anvil" command
deploy-anvil :;
	@forge script script/DeployBridgeAndReceptor.s.sol:DeployBridgeAndReceptorModuleScript --rpc-url http://localhost:8545 --broadcast && \
	forge script script/DeployTransmitter.s.sol:DeployTransmitterModuleScript --rpc-url http://localhost:8545 --broadcast && \
	forge script script/ConfigureReceptor.s.sol:ConfigureReceptorModuleScript --rpc-url http://localhost:8545 --broadcast 

# Deploy the contract to remote network and verify the code
deploy-network :;
	@export FOUNDRY_PROFILE=deploy && \
	forge script script/01_Deploy.s.sol:Deploy -f ${network} --broadcast --verify --delay 20 --retries 10 -vvvv && \
	export FOUNDRY_PROFILE=default

run-script :;
	@export FOUNDRY_PROFILE=deploy && \
	./utils/run_script.sh && \
	export FOUNDRY_PROFILE=default

run-script-local :;
	@./utils/run_script_local.sh