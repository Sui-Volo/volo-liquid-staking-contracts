// SPDX-License-Identifier: MIT

#[test_only]
module liquid_staking::otter_tests2 {

    use liquid_staking::native_pool::{Self, NativePool};
    use liquid_staking::cert::{Self};
    use liquid_staking::ownership::{Self, OperatorCap};
    use sui::test_scenario::{Self, next_tx, ctx, Scenario};
    // use sui::test_utils;
    // use sui::sui::{SUI};
    // use sui::balance;
    // use sui::coin;
    // use std::vector;
    // use sui::clock;
    // use std::debug;
    use sui_system::sui_system::{SuiSystemState};
    use sui_system::governance_test_utils::{
        // Self,
        // advance_epoch,
        // advance_epoch_with_reward_amounts,
        create_validator_for_testing,
        create_sui_system_state_for_testing,
        // stake_with,
        // total_sui_balance,
        // unstake,
    };
    // use sui::tx_context;

    // const MIST_PER_SUI: u64 = 1_000_000_000;
    // const INITIAL_RATIO: u256 = 1_000_000_000_000_000_000;
    const SENDER: address = @0x0;

    const SENDER1: address = @0x0;
    // const SENDER2: address = @0x1;
    // const SENDER3: address = @0x2;

    #[test]
    fun update_validator_poc() {
        let scenario = set_up_native_pool(); //// #vldrs : 2

        next_tx(&mut scenario, SENDER);
        {
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let operator_cap = test_scenario::take_from_sender<OperatorCap>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            let vldrs = vector[@0x3, @0x4, @0x5, @0x6, @0x7, @0x8, @0x9, @0x10, @0x11, @0x12, @0x13, @0x14, @0x15]; //// #vldrs : 15
            let priors = vector[100, 102, 101, 110, 1, 1, 1, 1, 1, 1, 0, 0, 0];

            native_pool::update_validators(&mut pool, vldrs, priors, &operator_cap);
            native_pool::sort_validators(&mut pool);
            native_pool::rebalance(&mut pool, &mut system_state, ctx(&mut scenario)); //// we expect #vldrs to decrease by 3 but it doesn't work

            let vldrs = vector[@0x16];
            let priors = vector[0];
            native_pool::update_validators(&mut pool, vldrs, priors, &operator_cap); //// #vldrs : 16 -> E_TOO_MANY_VLDRS

            test_scenario::return_shared(system_state);
            test_scenario::return_shared(pool);
            test_scenario::return_to_address<OperatorCap>(SENDER, operator_cap);
        };
        test_scenario::end(scenario);
    }

    fun set_up_native_pool(): Scenario {
        let scenario = test_scenario::begin(SENDER1);
        let ctx = ctx(&mut scenario);

        let validators = vector[
            create_validator_for_testing(@0xAB1, 100, ctx),
            create_validator_for_testing(@0xAB2, 100, ctx)
        ];
        create_sui_system_state_for_testing(validators, 0, 0, ctx);

        native_pool::test_init(ctx);
        ownership::test_init(ctx);
        cert::test_init(ctx);

        next_tx(&mut scenario, SENDER1);
        {
            let pool = test_scenario::take_shared<NativePool>(&mut scenario);
            native_pool::test_update_and_sort(&mut pool, vector[@0xAB1, @0xAB2], vector[2, 1]);
            test_scenario::return_shared(pool);
        };

        scenario
    }
}