# Liquid staking

## Setup
### 1. Publish contracts
### 2. Prepare .env
2.1 Create .env-{env} file
2.2 Check the logs and put created objects to .env-{env}
### 3. Update validators set
```bash
bash scripts/update_validators.bash ${env}
```
### 4. Transfer ownerships
```bash
bash scripts/transfer_operator.bash ${env} ${recipient}
bash scripts/transfer_owner.bash ${env} ${recipient}
```

## Integration

To integrate volo liquid staking in your Move project.

### Configure

Edit `Move.toml` file.

```
[dependencies]
liquid_staking = { git = "https://github.com/Sui-Volo/volo-liquid-staking-contracts.git", subdir = "liquid_staking", rev = "mainnet-v1.0.0" }
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet", override = true }
```