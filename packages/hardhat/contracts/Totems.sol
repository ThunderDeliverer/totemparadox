//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// Useful for debugging. Remove when deploying to a live network.
import "hardhat/console.sol";

import "@rmrk-team/evm-contracts/contracts/implementations/abstract/RMRKAbstractEquippable.sol";
import "@rmrk-team/evm-contracts/contracts/implementations/utils/RMRKTokenURIPerToken.sol";
import "@rmrk-team/evm-contracts/contracts/RMRK/extension/soulbound/RMRKSoulboundPerToken.sol";
import "@rmrk-team/evm-contracts/contracts/RMRK/extension/tokenProperties/IERC7508.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

error TotemsMaxStageViolation(uint256 maxStage, uint256 attempedStage);
error TotemsMaxTierViolation(uint256 maxTier, uint256 attempedTier);
error TotemsNotCrafter();
error TotemsNotTransferable(uint256 tokenId);
error TotemsTransferable(uint256 tokenId);

contract Totems is RMRKAbstractEquippable, RMRKTokenURIPerToken, RMRKSoulboundPerToken, AccessControl {
	IERC7508 public immutable erc7508 = IERC7508(0xA77b75D5fDEC6E6e8E00e05c707a7CA81a3F9f4a);
	using Counters for Counters.Counter;

	Counters.Counter private _tokenIdCounter;

    uint256 maxStage; // This defines a maximum stage the totem can reach. The stage of the `Totem` can also be considered a size stage.
    uint256 maxTier; // This defines a maximum rarity tier a totem can reach. Can be regarded as the star rating of the totem.
	bytes32 public constant CRAFTER_ROLE = keccak256("CRAFTER_ROLE");
	bytes32 public constant TRANSFERABILITY_MANAGER_ROLE = keccak256("TRANSFERABILITY_MANAGER_ROLE");

	event TotemCrafted(uint256 indexed totemId, string element, uint256 stage, uint256 tier);

    constructor(
		string memory name,
		string memory symbol,
		string memory collectionMetadata,
		uint256 maxSupply,
		address royaltyRecipient,
		uint256 royaltyPercentageBps
	) RMRKImplementationBase(
		name,
		symbol,
		collectionMetadata,
		maxSupply,
		royaltyRecipient,
		royaltyPercentageBps
	) {
		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(CRAFTER_ROLE, msg.sender);
		_tokenIdCounter.increment(); // This is done, so that token IDs start with 1 and are compatible with ERC_6220

		erc7508.setStringAttribute(address(this), 0, "element", "infernum"); // These are set, so that the user doesn't
		erc7508.setStringAttribute(address(this), 0, "element", "eternum"); // have to pay for the setting the string
		erc7508.setStringAttribute(address(this), 0, "element", "metamorphium"); // value to the ID representing it.
		erc7508.setStringAttribute(address(this), 0, "element", "genesisium");
		erc7508.setStringAttribute(address(this), 0, "element", "emphatium");
		erc7508.setUintAttribute(address(this), 0, "stage", 0);
		erc7508.setUintAttribute(address(this), 0, "tier", 0);
	}

	function supportsInterface(bytes4 interfaceId)
		public
		view
		virtual
		override(AccessControl, RMRKAbstractEquippable, RMRKSoulbound)
		returns (bool)
	{
		return RMRKAbstractEquippable.supportsInterface(interfaceId) ||
			RMRKSoulbound.supportsInterface(interfaceId) ||
			AccessControl.supportsInterface(interfaceId);
	}

	function craft(
		string memory element,
		string memory tokenUri,
		uint8 stage,
		uint8 tier,
		address to
	) external {
		if (!hasRole(CRAFTER_ROLE, _msgSender())) revert TotemsNotCrafter();
        if (stage > maxStage) revert TotemsMaxStageViolation({maxStage: maxStage, attempedStage: stage});
        if (tier > maxTier) revert TotemsMaxTierViolation({maxTier: maxTier, attempedTier: tier});

		uint256 tokenId = _tokenIdCounter.current();

		_safeMint(to, tokenId, "");
		_setTokenURI(tokenId, tokenUri);

		erc7508.setStringAttribute(address(this), tokenId, "element", element);
		erc7508.setUintAttribute(address(this), tokenId, "stage", stage);
		erc7508.setUintAttribute(address(this), tokenId, "tier", tier);

		_tokenIdCounter.increment();

		emit TotemCrafted(tokenId, element, stage, tier);
	}

	function disableTransferability(uint256 tokenId) public onlyRole(TRANSFERABILITY_MANAGER_ROLE) {
		if (!isTransferable(tokenId, address(0), address(0))) revert TotemsNotTransferable({ tokenId: tokenId});

		_setSoulbound(tokenId, true);
	}

	function batchDisableTransferability(uint256[] memory tokenIds) public onlyRole(TRANSFERABILITY_MANAGER_ROLE) {
		for (uint256 i; i < tokenIds.length;) {
			if (!isTransferable(tokenIds[i], address(0), address(0))) revert TotemsNotTransferable({ tokenId: tokenIds[i]});

			_setSoulbound(tokenIds[i], true);

			unchecked {
				++i;
			}
		}
	}

	function enableTransferability(uint256 tokenId) public onlyRole(TRANSFERABILITY_MANAGER_ROLE) {
		if (isTransferable(tokenId, address(0), address(0))) revert TotemsTransferable({ tokenId: tokenId});

		_setSoulbound(tokenId, false);
	}

	function batchEnableTransferability(uint256[] memory tokenIds) public onlyRole(TRANSFERABILITY_MANAGER_ROLE) {
		for (uint256 i; i < tokenIds.length;) {
			if (isTransferable(tokenIds[i], address(0), address(0))) revert TotemsTransferable({ tokenId: tokenIds[i]});

			_setSoulbound(tokenIds[i], false);

			unchecked {
				++i;
			}
		}
	}

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(RMRKSoulbound, RMRKAbstractEquippable) {
        RMRKSoulbound._beforeTokenTransfer(from, to, tokenId);
        RMRKAbstractEquippable._beforeTokenTransfer(from, to, tokenId);
    }
}