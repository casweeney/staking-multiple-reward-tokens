#[starknet::contract]
pub mod MultiRewardStaking {
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
    pub struct Reward {
        duration: u256,
        finish_at: u256,
        updated_at: u256,
        reward_rate: u256,
        reward_per_token_stored: u256
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct StakingPosition {
        balance: u256
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, staking_token: ContractAddress) {
        self.owner.write(owner);
        self.staking_token.write(staking_token);
    }

    impl MultiRewardStakingImpl of IMultiRewardStaking<ContractState> {
        fn is_reward_token_added(self: @ContractState) -> bool {

            let mut balance_sum = 0;
            let mut greater_than_zero = false;

            for index in 0..self.reward_tokens.len() {
                let token_address = self.reward_tokens.at(index).read();

                balance_sum = balance_sum + IERC20Dispatcher {contract_address: token_address}.balance_of(get_contract_address());
            };

            if balance_sum > 0 {
                greater_than_zero = true;
            }

            greater_than_zero
        }

        fn add_reward(ref self: ContractState, rewards_token: ContractAddress, reward_duration: u256) {
            assert!(self.reward_data.entry(rewards_token).duration.read() == 0, "already added");
            assert!(reward_duration > 0, "duration can't be zero");

            self.reward_tokens.append().write(rewards_token);
            self.reward_data.entry(rewards_token).duration.write(reward_duration);
        }

        fn set_reward_duration(ref self: ContractState, rewards_token: ContractAddress, duration: u256) {
            let block_timestamp: u256 = get_block_timestamp().try_into().unwrap();
            assert!(block_timestamp > self.reward_data.entry(rewards_token).finish_at.read(), "reward period still active");
            assert!(duration > 0, "duration can't be zero");

            self.reward_data.entry(rewards_token).duration.write(duration);
        }

        fn set_reward_amount(ref self: ContractState, rewards_token: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            assert!(caller == self.owner.read(), "not authorized");

            let zero_address = self.zero_address();

            self.update_reward(zero_address, 0);

            assert!(self.reward_data.entry(rewards_token).duration.read() > 0, "reward duration = 0");

            let caller = get_caller_address();
            let this_contract = get_contract_address();

            let transfer = IERC20Dispatcher { contract_address: rewards_token }.transfer_from(caller, this_contract, amount);
            assert!(transfer, "transfer failed");

            let block_timestamp: u256 = get_block_timestamp().try_into().unwrap();
            if block_timestamp > self.reward_data.entry(rewards_token).finish_at.read() {
                self.reward_data.entry(rewards_token).reward_rate.write(amount / self.reward_data.entry(rewards_token).duration.read());
            } else {
                let block_timestamp: u256 = get_block_timestamp().try_into().unwrap();

                let remaining_rewards = self.reward_data.entry(rewards_token).reward_rate.read() * (self.reward_data.entry(rewards_token).finish_at.read() - block_timestamp);

                self.reward_data.entry(rewards_token).reward_rate.write((remaining_rewards + amount) / self.reward_data.entry(rewards_token).duration.read())
            }

            assert!(self.reward_data.entry(rewards_token).reward_rate.read() > 0, "reward rate = 0");
            assert!(self.reward_data.entry(rewards_token).reward_rate.read() * self.reward_data.entry(rewards_token).duration.read() <= IERC20Dispatcher{contract_address: rewards_token}.balance_of(get_contract_address()), "insufficient reward token");

            let block_timestamp: u256 = get_block_timestamp().try_into().unwrap();
            self.reward_data.entry(rewards_token).finish_at.write(block_timestamp + self.reward_data.entry(rewards_token).duration.read());
            self.reward_data.entry(rewards_token).updated_at.write(block_timestamp)
        }

        fn stake(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            let this_address = get_contract_address();
            let next_user_position = self.user_next_position_index(caller);
            self.update_reward(caller, next_user_position);

            assert!(amount > 0, "can't stake zero amount");

            let transfer = IERC20Dispatcher { contract_address: self.staking_token.read() }.transfer_from(caller, this_address, amount);
            assert!(transfer, "transfer failed");

            let staking_position = StakingPosition {
                balance: amount
            };

            self.user_staking_positions.entry(caller).append().write(staking_position);
            self.total_stake.write(self.total_stake.read() + amount);
        }

