//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./IERC20.sol";
import "./IUniswapV2Router02.sol";

contract TaxedSwapper {

    // Token To Swap
    address public immutable token;

    // router
    IUniswapV2Router02 public router;

    // path
    address[] public path;

    constructor(address _token, address _DEX) {
        token = _token;
        router = IUniswapV2Router02(_DEX);
        path = new address[](2);
        path[0] = router.WETH();
        path[1] = _token;
    }

    function buyToken(address recipient, uint minOut) external payable {
        _buyToken(recipient, msg.value, minOut);
    }

    function buyToken(address recipient) external payable {
        _buyToken(recipient, msg.value, 0);
    }

    function buyToken() external payable {
        _buyToken(msg.sender, msg.value, 0);
    }

    receive() external payable {
        _buyToken(msg.sender, msg.value, 0);
    }

    function _buyToken(address recipient, uint value, uint minOut) internal {
        require(
            value > 0,
            'Zero Value'
        );
        require(
            recipient != address(0),
            'Recipient Cannot Be Zero'
        );

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: address(this).balance}(
            minOut,
            path,
            recipient,
            block.timestamp + 300
        );
    }

    function _send(address to, uint val) internal {
        (bool s,) = payable(to).call{value: val}("");
        require(s);
    }
}