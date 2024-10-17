use starknet::ContractAddress;
use staking_multiple_reward_tokens::multi_reward_staking::MultiRewardStaking::{Reward, StakingPosition};

#[starknet::interface]
pub trait IMultiRewardStaking<TContractState> {
    fn is_reward_token_added(self: @TContractState) -> bool;
    fn add_reward(ref self: TContractState, rewards_token: ContractAddress, reward_duration: u256);
    fn set_reward_duration(ref self: TContractState, rewards_token: ContractAddress, duration: u256);
    fn set_reward_amount(ref self: TContractState, rewards_token: ContractAddress, amount: u256);
    fn stake(ref self: TContractState, amount: u256);
    fn withdraw_token(ref self: TContractState, amount: u256, position_index: u256);
    fn last_time_reward_applicable(self: @TContractState, rewards_token: ContractAddress) -> u256;
    fn reward_per_token(self: @TContractState, rewards_token: ContractAddress) -> u256;
    fn rewards_earned(self: @TContractState, account: ContractAddress, position_index: u256, rewards_token: ContractAddress) -> u256;
    fn get_reward(ref self: TContractState, position_index: u256);
    fn user_next_position_index(self: @TContractState, account: ContractAddress) -> u256;

    fn staking_token(self: @TContractState) -> ContractAddress;
    fn reward_data(self: @TContractState, reward_token: ContractAddress) -> Reward;
    fn total_stake(self: @TContractState) -> u256;
    fn owner(self: @TContractState) -> ContractAddress;
}