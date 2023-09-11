#!/usr/bin/env bash

ENVIRONMENT=$1
RECIPIENT=$2
SCRIPT_PATH=$(dirname "$0")

source "$SCRIPT_PATH/../.env-$ENVIRONMENT"

echo "operator transferring to $RECIPIENT..."

GAS_BUDGET=${GAS_BUDGET:=300000000}
echo "Gas budget: $GAS_BUDGET"
echo "Package: $PACKAGE"

sui client call --function transfer_operator --module ownership --package "$PACKAGE" --args "$OPERATOR_CAP" "$RECIPIENT" --gas-budget "$GAS_BUDGET"

exit 0
