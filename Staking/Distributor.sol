//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./IERC20.sol";
import "./Ownable.sol";

contract Distributor is Ownable {

    // token we are distributing to staking
    IERC20 public immutable token;

    // daily return of the staking pool
    uint256 public dailyReturn;
    uint256 private constant RETURN_DENOM = 10**9;

    // last time a distribution was made
    uint256 public lastTime;

    // contract address of the staking pool we are distributing rewards to
    address public stakingPool;

    constructor(
        address _token, 
        address _stakingPool, 
        uint256 _dailyReturn,
        uint256 _timeBuffer
    ) {
        token = IERC20(_token);
        stakingPool = _stakingPool;
        dailyReturn = _dailyReturn;
        lastTime = block.timestamp + _timeBuffer;
    }

    function setDailyReturn(uint256 _dailyReturn) external onlyOwner {
        dailyReturn = _dailyReturn;
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

        // determine amounts
        uint256 dailyAmount = ( tvl * dailyReturn ) / RETURN_DENOM;
        uint256 amountToDistribute = ( dailyAmount * time ) / 86400;

        // update last reward time
        lastTime = block.timestamp;

        // clamp distribution to available balance
        uint256 balance = token.balanceOf(address(this));
        if (amountToDistribute > balance) {
            amountToDistribute = balance;
        }

        // transfer to staking pool
        if (amountToDistribute > 0) {
            token.transfer(stakingPool, amountToDistribute);
        }
    }

    function timeSince() public view returns (uint256) {
        return block.timestamp > lastTime ? block.timestamp - lastTime : 0;
    }

    function balanceInStaking() public view returns (uint256) {
        return token.balanceOf(stakingPool);
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