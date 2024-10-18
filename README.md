# Staking multiple reward tokens

This is a modified Synthetix staking implementation that uses more than one ERC20 token as reward tokens.

## How it works
Using similar staking mechanism as the Synthetix staking reward contract, the multiple reward tokens allows that users can set more than one ERC20 token as reward which means, when a user stakes, they can get more than one reward tokens as their reward for staking.<br />

This contract using a staking position that separates each user's stake. When a user stakes multiple times e.g 3 times, all 3 stakes are independent, the staking amount is not cumulative.
