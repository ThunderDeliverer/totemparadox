//SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/AccessControl.sol";

error ArrayMismatch();

interface IMintingUtils {
    event ElementUpdated(string name, uint8 from, uint8 to);

    function getRandomElement() external view returns (string memory);

    function getTotemUri(string memory element, uint256 stage, uint256 tier) external view returns (string memory);
}