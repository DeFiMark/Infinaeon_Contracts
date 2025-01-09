//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract TradeMiningTracker {

    mapping ( address => uint256 ) public tradeMiningRewards;

    address public updater;
    address public owner;

    constructor() {
        owner = msg.sender;
    }
    
    function setUpdater(address _updater) external {
        require(msg.sender == owner, 'Only Owner');
        updater = _updater;
    }

    function setOwner(address _owner) external onlyOwner {
        require(msg.sender == owner, 'Only Owner');
        owner = _owner;
    }

    function gaveRewards(address user, uint256 amount) external {
        require(msg.sender == updater, 'Not Updater');
        unchecked {
            tradeMiningRewards[user] += amount;
        }
    }
}