        fn withdraw_token(ref self: ContractState, amount: u256, position_index: u256) {
            let caller = get_caller_address();

            self.update_reward(caller, position_index);

            assert!(position_index <= self.user_staking_positions.entry(caller).len().try_into().unwrap() - 1, "invalid position index");
            assert!(amount > 0, "can't withdraw zero amount");

            let prev_balance = self.user_staking_positions.entry(caller).at(position_index.try_into().unwrap()).balance.read();
            self.user_staking_positions.entry(caller).at(position_index.try_into().unwrap()).balance.write(prev_balance - amount);

            let prev_total_stake = self.total_stake.read();
            self.total_stake.write(prev_total_stake - amount);

            IERC20Dispatcher { contract_address: self.staking_token.read() }.transfer(caller, amount);
        }

        fn last_time_reward_applicable(self: @ContractState, rewards_token: ContractAddress) -> u256 {
            let block_timestamp: u256 = get_block_timestamp().try_into().unwrap();

            self.min(block_timestamp, self.reward_data.entry(rewards_token).finish_at.read())
        }

        fn reward_per_token(self: @ContractState, rewards_token: ContractAddress) -> u256 {
            if self.total_stake.read() == 0 {
                self.reward_data.entry(rewards_token).reward_per_token_stored.read()
            } else {
                self.reward_data.entry(rewards_token).reward_per_token_stored.read() + (self.reward_data.entry(rewards_token).reward_rate.read() * (self.last_time_reward_applicable(rewards_token) - self.reward_data.entry(rewards_token).updated_at.read()) * ONE_E18) / self.total_stake.read()
            }
        }

        fn rewards_earned(self: @ContractState, account: ContractAddress, position_index: u256, rewards_token: ContractAddress) -> u256 {
            if self.user_staking_positions.entry(account).len() == 0 {
                return 0;
            }

            if position_index <= self.user_staking_positions.entry(account).len().try_into().unwrap() - 1 {
                ((self.user_staking_positions.entry(account).at(position_index.try_into().unwrap()).balance.read() * (self.reward_per_token(rewards_token) - self.user_reward_per_tokens.entry((account, position_index, rewards_token)).read())) / ONE_E18) + self.user_position_rewards.entry((account, position_index, rewards_token)).read()
            } else {
                return 0;
            }
        }

        fn get_reward(ref self: ContractState, position_index: u256) {
            let caller = get_caller_address();

            self.update_reward(caller, position_index);

            assert!(position_index <= self.user_staking_positions.entry(caller).len().try_into().unwrap() - 1, "invalid position index");

            for i in 0..self.reward_tokens.len() {
                let reward_token = self.reward_tokens.at(i).read();
                let reward = self.user_position_rewards.entry((caller, position_index, reward_token)).read();

                if reward > 0 {
                    self.user_position_rewards.entry((caller, position_index, reward_token)).write(0);
                    IERC20Dispatcher { contract_address: reward_token }.transfer(caller, reward);
                }
            }
        }

        fn user_next_position_index(self: @ContractState, account: ContractAddress) -> u256 {
            self.user_staking_positions.entry(account).len().try_into().unwrap()
        }

        fn staking_token(self: @ContractState) -> ContractAddress {
            self.staking_token.read()
        }

        fn reward_data(self: @ContractState, reward_token: ContractAddress) -> Reward {
            self.reward_data.entry(reward_token).read()
        }

        fn total_stake(self: @ContractState) -> u256 {
            self.total_stake.read()
        }

        fn owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn update_reward(ref self: ContractState, account: ContractAddress, position_index: u256) {
            for i in 0..self.reward_tokens.len() {
                let token = self.reward_tokens.at(i).read();

                self.reward_data.entry(token).reward_per_token_stored.write(self.reward_per_token(token));
                self.reward_data.entry(token).updated_at.write(self.last_time_reward_applicable(token));

                if account.is_non_zero() {
                    self.user_position_rewards.entry((account, position_index, token)).write(self.rewards_earned(account, position_index, token));
                    self.user_reward_per_tokens.entry((account, position_index, token)).write(self.reward_data.entry(token).reward_per_token_stored.read());
                }
            }
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