// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Ownable.sol";
import "./TransferHelper.sol";

interface IChainlinkContract {
    function getLinkBalanceInVRF() external view returns (uint96);
}

contract ChainlinkFeeReceiver is Ownable {

    address public chainlinkOwner = 0x1A7B4790A47a8488C3dA183CBC193cd3F6DcCc0c;
    address public jackpotKeeperOwner = 0x84c630626330168aBAb2eaE19eF67367aE88c440;
    address public maxiKeeperOwner = 0x867d9091682120B82b7C750b38fCFfeD7a736132;

    uint256 public minValueToTrigger = 0.2 ether;
    uint256 public splitForJackpotKeeper = 10;
    uint256 public splitForMaxiKeeper = 60;

    address private maxedContractsRecipient;

    constructor(
        address _maxedContractsRecipient
    ) {
        maxedContractsRecipient = _maxedContractsRecipient;
    }

    function setChainlinkOwner(address _chainlinkOwner) external onlyOwner {
        chainlinkOwner = _chainlinkOwner;
    }

    function setJackpotKeeperOwner(address _jackpotKeeperOwner) external onlyOwner {
        jackpotKeeperOwner = _jackpotKeeperOwner;
    }

    function setMaxiKeeperOwner(address _maxiKeeperOwner) external onlyOwner {
        maxiKeeperOwner = _maxiKeeperOwner;
    }

    function setMinValueToTrigger(uint256 _minValueToTrigger) external onlyOwner {
        minValueToTrigger = _minValueToTrigger;
    }

    function setSplitForJackpotKeeper(uint256 _splitForJackpotKeeper) external onlyOwner {
        require(_splitForJackpotKeeper <= 100, "ChainlinkFeeReceiver: splitForJackpotKeeper must be <= 100");
        splitForJackpotKeeper = _splitForJackpotKeeper;
    }

    function setSplitForMaxiKeeper(uint256 _splitForMaxiKeeper) external onlyOwner {
        require(_splitForMaxiKeeper <= 100, "ChainlinkFeeReceiver: splitForMaxiKeeper must be <= 100");
        splitForMaxiKeeper = _splitForMaxiKeeper;
    }

    function setMaxedContractsRecipient(address _maxedContractsRecipient) external {
        require(msg.sender == maxedContractsRecipient, "ChainlinkFeeReceiver: caller is not maxedContractsRecipient");
        maxedContractsRecipient = _maxedContractsRecipient;
    }

    // Transfer contract tokens to an address
    function withdrawToken(address token, uint256 amount, address to) external onlyOwner {
        TransferHelper.safeTransfer(token, to, amount);
    }

    // Transfer contract ETH to an address
    function withdrawETH(uint256 amount, address to) external onlyOwner {
        TransferHelper.safeTransferETH(to, amount);
    }

    function forceSplit() external payable onlyOwner {
        uint256 jackpotKeeperSplit = ( address(this).balance * splitForJackpotKeeper ) / 100;
        uint256 maxiKeeperSplit = ( address(this).balance * splitForMaxiKeeper ) / 100;
        _send(jackpotKeeperOwner, jackpotKeeperSplit);
        _send(maxiKeeperOwner, maxiKeeperSplit);
        _send(chainlinkOwner, address(this).balance);
    }

    function forceMaxxed() external payable onlyOwner {
        (bool success, ) = payable(maxedContractsRecipient).call{value: address(this).balance}("");
        require(success, "ChainlinkFeeReceiver: failed to send maxedContractsRecipient");
    }

    function forceTrigger() external onlyOwner {
        _trigger();
    }

    function trigger() external payable {
        if (address(this).balance >= minValueToTrigger) {
            _trigger();
        }
    }

    receive() external payable {
        if (address(this).balance >= minValueToTrigger) {
            _trigger();
        }
    }

    function getVRFBalances() external view returns (uint96, uint96, uint96) {
        return (IChainlinkContract(chainlinkOwner).getLinkBalanceInVRF(), IChainlinkContract(jackpotKeeperOwner).getLinkBalanceInVRF(), IChainlinkContract(maxiKeeperOwner).getLinkBalanceInVRF());
    }

    function _trigger() internal {
        uint256 remainBalance = address(this).balance / 10;
        uint256 jackpotKeeperSplit = ( remainBalance * splitForJackpotKeeper ) / 100;
        uint256 maxiKeeperSplit = ( remainBalance * splitForMaxiKeeper ) / 100;
        uint256 vrfSplit = remainBalance - jackpotKeeperSplit - maxiKeeperSplit;

        _send(jackpotKeeperOwner, jackpotKeeperSplit);
        _send(chainlinkOwner, vrfSplit);
        _send(maxiKeeperOwner, maxiKeeperSplit);

        if (address(this).balance > 0) {
            _send(maxedContractsRecipient, address(this).balance);
        }
    }

    function _send(address to, uint256 amount) internal {
        if (to == address(0) || amount == 0) {
            return;
        }
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "ChainlinkFeeReceiver: failed to send");
    }
}