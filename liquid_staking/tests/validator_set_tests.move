// SPDX-License-Identifier: MIT

#[test_only]
module liquid_staking::validator_set_tests {

    use liquid_staking::validator_set::{Self, ValidatorSet};
    use sui::test_scenario::{Self, next_tx, ctx, Scenario};
    use sui::coin;
    use sui_system::sui_system::{Self, SuiSystemState};
    use sui::balance;
    use sui::test_utils;
    use std::vector;
    use sui::tx_context::{Self};
    // use std::debug;

    use sui_system::governance_test_utils::{
        // Self,
        // add_validator,
        // add_validator_candidate,
        // advance_epoch,
        // advance_epoch_with_reward_amounts,
        create_validator_for_testing,
        create_sui_system_state_for_testing,
        // stake_with,
        // remove_validator,
        // remove_validator_candidate,
        // total_sui_balance,
        // unstake,
    };

    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;
    const VALIDATOR_ADDR_3: address = @0x3;
    const VALIDATOR_ADDR_4: address = @0x4;

    const MIST_PER_SUI: u64 = 1_000_000_000;

    #[test, expected_failure]
    fun update_more_than_max() {
        let addr = @0x0;
        let scenario = test_scenario::begin(addr);
        {
            validator_set::test_create(ctx(&mut scenario));
        };

        next_tx(&mut scenario, addr);
        {
            let vldr_set = test_scenario::take_shared<ValidatorSet>(&scenario);

            let vldrs = vector[VALIDATOR_ADDR_1, VALIDATOR_ADDR_2, VALIDATOR_ADDR_3, VALIDATOR_ADDR_4];
            let priors = vector[100, 101, 102, 0];

            validator_set::test_update_and_sort(&mut vldr_set, vldrs, priors);

            let validators = validator_set::get_validators(&vldr_set);

            test_utils::assert_eq(vector::length<address>(&validators), 4);
            test_utils::assert_eq(*vector::borrow(&validators, 0), VALIDATOR_ADDR_3);
            test_utils::assert_eq(*vector::borrow(&validators, 3), VALIDATOR_ADDR_4);

            test_scenario::return_shared<ValidatorSet>(vldr_set);
        };

        next_tx(&mut scenario, addr);
        {
            let vldr_set = test_scenario::take_shared<ValidatorSet>(&scenario);

            let vldrs = vector[VALIDATOR_ADDR_1, VALIDATOR_ADDR_2, VALIDATOR_ADDR_3, VALIDATOR_ADDR_4, @0x5, @0x6, @0x7, @0x8, @0x9, @0x10, @0x11, @0x12, @0x13, @0x14, @0x15, @0x16, @0x17];
            let priors = vector[100, 102, 101, 110, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];

            validator_set::test_update_and_sort(&mut vldr_set, vldrs, priors);

            test_scenario::return_shared<ValidatorSet>(vldr_set);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun update_and_sort() {
        let addr = @0x0;
        let scenario = test_scenario::begin(addr);
        {
            validator_set::test_create(ctx(&mut scenario));
        };

        next_tx(&mut scenario, addr);
        {
            let vldr_set = test_scenario::take_shared<ValidatorSet>(&scenario);

            let vldrs = vector[VALIDATOR_ADDR_1, VALIDATOR_ADDR_2, VALIDATOR_ADDR_3, VALIDATOR_ADDR_4];
            let priors = vector[100, 101, 102, 0];

            validator_set::test_update_and_sort(&mut vldr_set, vldrs, priors);

            let validators = validator_set::get_validators(&vldr_set);

            test_utils::assert_eq(vector::length<address>(&validators), 4);
            test_utils::assert_eq(*vector::borrow(&validators, 0), VALIDATOR_ADDR_3);
            test_utils::assert_eq(*vector::borrow(&validators, 3), VALIDATOR_ADDR_4);

            test_scenario::return_shared<ValidatorSet>(vldr_set);
        };

        next_tx(&mut scenario, addr);
        {
            let vldr_set = test_scenario::take_shared<ValidatorSet>(&scenario);

            let vldrs = vector[VALIDATOR_ADDR_1, VALIDATOR_ADDR_2, VALIDATOR_ADDR_3, VALIDATOR_ADDR_4];
            let priors = vector[100, 102, 101, 110];

            validator_set::test_update_and_sort(&mut vldr_set, vldrs, priors);

            let validators = validator_set::get_validators(&vldr_set);

            test_utils::assert_eq(vector::length<address>(&validators), 4);
            test_utils::assert_eq(*vector::borrow(&validators, 0), VALIDATOR_ADDR_4);
            test_utils::assert_eq(*vector::borrow(&validators, 1), VALIDATOR_ADDR_2);
            test_utils::assert_eq(*vector::borrow(&validators, 2), VALIDATOR_ADDR_3);
            test_utils::assert_eq(*vector::borrow(&validators, 3), VALIDATOR_ADDR_1);

            test_scenario::return_shared<ValidatorSet>(vldr_set);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun add() {
        let addr = @0x0;

        let scenario = test_scenario::begin(addr);
        {
            set_up_sui_system_state(&mut scenario);
            validator_set::test_create(ctx(&mut scenario));
        };

        next_tx(&mut scenario, addr);
        {
            let set = test_scenario::take_shared<ValidatorSet>(&scenario);
            validator_set::test_update_and_sort(&mut set, vector[VALIDATOR_ADDR_1, VALIDATOR_ADDR_2, VALIDATOR_ADDR_3], vector[1,2,3]);
            test_scenario::return_shared<ValidatorSet>(set);
        };

        next_tx(&mut scenario, addr);
        {
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);
            let vldr_set = test_scenario::take_shared<ValidatorSet>(&scenario);

            let i = 0;
            while (i < 2) {
                let staked_sui_1 = sui_system::request_add_stake_non_entry(&mut system_state, coin::mint_for_testing(60 * MIST_PER_SUI, ctx(&mut scenario)), VALIDATOR_ADDR_1, ctx(&mut scenario));
                validator_set::add_stake_for_testing(&mut vldr_set, VALIDATOR_ADDR_1, staked_sui_1, ctx(&mut scenario));

                let staked_sui_2 = sui_system::request_add_stake_non_entry(&mut system_state, coin::mint_for_testing(60 * MIST_PER_SUI, ctx(&mut scenario)), VALIDATOR_ADDR_2, ctx(&mut scenario));
                validator_set::add_stake_for_testing(&mut vldr_set, VALIDATOR_ADDR_2, staked_sui_2, ctx(&mut scenario));

                i = i + 1;
            };

            test_utils::assert_eq(validator_set::get_total_stake(&vldr_set, VALIDATOR_ADDR_1), 2 * 60 * MIST_PER_SUI);
            test_utils::assert_eq(validator_set::get_total_stake(&vldr_set, VALIDATOR_ADDR_2), 2 * 60 * MIST_PER_SUI);

            tx_context::increment_epoch_number(ctx(&mut scenario));

            let (balance, principal, reward) = validator_set::remove_stakes_for_testing(&mut vldr_set, &mut system_state, VALIDATOR_ADDR_1, 30 * MIST_PER_SUI, ctx(&mut scenario));
            test_utils::assert_eq(balance::value(&balance), 30 * MIST_PER_SUI);
            test_utils::assert_eq(principal, 30 * MIST_PER_SUI);
            test_utils::assert_eq(reward, 0);
            balance::destroy_for_testing(balance);

            test_utils::assert_eq(validator_set::get_total_stake(&vldr_set, VALIDATOR_ADDR_1), 90 * MIST_PER_SUI);

            test_scenario::return_shared(system_state);
            test_scenario::return_shared(vldr_set);
        };

        // make top validator inactive
        next_tx(&mut scenario, addr);
        {
            let set = test_scenario::take_shared<ValidatorSet>(&scenario);

            validator_set::test_update_and_sort(&mut set, vector[VALIDATOR_ADDR_1, VALIDATOR_ADDR_2, VALIDATOR_ADDR_3], vector[0,2,3]);
            test_utils::assert_eq(vector::length(&validator_set::get_validators(&set)), 3);
            test_utils::assert_eq(validator_set::get_top_validator(&set), VALIDATOR_ADDR_3);

            test_scenario::return_shared<ValidatorSet>(set);
        };

        next_tx(&mut scenario, addr);
        {
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);
            let vldr_set = test_scenario::take_shared<ValidatorSet>(&scenario);

            let (balance, principal, reward) = validator_set::remove_stakes_for_testing(&mut vldr_set, &mut system_state, VALIDATOR_ADDR_1, 90 * MIST_PER_SUI, ctx(&mut scenario));
            test_utils::assert_eq(principal, 90 * MIST_PER_SUI);
            test_utils::assert_eq(reward, 0);

            test_utils::assert_eq(validator_set::get_total_stake(&vldr_set, VALIDATOR_ADDR_1), 0);

            test_utils::assert_eq(vector::length(&validator_set::get_validators(&vldr_set)), 2);

            balance::destroy_for_testing(balance);

            test_scenario::return_shared(system_state);
            test_scenario::return_shared(vldr_set);
        };

        test_scenario::end(scenario);
    }


    fun set_up_sui_system_state(scenario: &mut Scenario) {
        let ctx = ctx(scenario);

        let validators = vector[
            create_validator_for_testing(VALIDATOR_ADDR_1, 100, ctx),
            create_validator_for_testing(VALIDATOR_ADDR_2, 100, ctx)
        ];
        create_sui_system_state_for_testing(validators, 0, 0, ctx);
    }

    // fun set_up_sui_system_state_with_storage_fund() {
    //     let scenario_val = test_scenario::begin(@0x0);
    //     let scenario = &mut scenario_val;
    //     let ctx = test_scenario::ctx(scenario);

    //     let validators = vector[
    //         create_validator_for_testing(VALIDATOR_ADDR_1, 100, ctx),
    //         create_validator_for_testing(VALIDATOR_ADDR_2, 100, ctx)
    //     ];
    //     create_sui_system_state_for_testing(validators, 300, 100, ctx);
    //     test_scenario::end(scenario_val);
    // }
}