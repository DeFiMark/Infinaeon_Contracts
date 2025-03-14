//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;


/**
 * @title Owner
 * @dev Set & change owner
 */
contract Ownable {

    address private owner;
    
    // event for EVM logging
    event OwnerSet(address indexed oldOwner, address indexed newOwner);
    
    // modifier to check if caller is owner
    modifier onlyOwner() {
        // If the first argument of 'require' evaluates to 'false', execution terminates and all
        // changes to the state and to Ether balances are reverted.
        // This used to consume all gas in old EVM versions, but not anymore.
        // It is often a good idea to use 'require' to check if functions are called correctly.
        // As a second argument, you can also provide an explanation about what went wrong.
        require(msg.sender == owner, "Caller is not owner");
        _;
    }
    
    /**
     * @dev Set contract deployer as owner
     */
    constructor() {
        owner = msg.sender; // 'msg.sender' is sender of current call, contract deployer for a constructor
        emit OwnerSet(address(0), owner);
    }

    /**
     * @dev Change owner
     * @param newOwner address of new owner
     */
    function changeOwner(address newOwner) public onlyOwner {
        emit OwnerSet(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev Return owner address 
     * @return address of owner
     */
    function getOwner() external view returns (address) {
        return owner;
    }
}

interface IERC20 {

    function totalSupply() external view returns (uint256);
    
    function symbol() external view returns(string memory);
    
    function name() external view returns(string memory);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
    
    /**
     * @dev Returns the number of decimal places
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Distributor is Ownable {

    // token we are distributing to staking
    IERC20 public constant token = IERC20(0x5bB69934ca31a2a0b520FFb1496a076ffa9FD17e);

    // daily return of the staking pool
    uint256 public dailyReturn = 261160;
    uint256 private constant RETURN_DENOM = 10**9;

    // last time a distribution was made
    uint256 public lastTime;

    // contract address of the staking pool we are distributing rewards to
    address public stakingPool;

    // bounty reward per day
    uint256 public bountyRewardPerDay = 240 ether;

    constructor(
        address _stakingPool, 
        uint256 _timeBuffer
    ) {
        stakingPool = _stakingPool;
        lastTime = block.timestamp + _timeBuffer;
    }

    function setDailyReturn(uint256 _dailyReturn) external onlyOwner {
        dailyReturn = _dailyReturn;
    }

    function setBountyRewardPerDay(uint256 _bountyRewardPerDay) external onlyOwner {
        bountyRewardPerDay = _bountyRewardPerDay;
    }

    function withdrawToken(address _token, address to, uint256 amount) external onlyOwner {
        IERC20(_token).transfer(to, amount);
    }

    function withdrawETH(address to, uint256 amount) external onlyOwner {
        (bool s,) = payable(to).call{value: amount}("");
        require(s);
    }

    function setLastTime(uint256 _lastTime) external onlyOwner {
        lastTime = _lastTime;
    }

    function resetTimer() external onlyOwner {
        lastTime = block.timestamp;
    }

    function distribute() external {
        uint256 time = timeSince();
        if (time == 0) {
            return;
        }
        uint256 tvl = balanceInStaking();
        if (tvl == 0) {
            lastTime = block.timestamp;
            return;
        }

        // pending bounty reward
        uint256 bountyReward = pendingBountyReward();

        // determine amounts
        uint256 dailyAmount = ( tvl * dailyReturn ) / RETURN_DENOM;
        uint256 amountToDistribute = ( dailyAmount * time ) / 86400;

        // update last reward time
        lastTime = block.timestamp;

        // transfer to staking pool
        if (amountToDistribute > 0) {
            token.transfer(stakingPool, amountToDistribute);
        }

        // transfer bounty reward
        if (bountyReward > 0) {
            token.transfer(msg.sender, bountyReward);
        }
    }

    function timeSince() public view returns (uint256) {
        return block.timestamp > lastTime ? block.timestamp - lastTime : 0;
    }

    function balanceInStaking() public view returns (uint256) {
        return token.balanceOf(stakingPool);
    }

    function pendingBountyReward() public view returns (uint256) {
        uint256 time = timeSince();
        if (time == 0) {
            return 0;
        }

        // return amount
        return ( bountyRewardPerDay * time ) / 86400;
    }

    function pendingDistribution() external view returns (uint256) {
        uint256 time = timeSince();
        if (time == 0) {
            return 0;
        }
        uint256 tvl = balanceInStaking();
        if (tvl == 0) {
            return 0;
        }

        // determine amounts
        uint256 dailyAmount = ( tvl * dailyReturn ) / RETURN_DENOM;
        uint256 amount = ( dailyAmount * time ) / 86400;

        // clamp distribution to available balance
        uint256 balance = token.balanceOf(address(this));
        if (amount > balance) {
            amount = balance;
        }
        return amount;
    }
}
