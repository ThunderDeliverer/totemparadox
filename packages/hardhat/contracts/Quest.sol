//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@rmrk-team/evm-contracts/contracts/implementations/abstract/RMRKAbstractEquippable.sol";
import "@rmrk-team/evm-contracts/contracts/implementations/utils/RMRKTokenURIPerToken.sol";
import "@rmrk-team/evm-contracts/contracts/RMRK/extension/tokenProperties/IERC7508.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./interfaces/ITotems.sol";
import "./interfaces/IRewards.sol";

error QuestActive();
error QuestInstanceDoesNotExist();
error QuestJoinCutoffElapsed(uint256 startTime, uint256 joinAttemptTime);
error QuestMaxTotemsPerInstanceReached();
error QuestMintingPaused();
error QuestNotActive();
error QuestNotCreator();
error QuestNotTotemOwner();
error QuestStillInProgress(uint256 endTime, uint256 currentTime);

contract Quest is RMRKAbstractEquippable, RMRKTokenURIPerToken, AccessControl {
	IERC7508 public immutable erc7508 = IERC7508(0xA77b75D5fDEC6E6e8E00e05c707a7CA81a3F9f4a);
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    ITotems public immutable totems;
    IRewards public rewards;

    uint256 public questJoinTimeBpts; // Emout of time after the quest is started, that the user can join the quest. Expressed in basis points (1/100 of a percent)
    uint256 public maxTotemsPerInstance;
    bool private mintingPaused;
    bytes32 public constant QUEST_CREATOR_ROLE = keccak256("QUEST_CREATOR_ROLE");
    mapping (uint256 questId => uint256 latestInstace) public latestInstances;
    mapping (uint256 questId => mapping (uint256 instanceId => QuestInstance)) public questInstances;

    struct QuestInstance {
        uint256 startTime;
        uint256 endTime;
        uint256[] totemIds;
    }

    event NewQuest(uint256 indexed questId, string name, string element, uint256 difficulty, uint256 duration, uint256 indexed rewardId);
    event QuestCompleted(uint256 indexed questId, uint256 indexed questInstance, uint256[] totemIds);
    event QuestJoinTimeBptsUpdated(uint256 newJoinTimeBpts);
    event QuestInstanceJoined(uint256 indexed questId, uint256 questInstance, uint256 indexed totemId);
    event QuestMaxTotemsPerInstanceUpdated(uint256 newMaxTotemsPerInstance);
    event QuestUpdated(uint256 indexed questId, string name, string element, uint256 difficulty, uint256 duration, uint256 indexed rewardId);
    event QuestRewardsAddressUpdated(address newRewardsAddress);
    event QuestStarted(uint256 indexed questId, uint256 questInstance, uint256 indexed totemId);
    event QuestStatusChanged(uint256 indexed questId, bool active);

    modifier onlyWhenMintingOperational {
        if (!mintingPaused) revert QuestMintingPaused();
        _;
    }

    event FeeUpdated(uint256 newFee);

    constructor(
        string memory name,
        string memory symbol,
        string memory collectionMetadata,
        uint256 maxSupply,
        address totems_,
        address initialQuestCreator_
    ) RMRKImplementationBase(
        name,
        symbol,
        collectionMetadata,
        maxSupply,
        address(0),
        0  
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(QUEST_CREATOR_ROLE, initialQuestCreator_);
        _tokenIdCounter.increment(); // This is done, so that token IDs start with 1 and are compatible with ERC-6220

        totems = ITotems(totems_);
        mintingPaused = false;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, RMRKAbstractEquippable) returns (bool) {
        return AccessControl.supportsInterface(interfaceId)||
            RMRKAbstractEquippable.supportsInterface(interfaceId);
    }

    function isQuestActive(uint256 questId) public view returns (bool) {
        return erc7508.getBoolTokenAttribute(address(this), questId, "active");
    }

    function isMintingOperational() public view returns (bool) {
        return !mintingPaused;
    }

    function createQuest(
        string memory name,
        string memory element,
        string memory primaryAssetUri,
        string memory tokenUri,
        string memory descriptionUri,
        uint256 duration,
        uint256 difficulty,
        uint256 rewardId
    ) public onlyWhenMintingOperational onlyRole(QUEST_CREATOR_ROLE) {
        if (!hasRole(QUEST_CREATOR_ROLE, _msgSender())) revert QuestNotCreator();

        uint256 tokenId = _tokenIdCounter.current();

        _safeMint(address(this), tokenId, "");
        _setTokenURI(tokenId, tokenUri);

        unchecked {
            _totalAssets += 2;
        }
        uint64 lastAssetId = uint64(_totalAssets);
        _addAssetEntry(lastAssetId - 1, primaryAssetUri);
        _addAssetEntry(lastAssetId, descriptionUri);

        _addAssetToToken(tokenId, lastAssetId - 1, 0);
        _addAssetToToken(tokenId, lastAssetId, 0);

        uint64[] memory priorities = new uint64[](2);
        priorities[0] = 5;
        priorities[1] = 10;
        setPriority(tokenId, priorities);

        erc7508.setStringAttribute(address(this), tokenId, "name", name);
        erc7508.setStringAttribute(address(this), tokenId, "element", element);
        erc7508.setUintAttribute(address(this), tokenId, "duration", duration);
        erc7508.setUintAttribute(address(this), tokenId, "difficulty", difficulty);
        erc7508.setUintAttribute(address(this), tokenId, "rewardId", rewardId);
        erc7508.setBoolAttribute(address(this), tokenId, "active", true);

        emit NewQuest(tokenId, name, element, difficulty, duration, rewardId);
        emit QuestStatusChanged(tokenId, true);
    }

    function updateQuest(
        uint256 questId,
        string memory newName,
        string memory newElement,
        uint256 newDuration,
        uint256 newDifficulty,
        uint256 newRewardId
    ) public onlyRole(QUEST_CREATOR_ROLE) {
        if (keccak256(abi.encode(newName)) != keccak256("")) {
            erc7508.setStringAttribute(address(this), questId, "name", newName);
        }
        if (keccak256(abi.encode(newElement)) != keccak256("")) {
            erc7508.setStringAttribute(address(this), questId, "element", newElement);
        }
        if (newDuration > 0) {
            erc7508.setUintAttribute(address(this), questId, "duration", newDuration);
        }
        if (newDifficulty > 0) {
            erc7508.setUintAttribute(address(this), questId, "difficulty", newDifficulty);
        }
        if (newRewardId > 0) {
            erc7508.setUintAttribute(address(this), questId, "rewardId", newRewardId);
        }

        emit QuestUpdated(questId, newName, newElement, newDuration, newDifficulty, newRewardId);
    }

    function disableQuest(uint256 questId) public onlyRole(QUEST_CREATOR_ROLE) {
        if (!isQuestActive(questId)) revert QuestNotActive();

        erc7508.setBoolAttribute(address(this), questId, "active", false);

        emit QuestStatusChanged(questId, false);
    }

    function enableQuest(uint256 questId) public onlyRole(QUEST_CREATOR_ROLE) {
        if (isQuestActive(questId)) revert QuestActive();

        erc7508.setBoolAttribute(address(this), questId, "active", true);

        emit QuestStatusChanged(questId, true);
    }

    function startQuest(uint256 questId, uint256 totemId) public {
        if (!isQuestActive(questId)) revert QuestNotActive();
        if (totems.ownerOf(totemId) != msg.sender) revert QuestNotTotemOwner();

        totems.disableTransferability(totemId);

        uint256 questInstance = latestInstances[questId] + 1;

        uint256 start = block.timestamp;
        uint256 end = start + erc7508.getUintTokenAttribute(address(this), questId, "duration");
        uint256[] memory totemIds = new uint256[](1);
        totemIds[0] = totemId;

        questInstances[questId][questInstance] = QuestInstance(start, end, totemIds);

        latestInstances[questId] = questInstance;
        emit QuestStarted(questId, questInstance, totemId);
    }

    function joinQuest(uint256 questId, uint256 questInstance, uint256 totemId) public {
        if (!isQuestActive(questId)) revert QuestNotActive();
        if (totems.ownerOf(totemId) != msg.sender) revert QuestNotTotemOwner();

        QuestInstance memory instance = questInstances[questId][questInstance];
        if (instance.startTime == 0) revert QuestInstanceDoesNotExist();
        if (instance.totemIds.length > maxTotemsPerInstance) revert QuestMaxTotemsPerInstanceReached();

        uint256 joinBuffer = instance.startTime + (erc7508.getUintTokenAttribute(address(this), questId, "duration") * questJoinTimeBpts / 10_000);
        if (instance.startTime + joinBuffer < block.timestamp) revert QuestJoinCutoffElapsed({ startTime: instance.startTime, joinAttemptTime: block.timestamp});

        totems.disableTransferability(totemId);

        questInstances[questId][questInstance].totemIds.push(totemId);
        emit QuestStarted(questId, questInstance, totemId);
    }

    function updateQuestJoinTimeBpts(uint256 newJoinTimeBpts) public onlyRole(QUEST_CREATOR_ROLE) {
        questJoinTimeBpts = newJoinTimeBpts;

        emit QuestJoinTimeBptsUpdated(newJoinTimeBpts);
    }

    function updateMaxTotemsPerInstance(uint256 newMaxTotemsPerInstance) public onlyRole(QUEST_CREATOR_ROLE) {
        maxTotemsPerInstance = newMaxTotemsPerInstance;

        emit QuestMaxTotemsPerInstanceUpdated(newMaxTotemsPerInstance);
    }

    function setRewardsAddress(address rewardsAddress) public onlyRole(QUEST_CREATOR_ROLE) {
        rewards = IRewards(rewardsAddress);

        emit QuestRewardsAddressUpdated(rewardsAddress);
    }

    function completeQuest(uint256 questId, uint256 instanceId) public {
        if (!isQuestActive(questId)) revert QuestNotActive();

        QuestInstance memory instance = questInstances[questId][instanceId];
        if (instance.startTime == 0) revert QuestInstanceDoesNotExist();
        if (instance.endTime > block.timestamp) revert QuestStillInProgress({ endTime: instance.endTime, currentTime: block.timestamp});

        uint256 rewardId = erc7508.getUintTokenAttribute(address(this), questId, "rewardId");
        uint256[] memory totemIds = instance.totemIds;
        string memory questElement = erc7508.getStringTokenAttribute(address(this), questId, "element");

        rewards.distributeRewards(rewardId, totemIds, questElement);

        totems.batchEnableTransferability(totemIds);

        emit QuestCompleted(questId, instanceId, totemIds);
    }
}