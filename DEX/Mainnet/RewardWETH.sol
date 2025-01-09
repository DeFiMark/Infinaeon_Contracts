//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Ownable.sol";
import "./IERC20.sol";
import "./TransferHelper.sol";
import "./ReentrancyGuard.sol";

interface IMintManager {
    function getMintFee(address user) external view returns (uint256);
    function getSellFee(address user) external view returns (uint256);
}

contract xBNB is Ownable, IERC20 {

    string public constant override name     = "xBNB";
    string public constant override symbol   = "XBNB";
    uint8  public constant override decimals = 18;

    // constant values
    uint256 private constant PRECISION = 10**18;
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;

    // total supply
    uint256 private _totalSupply;

    // transaction fees
    uint256 private constant FEE_DENOM = 100_000; // 0.001% fee precision

    // Minter, determines the fees required for a specific address to mint new tokens
    IMintManager public mintManager;

    mapping (address => uint256)                       public  balanceOf;
    mapping (address => mapping (address => uint256))  public  allowance;

    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);

    constructor() payable {

        // allocates some supply to DEAD wallet to ensure the _totalSupply never reaches zero
        uint256 deadAllocation = 0.0001 ether;
        require(msg.value > deadAllocation, 'Invalid Value');

        // value for user
        uint256 userValue = msg.value - deadAllocation;

        // pre-set the total supply
        _totalSupply = msg.value;

        // mint tokens to user
        balanceOf[msg.sender] = userValue;
        emit Transfer(address(0), msg.sender, userValue);

        // mint tokens to dead
        balanceOf[DEAD] = deadAllocation;
        emit Transfer(address(0), DEAD, deadAllocation);
    }

    function setMintManager(address mintManager_) external onlyOwner {
        mintManager = IMintManager(mintManager_);
    }

    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    function deposit() external payable {
        _deposit(msg.sender, msg.value);
    }

    function donate() external payable {}

    function depositFor(address user) external payable returns (uint256) {
        return _deposit(user, msg.value);
    }

    function withdraw(uint wad) external nonReentrant {
        _withdraw(msg.sender, wad);
    }

    function totalSupply() external view returns (uint) {
        return _totalSupply;
    }

    function approve(address guy, uint wad) external returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint wad) external returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad)
    public
    returns (bool)
    {
        require(balanceOf[src] >= wad, 'Insufficient Balance');
        if (src != msg.sender && allowance[src][msg.sender] != uint(-1)) {
            require(allowance[src][msg.sender] >= wad, 'Insufficient Allowance');
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);
        return true;
    }

    function _deposit(address dst, uint wad) internal nonReentrant returns (uint256 nMinted) {
        require(dst != address(0), 'Zero Address');
        require(dst != DEAD, 'Dead Address');
        require(wad > 0, 'Zero Value');

        // get mint fee
        uint256 numTokensToMint = tokensToMint(dst, wad, address(this).balance - wad);
        require(numTokensToMint > 0, 'Mints Zero Tokens');

        // add balance to dest and total supply
        unchecked {
            balanceOf[dst] += numTokensToMint;
            _totalSupply += numTokensToMint;
        }
        emit Transfer(address(0), dst, numTokensToMint);

        return numTokensToMint;
    }

    function _withdraw(address account, uint256 amount) internal returns (uint256 bnbOut) {
        require(balanceOf[account] >= amount, 'Insufficient Balance');
        require(account != DEAD, 'Dead Address');

        // determine the value of tokens
        bnbOut = amountOut(amount);

        // reduce supply and balance
        balanceOf[account] -= amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);

        // send funds
        TransferHelper.safeTransferETH(account, bnbOut);
    }

    /** Number Of Tokens To Mint */
    function tokensToMint(
        address user,
        uint256 received,
        uint256 totalBacking
    ) public view returns (uint256) {
        uint256 mintFee = getMintFee(user);
        uint256 mintFeeDenom = FEE_DENOM - mintFee;
        return
            : mintFee == 0
            ? ( ( _totalSupply * received ) / totalBacking )
            : ( ( ( _totalSupply * received ) / ( totalBacking + ( ( amount * mintFee ) / FEE_DENOM ) ) ) * mintFeeDenom ) / FEE_DENOM;
    }

    function calculatePrice() external view returns (uint256) {
        return _calculatePrice();
    }

    function _calculatePrice() internal view returns (uint256) {
        if (_totalSupply == 0) {
            return PRECISION;
        }
        return ( address(this).balance * PRECISION ) / _totalSupply;
    }

    function amountOut(address seller, uint256 amountToSell) public view returns (uint256) {
        uint256 amount = ( amountToSell * _calculatePrice() ) / PRECISION;
        uint256 sellFee = getSellFee(seller);
        // NOTE: User Minter to determine this?
        return amount - ( ( amount * sellFee ) / FEE_DENOM );
    }

    function getMintFee(address user) public view returns (uint256) {
        uint256 fee = IMintManager(mintManager).getMintFee(user);
        return fee >= FEE_DENOM / 2 ? 0 : fee;
    }

    function getSellFee(address user) public view returns (uint256) {
        uint256 fee = IMintManager(mintManager).getSellFee(user);
        return fee >= FEE_DENOM / 2 ? 0 : fee;
    }
}