// SPDX-License-Identifier: MIT

#[test_only]
module liquid_staking::ownership_tests {

    use liquid_staking::ownership::{Self, OperatorCap, OwnerCap};
    use sui::test_scenario::{Self, next_tx, ctx};

    #[test]
    fun transfer_ownsership() {
        // Initialize a mock sender address
        let addr1 = @0xA;
        let addr2 = @0xCAFE;

        // Begins a multi transaction scenario with addr1 as the sender
        let scenario = test_scenario::begin(addr1);
        
        {
            ownership::test_init(ctx(&mut scenario));
        };

        // transfer operator cap
        next_tx(&mut scenario, addr1);
        {
            let operator_cap = test_scenario::take_from_sender<OperatorCap>(&scenario);
            ownership::transfer_operator(operator_cap, addr2, ctx(&mut scenario));
        };

        // transfer owner cap
        next_tx(&mut scenario, addr1);
        {
            let owner_cap = test_scenario::take_from_sender<OwnerCap>(&scenario);
            ownership::transfer_owner(owner_cap, addr2, ctx(&mut scenario));
        };

        // Cleans up the scenario object
        test_scenario::end(scenario);
    }

}