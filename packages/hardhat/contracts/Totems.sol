//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// Useful for debugging. Remove when deploying to a live network.
import "hardhat/console.sol";

import "@rmrk-team/evm-contracts/contracts/implementations/abstract/RMRKAbstractEquippable.sol";
import "@rmrk-team/evm-contracts/contracts/implementations/utils/RMRKTokenURIPerToken.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Totems is RMRKAbstractEquippable, RMRKTokenURIPerToken, AccessControl {
	using Counters for Counters.Counter;

	Counters.Counter private _tokenIdCounter;

	bytes32 public constant CRAFTER_ROLE = keccak256("CRAFTER_ROLE");

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
		transferOwnership(address(0));
		_tokenIdCounter.increment(); // This is done, so that token IDs start with 1 and are compatible with ERC_6220
	}

	function supportsInterface(bytes4 interfaceId)
		public
		view
		virtual
		override(AccessControl, RMRKAbstractEquippable)
		returns (bool)
	{
		return RMRKAbstractEquippable.supportsInterface(interfaceId) ||
			AccessControl.supportsInterface(interfaceId);
	}
}