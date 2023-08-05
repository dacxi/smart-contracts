// SPDX-License-Identifier: MIT

// Developed by dacxi
// Inspired by smart contract code from www.soroosh.app

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol"; // Import ownable interface
import "@openzeppelin/contracts/interfaces/IERC20.sol"; // Import the ERC-20 token interface

contract SSETokenTimeLockV3 is Ownable {

    // Creation time of the contract
    uint256 public immutable creationTime;

    // Time where the token starts to unlock
    uint256 public immutable unlockStartTime;

    // The token to lock
    IERC20 public immutable token;

    // Number of tokens that has been withdrawn already.
    uint256 public withdrawnTokens;

    bool private reentrancyLock = false; // mutex for reentrancy attack control. See nonReentrant modifier

    event TokenWithdrawn(uint indexed previousAmount, uint indexed newAmount);

    /**
     * @dev Creates timelocked wallet with given info.
     * @param _token tokenContract address.
     * @param _unlockAfter the number of seconds to start unlock the token starting from the contract creation time.
     */
    constructor(IERC20 _token, uint256 _unlockAfter) {
        _transferOwnership(msg.sender);
        token = _token;
        creationTime = block.timestamp;
        unlockStartTime = creationTime + _unlockAfter;
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
        require(areTokensAvailable(), "Tokens not available yet.");

        uint256 oldAmount = withdrawnTokens;
        withdrawnTokens += _amount;

        require(token.transfer(_beneficiary, _amount));

        emit TokenWithdrawn(oldAmount, withdrawnTokens);
    }

    /**
     * @dev Return if the tokens are available to  balance to withdraw.
     */
    function areTokensAvailable() public view returns (bool) {
        uint256 currentTime = block.timestamp;

        return unlockStartTime < currentTime;
    }

    /**
     * @dev Returns the total balance of the token.
     */
    function timeLockWalletBalance() public view returns (uint256) {
        uint256 balance = token.balanceOf(address(this));

        return balance;
    }
}
