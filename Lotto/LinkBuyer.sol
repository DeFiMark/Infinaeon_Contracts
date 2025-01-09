//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./IUniswapV2Router02.sol";
import "./IERC20.sol";

interface IPegSwap {
   /**
    * @notice exchanges the source token for target token
    * @param amount count of tokens being swapped
    * @param source the token that is being given
    * @param target the token that is being taken
    */
  function swap(
    uint256 amount,
    address source,
    address target
  ) external;

  /**
   * @notice returns the amount of tokens for a pair that are available to swap
   * @param source the token that is being given
   * @param target the token that is being taken
   * @return amount count of tokens available to swap
   */
  function getSwappableAmount(
    address source,
    address target
  ) external view returns(uint256 amount);
}

/**
    Responsible for buying link with ETH, and converting to valid link if possible (ERC677)
 */
contract LinkBuyer {

    // Peg swap to convert ERC20 Link into ERC677 Link
    IPegSwap public immutable pegSwap;

    // DEX router to convert ETH to Link
    IUniswapV2Router02 public immutable router;

    // ERC20 Link that is bought from the DEX
    address public immutable erc20Link;

    // ERC677 Link that is swapped via PegSwap
    address public immutable erc677Link;

    // Swap path between WETH and LINK
    address[] public path;

    constructor(
        address pegSwap_,   // BSC: 0x1FCc3B22955e76Ca48bF025f1A6993685975Bb9e
        address router_,    // BSC: 0x10ED43C718714eb63d5aA57B78B54704E256024E
        address erc20Link_, // BSC: 0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD
        address erc677Link_ // BSC: 0x404460C6A5EdE2D891e8297795264fDe62ADBB75
    ) {
        // set swap routers
        router = IUniswapV2Router02(router_);
        pegSwap = IPegSwap(pegSwap_);

        // set link token addresses
        erc20Link = erc20Link_;
        erc677Link = erc677Link_;

        // set swap path
        path = new address[](2);
        path[0] = IUniswapV2Router02(router_).WETH();
        path[1] = erc20Link_;
    }



    receive() external payable {
        
        // buy link from router
        router.swapExactETHForTokens{value: address(this).balance}(
            1, path, address(this), block.timestamp + 300
        );

        // fetch balance
        uint256 balance = IERC20(erc20Link).balanceOf(address(this));
        require(balance > 0, 'ZERO BALANCE');

        // clamp balance to available swap amount
        uint256 availableToSwap = pegSwap.getSwappableAmount(erc20Link, erc677Link);
        if (balance > availableToSwap) {
            balance = availableToSwap;
        }
        if (balance == 0) {
            return;
        }

        // approve of link for pegswap router
        IERC20(erc20Link).approve(address(pegSwap), balance);

        // make the swap on pegSwap router
        pegSwap.swap(balance, erc20Link, erc677Link);

        // transfer all ERC677 link over to msg.sender
        IERC20(erc677Link).transfer(msg.sender, IERC20(erc677Link).balanceOf(address(this)));
    }

}