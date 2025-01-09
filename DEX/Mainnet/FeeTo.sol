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
    function takeFee(address sender) external payable;
}

contract FeeTo is IFeeTo {

    uint256 public addr0Split = 15;
    address public addr0;

    address public ophxFeeReceiver;
    address public owner;

    // pending OPHX amount
    uint256 public pendingOPHXCut;

    struct Pair {
        uint256 totalFees;
        uint256 feeCut;
        address rewardPayoutDestination;
        address ref;
        uint256 refCut;
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

    function setAddr0Split(uint256 newSplit) external {
        require(msg.sender == addr0, 'Only Addr0');
        addr0Split = newSplit;
    }

    function claimOPHXCut() external {
        uint256 pending = pendingOPHXCut;
        require(pending > 0, 'No Pending OPHX Cut');
        TransferHelper.safeTransferETH(ophxFeeReceiver, pendingOPHXCut);
        delete pendingOPHXCut;
    }

    function setPairInfo(address pair, address rewardPayoutDestination, uint256 feeCut) external onlyOwner {
        require(feeCut < 100, 'Invalid Cut');
        pairs[pair].rewardPayoutDestination = rewardPayoutDestination;
        pairs[pair].feeCut = feeCut;
    }

    function setRefInfo(address pair, address ref, uint256 refCut) external onlyOwner {
        require(refCut < 100, 'Invalid Cut');
        pairs[pair].ref = ref;
        pairs[pair].refCut = refCut;
    }

    function getPairCut(address pair) public view returns (uint256) {
        if (pairs[pair].rewardPayoutDestination == address(0)) {
            return 0;
        }
        return pairs[pair].feeCut;
    }

    function takeFee(address sender, address pair) external override payable {

        // split value
        uint projectCut = ( msg.value * getPairCut(pair) ) / 100;
        uint refCut = pairs[pair].ref != address(0) ? ( msg.value * pairs[pair].refCut ) / 100 : 0;
        uint addr0Cut = ( msg.value * addr0Split ) / 100;
        uint ophxCut = msg.value - ( addr0Cut + projectCut + refCut );

        // send ETH to fee recipient
        if (addr0Cut > 0) {
            TransferHelper.safeTransferETH(addr0, addr0Cut);
        }

        if (ophxCut > 0) {
            IOPHXFeeReceiver(ophxFeeReceiver).takeFee{value: ophxCut}(sender);
        }

        if (refCut > 0) {
            TransferHelper.safeTransferETH(pairs[pair].ref, refCut);
        }

        if (projectCut > 0) {
            TransferHelper.safeTransferETH(pairs[pair].rewardPayoutDestination, projectCut);
        }

        // track trades per LP
        unchecked {
            pairs[pair].totalFees += msg.value;
        }
    }

    receive() external payable {}
}