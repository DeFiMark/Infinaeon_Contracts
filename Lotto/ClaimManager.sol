//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./IUniswapV2Router02.sol";
import "./IERC20.sol";
import "./Ownable.sol";
import "./TransferHelper.sol";

interface IClaimManager {
    function credit(address user) external payable;
}

/**
    Claim Manager inspired by pvp.money
    Check out https://pvp.money
 */
contract ClaimManager is Ownable, IClaimManager {

    // OPHX token
    address public immutable token;

    // Uniswap Router
    IUniswapV2Router02 public router;

    // Swap Path
    address[] public path;

    // Maps a user to a claim amount
    mapping ( address => uint256 ) public pendingClaim;

    // Fee taken when claiming as ETH
    uint256 public fee = 10;

    // Fee Receiver which buys and burns OPHX
    address public feeReceiver;

    constructor(
        address _token,
        address _router,
        address _feeReceiver
    ) {
        token = _token;
        router = IUniswapV2Router02(_router);
        feeReceiver = _feeReceiver;
        path = new address[](2);
        path[0] = router.WETH();
        path[1] = _token;
    }

    function withdrawETH(uint256 amount, address to) external onlyOwner {
        TransferHelper.safeTransferETH(to, amount);
    }

    function withdrawToken(address _token, uint256 amount, address to) external onlyOwner {
        TransferHelper.safeTransfer(_token, to, amount);
    }

    function setRouter(address _router) external onlyOwner {
        router = IUniswapV2Router02(_router);
    }

    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        feeReceiver = _feeReceiver;
    }

    function setPath(address[] calldata _path) external onlyOwner {
        path = _path;
    }

    function setFee(uint256 _fee) external onlyOwner {
        require(_fee < 100, "ClaimManager: fee must be < 100");
        fee = _fee;
    }

    function credit(address user) external payable {
        unchecked { pendingClaim[user] += msg.value; }
    }

    function claim(uint256 amountToken, uint256 amountETH, uint256 minOut) external {

        // get pending claim
        uint256 pending = pendingClaim[msg.sender];
        uint256 totalAmount = amountToken + amountETH;

        // validate there is a claim pending and their requested amount does not exceed this
        require(pending > 0, "ClaimManager: no claim available");
        require(totalAmount <= pending, "ClaimManager: amount exceeds claim");

        // reduce pending claim
        pendingClaim[msg.sender] -= totalAmount;

        // buy OPHX with amountToken, sending to user
        if (amountToken > 0) {
            router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amountToken}(
                minOut, path, msg.sender, block.timestamp + 300
            );
        }

        // take fee from amountETH, burn fee, send rest of ETH to user
        if (amountETH > 0) {

            // take fee
            uint256 feeTaken = ( amountETH * fee ) / 100;
            if (feeTaken > 0) {
                (bool s,) = payable(feeReceiver).call{value: feeTaken}("");
                require(s, "ClaimManager: failed to send fee");
            }
            
            // send the rest to the user
            (bool s1,) = payable(msg.sender).call{value: (amountETH - feeTaken)}("");
            require(s1, "ClaimManager: failed to send ETH");
        }

    }

    receive() external payable {}
}