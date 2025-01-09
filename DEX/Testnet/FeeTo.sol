//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

interface IFeeTo {
    function takeFee(address sender, address pair) external payable;
}

interface IOPHXFeeReceiver {
    function takeFee(address sender, address pair) external payable;
}

contract FeeTo is IFeeTo {

    uint256 public constant addr0Split = 25;
    address public addr0;

    uint256 public baseFeeCut = 10;

    address public ophxFeeReceiver;

    address public owner;

    struct Pair {
        uint256 valueHeld;
        uint256 totalFees;
        uint256 feeCut;
        address rewardPayoutDestination;
    }

    mapping ( address => Pair ) public pairs;

    modifier onlyOwner(){
        require(msg.sender == owner, 'Only Owner');
        _;
    }

    constructor(
        address _addr0,
        address _ophxFeeReceiver
    ) {
        addr0 = _addr0;
        ophxFeeReceiver = _ophxFeeReceiver;
        owner = msg.sender;
    }

    function withdraw(uint256 amount) external onlyOwner {
        TransferHelper.safeTransferETH(msg.sender, amount);
    }

    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        TransferHelper.safeTransfer(token, msg.sender, amount);
    }

    function changeOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function setOPHXFeeReceiver(address newOPHX) external onlyOwner {
        require(newOPHX != address(0), 'Invalid Address');
        ophxFeeReceiver = newOPHX;
    }

    function setAddr0(address newAddr0) external {
        require(msg.sender == addr0, 'Only Addr0');
        addr0 = newAddr0;
    }

    function setPairInfo(address pair, address rewardPayoutDestination, uint256 feeCut) external onlyOwner {
        pairs[pair].rewardPayoutDestination = rewardPayoutDestination;
        pairs[pair].feeCut = feeCut;
    }

    function setBaseFeeCut(uint256 newCut) external onlyOwner {
        require((newCut + addr0Split) < 100, 'Invalid Cut');
        baseFeeCut = newCut;
    }

    function triggerPairs(address[] calldata pairAddresses) external onlyOwner {
        uint len = pairAddresses.length;
        for (uint i = 0; i < len;) {
            _triggerPair(pairAddresses[i]);
            unchecked { ++i; }
        }
    }

    function _triggerPair(address pair) internal {
        if (pairs[pair].rewardPayoutDestination != address(0)) {

            uint256 value = pairs[pair].valueHeld;
            if (value > 0) {

                // remove value to protect against multiple claims
                delete pairs[pair].valueHeld;

                // send value to rewardPayoutDestination
                TransferHelper.safeTransferETH(pairs[pair].rewardPayoutDestination, value);
            }
        }
    }

    function getPairCut(address pair) external view returns (uint256) {
        return pairs[pair].feeCut == 0 ? baseFeeCut : pairs[pair].feeCut;
    }

    function takeFee(address sender, address pair) external override payable {

        // split value
        uint projectCut = ( msg.value * getPairCut(pair) ) / 100;
        uint addr0Cut = ( msg.value * addr0Split ) / 100;
        uint ophxCut = msg.value - ( addr0Cut + projectCut );

        // send ETH to fee recipient
        if (addr0Cut > 0) {
            TransferHelper.safeTransferETH(addr0, addr0Cut);
        }

        if (ophxCut > 0) {
            TransferHelper.safeTransferETH(ophxFeeReceiver, ophxCut);
        }

        // increase amount tracked for LP, so rewards aren't processed every tx
        unchecked {
            pairs[pair].valueHeld += projectCut;
            pairs[pair].totalFees += msg.value;
        }
    }

    receive() external payable {
        // split value
        uint addr0Cut = msg.value / 2;
        uint ophxCut = msg.value - addr0Cut;

        // send ETH to fee recipient
        if (addr0Cut > 0) {
            TransferHelper.safeTransferETH(addr0, addr0Cut);
        }

        if (ophxCut > 0) {
            TransferHelper.safeTransferETH(ophxFeeReceiver, ophxCut);
        }
    }
}