//SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@rmrk-team/evm-contracts/contracts/RMRK/extension/tokenProperties/IERC7508.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./interfaces/ITotems.sol";
import "./interfaces/IResources.sol";

error ArrayLengthMismatch();
error MaxTierViolation(uint256 maxTier, uint256 attemptedTier);

contract Rewards is  AccessControl {
    IERC7508 public immutable erc7508 = IERC7508(0xA77b75D5fDEC6E6e8E00e05c707a7CA81a3F9f4a);
    using Counters for Counters.Counter;

    Counters.Counter private _rewardCounterId;

    ITotems public immutable totems;

    bool private mintingPaused;
    bytes32 public constant REWARDS_CREATOR_ROLE = keccak256("REWARDS_CREATOR_ROLE");
    bytes32 public constant QUEST_ROLE = keccak256("QUEST_ROLE");
    uint256 public maxTier;
    uint256 public mathchingElementMultipierBpts; // Expressed in basis points (1/100 of a percent)

    mapping (uint256 rewardId => Reward) public rewards;

    struct Reward {
        uint256 tier;
        address[] rewardAddress;
        uint256[] rewardIds;
        uint256[] rewardAmount;
    }

    event NewReward(uint256 indexed rewardId, uint256 tier, address[] rewardAddress, uint256[] rewardIds, uint256[] rewardAmount);

    constructor(
        uint256 initialMaxTier,
        address totems_,
        address initialRewardsCreator_
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(REWARDS_CREATOR_ROLE, initialRewardsCreator_);

        totems = ITotems(totems_);
        mintingPaused = false;
        maxTier = initialMaxTier;
    }

    function createReward(
        uint256 tier,
        address[] memory rewardAddresses,
        uint256[] memory rewardIds,
        uint256[] memory rewardAmounts
    ) public onlyRole(REWARDS_CREATOR_ROLE) {
        if (tier > maxTier) revert MaxTierViolation( { maxTier: maxTier, attemptedTier: tier } );
        if (rewardAddresses.length != rewardAmounts.length) revert ArrayLengthMismatch();
        if (rewardAddresses.length != rewardIds.length) revert ArrayLengthMismatch();

        rewards[_rewardCounterId.current()] = Reward(tier, rewardAddresses, rewardIds, rewardAmounts);

        _rewardCounterId.increment();

        emit NewReward(_rewardCounterId.current() - 1, tier, rewardAddresses, rewardIds, rewardAmounts);
    }

    function distributeRewards(uint256 rewardId, uint256[] memory totemIds, string memory questElement) public onlyRole(QUEST_ROLE) {
        Reward memory reward = rewards[rewardId];

         for (uint256 i; i < totemIds.length; ) {
            address totemBearer = totems.ownerOf(totemIds[i]);
            string memory totemElement = erc7508.getStringTokenAttribute(address(totems), totemIds[i], "element");
            uint256 rewardMultipier = 10_000;

            if (keccak256(abi.encode(totemElement)) == keccak256(abi.encode(questElement))) {
                rewardMultipier = mathchingElementMultipierBpts;
            }

            for (uint256 j; j < reward.rewardAddress.length; ) {
                IResources(address(reward.rewardAddress[j])).mint(totemBearer, reward.rewardIds[j], reward.rewardAmount[j] * rewardMultipier / 10_000, "");

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
    }
}