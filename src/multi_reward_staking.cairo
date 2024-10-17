#[starknet::contract]
mod MultiRewardStaking {
    use staking_multiple_reward_tokens::interfaces::imulti_reward_staking::IMultiRewardStaking;
    use staking_multiple_reward_tokens::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address, contract_address_const};
    use core::starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, 
        Map, StoragePathEntry,
        MutableVecTrait, Vec, VecTrait
    };
    use core::num::traits::Zero;
    const ONE_E18: u256 = 1000000000000000000_u256;

    #[storage]
    struct Storage {
        staking_token: ContractAddress,
        reward_data: Map<ContractAddress, Reward>,
        reward_tokens: Vec<ContractAddress>,
        user_staking_positions: Map<ContractAddress, Vec<StakingPosition>>,
        user_position_rewards: Map<(ContractAddress, u256, ContractAddress), u256>,
        user_reward_per_tokens: Map<(ContractAddress, u256, ContractAddress), u256>,
        total_stake: u256,
        owner: ContractAddress,
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct Reward {
        duration: u256,
        finish_at: u256,
        updated_at: u256,
        reward_rate: u256,
        reward_per_token_stored: u256
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct StakingPosition {
        balance: u256
    }

    impl MultiRewardStakingImpl of IMultiRewardStaking<ContractState> {
        fn is_reward_token_added(self: @ContractState) -> bool {

            false
        }

        fn add_reward(ref self: ContractState, rewards_token: ContractAddress, reward_duration: u256) {

        }

        fn set_reward_duration(ref self: ContractState, rewards_token: ContractAddress, duration: u256) {

        }

        fn set_reward_amount(ref self: ContractState, rewards_token: ContractAddress, amount: u256) {

        }

        fn stake(ref self: ContractState, amount: u256) {

        }

        fn withdraw_token(ref self: ContractState, amount: u256, position_index: u256) {

        }

        fn last_time_reward_applicable(self: @ContractState, rewards_token: ContractAddress) -> u256 {

            9
        }

        fn reward_per_token(self: @ContractState, rewards_token: ContractAddress) -> u256 {

            9
        }

        fn rewards_earned(self: @ContractState, account: ContractAddress, position_index: u256, rewards_token: ContractAddress) -> u256 {

            9
        }

        fn get_reward(ref self: ContractState, position_index: u256) {

        }

        fn user_next_position_index(self: @ContractState, account: ContractAddress) -> u256 {

            9
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn update_reward(ref self: ContractState, account: ContractAddress, position_index: u256) {

        }

        fn min(self: @ContractState, x: u256, y: u256) -> u256 {
            if x <= y {
                x
            } else {
                y
            }
        }

        fn zero_address(self: @ContractState) -> ContractAddress {
            contract_address_const::<0>()
        }
    }
}