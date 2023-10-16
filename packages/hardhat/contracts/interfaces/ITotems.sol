// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface ITotems {
    function craft(string memory element, string memory totemUri, uint8 stage, uint8 tier, address to) external;

    function disableTransferability(uint256 tokenId) external;

    function batchDisableTransferability(uint256[] memory tokenIds) external;

    function enableTransferability(uint256 tokenId) external;

    function batchEnableTransferability(uint256[] memory tokenIds) external;

    function ownerOf(uint256 tokenId) external view returns (address);
}