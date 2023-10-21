// SPDX-License-Identifier: MIT

#[test_only]
module liquid_staking::native_pool_tests {

    use liquid_staking::native_pool::{Self, NativePool};
    use liquid_staking::cert::{Self, Metadata, CERT};
    use liquid_staking::ownership::{Self, OperatorCap, OwnerCap};
    use sui::test_scenario::{Self, next_tx, ctx, Scenario};
    use sui::test_utils;
    use sui::sui::{SUI};
    // use sui::balance;
    use sui::coin;
    // use std::vector;
    use sui::clock;
    // use std::debug;
    use sui_system::sui_system::{SuiSystemState};
    use sui_system::governance_test_utils::{
        // Self,
        advance_epoch,
        // advance_epoch_with_reward_amounts,
        create_validator_for_testing,
        create_sui_system_state_for_testing,
        // stake_with,
        // total_sui_balance,
        // unstake,
    };

    const MIST_PER_SUI: u64 = 1_000_000_000;
    const INITIAL_RATIO: u256 = 1_000_000_000_000_000_000;
    const SENDER: address = @0x0;

    /* Migrations */

    #[test, expected_failure]
    fun trigger_migration_gt_version() {
        let scenario = set_up_native_pool();

        next_tx(&mut scenario, SENDER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);

            cert::test_update_version(&mut metadata, 5);
            cert::test_migrate(&mut metadata, &owner_cap);

            test_scenario::return_shared<Metadata<CERT>>(metadata);
            test_scenario::return_to_address<OwnerCap>(SENDER, owner_cap);
        };

        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    fun failed_to_assert_migration() {
        let scenario = set_up_native_pool();

        next_tx(&mut scenario, SENDER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);

            cert::test_update_version(&mut metadata, 20);
            cert::test_assert_version(&metadata);

            test_scenario::return_shared<Metadata<CERT>>(metadata);
            test_scenario::return_to_address<OwnerCap>(SENDER, owner_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun soft_migration() {
        let scenario = set_up_native_pool();

        next_tx(&mut scenario, SENDER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);

            cert::test_update_version(&mut metadata, 1);
            cert::test_assert_version(&metadata);

            test_scenario::return_shared<Metadata<CERT>>(metadata);
            test_scenario::return_to_address<OwnerCap>(SENDER, owner_cap);
        };

        test_scenario::end(scenario);
    }

    /* Staking */

    #[test]
    fun stake_without_pending_successful() {
        let scenario = set_up_native_pool();

        next_tx(&mut scenario, SENDER);
        {
            let native_pool = test_scenario::take_shared<NativePool>(&scenario);

            let min_stake = native_pool::get_min_stake(&native_pool);
            test_utils::assert_eq(min_stake, MIST_PER_SUI);

            let total_staked = native_pool::get_total_staked(&native_pool);
            test_utils::assert_eq(total_staked, 0);

            let total_active_stake = native_pool::get_total_active_stake(&native_pool, ctx(&mut scenario));
            test_utils::assert_eq(total_active_stake, 0);

            let total_rewards = native_pool::get_total_rewards(&native_pool);
            test_utils::assert_eq(total_rewards, 0);

            let unstake_fee_threshold = native_pool::get_unstake_fee_threshold(&native_pool);
            test_utils::assert_eq(unstake_fee_threshold, 1000);

            let unstake_fee = native_pool::calculate_unstake_fee(&native_pool, 10000);
            test_utils::assert_eq(unstake_fee, 5);

            test_scenario::return_shared(native_pool);
        };

        // Stake SUI and receive cert
        next_tx(&mut scenario, SENDER);
        {
            let sui = coin::mint_for_testing<SUI>(MIST_PER_SUI, ctx(&mut scenario)); // 1 SUI
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            let cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx(&mut scenario));
            cert::burn_coin_for_testing(&mut metadata, cert);

            let pending = native_pool::get_pending(&pool);
            test_utils::assert_eq(pending, 0);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun unstake() {
        let scenario = set_up_native_pool();

        // Stake SUI, epoch = 0
        next_tx(&mut scenario, SENDER);
        {
            let sui = coin::mint_for_testing<SUI>(MIST_PER_SUI * 100, ctx(&mut scenario)); // 100 SUI
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            let cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx(&mut scenario));
            coin::burn_for_testing(cert);

            let cert = coin::mint_for_testing(MIST_PER_SUI, ctx(&mut scenario));
            native_pool::mint_ticket(&mut pool, &mut metadata, cert, ctx(&mut scenario));

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        // advance epoch -> epoch = 1
        next_tx(&mut scenario, SENDER);
        {
            advance_epoch(&mut scenario);
        };

        // Stake SUI, epoch = 1
        next_tx(&mut scenario, SENDER);
        {
            let sui = coin::mint_for_testing<SUI>(MIST_PER_SUI * 2, ctx(&mut scenario)); // 1 SUI
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            let cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx(&mut scenario));
            coin::burn_for_testing(cert);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        // advance epoch -> epoch = 2
        next_tx(&mut scenario, SENDER);
        {
            let pool = test_scenario::take_shared<NativePool>(&scenario);

            let total_staked = native_pool::get_total_staked(&pool);
            test_utils::assert_eq(total_staked, MIST_PER_SUI * 102);
            let total_active_stake = native_pool::get_total_active_stake(&pool, ctx(&mut scenario));
            test_utils::assert_eq(total_active_stake, MIST_PER_SUI * 101);

            advance_epoch(&mut scenario);

            let total_staked = native_pool::get_total_staked(&pool);
            test_utils::assert_eq(total_staked, MIST_PER_SUI * 102);
            let total_active_stake = native_pool::get_total_active_stake(&pool, ctx(&mut scenario));
            test_utils::assert_eq(total_active_stake, MIST_PER_SUI * 102);

            test_scenario::return_shared(pool);
        };

        // unstake, epoch = 2
        next_tx(&mut scenario, SENDER);
        {
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            let ctx = ctx(&mut scenario);
            let cert = coin::mint_for_testing(MIST_PER_SUI, ctx);

            let ticket = native_pool::mint_ticket_non_entry(&mut pool, &mut metadata, cert, ctx);

            let sui = native_pool::burn_ticket_non_entry(&mut pool, &mut system_state, ticket, ctx);
            coin::burn_for_testing(sui);

            let total_staked = native_pool::get_total_staked(&pool);
            test_utils::assert_eq(total_staked, MIST_PER_SUI * 101);
            let total_active_stake = native_pool::get_total_active_stake(&pool, ctx);
            test_utils::assert_eq(total_active_stake, MIST_PER_SUI * 101);

            let ticket_supply = native_pool::get_ticket_supply(&pool);
            test_utils::assert_eq(ticket_supply, MIST_PER_SUI);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun mint_tickets_in_same_epoch() {
        let scenario = set_up_native_pool();

        // advance epoch -> epoch = 1
        next_tx(&mut scenario, SENDER);
        {
            advance_epoch(&mut scenario);
        };

        next_tx(&mut scenario, SENDER);
        {
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario); 
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);

            let ctx = ctx(&mut scenario);

            // stake 1
            let sui = coin::mint_for_testing<SUI>(MIST_PER_SUI, ctx);
            let cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx);
            coin::burn_for_testing(cert);

            // change_min_stake 100 000 000
            native_pool::change_min_stake(&mut pool, &owner_cap, 100_000_000);

            // stake 0.6
            sui = coin::mint_for_testing<SUI>(MIST_PER_SUI * 6 / 10, ctx);
            cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx);
            coin::burn_for_testing(cert);

            let total_staked = native_pool::get_total_staked(&pool);
            test_utils::assert_eq(total_staked, MIST_PER_SUI * 16 / 10);

            // stake 0.1
            sui = coin::mint_for_testing<SUI>(MIST_PER_SUI * 1 / 10, ctx);
            cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx);
            coin::burn_for_testing(cert);

            // stake 0.5
            sui = coin::mint_for_testing<SUI>(MIST_PER_SUI * 5 / 10, ctx);
            cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx);
            coin::burn_for_testing(cert);

