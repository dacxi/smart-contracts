// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "./Ownable.sol";

interface IBEP20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract SSETokenTimeLock is Ownable {

    uint256 public immutable creationTime;

    uint256 private immutable periodicReleaseNum;

    uint256 public constant PERIOD = 15552000; // (seconds for 6 month)

    uint256 private _withdrawnTokens;

    IBEP20 privae immutable _token;

    event TokenWithdrawn(uint indexed previousAmount, uint indexed newAmount);

    constructor(IBEP20 token_, uint256 periodicReleaseNum_) {
        _transferOwnership(msg.sender);
        _token = token_;
        creationTime = block.timestamp;
        periodicReleaseNum = periodicReleaseNum_;
    }

    function withdraw(uint256 amount_, address beneficiary_) public onlyOwner {
        require(availableTokens() >= amount_);
        uint256 oldAmount  = _withdrawnTokens;
        _withdrawnTokens += amount_;
        emit TokenWithdrawn(oldAmount, _withdrawnTokens);
        require(token().transfer(beneficiary_, amount_));
    }

    function token() public view returns (IBEP20) {
        return _token;
    }

    function getPeriodicReleaseNum() public view returns (uint256) {
        return periodicReleaseNum;
    }

    function withdrawnTokens() public view returns (uint256) {
        return _withdrawnTokens;
    }

    function availableTokens() public view returns (uint256) {
        uint256 passedTime = block.timestamp - creationTime;
        return (passedTime * periodicReleaseNum / PERIOD) - _withdrawnTokens;
    }

    function lockedTokens() public view returns (uint256) {
        uint256 balance = timeLockWalletBalance();
        return balance - availableTokens();
    }

    function timeLockWalletBalance() public view returns (uint256) {
        uint256 balance = token().balanceOf(address(this));
        return balance;
    }
}
