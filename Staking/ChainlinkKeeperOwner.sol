// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Ownable.sol";
import "./TransferHelper.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 * VRF Contracts: https://docs.chain.link/docs/vrf-contracts/#configurations
 */

interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);

  function approve(address spender, uint256 value) external returns (bool success);

  function balanceOf(address owner) external view returns (uint256 balance);

  function decimals() external view returns (uint8 decimalPlaces);

  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

  function increaseApproval(address spender, uint256 subtractedValue) external;

  function name() external view returns (string memory tokenName);

  function symbol() external view returns (string memory tokenSymbol);

  function totalSupply() external view returns (uint256 totalTokensIssued);

  function transfer(address to, uint256 value) external returns (bool success);

  function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);

  function transferFrom(address from, address to, uint256 value) external returns (bool success);
}


contract ChainlinkKeeperOwner is Ownable {

    address public constant registry = 0xDc21E279934fF6721CaDfDD112DAfb3261f09A2C;

    // Chainlink LINK Token
    LinkTokenInterface public constant LINKTOKEN = LinkTokenInterface(0x404460C6A5EdE2D891e8297795264fDe62ADBB75);

    // link buyer
    address public constant linkBuyer = 0x2B00bDAA09D4D1a8F6063F6b60E8048C984D4118;

    // min link
    uint256 public constant minLink = 1e17;

    // upkeepId to fund account
    uint256 public upkeepId = 55443577667390338768298829436237209397164736546107777674294882711508994549627;

    // Transfer this contract's LINK balance to an address.
    function withdrawLink(uint256 amount, address to) external onlyOwner {
        LINKTOKEN.transfer(to, amount);
    }

    // Transfer contract tokens to an address
    function withdrawToken(address token, uint256 amount, address to) external onlyOwner {
        TransferHelper.safeTransfer(token, to, amount);
    }

    // Transfer contract ETH to an address
    function withdrawETH(uint256 amount, address to) external onlyOwner {
        TransferHelper.safeTransferETH(to, amount);
    }

    // set upkeepid
    function setUpkeepId(uint256 _upkeepId) external onlyOwner {
        upkeepId = _upkeepId;
    }

    function topUp(uint256 minOut) external payable {
        _topUp(minOut);
    }

    receive() external payable {
        _topUp(1);
    }

    function _topUp(uint256 minOut) internal {

        // buy link, using CHAINLINK Price Oracle to determine minOut, convert to ERC677 if applicable
        uint256 received = _buyLink(msg.value);

        // ensure balance
        require(
            received >= minOut,
            'Insufficient Out'
        );

        // top up subscription
        _topUpWithInternalLink(received);
    }

    function _buyLink(uint256 amount) internal returns (uint256){

        // note balance before swap
        uint256 balBefore = LINKTOKEN.balanceOf(address(this));

        // perform the swap
        (bool s,) = payable(linkBuyer).call{value: amount}("");
        require(s, 'Failure To Buy Link');

        // note balance after swap
        uint256 balAfter = LINKTOKEN.balanceOf(address(this));

        // return the difference
        require(balAfter > balBefore, 'Zero Received');
        return balAfter - balBefore;
    }

    function topUpWithInternalLink(uint256 amount) external {
        _topUpWithInternalLink(amount);
    }

    function _topUpWithInternalLink(uint256 amount) internal {
        if (amount < minLink) {
            return;
        }
        LINKTOKEN.transferAndCall(
            registry,
            amount,
            abi.encode(upkeepId)
        );
    }
}