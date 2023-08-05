// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract SSETokenTimeLockV2 is Ownable {

    uint256 public immutable creationTime;

    uint256 public immutable unlockStartTime;

    uint256 public immutable periodicReleaseNum;

    uint256 public constant PERIOD = 3600; // (seconds for 1 hour)

    IERC20 public immutable token;

    uint256 public withdrawnTokens;

    bool private reentrancyLock = false;

    event TokenWithdrawn(uint indexed previousAmount, uint indexed newAmount);

    constructor(IERC20 _token, uint256 _periodicReleaseNum, uint256 _unlockAfter) {
        _transferOwnership(msg.sender);
        token = _token;
        creationTime = block.timestamp;
        unlockStartTime = creationTime + _unlockAfter;
        periodicReleaseNum = _periodicReleaseNum;
    }

    modifier nonReentrant() {
        require(!reentrancyLock, "No re-entrancy");

        reentrancyLock = true;
        _;
        reentrancyLock = false;
    }

    function withdraw(uint256 _amount, address _beneficiary) external nonReentrant onlyOwner {
        require(availableTokens() >= _amount, "Not enough available tokens.");

        uint256 oldAmount = withdrawnTokens;
        withdrawnTokens += _amount;

        require(token.transfer(_beneficiary, _amount));

        emit TokenWithdrawn(oldAmount, withdrawnTokens);
    }

    function availableTokens() public view returns (uint256) {
        uint256 currentTime = block.timestamp;
        uint256 totalSupply = token.totalSupply();

        uint256 passedTimeSinceUnlock = (unlockStartTime > currentTime) ? 0 : (currentTime - unlockStartTime);
        uint256 available = (passedTimeSinceUnlock * (periodicReleaseNum / PERIOD)) - withdrawnTokens;

        return (available > totalSupply) ? totalSupply : available;
    }

    function lockedTokens() public view returns (uint256) {
        uint256 balance = timeLockWalletBalance();
        uint256 available = availableTokens();

        return (balance > available) ? (balance - available) : 0;
    }

    function timeLockWalletBalance() public view returns (uint256) {
        uint256 balance = token.balanceOf(address(this));

        return balance;
    }
}
