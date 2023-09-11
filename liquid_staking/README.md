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