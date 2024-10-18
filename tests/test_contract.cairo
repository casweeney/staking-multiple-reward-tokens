use starknet::{ContractAddress, get_block_timestamp};

use snforge_std::{
    declare, ContractClassTrait,
    start_cheat_caller_address, stop_cheat_caller_address,
    start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global
};

use staking_multiple_reward_tokens::interfaces::imulti_reward_staking::{IMultiRewardStakingDispatcher, IMultiRewardStakingDispatcherTrait};
use staking_multiple_reward_tokens::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};

const ONE_E18: u256 = 1000000000000000000_u256;

fn deploy_token_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

fn deploy_staking_contract(name: ByteArray, staking_token: ContractAddress) -> ContractAddress {
    let owner: ContractAddress = starknet::contract_address_const::<0x123626789>();

    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    constructor_calldata.append(staking_token.into());

    let contract = declare(name).unwrap();
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    contract_address
}

#[test]
fn test_token_mint() {
    let staking_token_address = deploy_token_contract("StakingToken");
    let reward_token1_address = deploy_token_contract("RewardToken1");
    let reward_token2_address = deploy_token_contract("RewardToken2");

    let staking_token = IERC20Dispatcher { contract_address: staking_token_address };
    let reward_token1 = IERC20Dispatcher { contract_address: reward_token1_address };
    let reward_token2 = IERC20Dispatcher { contract_address: reward_token2_address };

    let receiver: ContractAddress = starknet::contract_address_const::<0x123626789>();

    let mint_amount: u256 = 10000_u256 * ONE_E18;
    staking_token.mint(receiver, mint_amount);
    reward_token1.mint(receiver, mint_amount);
    reward_token2.mint(receiver, mint_amount);

    assert!(staking_token.balance_of(receiver) == mint_amount, "wrong staking token balance");
    assert!(reward_token1.balance_of(receiver) == mint_amount, "wrong reward token1 balance");
    assert!(reward_token2.balance_of(receiver) == mint_amount, "wrong reward token2 balance");


    assert!(staking_token.balance_of(receiver) > 0, "balance failed to increase");
    assert!(reward_token1.balance_of(receiver) > 0, "token1 balance didn't increase");
    assert!(reward_token2.balance_of(receiver) > 0, "token2 balance didn't increase");
}

#[test]
fn test_staking_constructor() {
    let staking_token_address = deploy_token_contract("StakingToken");
    let staking_contract_address = deploy_staking_contract("MultiRewardStaking", staking_token_address);

    let staking_contract = IMultiRewardStakingDispatcher { contract_address: staking_contract_address };

    let owner: ContractAddress = starknet::contract_address_const::<0x123626789>();

    assert!(staking_contract.owner() == owner, "wrong owner");
    assert!(staking_contract.staking_token() == staking_token_address, "wrong staking token address");
}

#[test]
#[should_panic(expected: ("not authorized",))]
fn test_add_reward_token_should_panic() {
    let staking_token_address = deploy_token_contract("StakingToken");
    let staking_contract_address = deploy_staking_contract("MultiRewardStaking", staking_token_address);

    let reward_token1_address = deploy_token_contract("RewardToken1");

    let staking_contract = IMultiRewardStakingDispatcher { contract_address: staking_contract_address };

    staking_contract.add_reward_token(reward_token1_address);
}

#[test]
fn test_add_reward_token() {
    let staking_token_address = deploy_token_contract("StakingToken");
    let staking_contract_address = deploy_staking_contract("MultiRewardStaking", staking_token_address);

    let reward_token1_address = deploy_token_contract("RewardToken1");
    let reward_token2_address = deploy_token_contract("RewardToken2");

    let staking_contract = IMultiRewardStakingDispatcher { contract_address: staking_contract_address };
    let owner: ContractAddress = starknet::contract_address_const::<0x123626789>();

    start_cheat_caller_address(staking_contract_address, owner);
    staking_contract.add_reward_token(reward_token1_address);
    staking_contract.add_reward_token(reward_token2_address);
    stop_cheat_caller_address(staking_contract_address);

    
    assert!(staking_contract.reward_tokens_count() == 2, "wrong token count");
    assert!(staking_contract.reward_data(reward_token1_address).duration == 0, "wrong token1 duration");
    assert!(staking_contract.reward_data(reward_token2_address).duration == 0, "wrong token2 duration");
}

