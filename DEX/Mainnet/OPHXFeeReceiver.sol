//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

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

interface IERC20 {

    function totalSupply() external view returns (uint256);
    
    function symbol() external view returns(string memory);
    
    function name() external view returns(string memory);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
    
    /**
     * @dev Returns the number of decimal places
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

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

interface IOPHXFeeReceiver {
    function takeFee(address sender) external payable;
}

contract OPHXFeeReceiver is Ownable, IOPHXFeeReceiver {

    // Buy from PCS router to avoid reentrancy
    IUniswapV2Router02 public constant pcsRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address public constant OPHX = 0x59803e5Fe213D4B22fb9b061c4C89E716a1CA760;
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address[] public path = [WBNB, OPHX];

    // Dead wallet, only way to burn OPHX
    address public constant deadWallet = 0x000000000000000000000000000000000000dEaD;

    // percentages involving the OPHX Token
    uint256 public tradeMiningPercent = 10;
    uint256 public buyAndBurnPercent = 45;
    uint256 public stakingRewardPercent = 10;

    // percentages involving BNB distribution
    uint256 public burnStakingPercent = 20;
    uint256 public marketingPercent = 15;

    // addresses involving BNB distribution
    address public burnStakingAddress = 0xa0F0A4822c5fF4a80D6220B60a60d1d4Df3b469A;
    address public marketingAddress = 0x2d2171118BceF0649D6472DC5219d58bE4F259Ca;

    // addresses involving OPHX distribution
    address public stakingRewardAddress = 0xDA0b6b2A51c4c9D7b05ed842207769E862130675;

    // Maps an address to how much bnb they can use to buy OPHX
    mapping ( address => uint256 ) public pendingTradeMiningRewards;
    uint256 public totalPendingTradeMiningRewards;


    // setters for all percents
    function setTradeMiningPercent(uint256 _tradeMiningPercent) external onlyOwner {
        tradeMiningPercent = _tradeMiningPercent;
    }

    function setBuyAndBurnPercent(uint256 _buyAndBurnPercent) external onlyOwner {
        buyAndBurnPercent = _buyAndBurnPercent;
    }

    function setStakingRewardPercent(uint256 _stakingRewardPercent) external onlyOwner {
        stakingRewardPercent = _stakingRewardPercent;
    }

    function setBurnStakingPercent(uint256 _burnStakingPercent) external onlyOwner {
        burnStakingPercent = _burnStakingPercent;
    }

    function setMarketingPercent(uint256 _marketingPercent) external onlyOwner {
        marketingPercent = _marketingPercent;
    }

    // setters for all addresses
    function setBurnStakingAddress(address _burnStakingAddress) external onlyOwner {
        burnStakingAddress = _burnStakingAddress;
    }

    function setMarketingAddress(address _marketingAddress) external onlyOwner {
        marketingAddress = _marketingAddress;
    }

    function setStakingRewardAddress(address _stakingRewardAddress) external onlyOwner {
        stakingRewardAddress = _stakingRewardAddress;
    }

    function batchClaimRewards(address[] calldata users) external onlyOwner {
        uint len = users.length;
        for (uint256 i = 0; i < len;) {
            uint256 pending = pendingTradeMiningRewards[users[i]];
            if (pending > 0) {
                delete pendingTradeMiningRewards[users[i]];
                totalPendingTradeMiningRewards -= pending;
                _buyOPHX(users[i], pending);
            }
            unchecked { ++i; }
        }
    }

    function trigger() external {

        // amount to trigger
        uint256 amount = address(this).balance - totalPendingTradeMiningRewards;
        require(amount > 10, 'Amount too low');

        // send bnb fees first
        uint256 burnStakingCut = amount * burnStakingPercent / 100;
        uint256 marketingCut = amount * marketingPercent / 100;

        if (burnStakingCut > 0 && burnStakingAddress != address(0)) {
            TransferHelper.safeTransferETH(burnStakingAddress, burnStakingCut);
        }

        if (marketingCut > 0 && marketingAddress != address(0)) {
            TransferHelper.safeTransferETH(marketingAddress, marketingCut);
        }

        // buy OPHX with remaining
        uint256 ophxBalance = _buyOPHX(address(this), address(this).balance);
        uint256 ophxDenom = buyAndBurnPercent + stakingRewardPercent;
        if (ophxDenom == 0 || ophxBalance == 0) {
            return;
        }

        // split up OPHX
        uint256 ophxBuyAndBurnCut = ophxBalance * buyAndBurnPercent / ophxDenom;
        uint256 ophxStakingRewardCut = ophxBalance * stakingRewardPercent / ophxDenom;

        // burn ophx
        if (ophxBuyAndBurnCut > 0) {
            IERC20(OPHX).transfer(deadWallet, ophxBuyAndBurnCut);
        }

        // reward to staking
        if (ophxStakingRewardCut > 0) {
            TransferHelper.safeTransfer(OPHX, stakingRewardAddress, ophxStakingRewardCut);
        }
    }

    function claimRewards() external {
        uint256 pending = pendingTradeMiningRewards[msg.sender];
        require(pending > 0, 'No Pending Rewards');
        delete pendingTradeMiningRewards[msg.sender];
        totalPendingTradeMiningRewards -= pending;
        _buyOPHX(msg.sender, pending);
    }

    function takeFee(address sender) external payable override {
        uint256 cut = ( msg.value * tradeMiningPercent ) / 100;
        unchecked {
            pendingTradeMiningRewards[sender] += cut;
            totalPendingTradeMiningRewards += cut;
        }
    }

    receive() external payable {}

    function _buyOPHX(address destination, uint256 amount) internal returns (uint256 balance) {
        if (amount > 0) {
            pcsRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(1, path, destination, block.timestamp + 100);
        }
        return IERC20(OPHX).balanceOf(address(this));
    }

}