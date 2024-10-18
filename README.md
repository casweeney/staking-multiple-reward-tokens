# Staking multiple reward tokens

This is a modified Synthetix staking implementation that uses more than one ERC20 token as reward tokens.

## How it works
Using similar staking mechanism as the Synthetix staking reward contract, the multiple reward tokens allows that users can set more than one ERC20 token as reward which means, when a user stakes, they can get more than one reward tokens as their reward for staking.<br />

This contract using a staking position that separates each user's stake. When a user stakes multiple times e.g 3 times, all 3 stakes are independent, the staking amount is not cumulative.

## Testing
Test cases were covered using unit and feature testing. We also did onchain interaction to test functions using https://sepolia.voyager.online with the following deployed contract addresses:


See interactions: https://sepolia.voyager.online/contract/0x0204699f98282c34ea7147290dae81c5cc702f3795a961ee62f4afe7f48be276


### Deployed addresses on Starknet Sepolia:
<b>Staking token contract:</b> 0x4a11dd45a62aeca462aeeca9d5168dc8cd11298db14dbdbb105505cd6631924 <br>

<b>Reward token1 contract:</b> 0xc2e627839c48db9de26bafb4dcff52cf0c22d154d887c9abd9c726b911156f <br>

<b>Reward token2 contract:</b> 0x775a9e2b7ed8b02beaa1d19c90c053042aedecddd917a9c445f3036f19a1e1c <br>

<b>Staking Multi Reward contract:</b> 0x204699f98282c34ea7147290dae81c5cc702f3795a961ee62f4afe7f48be276 <br>

## Deployment
`deploy-r-t1`: deploys the reward token 1 using: `npm run deploy-r-t1` <br>
`deploy-r-t2`: deploys the reward token 2 using: `npm run deploy-r-t2` <br>
`deploy-s-t`: deploys the staking token using: `npm run deploy-s-t` <br>
`deploy`: deploys the Staking contract using: `npm run deploy` <br>