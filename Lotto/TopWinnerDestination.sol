//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Ownable.sol";
import "./IERC20.sol";
import "./TransferHelper.sol";

contract TopWinnerDestination is Ownable {

    address public token;

    constructor(address _token) {
        token = _token;
    }

    function withdrawToken(address _token, uint256 amount, address to) external onlyOwner {
        TransferHelper.safeTransfer(_token, to, amount);
    }

    function withdrawETH(uint256 amount, address to) external onlyOwner {
        TransferHelper.safeTransferETH(to, amount);
    }

    function setToken(address _token) external onlyOwner {
        token = _token;
    }

    function sendToWinner(address winner) external onlyOwner {
        IERC20(token).transfer(winner, IERC20(token).balanceOf(address(this)));
    }

    function sendCustomAmountToWinner(address winner, uint256 amount) external onlyOwner {
        IERC20(token).transfer(winner, amount);
    }

    receive() external payable {}

}