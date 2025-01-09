//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title Owner
 * @dev Set & change owner
 */
contract Ownable {

    address private owner;
    
    // event for EVM logging
    event OwnerSet(address indexed oldOwner, address indexed newOwner);
    
    // modifier to check if caller is owner
    modifier onlyOwner() {
        // If the first argument of 'require' evaluates to 'false', execution terminates and all
        // changes to the state and to Ether balances are reverted.
        // This used to consume all gas in old EVM versions, but not anymore.
        // It is often a good idea to use 'require' to check if functions are called correctly.
        // As a second argument, you can also provide an explanation about what went wrong.
        require(msg.sender == owner, "Caller is not owner");
        _;
    }
    
    /**
     * @dev Set contract deployer as owner
     */
    constructor() {
        owner = msg.sender; // 'msg.sender' is sender of current call, contract deployer for a constructor
        emit OwnerSet(address(0), owner);
    }

    /**
     * @dev Change owner
     * @param newOwner address of new owner
     */
    function changeOwner(address newOwner) public onlyOwner {
        emit OwnerSet(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev Return owner address 
     * @return address of owner
     */
    function getOwner() external view returns (address) {
        return owner;
    }
}

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeApprove: approve failed'
        );
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeTransfer: transfer failed'
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::transferFrom: transferFrom failed'
        );
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    }
}


interface IReceiver {
    function receiveFee(bytes calldata data) external payable;
}

contract InfinaeonFeeSplitter is Ownable {

    // list of all recipients
    address[] public recipients;

    // maps address to allocation of points
    mapping ( address => uint256 ) public allocation;

    // total points allocated
    uint256 public totalAllocation;

    // Maps addresses to permission to call trigger
    mapping ( address => bool ) public canTrigger;

    modifier onlyApproved() {
        require(
            canTrigger[msg.sender] == true,
            'Only Authorized'
        );
        _;
    }

    constructor() {
        canTrigger[msg.sender] = true;
    }

    function withdraw(address token, address to, uint256 amount) external onlyOwner {
        TransferHelper.safeTransfer(token, to, amount);
    }

    function withdrawETH(address to, uint256 amount) external onlyOwner {
        TransferHelper.safeTransferETH(to, amount);
    }

    function setCanTrigger(address addr, bool _canTrigger) external onlyOwner {
        canTrigger[addr] = _canTrigger;
    }

    function addRecipient(address newRecipient, uint256 newAllocation) external onlyOwner {
        require(
            allocation[newRecipient] == 0,
            'Already Added'
        );

        // add to list
        recipients.push(newRecipient);

        // set allocation and increase total allocation
        allocation[newRecipient] = newAllocation;
        unchecked {
            totalAllocation += newAllocation;
        }
    }

    function removeRecipient(address recipient, uint256 index) external onlyOwner {
        require(
            recipients[index] == recipient,
            'Invalid Recipient Index'
        );

        // ensure recipient is in the system
        uint256 allocation_ = allocation[recipient];
        require(
            allocation_ > 0,
            'User Not Present'
        );

        // delete allocation, subtract from total allocation
        delete allocation[recipient];
        unchecked {
            totalAllocation -= allocation_;
        }

        // swap positions with last element then pop last element off
        recipients[index] = recipients[recipients.length - 1];
        recipients.pop();
    }

    function setAllocation(address recipient, uint256 newAllocation) external onlyOwner {

        // ensure recipient is in the system
        uint256 allocation_ = allocation[recipient];
        require(
            allocation_ > 0,
            'User Not Present'
        );

        // adjust their allocation and the total allocation
        allocation[recipient] = newAllocation;
        totalAllocation = ( totalAllocation + newAllocation ) - allocation_;
    }

    function triggerETH(bytes[] calldata data) external onlyApproved {

        // Ensure an ETH balance
        require(
            address(this).balance > 0,
            'Zero Amount'
        );

        // split balance into distributions
        uint256[] memory distributions = splitAmount(address(this).balance);

        // transfer distributions to each recipient
        uint len = distributions.length;
        for (uint i = 0; i < len;) {
            _sendETH(recipients[i], distributions[i], data[i]);
            unchecked { ++i; }
        }
    }

    function _sendETH(address to, uint amount, bytes calldata data) internal {
        IReceiver(to).receiveFee{value: amount}(data);
    }

    function getRecipients() external view returns (address[] memory) {
        return recipients;
    }

    function splitAmount(uint256 amount) public view returns (uint256[] memory distributions) {

        // length of recipient list
        uint256 len = recipients.length;
        distributions = new uint256[](len);

        // loop through recipients, setting their allocations
        for (uint i = 0; i < len;) {
            distributions[i] = ( ( amount * allocation[recipients[i]] ) / totalAllocation );
            unchecked { ++i; }
        }
    }

    receive() external payable {}
}