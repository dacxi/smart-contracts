// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/master/contracts/interfaces/IERC20.sol"; // Import the ERC-20 token interface

/**
 * @dev A contract that can lock erc20 tokens for a period of time, allowing a single beneficiary to withdrawal the tokens
 * once the lock period ends. Only one beneficiary can exists. But multiple deposits/withdrawal cycles can be made.
 */
contract LockVault {
    address public owner; // Address that sends the ERC-20 tokens
    IERC20 public token; // ERC-20 token contract
    address public beneficiary; // Address that receives access to tokens in the future

    uint256 public unlockBlock = 0; // Block number after which tokens can be accessed
    uint256 public unlockBlockForOwner = 0; // Block number after which tokens can be accessed from owner
    uint256 public lockedAmount = 0; // the deposited amount

    bool private callLocked = false; // mutex for reentrancy attack control. See nonReentrant modifier

    event TokenDeposited(address indexed from, uint256 amount, uint256 unlockBlock, uint256 unlockBlockForOwner);
    event TokenWithdrawn(address indexed from, uint256 amount);

    constructor(
        address _tokenAddress,
        address _beneficiary
    ) {
        owner = msg.sender;
        token = IERC20(_tokenAddress);
        beneficiary = _beneficiary;
    }

    /**
     * @dev Only the owner of this contract can call those functions
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    /**
     * @dev Only the beneficiary of this contract can call those functions
     */
    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "Only the beneficiary can perform this action");
        _;
    }

    /**
     * @dev Function can only be called if the tokens are unlocked for the beneficiary
     */
    modifier checkLockForBeneficiary() {
        require(lockedAmount > 0, "There is no locked amount");
        require(block.number >= unlockBlock, "Tokens are still locked");
        _;
    }

    /**
     * @dev Function can only be called if the tokens are unlocked for the onwer
     */
    modifier checkLockForOwner() {
        require(block.number >= unlockBlockForOwner, "Tokens are still locked");
        _;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported.
     */
    modifier nonReentrant() {
        require(!callLocked, "No re-entrancy");

        callLocked = true;
        _;
        callLocked = false;
    }

    /**
     * @dev Deposit and lock the tokens. Only the onwer can call this function.
     * A deposit can only be made if there is no locked amount already in the contract.
     */
    function depositTokens(uint256 _amount, uint256 _blocksUntilUnlock) external onlyOwner {
        require(lockedAmount == 0, "A deposit is already locked");
        require(_amount > 0, "Amount must be greater than zero");

        // get the current block
        uint256 currentBlock = block.number;

        // set the block to unlock the tokens for beneficiary and owner
        unlockBlock = currentBlock + _blocksUntilUnlock;
        unlockBlockForOwner = currentBlock + _blocksUntilUnlock + (_blocksUntilUnlock / 2);

        //
        // SECURITY NOTE: We use the checks-effects-interaction pattern here to protect against reentrancy attack.
        //
        lockedAmount = _amount;

        // Transfer tokens from the owner to the contract
        token.transferFrom(owner, address(this), lockedAmount);

        emit TokenDeposited(owner, lockedAmount, unlockBlock, unlockBlockForOwner);
    }

    /**
     * @dev Withdrawal the unlocked tokens. Only the beneficiary can call this function
     */
    function withdrawalTokens() external nonReentrant onlyBeneficiary checkLockForBeneficiary {
        // get the amount to withdrawal
        uint256 amountToWithdrawal = lockedAmount;

        //
        // SECURITY NOTE: We use the checks-effects-interaction pattern here to protect against reentrancy attack.
        // Although this function already have a reentrancy guard (nonReentrant) that protects agains recursive calls,
        // we still apply the pattern to make sure no reentrancy attack is possible. Better safe than sorry.
        //
        lockedAmount = 0;
        unlockBlock = 0;
        unlockBlockForOwner = 0;

        // And finally transfer all tokens to the beneficiary
        token.transfer(beneficiary, amountToWithdrawal);

        emit TokenWithdrawn(beneficiary, amountToWithdrawal);
    }

    /**
     * @dev Withdrawal all token balance of the contract. Only the owner can call this function.
     * This function can only be called if there is no locked balance for the owner.
     */
    function withdrawalAllTokens() external nonReentrant onlyOwner checkLockForOwner {
        // Here we get all balance instead of the just locked balance. This is a last resort function
        // that can be used to recover all token from the contract in case the beneficiary could not
        // withdrawal the tokens by himself.
        uint256 amountToWithdrawal = token.balanceOf(address(this));
        require(amountToWithdrawal > 0, "There is no balance to withdrawal");

        //
        // SECURITY NOTE: We use the checks-effects-interaction pattern here to protect against reentrancy attack.
        // Although this function already have a reentrancy guard (nonReentrant) that protects agains recursive calls,
        // we still apply the pattern make sure no reentrancy attack is possible. Better safe than sorry.
        //
        lockedAmount = 0;
        unlockBlock = 0;
        unlockBlockForOwner = 0;

        // And transfer all tokens to the beneficiary
        token.transfer(owner, amountToWithdrawal);

        emit TokenWithdrawn(owner, amountToWithdrawal);
    }
}
