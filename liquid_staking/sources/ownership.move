module liquid_staking::ownership {
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::event;

    struct OwnerCap has key {
        id: UID,
    }

    struct OperatorCap has key {
        id: UID,
    }

    fun init(ctx: &mut TxContext) {
        // initialize admin cap and transfer to publisher
        transfer::transfer(OwnerCap {
            id: object::new(ctx),
        }, tx_context::sender(ctx));

        // initialize operator cap and transfer to publisher
        transfer::transfer(OperatorCap {
            id: object::new(ctx),
        }, tx_context::sender(ctx));
    }

    /// OwnerCapTransferred event
    struct OwnerCapTransferred has copy, drop {
        from: address,
        to: address
    }

    public entry fun transfer_owner(cap: OwnerCap, to: address, ctx: &mut TxContext) {
        transfer::transfer(cap, to);
        event::emit(OwnerCapTransferred {
            from: sui::tx_context::sender(ctx),
            to,
        });
    }

    /// OperatorCapTransferred event
    struct OperatorCapTransferred has copy, drop {
        from: address,
        to: address
    }

    public entry fun transfer_operator(cap: OperatorCap, to: address, ctx: &mut TxContext) {
        transfer::transfer(cap, to);
        event::emit(OperatorCapTransferred {
            from: sui::tx_context::sender(ctx),
            to,
        });
    }
    
    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        init(ctx)
    }
}