            // stake 1.2
            sui = coin::mint_for_testing<SUI>(MIST_PER_SUI * 12 / 10, ctx);
            cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx);
            coin::burn_for_testing(cert);

            // stake 16
            sui = coin::mint_for_testing<SUI>(MIST_PER_SUI * 16, ctx);
            cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx);
            coin::burn_for_testing(cert);

            // stake 4
            sui = coin::mint_for_testing<SUI>(MIST_PER_SUI * 4, ctx);
            cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx);
            coin::burn_for_testing(cert);

            total_staked = native_pool::get_total_staked(&pool);
            test_utils::assert_eq(total_staked, MIST_PER_SUI * 234 / 10);

            let supply = cert::get_total_supply_value(&metadata);
            test_utils::assert_eq(supply, MIST_PER_SUI * 234 / 10);

            // unstake 2
            let cert = coin::mint_for_testing(MIST_PER_SUI * 2, ctx);
            native_pool::mint_ticket(&mut pool, &mut metadata, cert, ctx);

            total_staked = native_pool::get_total_staked(&pool);
            test_utils::assert_eq(total_staked, MIST_PER_SUI * 234 / 10);
            let total_active_stake = native_pool::get_total_active_stake(&pool, ctx);
            test_utils::assert_eq(total_active_stake, 0);

            let ticket_supply = native_pool::get_ticket_supply(&pool);
            test_utils::assert_eq(ticket_supply, MIST_PER_SUI * 2);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
            test_scenario::return_to_address(SENDER, owner_cap);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun rebalance() {
        let scenario = set_up_native_pool();

        // Stake SUI, epoch = 0
        next_tx(&mut scenario, SENDER);
        {
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            // epoch = 0

            let sui = coin::mint_for_testing<SUI>(MIST_PER_SUI * 50, ctx(&mut scenario)); // 50 SUI
            let cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx(&mut scenario));
            coin::burn_for_testing(cert);

            test_scenario::return_shared(system_state);
            advance_epoch(&mut scenario);
            system_state = test_scenario::take_shared<SuiSystemState>(&scenario);
            // epoch = 1

            let sui = coin::mint_for_testing<SUI>(MIST_PER_SUI * 100, ctx(&mut scenario)); // 100 SUI
            let cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx(&mut scenario));
            coin::burn_for_testing(cert);

            test_scenario::return_shared(system_state);
            advance_epoch(&mut scenario);
            system_state = test_scenario::take_shared<SuiSystemState>(&scenario);
            // epoch = 2

            let sui = coin::mint_for_testing<SUI>(MIST_PER_SUI * 150, ctx(&mut scenario)); // 150 SUI
            let cert = native_pool::stake_non_entry(&mut pool, &mut metadata, &mut system_state, sui, ctx(&mut scenario));
            coin::burn_for_testing(cert);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        next_tx(&mut scenario, SENDER);
        {
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            native_pool::test_update_and_sort(&mut pool, vector[@0xAB1, @0xAB2], vector[0, 2]);
            test_scenario::return_shared(pool);
        };

        // rebalance
        next_tx(&mut scenario, SENDER);
        {
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let system_state = test_scenario::take_shared<SuiSystemState>(&scenario);

            let ctx = ctx(&mut scenario);

            let staked_to_ab1 = native_pool::get_total_stake_of(&pool, @0xAB1);
            test_utils::assert_eq(staked_to_ab1, MIST_PER_SUI * 300);
            let staked_to_ab2 = native_pool::get_total_stake_of(&pool, @0xAB2);
            test_utils::assert_eq(staked_to_ab2, 0);

            native_pool::rebalance(&mut pool, &mut system_state, ctx);

            // total staked not changed
            let total_staked = native_pool::get_total_staked(&pool);
            test_utils::assert_eq(total_staked, MIST_PER_SUI * 300);

            // active changed
            let total_active_stake = native_pool::get_total_active_stake(&pool, ctx);
            test_utils::assert_eq(total_active_stake, 0);

            staked_to_ab1 = native_pool::get_total_stake_of(&pool, @0xAB1);
            test_utils::assert_eq(staked_to_ab1, MIST_PER_SUI * 150);
            staked_to_ab2 = native_pool::get_total_stake_of(&pool, @0xAB2);
            test_utils::assert_eq(staked_to_ab2, MIST_PER_SUI * 150);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(metadata);
            test_scenario::return_shared(system_state);
        };

        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    fun change_min_stake_zero() {
        let scenario = set_up_native_pool();

        next_tx(&mut scenario, SENDER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let pool = test_scenario::take_shared<NativePool>(&scenario);

            native_pool::change_min_stake(&mut pool, &owner_cap, 0);

            test_scenario::return_to_address<OwnerCap>(SENDER, owner_cap);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun change_min_unstake_success() {
        let scenario = set_up_native_pool();

        next_tx(&mut scenario, SENDER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let pool = test_scenario::take_shared<NativePool>(&scenario);

            native_pool::change_min_stake(&mut pool, &owner_cap, 2002);
            let min_stake = native_pool::get_min_stake(&pool);
            test_utils::assert_eq(min_stake, 2002);

            test_scenario::return_to_address<OwnerCap>(SENDER, owner_cap);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun ratio_calculated() {
        let scenario = set_up_native_pool();

        // initial ratio
        next_tx(&mut scenario, SENDER);
        {
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let pool = test_scenario::take_shared<NativePool>(&scenario);

            let ratio = native_pool::get_ratio(&pool, &metadata);
            test_utils::assert_eq(ratio, INITIAL_RATIO);

            let shares = native_pool::to_shares(&pool, &metadata, MIST_PER_SUI);
            // value the same
            test_utils::assert_eq(shares, MIST_PER_SUI);

            let amount = native_pool::from_shares(&pool, &metadata, MIST_PER_SUI);
            test_utils::assert_eq(amount, MIST_PER_SUI);

            test_scenario::return_shared<Metadata<CERT>>(metadata);
            test_scenario::return_shared(pool);
        };

        // make x2 profit for pool
        next_tx(&mut scenario, SENDER);
        {
            // TODO: add test with zero tvl and supply when ratio is impossible

            let operator_cap = test_scenario::take_from_sender<OperatorCap>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let pool = test_scenario::take_shared<NativePool>(&scenario);
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);


            // prepare clock
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 43_200_001); // set eligible time

            // make 1:1 proprtion
            let cert_coin = cert::mint_coin_for_testing(&mut metadata, MIST_PER_SUI, ctx(&mut scenario));
            coin::burn_for_testing(cert_coin);
            let staked = native_pool::add_total_staked_for_testing(&mut pool, MIST_PER_SUI, ctx(&mut scenario));
            test_utils::assert_eq(staked, MIST_PER_SUI);

            // set max threshold
            native_pool::update_rewards_threshold(&mut pool, &owner_cap, 100_00); // 100.00%

            // x2 profit
            native_pool::update_rewards(&mut pool, &clock, MIST_PER_SUI * 5 / 10, &operator_cap);

            test_utils::assert_eq(native_pool::get_total_rewards(&pool), 450_000_000); // 1 SUI * 0.1
            test_utils::assert_eq(native_pool::get_total_staked(&pool), MIST_PER_SUI);

            test_scenario::return_shared<Metadata<CERT>>(metadata);
            test_scenario::return_to_address<OperatorCap>(SENDER, operator_cap);
            test_scenario::return_shared(pool);
            test_scenario::return_to_address(SENDER, owner_cap);
            clock::destroy_for_testing(clock);
        };

        next_tx(&mut scenario, SENDER);
        {
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let pool = test_scenario::take_shared<NativePool>(&scenario);

            let ratio = native_pool::get_ratio(&pool, &metadata);
            test_utils::assert_eq(ratio, 689_655_172_413_793_103);

            let shares = native_pool::to_shares(&pool, &metadata, MIST_PER_SUI);
            test_utils::assert_eq(shares, 689_655_172);

            let amount = native_pool::from_shares(&pool, &metadata, MIST_PER_SUI);
            test_utils::assert_eq(amount, 1_450_000_000);

            test_scenario::return_shared<Metadata<CERT>>(metadata);
            test_scenario::return_shared(pool);
        };

        // update ratio
        next_tx(&mut scenario, SENDER);
        {
            let operator_cap = test_scenario::take_from_sender<OperatorCap>(&scenario);
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let pool = test_scenario::take_shared<NativePool>(&scenario);

            // prepare clock
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 43200001 * 2); // set eligible time


            // TODO: add test when threshold greater than max
            native_pool::update_rewards(&mut pool, &clock, MIST_PER_SUI, &operator_cap);

            test_scenario::return_shared<Metadata<CERT>>(metadata);
            test_scenario::return_to_address<OperatorCap>(SENDER, operator_cap);
            test_scenario::return_shared(pool);
            clock::destroy_for_testing(clock);
        };

        next_tx(&mut scenario, SENDER);
        {
            let metadata = test_scenario::take_shared<Metadata<CERT>>(&scenario);
            let pool = test_scenario::take_shared<NativePool>(&scenario);

            let ratio = native_pool::get_ratio(&pool, &metadata);
            test_utils::assert_eq(ratio, 526_315_789_473_684_210);

            let shares = native_pool::to_shares(&pool, &metadata, MIST_PER_SUI);
            test_utils::assert_eq(shares, 526_315_789);

            let amount = native_pool::from_shares(&pool, &metadata, MIST_PER_SUI);
            test_utils::assert_eq(amount, 1_900_000_000);

            test_scenario::return_shared<Metadata<CERT>>(metadata);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    fun update__rewards_threshold_gt_max() {
        let scenario = set_up_native_pool();

        next_tx(&mut scenario, SENDER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let pool = test_scenario::take_shared<NativePool>(&scenario);

            native_pool::update_rewards_threshold(&mut pool, &owner_cap, 10_001);

            test_scenario::return_to_address(SENDER, owner_cap);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    fun update_rewards_threshold_to_zero() {
        let scenario = set_up_native_pool();

        next_tx(&mut scenario, SENDER);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            let pool = test_scenario::take_shared<NativePool>(&scenario);

            native_pool::update_rewards_threshold(&mut pool, &owner_cap, 0);

            test_scenario::return_to_address(SENDER, owner_cap);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    fun operator_update_rewards_without_delay_failed() {
        let scenario = set_up_native_pool();

        next_tx(&mut scenario, SENDER);
        {
            let operator_cap = test_scenario::take_from_sender<OperatorCap>(&scenario);
            let pool = test_scenario::take_shared<NativePool>(&scenario);

            // prepare clock
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            native_pool::update_rewards(&mut pool, &clock, MIST_PER_SUI, &operator_cap);

            test_scenario::return_to_address<OperatorCap>(SENDER, operator_cap);
            test_scenario::return_shared(pool);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    fun operator_update_ratio_with_bad_threshold() {
        let scenario = set_up_native_pool();

        next_tx(&mut scenario, SENDER);
        {
            let operator_cap = test_scenario::take_from_sender<OperatorCap>(&scenario);
            let pool = test_scenario::take_shared<NativePool>(&scenario);

            // prepare clock
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 43200001 * 1); // set eligible time

            native_pool::update_rewards(&mut pool, &clock, MIST_PER_SUI, &operator_cap);
            clock::set_for_testing(&mut clock, 43200001 * 2); // set eligible time
            native_pool::update_rewards(&mut pool, &clock, MIST_PER_SUI, &operator_cap);

            test_scenario::return_to_address<OperatorCap>(SENDER, operator_cap);
            test_scenario::return_shared(pool);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
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
}