//SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface IRewards {
    function distributeRewards(uint256 rewardId, uint256[] memory totemIds, string memory questElement) external;
}