#[test]
fn test_set_reward_duration() {
    let staking_token_address = deploy_token_contract("StakingToken");
    let staking_contract_address = deploy_staking_contract("MultiRewardStaking", staking_token_address);

    let reward_token1_address = deploy_token_contract("RewardToken1");
    let reward_token2_address = deploy_token_contract("RewardToken2");

    let staking_contract = IMultiRewardStakingDispatcher { contract_address: staking_contract_address };
    let owner: ContractAddress = starknet::contract_address_const::<0x123626789>();
    let duration: u256 = 1800_u256;

    start_cheat_block_timestamp_global(1698152400);

    start_cheat_caller_address(staking_contract_address, owner);
    staking_contract.add_reward_token(reward_token1_address);
    staking_contract.add_reward_token(reward_token2_address);

    staking_contract.set_reward_duration(reward_token1_address, duration);
    staking_contract.set_reward_duration(reward_token2_address, duration);
    stop_cheat_caller_address(staking_contract_address);

    assert!(staking_contract.reward_data(reward_token1_address).duration == duration, "wrong token1 duration");
    assert!(staking_contract.reward_data(reward_token2_address).duration == duration, "wrong token2 duration");

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_set_reward_amount() {
    let staking_token_address = deploy_token_contract("StakingToken");
    let staking_contract_address = deploy_staking_contract("MultiRewardStaking", staking_token_address);
    let owner: ContractAddress = starknet::contract_address_const::<0x123626789>();

    let reward_token1_address = deploy_token_contract("RewardToken1");
    let reward_token2_address = deploy_token_contract("RewardToken2");

    let reward_token1 = IERC20Dispatcher { contract_address: reward_token1_address };
    let reward_token2 = IERC20Dispatcher { contract_address: reward_token2_address };

    let mint_amount: u256 = 10000_u256 * ONE_E18;

    reward_token1.mint(owner, mint_amount);
    reward_token2.mint(owner, mint_amount);

    // Approve staking contract to spend token1
    start_cheat_caller_address(reward_token1_address, owner);
    reward_token1.approve(staking_contract_address, mint_amount);
    stop_cheat_caller_address(reward_token1_address);

    // Approve staking contract to spend token2
    start_cheat_caller_address(reward_token2_address, owner);
    reward_token2.approve(staking_contract_address, mint_amount);
    stop_cheat_caller_address(reward_token2_address);


    let staking_contract = IMultiRewardStakingDispatcher { contract_address: staking_contract_address };
    let duration: u256 = 1800_u256;

    start_cheat_block_timestamp_global(1698152400);

    let block_timestamp:u256 = get_block_timestamp().try_into().unwrap();

    start_cheat_caller_address(staking_contract_address, owner);
    staking_contract.add_reward_token(reward_token1_address);
    staking_contract.add_reward_token(reward_token2_address);

    staking_contract.set_reward_duration(reward_token1_address, duration);
    staking_contract.set_reward_duration(reward_token2_address, duration);

    staking_contract.set_reward_amount(reward_token1_address, mint_amount);
    staking_contract.set_reward_amount(reward_token2_address, mint_amount);
    stop_cheat_caller_address(staking_contract_address);

    assert!(reward_token1.balance_of(owner) == 0, "token1 tranfetr failed");
    assert!(reward_token2.balance_of(owner) == 0, "token1 tranfetr failed");
    assert!(reward_token1.balance_of(staking_contract_address) == mint_amount, "token1 balance didn't increase");
    assert!(reward_token2.balance_of(staking_contract_address) == mint_amount, "token2 balance didn't increase");

    assert!(staking_contract.reward_data(reward_token1_address).finish_at == block_timestamp + duration, "finish_at failed to update");
    assert!(staking_contract.reward_data(reward_token1_address).updated_at == block_timestamp, "finish_at failed to update");

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_stake() {
    let staking_token_address = deploy_token_contract("StakingToken");
    let staking_contract_address = deploy_staking_contract("MultiRewardStaking", staking_token_address);
    let owner: ContractAddress = starknet::contract_address_const::<0x123626789>();

    let reward_token1_address = deploy_token_contract("RewardToken1");
    let reward_token2_address = deploy_token_contract("RewardToken2");

    let reward_token1 = IERC20Dispatcher { contract_address: reward_token1_address };
    let reward_token2 = IERC20Dispatcher { contract_address: reward_token2_address };
    let staking_token = IERC20Dispatcher { contract_address: staking_token_address };

    let mint_amount: u256 = 10000_u256 * ONE_E18;

    reward_token1.mint(owner, mint_amount);
    reward_token2.mint(owner, mint_amount);
    staking_token.mint(owner, mint_amount);

    // Approve staking contract to spend reward token1
    start_cheat_caller_address(reward_token1_address, owner);
    reward_token1.approve(staking_contract_address, mint_amount);
    stop_cheat_caller_address(reward_token1_address);

    // Approve staking contract to spend reward token2
    start_cheat_caller_address(reward_token2_address, owner);
    reward_token2.approve(staking_contract_address, mint_amount);
    stop_cheat_caller_address(reward_token2_address);

    // Approve staking contract to spend staking token
    start_cheat_caller_address(staking_token_address, owner);
    staking_token.approve(staking_contract_address, mint_amount);
    stop_cheat_caller_address(staking_token_address);


    let staking_contract = IMultiRewardStakingDispatcher { contract_address: staking_contract_address };
    let duration: u256 = 1800_u256;
    let stake_amount: u256 = 100_u256 * ONE_E18;

    start_cheat_block_timestamp_global(1698152400);

    start_cheat_caller_address(staking_contract_address, owner);
    staking_contract.add_reward_token(reward_token1_address);
    staking_contract.add_reward_token(reward_token2_address);

    staking_contract.set_reward_duration(reward_token1_address, duration);
    staking_contract.set_reward_duration(reward_token2_address, duration);

    staking_contract.set_reward_amount(reward_token1_address, mint_amount);
    staking_contract.set_reward_amount(reward_token2_address, mint_amount);
    staking_contract.stake(stake_amount);
    stop_cheat_caller_address(staking_contract_address);

    assert!(staking_contract.total_stake() == stake_amount, "stake failed");
    assert!(staking_token.balance_of(staking_contract_address) == stake_amount, "stake didn't work");
    assert!(staking_token.balance_of(owner) == mint_amount - stake_amount, "balance decrease failed");

    stop_cheat_block_timestamp_global();
}

#[test]
fn test_earned() {
    let staking_token_address = deploy_token_contract("StakingToken");
    let staking_contract_address = deploy_staking_contract("MultiRewardStaking", staking_token_address);
    let owner: ContractAddress = starknet::contract_address_const::<0x123626789>();

    let reward_token1_address = deploy_token_contract("RewardToken1");
    let reward_token2_address = deploy_token_contract("RewardToken2");

    let reward_token1 = IERC20Dispatcher { contract_address: reward_token1_address };
    let reward_token2 = IERC20Dispatcher { contract_address: reward_token2_address };
    let staking_token = IERC20Dispatcher { contract_address: staking_token_address };

    let mint_amount: u256 = 10000_u256 * ONE_E18;

    reward_token1.mint(owner, mint_amount);
    reward_token2.mint(owner, mint_amount);
    staking_token.mint(owner, mint_amount);

    // Approve staking contract to spend reward token1
    start_cheat_caller_address(reward_token1_address, owner);
    reward_token1.approve(staking_contract_address, mint_amount);
    stop_cheat_caller_address(reward_token1_address);

    // Approve staking contract to spend reward token2
    start_cheat_caller_address(reward_token2_address, owner);
    reward_token2.approve(staking_contract_address, mint_amount);
    stop_cheat_caller_address(reward_token2_address);

    // Approve staking contract to spend staking token
    start_cheat_caller_address(staking_token_address, owner);
    staking_token.approve(staking_contract_address, mint_amount);
    stop_cheat_caller_address(staking_token_address);


    let staking_contract = IMultiRewardStakingDispatcher { contract_address: staking_contract_address };
    let duration: u256 = 1800_u256;
    let stake_amount: u256 = 100_u256 * ONE_E18;

    start_cheat_block_timestamp_global(1698152400);

    start_cheat_caller_address(staking_contract_address, owner);
    staking_contract.add_reward_token(reward_token1_address);
    staking_contract.add_reward_token(reward_token2_address);

    staking_contract.set_reward_duration(reward_token1_address, duration);
    staking_contract.set_reward_duration(reward_token2_address, duration);

    staking_contract.set_reward_amount(reward_token1_address, mint_amount);
    staking_contract.set_reward_amount(reward_token2_address, mint_amount);
    staking_contract.stake(stake_amount);
    stop_cheat_caller_address(staking_contract_address);
    stop_cheat_block_timestamp_global();

    // Using a 10mins increased block_timestamp to stake again
    start_cheat_block_timestamp_global(1698153000);
    start_cheat_caller_address(staking_contract_address, owner);
    staking_contract.stake(stake_amount);
    stop_cheat_caller_address(staking_contract_address);

    assert!(staking_contract.total_stake() == stake_amount + stake_amount, "stake failed");
    assert!(staking_token.balance_of(staking_contract_address) == stake_amount + stake_amount, "stake didn't work");

    // testing user earnings
    assert!(staking_contract.rewards_earned(owner, 0, reward_token1_address) > 0, "earnings didn't increase");
    assert!(staking_contract.rewards_earned(owner, 0, reward_token2_address) > 0, "earnings didn't increase");

    stop_cheat_block_timestamp_global();
}