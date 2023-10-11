//SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "../interfaces/IMintingUtils.sol";

contract MintingUtils is AccessControl, IMintingUtils {
    bytes32 public constant CONTRIBUTOR_ROLE = keccak256("CONTRIBUTOR_ROLE");
    uint256 private numberOfElements;

    mapping(uint256 index => Element) private elements;

    /**
     * @notice Used to store element distribution data
     * @dev `from` and `to` are inclusive
     * @dev `from` and `to` are expressed in base points (1 == 0.01% && 10000 == 100%)
     * @param name Name of the element
     * @param from Starting base point of the element
     * @param to Ending base point of the element
     */
    struct Element {
        string name;
        uint8 from;
        uint8 to;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CONTRIBUTOR_ROLE, msg.sender);
    }

    function getRandomElement() public view returns (string memory) {
        uint256 randomNumber = block.prevrandao % 10000;
        for (uint256 i = numberOfElements; i > 0; ) {
            if(randomNumber <= elements[i-1].from && randomNumber >= elements[i-1].to){
                return elements[i-1].name;
            }
            unchecked {
                --i;
            }
        }
    }

    function setElementDistribution(string[] memory _elements, uint8[] memory _from, uint8[] memory _to) public onlyRole(CONTRIBUTOR_ROLE) {
        if(_elements.length != _from.length) revert ArrayMismatch();
        if(_elements.length != _to.length) revert ArrayMismatch();

        for (uint256 i; i < _elements.length; ) {
            elements[i] = Element(_elements[i], _from[i], _to[i]);
            emit ElementUpdated(_elements[i], _from[i], _to[i]);
            unchecked {
                ++i;
            }
        }

        // Remove elements that are not needed anymore
        if(numberOfElements > _elements.length){
            for (uint256 i = _elements.length; i < numberOfElements; ) {
                delete elements[i];
                unchecked {
                    ++i;
                }
            }
        }

        numberOfElements = _elements.length;
    }
}