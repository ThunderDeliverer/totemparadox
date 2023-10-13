//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@rmrk-team/evm-contracts/contracts/implementations/abstract/RMRKAbstractEquippable.sol";
import "@rmrk-team/evm-contracts/contracts/implementations/utils/RMRKTokenURIPerToken.sol";
import "@rmrk-team/evm-contracts/contracts/RMRK/extension/tokenProperties/IERC7508.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./interfaces/ITotems.sol";

error QuestMintingPaused();
error QuestNotCreator();

contract Quest is RMRKAbstractEquippable, RMRKTokenURIPerToken, AccessControl {
	IERC7508 public immutable erc7508 = IERC7508(0xA77b75D5fDEC6E6e8E00e05c707a7CA81a3F9f4a);
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    ITotems public immutable totems;

    bool private mintingPaused;
    bytes32 public constant QUEST_CREATOR_ROLE = keccak256("QUEST_CREATOR_ROLE");

    event NewQuest(uint256 indexed questId, string name, uint256 difficulty, uint256 duration, uint256 indexed rewardId);

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

    function isMintingOperational() public view returns (bool) {
        return !mintingPaused;
    }

    function createQuest(
        string memory name,
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
        erc7508.setUintAttribute(address(this), tokenId, "duration", duration);
        erc7508.setUintAttribute(address(this), tokenId, "difficulty", difficulty);
        erc7508.setUintAttribute(address(this), tokenId, "rewardId", rewardId);

        emit NewQuest(tokenId, name, difficulty, duration, rewardId);
    }
}