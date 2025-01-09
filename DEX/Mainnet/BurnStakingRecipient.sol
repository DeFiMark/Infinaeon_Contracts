//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

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

contract BurnStakingRecipient is Ownable {

    address public pool0;
    address public pool1;
    
    function setPool0(address _pool0) external onlyOwner {
        pool0 = _pool0;
    }

    function setPool1(address _pool1) external onlyOwner {
        pool1 = _pool1;
    }

    function trigger() external {
        _trigger();
    }

    receive() external payable {
        _trigger();
    }
    
    function _trigger() internal {
        if (pool0 == address(0) || pool1 == address(0)) {
            return;
        }
        (bool success0,) = pool0.call{value: address(this).balance / 4}(new bytes(0));
        require(success0, 'Transfer Failed');
        (bool success1,) = pool1.call{value: address(this).balance}(new bytes(0));
        require(success1, 'Transfer Failed');
    }
}