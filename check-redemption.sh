#!/bin/bash

NODE=https://rpc.osmosis.zone:443
CHAIN_ID="osmosis-1"
OSMO_ADDRESS=osmo15fqmdl8lfl9h0qflljd63ufw9j2m7xmsk3hu5vsn8xpta4hk5chqt7mddc # OSMO
ATOM_ADDRESS=osmo1hvl5kj4xzdj4udxjv2dzk2zfqhzkd9afqygwq3t84tn53e0250zqrltj48 # ATOM
TIA_ADDRESS=osmo1reyz7pwu7y9e7lmzqg6j4h7jcv32du7n7jhnk2lz93a9lxr56ess2qtgzl # TIA
OSMO_CONTROLLER=osmo1pzpe5v33udccmv64w57tv6pk8cjy06rtxfmsjq
STRIDE_CONTROLLER=stride1pzpe5v33udccmv64w57tv6pk8cjy06rtdegus7
ATOM_CONTROLLER=cosmos1pzpe5v33udccmv64w57tv6pk8cjy06rtwjgqyj
TIA_CONTROLLER=celestia1pzpe5v33udccmv64w57tv6pk8cjy06rtlces7l
ESTIMATE_PERIOD=17


# Queries to get state
OSMO_STATE=$(osmosisd query wasm contract-state smart $OSMO_ADDRESS "{\"vault_extension\": {\"vaultenator\": {\"state\": {}}}}" --node=$NODE --output=json | jq .)
ATOM_STATE=$(osmosisd query wasm contract-state smart $ATOM_ADDRESS "{\"vault_extension\": {\"vaultenator\": {\"state\": {}}}}" --node=$NODE --output=json | jq .)
TIA_STATE=$(osmosisd query wasm contract-state smart $TIA_ADDRESS "{\"vault_extension\": {\"vaultenator\": {\"state\": {}}}}" --node=$NODE --output=json | jq .)

# Queries to get balances
OSMO_BALANCE=$(osmosisd query bank balances $OSMO_ADDRESS --output=json --node=$NODE | jq .)
ATOM_BALANCE=$(osmosisd query bank balances $ATOM_ADDRESS --output=json --node=$NODE | jq .)
TIA_BALANCE=$(osmosisd query bank balances $TIA_ADDRESS --output=json --node=$NODE | jq .)

# Queries to get Stride data
STRIDE_OSMO=$(curl -s -X GET "https://stride-fleet.main.stridenet.co/api/Stride-Labs/stride/stakeibc/unbondings/$OSMO_CONTROLLER" | jq .address_unbondings)
STRIDE_ATOM=$(curl -s -X GET "https://stride-fleet.main.stridenet.co/api/Stride-Labs/stride/stakeibc/unbondings/$ATOM_CONTROLLER" | jq .address_unbondings)
STRIDE_TIA=$(curl -s -X GET "https://stride-fleet.main.stridenet.co/api/Stride-Labs/stride/staketia/redemption_records?address=$STRIDE_CONTROLLER" | jq .redemption_record_responses)
MILK_TIA=$(curl -s -X GET "https://apis.milkyway.zone/milktia/unstake-requests/$OSMO_CONTROLLER" | jq .requests)

# Sum calculations
TOTAL_SUM_OSMO=$(echo "$STRIDE_OSMO" | jq '[.[] | .amount | tonumber] | add // 0')
TOTAL_SUM_ATOM=$(echo "$STRIDE_ATOM" | jq '[.[] | .amount | tonumber] | add // 0')
TOTAL_SUM_STRIDE_TIA=$(echo "$STRIDE_TIA" | jq '[.[] | .redemption_record.native_amount | tonumber] | add // 0')
TOTAL_SUM_MILK_TIA=$(echo "$MILK_TIA" | jq '[.[] | .amount | tonumber] | add // 0')
TOTAL_SUM_TIA=$(($TOTAL_SUM_STRIDE_TIA + $TOTAL_SUM_MILK_TIA))

# Withdrawn amounts
TOTAL_WITHDRAWN_OSMO=$(echo "$OSMO_STATE" | jq '.data.total_withdrawn_tokens | tonumber')
TOTAL_WITHDRAWN_ATOM=$(echo "$ATOM_STATE" | jq '.data.total_withdrawn_tokens | tonumber')
TOTAL_WITHDRAWN_TIA=$(echo "$TIA_STATE" | jq '.data.total_withdrawn_tokens | tonumber')

# Calculate Deltas
DELTA_OSMO=$((TOTAL_SUM_OSMO - TOTAL_WITHDRAWN_OSMO))
DELTA_ATOM=$((TOTAL_SUM_ATOM - TOTAL_WITHDRAWN_ATOM))
DELTA_TIA=$((TOTAL_SUM_TIA - TOTAL_WITHDRAWN_TIA))

# Calculate Percentage Changes
# Check for division by zero and handle cases where TOTAL_WITHDRAWN is 0 to avoid runtime errors
PERCENT_CHANGE_OSMO=$(awk "BEGIN {print ($TOTAL_WITHDRAWN_OSMO != 0) ? ($DELTA_OSMO / $TOTAL_WITHDRAWN_OSMO) * 100 : 0}")
PERCENT_CHANGE_ATOM=$(awk "BEGIN {print ($TOTAL_WITHDRAWN_ATOM != 0) ? ($DELTA_ATOM / $TOTAL_WITHDRAWN_ATOM) * 100 : 0}")
PERCENT_CHANGE_TIA=$(awk "BEGIN {print ($TOTAL_WITHDRAWN_TIA != 0) ? ($DELTA_TIA / $TOTAL_WITHDRAWN_TIA) * 100 : 0}")

# Calculate APR using bc for floating point arithmetic
APR_OSMO=$(echo "scale=2; $ESTIMATE_PERIOD * $PERCENT_CHANGE_OSMO" | bc)
APR_ATOM=$(echo "scale=2; $ESTIMATE_PERIOD * $PERCENT_CHANGE_ATOM" | bc)
APR_TIA=$(echo "scale=2; $ESTIMATE_PERIOD * $PERCENT_CHANGE_TIA" | bc)

# Output results with deltas and percentage changes
echo "Total outstanding redemption amounts (OSMO): $TOTAL_SUM_OSMO   Total withdrawn amounts (OSMO): $TOTAL_WITHDRAWN_OSMO   Delta: $DELTA_OSMO   Percent Change: $PERCENT_CHANGE_OSMO%   APR: $APR_OSMO%"
echo "Total outstanding redemption amounts (ATOM): $TOTAL_SUM_ATOM   Total withdrawn amounts (ATOM): $TOTAL_WITHDRAWN_ATOM   Delta: $DELTA_ATOM   Percent Change: $PERCENT_CHANGE_ATOM%   APR: $APR_ATOM%"
echo "Total outstanding redemption amounts (TIA): $TOTAL_SUM_TIA   Total withdrawn amounts (TIA): $TOTAL_WITHDRAWN_TIA   Delta: $DELTA_TIA   Percent Change: $PERCENT_CHANGE_TIA%   APR: $APR_TIA%"
