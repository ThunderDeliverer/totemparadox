//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "./interfaces/ITotems.sol";
import "./interfaces/IMintingUtils.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

error MinterIncorrectFee();
error MinterMintingPaused();
error MinterWithdrawalFailed();

contract Minter is AccessControl {
    ITotems public immutable totems;
    IMintingUtils public immutable mintingUtils;

    uint256 private _fee;

    bool private mintingPaused;

    modifier onlyWhenMintingOperational {
        if (!mintingPaused) revert MinterMintingPaused();
        _;
    }

    event FeeUpdated(uint256 newFee);

    constructor(address totems_, address mintingUtils_, uint256 fee_) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        totems = ITotems(totems_);
        mintingUtils = IMintingUtils(mintingUtils_);
        _fee = fee_;
        mintingPaused = false;

        emit FeeUpdated(fee_);
    }

    function fee() public view returns (uint256) {
        return _fee;
    }

    function isMintingOperational() public view returns (bool) {
        return !mintingPaused;
    }

    function updateFee(uint256 newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _fee = newFee;

        emit FeeUpdated(newFee);
    }

    function mint() public payable onlyWhenMintingOperational {
        if (msg.value != _fee) revert MinterIncorrectFee();

        string memory element = mintingUtils.getRandomElement();
        totems.craft(element, 0, 0, msg.sender);
    }

    function pauseMinting() external onlyRole(DEFAULT_ADMIN_ROLE) {
        mintingPaused = true;
    }

    function resumeMinting() external onlyRole(DEFAULT_ADMIN_ROLE) {
        mintingPaused = false;
    }

    function withdrawFees(address recipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool success , ) = recipient.call{value: address(this).balance}("");

        if (!success) revert MinterWithdrawalFailed();
    }
}