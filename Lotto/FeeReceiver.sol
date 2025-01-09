//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./IUniswapV2Router02.sol";
import "./IERC20.sol";
import "./Ownable.sol";
import "./TransferHelper.sol";

/**
    Claim Manager inspired by pvp.money
    Check out https://pvp.money
 */
contract FeeReceiver is Ownable {

    // OPHX token
    address public immutable token;

    // Uniswap Router
    IUniswapV2Router02 public router;

    // Swap Path
    address[] public path;

    // Total OPHX Burned
    uint256 public totalBurned;

    // Total OPHX Bought
    uint256 public totalBought;

    // Dead wallet, only way to burn OPHX
    address public constant deadWallet = 0x000000000000000000000000000000000000dEaD;

    // Percentage going to the top winner
    uint256 public topWinnerPercentage = 5;
    address public topWinnerDestinationWallet = 0xC3250b0EdA6c5D5a96eCbA9AC799cAAC8d076287;

    // Permission to call trigger
    mapping ( address => bool ) public permissions;

    constructor(
        address _token,
        address _router
    ) {
        token = _token;
        router = IUniswapV2Router02(_router);
        path = new address[](2);
        path[0] = router.WETH();
        path[1] = _token;
        permissions[msg.sender] = true;
    }

    function withdrawETH(uint256 amount, address to) external onlyOwner {
        TransferHelper.safeTransferETH(to, amount);
    }

    function withdrawToken(address _token, uint256 amount, address to) external onlyOwner {
        TransferHelper.safeTransfer(_token, to, amount);
    }

    function setPermissions(address _address, bool _permission) external onlyOwner {
        permissions[_address] = _permission;
    }

    function setRouter(address _router) external onlyOwner {
        router = IUniswapV2Router02(_router);
    }

    function setTopWinnerPercentage(uint256 _topWinnerPercentage) external onlyOwner {
        require(_topWinnerPercentage < 100, "FeeReceiver: topWinnerPercentage must be < 100");
        topWinnerPercentage = _topWinnerPercentage;
    }

    function setTopWinnerDestinationWallet(address _topWinnerDestinationWallet) external onlyOwner {
        topWinnerDestinationWallet = _topWinnerDestinationWallet;
    }

    function setPath(address[] calldata _path) external onlyOwner {
        path = _path;
    }

    function trigger(uint256 minOut) external payable {
        require(
            permissions[msg.sender],
            "FeeReceiver: caller is not permitted"
        );
        
        // if there are native assets in this contract
        if (address(this).balance > 0) {
            // increment total bought
            unchecked { totalBought += address(this).balance; }
            // make the swap
            router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: address(this).balance}(
                minOut, path, address(this), block.timestamp + 300
            );
        }

        // get OPHX balance
        uint256 balance = IERC20(token).balanceOf(address(this));

        // split OPHX to top winner
        uint256 topWinnerAmount = ( balance * topWinnerPercentage ) / 100;
        TransferHelper.safeTransfer(token, topWinnerDestinationWallet, topWinnerAmount);

        // send the rest to dead wallet
        uint256 rest = balance - topWinnerAmount;

        // increment total burned
        unchecked { totalBurned += rest; }

        // if there are OPHX in this contract
        if (rest > 0) {
            // send to dead wallet
            IERC20(token).transfer(deadWallet, rest);
        }
    }

    receive() external payable {}
}