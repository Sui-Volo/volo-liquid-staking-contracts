// SPDX-License-Identifier: MIT

#[test_only]
module liquid_staking::otter_tests {

    use liquid_staking::native_pool::{Self, NativePool};
    use liquid_staking::cert::{Self, Metadata, CERT};
    use liquid_staking::ownership::{Self};
    use liquid_staking::unstake_ticket::UnstakeTicket;
    use sui::test_scenario::{Self, next_tx, ctx, Scenario};
    use sui::sui::{SUI};
    use sui::coin;
    use std::vector;
    // use sui::clock;
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

    // AUDIT: this scenario demonstrates the edge case in which the user is unable to unstake their ticket
    // because the activation epoch of the re-staked SUI is in the future.
    #[test]
    fun test_unstake_ticket_frontrun() {
        let scenario = set_up_native_pool();
        let tickets: vector<UnstakeTicket> = vector[];
        let certs: vector<coin::Coin<CERT>> = vector[];

        next_tx(&mut scenario, SENDER);
        {
            let sui = coin::mint_for_testing<SUI>(MIST_PER_SUI, ctx(&mut scenario));
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            let cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx(&mut scenario));
            vector::push_back(&mut certs, cert);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        next_tx(&mut scenario, SENDER);
        {
            advance_epoch(&mut scenario);
        };
        next_tx(&mut scenario, SENDER);
        {
            advance_epoch(&mut scenario);
        };

        next_tx(&mut scenario, SENDER);
        {
            let sui = coin::mint_for_testing<SUI>(MIST_PER_SUI + 100_000, ctx(&mut scenario)); // 1 SUI
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            let cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx(&mut scenario));
            let cert_one_sui = coin::split(&mut cert, MIST_PER_SUI, ctx(&mut scenario));

            let ticket = native_pool::mint_ticket_non_entry(&mut pool, &mut metadata, cert_one_sui, ctx(&mut scenario));
            vector::push_back(&mut tickets, ticket);
            vector::push_back(&mut certs, cert);

            let previous_cert = vector::remove(&mut certs, 0);
            let previous_ticket = native_pool::mint_ticket_non_entry(&mut pool, &mut metadata, previous_cert, ctx(&mut scenario));
            vector::push_back(&mut tickets, previous_ticket);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        next_tx(&mut scenario, SENDER);
        {
            advance_epoch(&mut scenario);
        };
        next_tx(&mut scenario, SENDER);
        {
            advance_epoch(&mut scenario);
        };

        next_tx(&mut scenario, SENDER);
        {
            let sui = coin::mint_for_testing<SUI>(MIST_PER_SUI + 100_000, ctx(&mut scenario)); // 1 SUI
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            let cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx(&mut scenario));
            let ticket = native_pool::mint_ticket_non_entry(&mut pool, &mut metadata, cert, ctx(&mut scenario));
            vector::push_back(&mut tickets, ticket);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        next_tx(&mut scenario, SENDER);
        {
            advance_epoch(&mut scenario);
        };
        
        next_tx(&mut scenario, SENDER);
        {
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            let ctx = ctx(&mut scenario);

            let tickets_number = vector::length(&tickets);
            let i = 0;
            while (i < tickets_number) {
                i = i + 1;
                let ticket = vector::pop_back(&mut tickets);
                debug_print(b"[~~~testcase~~~] ticket", &ticket);
                debug_print(b"[~~~testcase~~~] total stake", &native_pool::get_total_staked(&pool));

                let sui = native_pool::burn_ticket_non_entry(&mut pool, &mut system_state, ticket, ctx);
                coin::burn_for_testing(sui);
            };
            vector::destroy_empty(tickets);

            let remaining_certs = vector::length(&certs);
            i = 0;
            while (i < remaining_certs) {
                i = i + 1;
                let cert = vector::pop_back(&mut certs);
                debug_print(b"[~~~testcase~~~] cert", &coin::value(&cert));
                coin::burn_for_testing(cert);
            };
            vector::destroy_empty(certs);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        test_scenario::end(scenario);
    }

    // AUDIT: this scenario shows the case which abuses the fact that the pending value
    // is not used for the burn ticket logic, meaning that the pool is unable to fulfill all
    // payments if there are enough coins in the pending vault
    #[test]
    fun test_unstake_ticket_dos() {
        let scenario = set_up_native_pool();
        let tickets: vector<UnstakeTicket> = vector[];
        let certs: vector<coin::Coin<CERT>> = vector[];

        next_tx(&mut scenario, SENDER);
        {
            let sui = coin::mint_for_testing<SUI>(MIST_PER_SUI + 200_000, ctx(&mut scenario));
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            let cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx(&mut scenario));
            let ticket = native_pool::mint_ticket_non_entry(&mut pool, &mut metadata, cert, ctx(&mut scenario));
            vector::push_back(&mut tickets, ticket);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        next_tx(&mut scenario, SENDER);
        {
            advance_epoch(&mut scenario);
        };
        next_tx(&mut scenario, SENDER);
        {
            advance_epoch(&mut scenario);
        };

        next_tx(&mut scenario, SENDER);
        {
            let sui = coin::mint_for_testing<SUI>(MIST_PER_SUI + 100_000, ctx(&mut scenario));
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            let cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx(&mut scenario));
            let ticket = native_pool::mint_ticket_non_entry(&mut pool, &mut metadata, cert, ctx(&mut scenario));
            vector::push_back(&mut tickets, ticket);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        next_tx(&mut scenario, SENDER);
        {
            advance_epoch(&mut scenario);
        };
        next_tx(&mut scenario, SENDER);
        {
            advance_epoch(&mut scenario);
        };
        
        next_tx(&mut scenario, SENDER);
        {
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            let ctx = ctx(&mut scenario);

            let tickets_number = vector::length(&tickets);
            let i = 0;
            while (i < tickets_number) {
                i = i + 1;
                let ticket = vector::pop_back(&mut tickets);
                debug_print(b"[~~~testcase~~~] ticket", &ticket);
                debug_print(b"[~~~testcase~~~] total stake", &native_pool::get_total_staked(&pool));

                let sui = native_pool::burn_ticket_non_entry(&mut pool, &mut system_state, ticket, ctx);
                coin::burn_for_testing(sui);
            };
            vector::destroy_empty(tickets);

            let remaining_certs = vector::length(&certs);
            i = 0;
            while (i < remaining_certs) {
                i = i + 1;
                let cert = vector::pop_back(&mut certs);
                debug_print(b"[~~~testcase~~~] cert", &cert);
                coin::burn_for_testing(cert);
            };
            vector::destroy_empty(certs);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        test_scenario::end(scenario);
    }
}
