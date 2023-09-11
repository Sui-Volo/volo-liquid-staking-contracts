// SPDX-License-Identifier: MIT

#[test_only]
module liquid_staking::cert_tests {

    use liquid_staking::cert::{Self, CERT, Metadata};
    use liquid_staking::ownership::{Self, OwnerCap};
    use sui::coin::{Coin};
    use sui::test_scenario::{Self, next_tx, ctx};
    use sui::test_utils;
    use sui::transfer;
    use sui::balance;

    #[test]
    fun trigger_migration() {
        let addr = @0xA;
        let scenario = test_scenario::begin(addr);
        {
            cert::test_init(ctx(&mut scenario));
            ownership::test_init(ctx(&mut scenario));
        };

        next_tx(&mut scenario, addr);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);


            cert::test_update_version(&mut metadata, 0);
            cert::test_migrate(&mut metadata, &owner_cap);

            test_scenario::return_shared<Metadata<CERT>>(metadata);
            test_scenario::return_to_address<OwnerCap>(addr, owner_cap);
        };

        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    fun trigger_migration_gt_version() {
        let addr = @0xA;
        let scenario = test_scenario::begin(addr);
        {
            cert::test_init(ctx(&mut scenario));
            ownership::test_init(ctx(&mut scenario));
        };

        next_tx(&mut scenario, addr);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);


            cert::test_update_version(&mut metadata, 5);
            cert::test_migrate(&mut metadata, &owner_cap);

            test_scenario::return_shared<Metadata<CERT>>(metadata);
            test_scenario::return_to_address<OwnerCap>(addr, owner_cap);
        };

        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    fun failed_to_assert_migration() {
        let addr = @0xA;
        let scenario = test_scenario::begin(addr);
        {
            cert::test_init(ctx(&mut scenario));
            ownership::test_init(ctx(&mut scenario));
        };

        next_tx(&mut scenario, addr);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);

            cert::test_update_version(&mut metadata, 20);
            cert::test_assert_version(&metadata);

            test_scenario::return_shared<Metadata<CERT>>(metadata);
            test_scenario::return_to_address<OwnerCap>(addr, owner_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun mint_burn() {
        // Initialize a mock sender address
        let addr1 = @0xA;
        // let dummy_address = @0xCAFE;

        // Begins a multi transaction scenario with addr1 as the sender
        let scenario = test_scenario::begin(addr1);
        
        // Run the managed coin module init function
        {
            cert::test_init(ctx(&mut scenario));
            ownership::test_init(ctx(&mut scenario));

        };

        // Mint CERT
        next_tx(&mut scenario, addr1);
        {
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);

            let cert_coin = cert::mint_coin_for_testing(&mut metadata, 1_000_000, test_scenario::ctx(&mut scenario));

            let supply = cert::get_total_supply(&metadata);
            test_utils::assert_eq(balance::supply_value(supply), 1_000_000);
            let supply_value = cert::get_total_supply_value(&metadata);
            test_utils::assert_eq(supply_value, 1_000_000);

            test_scenario::return_shared<Metadata<CERT>>(metadata);
            transfer::public_transfer(cert_coin, addr1);
        };

        // Burn CERT
        next_tx(&mut scenario, addr1);
        {
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let coin = test_scenario::take_from_sender<Coin<CERT>>(&scenario);
            cert::burn_coin_for_testing(&mut metadata, coin);
            test_scenario::return_shared<Metadata<CERT>>(metadata);
        };
        
        // Cleans up the scenario object
        test_scenario::end(scenario);
    }

}