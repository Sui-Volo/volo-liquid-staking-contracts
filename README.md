# sui-smart-contracts

## Setup
### 1. Install SUI binaries 
Use the latest release as the tag
```bash
rustup update stable && cargo install --locked --git https://github.com/MystenLabs/sui.git --tag mainnet-v1.8.2 sui
```
### 2. Generate deployer wallet
*wip*
### 3. Deploy 
For example deploy of liquid_staking package
```bash
sui client publish --gas-budget 300000000 liquid_staking
```
### 4. Setup package
Check README.md of deployed package for further instructions
