// SPDX-License-Identifier: MIT

#[test_only]
module liquid_staking::unstake_ticket_tests {

    use liquid_staking::unstake_ticket::{Self, Metadata};
    use liquid_staking::cert::{Self, CERT};
    use sui::test_scenario::{Self, next_tx, ctx};
    use sui::tx_context::{Self};
    use sui::test_utils;
    use sui::transfer;
    // use std::debug;

    #[test]
    fun wrap_unwrap_ticket_succesful() {
        let addr = @0xA;
        let scenario = test_scenario::begin(addr);
        {
            let metadata = unstake_ticket::test_create(test_scenario::ctx(&mut scenario));
            transfer::public_transfer(metadata, addr);
            cert::test_init(test_scenario::ctx(&mut scenario))
        };


        next_tx(&mut scenario, addr);
        {
            let ticket_metadata = test_scenario::take_from_sender<Metadata>(&scenario);
            let cert_metadata = test_scenario::take_shared<cert::Metadata<CERT>>(&scenario);

            let value = 1_000_000;
            let ticket = unstake_ticket::wrap_unstake_ticket_for_testing(&mut ticket_metadata, value, 10_000, 0, ctx(&mut scenario));

            let supply_before = unstake_ticket::get_total_supply(&mut ticket_metadata);

            test_utils::assert_eq(supply_before, value);
            test_utils::assert_eq(unstake_ticket::get_value(&ticket), value);

            unstake_ticket::transfer_for_testing(ticket, addr);

            let i = 0;
            while(i < 10) {
                let ticket = unstake_ticket::wrap_unstake_ticket_for_testing(&mut ticket_metadata, value, 10_000, 0, ctx(&mut scenario));
                let (ticket_value, fee) = unstake_ticket::unwrap_unstake_ticket_for_testing(&mut ticket_metadata, ticket, ctx(&mut scenario));
                test_utils::assert_eq(ticket_value, value);
                test_utils::assert_eq(fee, 10_000);
                i = i + 1;
            };

            let supply_after = unstake_ticket::get_total_supply(&mut ticket_metadata);
            test_utils::assert_eq(supply_after, value);

            test_scenario::return_shared<cert::Metadata<CERT>>(cert_metadata);
            test_scenario::return_to_address<Metadata>(addr, ticket_metadata);
        };

        test_scenario::end(scenario);
    }


    #[test]
    fun is_locked() {
        let addr = @0xA;

        let scenario = test_scenario::begin(addr);
        
        // Run the managed coin module init function
        {
            let metadata = unstake_ticket::test_create(test_scenario::ctx(&mut scenario));
            transfer::public_transfer(metadata, addr);
            cert::test_init(test_scenario::ctx(&mut scenario))
        };

        next_tx(&mut scenario, addr);
        {
            let ticket_metadata = test_scenario::take_from_sender<Metadata>(&scenario);
            let cert_metadata = test_scenario::take_shared<cert::Metadata<CERT>>(&scenario);

            let value = 1_000_000;
            let ticket = unstake_ticket::wrap_unstake_ticket_for_testing(&mut ticket_metadata, value, 0, tx_context::epoch(ctx(&mut scenario)) + 1, ctx(&mut scenario));

            test_utils::assert_eq(unstake_ticket::is_unlocked(&ticket, ctx(&mut scenario)), false);

            tx_context::increment_epoch_number(test_scenario::ctx(&mut scenario));

            test_utils::assert_eq(unstake_ticket::is_unlocked(&ticket, ctx(&mut scenario)), true);

            unstake_ticket::transfer_for_testing(ticket, addr);

            test_scenario::return_shared<cert::Metadata<CERT>>(cert_metadata);
            test_scenario::return_to_address<Metadata>(addr, ticket_metadata);
        };


        // Cleans up the scenario object
        test_scenario::end(scenario);
    }

}