//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Ownable.sol";
import "./IERC20.sol";

contract PointManager is Ownable, IERC20 {

    // Name + Symbol for wallet support
    string public override constant name = "OPHX Points";
    string public override constant symbol = "OPHX POINTS";

    // Total Points
    uint256 private totalPoints;

    // Permission To Award Points
    mapping ( address => bool ) public permissions;

    // Balances and Allowances
    mapping ( address => uint256 ) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    constructor() {
        emit Transfer(address(0), msg.sender, 0);
    }

    function setPermissions(address _address, bool _permission) external onlyOwner {
        permissions[_address] = _permission;
    }

    function balanceOf(address user) external view override returns (uint256) {
        return _balances[user];
    }

    function totalSupply() external view override returns (uint256) {
        return totalPoints;
    }

    function decimals() external pure override returns (uint8) {
        return 0;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        // ensure allowance has been given
        require(_allowances[from][msg.sender] >= amount, "PointManager: Insufficient Allowance");
        // decrement allowance
        _allowances[from][msg.sender] -= amount;
        // make the transfer
        return _transfer(from, to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        require(
            from != address(0) && to != address(0),
            "PointManager: Transfer from/to the zero address"
        );
        require(
            amount > 0, 
            "PointManager: Transfer amount must be greater than zero"
        );
        require(
            _balances[from] >= amount, 
            "PointManager: Insufficient Balance"
        );

        // make the transfer
        unchecked {
            _balances[from] -= amount;
            _balances[to] += amount;
        }

        // emit the transfer event
        emit Transfer(from, to, amount);
        return true;
    }

    function addPoints(address user, uint256 amount) external {
        require(
            permissions[msg.sender],
            "PointManager: Caller is not permitted to add points"
        );
        unchecked {
            _balances[user] += amount;
            totalPoints += amount;
        }
        emit Transfer(address(0), user, amount);
    }

    function burn(uint256 amount) external {
        require(
            _balances[msg.sender] >= amount,
            "PointManager: Insufficient Balance"
        );
        unchecked {
            _balances[msg.sender] -= amount;
            totalPoints -= amount;
        }
        emit Transfer(msg.sender, address(0), amount);
    }

}