// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Lock is Ownable, ReentrancyGuard {
    struct VestingPeriod {
        uint256 startTime;
        uint256 releaseTime;
        uint256 totalTokens;
        uint256 releasedTokens;
        uint256 initialReleaseAmount;
        uint256 currentDuration;

        bool isInitialized;
    }

    // Address of the token contract
    address public tokenContract;

    // Address of the beneficiary who will receive the tokens
    address public beneficiary;

    // Number of months over which 90% locked tokens will be released
    uint256 public constant releaseDuration = 11;

    VestingPeriod[3] public vestingPeriods;
    // Constructor
    constructor(
        address _tokenContract,
        address _beneficiary,
        uint256 _totalTokens
    ) {
        tokenContract = _tokenContract;
        beneficiary = _beneficiary;

        uint256 initialReleaseAmount = _totalTokens * 10 / 100;
        uint256 _vestingTokens = _totalTokens;

        vestingPeriods[0] = VestingPeriod(
            0,
            0,
            _vestingTokens / 3,
            0,
            initialReleaseAmount /3,
            1,
            false
        );

        vestingPeriods[1] = VestingPeriod(
            0,
            0,
            _vestingTokens / 3,
            0,
            initialReleaseAmount /3,
            1,
            false
        );

        vestingPeriods[2] = VestingPeriod(
            0,
            0,
            _vestingTokens / 3,
            0,
            initialReleaseAmount /3,
            1,
            false
        );
    }

    function startVesting(
        uint256 vestingId
    ) external onlyOwner {
        require(vestingId < vestingPeriods.length, "Invalid vesting ID");
        VestingPeriod storage vesting = vestingPeriods[vestingId];
        require(!vesting.isInitialized, "Vesting already initialized");
        vesting.startTime = block.timestamp;
        vesting.releaseTime = block.timestamp + 730 days;
        vesting.isInitialized = true;
        IERC20(tokenContract).transferFrom(msg.sender, address(this), vesting.totalTokens);
    }

    function releaseInitialTokens(uint256 vestingId) external nonReentrant {
        require(msg.sender == beneficiary, "You aren't the owner");
        VestingPeriod storage vesting = vestingPeriods[vestingId];
        require(vesting.isInitialized, "Vesting period not initialized");
        require(vesting.initialReleaseAmount > 0, "Vesting period ended");
        vesting.releasedTokens += vesting.initialReleaseAmount;
        IERC20(tokenContract).transfer(beneficiary, vesting.initialReleaseAmount);
        vesting.initialReleaseAmount = 0;
    }
    // Function to release tokens after the lock-up period
    function releaseTokens(uint256 vestingId) external nonReentrant returns (bool) {
        require(msg.sender == beneficiary, "You aren't the owner");
        VestingPeriod storage vesting = vestingPeriods[vestingId];
        require(vesting.isInitialized, "Vesting period not initialized");
        require(vesting.currentDuration <= 12, "Vesting period ended");
        require(block.timestamp >= vesting.releaseTime, "Tokens are still locked.");

        if(vesting.currentDuration > releaseDuration && (vesting.totalTokens - vesting.releasedTokens) > 0) {
            require(block.timestamp >= vesting.releaseTime +  (12 * 30 days), "Tokens are still locked.");
            vesting.currentDuration = 13;
            // Release remaining tokens on the 12th month
            IERC20(tokenContract).transfer(beneficiary, vesting.totalTokens - vesting.releasedTokens);
            return true;
        }

        uint256 monthlyReleaseAmount = vesting.totalTokens * 77 / 100 / releaseDuration;

        // Release 7% tokens every month for 11 months
        for (uint256 i = vesting.currentDuration; i <= releaseDuration; i++) {
            uint256 releaseMonth = vesting.releaseTime + (i * 30 days);
            if (block.timestamp >= releaseMonth) {
                vesting.currentDuration = i+1;
                vesting.releasedTokens += monthlyReleaseAmount;
                IERC20(tokenContract).transfer(beneficiary, monthlyReleaseAmount);
            }
        }
        return true;
    }
}
