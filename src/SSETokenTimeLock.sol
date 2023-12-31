// SPDX-License-Identifier: MIT

// Developed by dacxi
// Inspired by smart contract code from www.soroosh.app

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol"; // Import ownable interface
import "@openzeppelin/contracts/interfaces/IERC20.sol"; // Import the ERC-20 token interface

contract SSETokenTimeLock is Ownable {

    // Creation time of the token
    uint256 public immutable creationTime;

    // Number of tokens which is released after each period.
    uint256 public immutable periodicReleaseNum;

    // Release period in seconds.
    uint256 public constant PERIOD = 15552000; // (seconds for 6 month)

    // The token to lock
    IERC20 public immutable token;

    // Number of tokens that has been withdrawn already.
    uint256 public withdrawnTokens;

    bool private reentrancyLock = false; // mutex for reentrancy attack control. See nonReentrant modifier

    event TokenWithdrawn(uint indexed previousAmount, uint indexed newAmount);

    /**
     * @dev Creates timelocked wallet with given info.
     * @param _token tokenContract address.
     * @param _periodicReleaseNum periodic release number.
     */
    constructor(IERC20 _token, uint256 _periodicReleaseNum) {
        _transferOwnership(msg.sender);
        token = _token;
        creationTime = block.timestamp;
        periodicReleaseNum = _periodicReleaseNum;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     *
     * @dev Calling a `nonReentrant` function from another `nonReentrant`
     *      function is not supported.
     */
    modifier nonReentrant() {
        require(!reentrancyLock, "No re-entrancy");

        reentrancyLock = true;
        _;
        reentrancyLock = false;
    }

    /**
     * @dev Withdraws token from wallet if it has enough balance.
     *
     * @param _amount amount of withdrawal.
     * @param _beneficiary destination address.
     */
    function withdraw(uint256 _amount, address _beneficiary) external nonReentrant onlyOwner {
        require(availableTokens() >= _amount, "Not enough available tokens.");

        uint256 oldAmount = withdrawnTokens;
        withdrawnTokens += _amount;

        require(token.transfer(_beneficiary, _amount));

        emit TokenWithdrawn(oldAmount, withdrawnTokens);
    }

    /**
     * @dev Return the available balance to withdraw.
     */
    function availableTokens() public view returns (uint256) {
        uint256 passedTime = block.timestamp - creationTime;

        return (passedTime * periodicReleaseNum / PERIOD) - withdrawnTokens;
    }

    /**
     * @dev Return the total locked balance of token.
     */
    function lockedTokens() public view returns (uint256) {
        uint256 balance = timeLockWalletBalance();
        uint256 available = availableTokens();

        return (balance > available ? (balance - available) : 0);
    }

    /**
     * @dev Returns the total balance of the token.
     */
    function timeLockWalletBalance() public view returns (uint256) {
        uint256 balance = token.balanceOf(address(this));

        return balance;
    }
}
