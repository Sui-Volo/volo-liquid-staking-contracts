// SPDX-License-Identifier: MIT

#[test_only]
module liquid_staking::math_tests {

    use liquid_staking::math;
    use sui::test_scenario::{Self, next_tx};
    use sui::test_utils;

    const MAX_U64: u64 = 18_446_744_073_709_551_615;
    const RATIO_MAX: u256 = 1_000_000_000_000_000_000; // 1e18

    #[test]
    fun mul_div() {
        let addr = @0xA;
        let scenario = test_scenario::begin(addr);

        next_tx(&mut scenario, addr);
        {
            let res = math::mul_div(1, 2, 3);
            test_utils::assert_eq(res, 0);
        };

        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    fun overflow() {
        let addr = @0xA;
        let scenario = test_scenario::begin(addr);

        next_tx(&mut scenario, addr);
        {
            math::mul_div(MAX_U64, MAX_U64, 1)
        };

        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    fun zero_div() {
        let addr = @0xA;
        let scenario = test_scenario::begin(addr);

        next_tx(&mut scenario, addr);
        {
            math::mul_div(1, 2, 0);
        };

        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    fun ratio_overflow() {
        let addr = @0xA;
        let scenario = test_scenario::begin(addr);

        next_tx(&mut scenario, addr);
        {
            math::ratio(1_000_000, 1_000);
        };

        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    fun to_shares_overflow() {
        let addr = @0xA;
        let scenario = test_scenario::begin(addr);

        next_tx(&mut scenario, addr);
        {
            math::to_shares(RATIO_MAX * 1_000, MAX_U64);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun to_shares_zero_round() {
        let addr = @0xA;
        let scenario = test_scenario::begin(addr);

        next_tx(&mut scenario, addr);
        {
            let res = math::to_shares(1_000, 1);
            test_utils::assert_eq(res, 1);
        };

        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    fun from_shares_overflow() {
        let addr = @0xA;
        let scenario = test_scenario::begin(addr);

        next_tx(&mut scenario, addr);
        {
            math::from_shares(1, MAX_U64);
        };

        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    fun from_shares_zero_ratio() {
        let addr = @0xA;
        let scenario = test_scenario::begin(addr);

        next_tx(&mut scenario, addr);
        {
            math::from_shares(0, 1);
        };

        test_scenario::end(scenario);
    }

}