 //SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract WETH {
    string public name     = "Wrapped ETH";
    string public symbol   = "WETH";
    uint8  public decimals = 18;

    event  Approval(address indexed src, address indexed guy, uint wad);
    event  Transfer(address indexed src, address indexed dst, uint wad);

    mapping (address => uint)                       public  balanceOf;
    mapping (address => mapping (address => uint))  public  allowance;

    uint256 private totalShares;
    uint256 public constant PRECISION = 10**18;

    constructor() payable {
        require(msg.value > 0, "WETH: INVALID_INITIAL_BALANCE");
        totalShares = msg.value;
        balanceOf[address(0)] = msg.value;
        emit Transfer(address(0), address(0), msg.value);
    }

    receive() external payable {
        _mint(msg.sender, msg.value);
    }

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function depositFor(address account) external payable {
        _mint(account, msg.value);
    }

    function raisePrice() external payable {}

    function withdraw(uint wad) external {
        require(balanceOf[msg.sender] >= wad, "WETH: INSUFFICIENT_BALANCE");

        // get eth amount
        uint ethAmount = amountOut(wad);
        
        // reduce balance
        unchecked {
            balanceOf[msg.sender] -= wad;
            totalShares -= wad;
        }

        // emit event
        emit Transfer(msg.sender, address(0), wad);

        // send ETH
        (bool s,) = payable(msg.sender).call{value: ethAmount}("");
        require(s, "WETH: TRANSFER_FAILED");
    }

    function totalSupply() public view returns (uint) {
        return totalShares;
    }

    function approve(address guy, uint wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad)
    public
    returns (bool)
    {
        require(balanceOf[src] >= wad, "WETH: INSUFFICIENT_BALANCE");

        if (src != msg.sender && allowance[src][msg.sender] != ~uint(0)) {
            require(allowance[src][msg.sender] >= wad, "WETH: INSUFFICIENT_ALLOWANCE");
            unchecked {
                allowance[src][msg.sender] -= wad;
            }
        }

        unchecked {
            balanceOf[src] -= wad;
            balanceOf[dst] += wad;
        }
        emit Transfer(src, dst, wad);
        return true;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) external {
        require(
            allowance[account][msg.sender] >= amount,
            'WETH: INSUFFICIENT_ALLOWANCE'
        );
        unchecked {
            allowance[account][msg.sender] -= amount;
        }
        _burn(account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(balanceOf[account] >= amount, "WETH: INSUFFICIENT_BALANCE");
        unchecked {
            balanceOf[account] -= amount;
            totalShares -= amount;
        }
        emit Transfer(account, address(0), amount);
    }

    function _mint(address account, uint256 amountWETH) internal {
        uint256 shares = ( ( amountWETH * totalShares ) / ( address(this).balance - amountWETH ) ) - 1;
        unchecked {
            balanceOf[account] += shares;
            totalShares += shares;
        }
        emit Transfer(address(0), account, shares);
    }

    function getPrice() public view returns (uint) {
        return ( address(this).balance * PRECISION ) / totalShares;
    }

    function amountOut(uint256 amountWETH) public view returns (uint) {
        return ( ( amountWETH * getPrice() ) / PRECISION ) - 1; // subtract one to avoid rounding errors and ensure getPrice() will never decrease
    }

    function getShares(uint256 amountETH) external view returns (uint) {
        return ( ( amountETH * totalShares ) / address(this).balance ) - 1;
    }
}