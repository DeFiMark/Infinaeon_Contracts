// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Ownable.sol";
import "./TransferHelper.sol";
import "./IVRF.sol";

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

/**
    Chainlink subscription owner contract, 
    inherited from the one deployed by pvp.money
    check out https://pvp.money to see it in action
 */
contract ChainlinkSubscriptionOwner is Ownable {

    // VRF Coordinator
    VRFCoordinatorV2Interface public immutable COORDINATOR;

    // Chainlink LINK Token
    LinkTokenInterface public immutable LINKTOKEN;

    // Storage parameters
    uint64 public s_subscriptionId;

    // Link buyer
    address public linkBuyer;

    // Pausable functionality
    bool public paused;

    constructor(
        address coordinator_,
        address linkToken
    ) {
        COORDINATOR = VRFCoordinatorV2Interface(coordinator_);
        LINKTOKEN = LinkTokenInterface(linkToken);

        // create subscription, saving the subscription ID
        _createSubscription();
    }

    // creates a subscription if one has not yet been created (or has been cancelled)
    function createSubscription() external onlyOwner {
        _createSubscription();
    }

    // Sets the link buyer address
    function setLinkBuyer(address newBuyer) external onlyOwner {
        require(newBuyer != address(0), 'Zero Address');
        linkBuyer = newBuyer;
    }

    // Add a consumer contract to the subscription.
    function addConsumer(address consumerAddress) external onlyOwner {
        require(consumerAddress != address(0), 'Zero Address');
        COORDINATOR.addConsumer(s_subscriptionId, consumerAddress);
    }

    // Remove a consumer contract from the subscription.
    function removeConsumer(address consumerAddress) external onlyOwner {
        require(consumerAddress != address(0), 'Zero Address');
        COORDINATOR.removeConsumer(s_subscriptionId, consumerAddress);
    }

    // Cancel the subscription and send the remaining LINK to a wallet address.
    function cancelSubscription(address receivingWallet) external onlyOwner {
        require(receivingWallet != address(0), 'Zero Address');
        COORDINATOR.cancelSubscription(s_subscriptionId, receivingWallet);
        s_subscriptionId = 0;
    }

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

    // Sets Paused, Pausing the purchase of LINK
    function setPaused(bool isPaused) external onlyOwner {
        paused = isPaused;
    }

    // Tops up, regardless if paused or not, and can use internal balance
    function ownerTopUp(uint256 minOut, uint256 amount, bool useFullBalance) external onlyOwner {
        // buy link, using CHAINLINK Price Oracle to determine minOut, convert to ERC677 if applicable
        uint256 received = _buyLink(amount);

        // ensure balance
        require(
            received >= minOut,
            'Insufficient Out'
        );

        // top up subscription
        topUpSubscriptionWithInternalLink(
            useFullBalance ? LINKTOKEN.balanceOf(address(this)) : received
        );
    }

    receive() external payable {
        if (paused) {
            return;
        }
        _topUp(1);
    }

    // top up this contract with LINK by providing ETH
    function topUp(uint256 minOut) external payable {
        if (paused) {
            return;
        }
        _topUp(minOut);
    }


    // Assumes this contract owns link.
    // 1000000000000000000 = 1 LINK
    function topUpSubscriptionWithInternalLink(uint256 amount) public {
        LINKTOKEN.transferAndCall(
            address(COORDINATOR),
            amount,
            abi.encode(s_subscriptionId)
        );
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
        topUpSubscriptionWithInternalLink(LINKTOKEN.balanceOf(address(this)));
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

    function _createSubscription() internal {
        require(
            s_subscriptionId == 0,
            'Zero Subscription'
        );

        //Create a new subscription when you deploy the contract.
        s_subscriptionId = COORDINATOR.createSubscription();
    }

    function getSubscription()
    external
    view
    returns (
      uint96 balance,
      uint64 reqCount,
      address owner,
      address[] memory consumers
    ) {
        return COORDINATOR.getSubscription(s_subscriptionId);
    }
    
    function getLinkBalanceInVRF() external view returns (uint96) {
        (uint96 balance,,,) = COORDINATOR.getSubscription(s_subscriptionId);
        return balance;
    }

    function getLinkBalanceInContract() external view returns (uint256) {
        return LINKTOKEN.balanceOf(address(this));
    }

    function getSubscriptionID() external view returns (uint64) {
        return s_subscriptionId;
    }

    function getLinkToken() external view returns (address) {
        return address(LINKTOKEN);
    }

    function getCoordinator() external view returns (address) {
        return address(COORDINATOR);
    }
}
