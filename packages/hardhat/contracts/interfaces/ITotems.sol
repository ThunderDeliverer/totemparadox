// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface ITotems {
    function craft(string memory element, uint8 stage, uint8 tier, address to) external;
}