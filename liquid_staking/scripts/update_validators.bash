#!/usr/bin/env bash

ENVIRONMENT=$1
SCRIPT_PATH=$(dirname "$0")

source "$SCRIPT_PATH/../.env-$ENVIRONMENT"

echo "Contract setup..."

GAS_BUDGET=${GAS_BUDGET:=300000000}
echo "Gas budget: $GAS_BUDGET"
echo "Package: $PACKAGE"
echo "Validators: $VALIDATOR_SET_ADDRS"
echo "Priorities: $VALIDATOR_SET_PRIORS"

# [0x..,0x..,0x...] is validators presented on network
# [1,2,3] their priority
sui client call --function update_validators --module native_pool --package "$PACKAGE" --args "$NATIVE_POOL" "[$VALIDATOR_SET_ADDRS]" "[$VALIDATOR_SET_PRIORS]" "$OPERATOR_CAP" --gas-budget "$GAS_BUDGET"
sui client call --function sort_validators --module native_pool --package "$PACKAGE" --args "$NATIVE_POOL" --gas-budget "$GAS_BUDGET"

exit 0
