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
    We'll need to accept native assets, swap them for aUSDC
    Do a contract call with token send, send the aUSDC cross chain
    Receive the aUSDC on the other chain, swap it for native asset
    Swap native asset into desired token, send to recipient
    Also let people simply swap native to native this way as well

    Or -- we have Dest Contracts all set up to receive aUSDC and swap it for native asset
    With an input being the desired token. This way we can have a single contract instead of needing a factory
 */


/// @title Callback for IPancakeV3PoolActions#swap
/// @notice Any contract that calls IPancakeV3PoolActions#swap must implement this interface
interface IPancakeV3SwapCallback {
    /// @notice Called to `msg.sender` after executing a swap via IPancakeV3Pool#swap.
    /// @dev In the implementation you must pay the pool tokens owed for the swap.
    /// The caller of this method must be checked to be a PancakeV3Pool deployed by the canonical PancakeV3Factory.
    /// amount0Delta and amount1Delta can both be 0 if no tokens were swapped.
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token0 to the pool.
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token1 to the pool.
    /// @param data Any data passed through by the caller via the IPancakeV3PoolActions#swap call
    function pancakeV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via PancakeSwap V3
interface IV3SwapRouter is IPancakeV3SwapCallback {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @dev Setting `amountIn` to 0 will cause the contract to look up its own balance,
    /// and swap the entire amount, enabling contracts to send tokens before calling this function.
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @dev Setting `amountIn` to 0 will cause the contract to look up its own balance,
    /// and swap the entire amount, enabling contracts to send tokens before calling this function.
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// that may remain in the router after the swap.
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// that may remain in the router after the swap.
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}

interface ISpecialBuyer {
    function buyFor(address user, uint112 percentForGas, uint256 minOut) external;
}

contract RubberSwapper is Ownable {

    /** Percentage Denominator */
    uint256 public constant PERCENT_GAS_DENOM = 1_000_000;

    /** V2 Router Contract */
    IUniswapV2Router02 public V2Router = IUniswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);

    /** V3 Router Contract */
    IV3SwapRouter public swapRouter = IV3SwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    /** aUSDC Address */
    address public constant aUSDC = 0x750e4C4984a9e0f12978eA6742Bc1c5D248f40ed;

    /** Fee (V3 Pool Fee) */
    uint24 public v3Fee = 100;

    /** Swap Path For middleWareToken to tokenToSwapFor */
    address[] public midToETH;

    /** Maps ETH To Token */
    address[] public ethToToken;

    /** Total Bought */
    uint256 public totalBought;

    constructor(address _token) {
        midToETH = new address[](2);
        midToETH[0] = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
        midToETH[1] = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

        ethToToken = new address[](2);
        ethToToken[0] = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        ethToToken[1] = _token;
    }

    // set eth to token
    function setEthToToken(
        address[] calldata ethToToken_
    ) external onlyOwner {
        ethToToken = ethToToken_;
    }

    // set middleware token
    function setMidToETH(
        address[] calldata midToETH_
    ) external onlyOwner {
        midToETH = midToETH_;
    }

    function setV2Router(
        address v2Router_
    ) external onlyOwner {
        V2Router = IUniswapV2Router02(v2Router_);
    }

    function setV3Router(
        address swapRouter_
    ) external onlyOwner {
        swapRouter = IV3SwapRouter(swapRouter_);
    }

    function setV3Fee(uint24 fee) external onlyOwner {
        v3Fee = fee;
    }

    function withdraw(address _token) external onlyOwner {
        TransferHelper.safeTransfer(_token, msg.sender, IERC20(_token).balanceOf(address(this)));
    }

    function withdrawETH() external onlyOwner {
        TransferHelper.safeTransferETH(msg.sender, address(this).balance);
    }

    function testSwap(
        address recipient,
        uint112 percentForGas,
        uint256 amount,
        uint256 minOut
    ) external onlyOwner {
        IERC20(aUSDC).transferFrom(msg.sender, address(this), amount);
        _swapToETH(amount);
        _swapToToken(recipient, percentForGas, minOut);
    }

    function buyFor(address user, uint256 amount, uint112 percentForGas, uint256 minOut) external {
        IERC20(aUSDC).transferFrom(msg.sender, address(this), amount);
        uint256 balance = IERC20(aUSDC).balanceOf(address(this));
        require(balance > 0, 'No Balance');

        // swap USDC to ETH
        _swapToETH(balance);

        // swap ETH into token
        _swapToToken(user, percentForGas, minOut);
    }

    function _swapToETH(uint256 amount) internal {
        
        // increment total bought
        unchecked {
            totalBought += amount;
        }

        // approve of aUSDC to dex
        TransferHelper.safeApprove(aUSDC, address(swapRouter), amount);

        // Note: To use this example, you should explicitly set slippage limits, omitting for simplicity
        uint256 minOut = /* Calculate min output */ 0;
        uint160 priceLimit = /* Calculate price limit */ 0;

        // Create the params that will be used to execute the swap
        IV3SwapRouter.ExactInputSingleParams memory params =
        IV3SwapRouter.ExactInputSingleParams({
            tokenIn: aUSDC,
            tokenOut: midToETH[0],
            fee: v3Fee,
            recipient: address(this),
            deadline: block.timestamp + 1000,
            amountIn: amount,
            amountOutMinimum: minOut,
            sqrtPriceLimitX96: priceLimit
        });

        // The call to `exactInputSingle` executes the swap.
        swapRouter.exactInputSingle(params);

        // determine new balance of middlewareToken
        uint256 midBal = IERC20(midToETH[0]).balanceOf(address(this));

        // approve of middleware token to dex
        TransferHelper.safeApprove(midToETH[0], address(V2Router), midBal);

        // make swap into eth
        V2Router.swapExactTokensForETH(
            midBal,
            1,
            midToETH,
            address(this),
            block.timestamp + 1000
        );
    }

    function _swapToToken(address recipient, uint112 percentForGas, uint256 minOut) internal {
    
        // fetch qty of eth
        uint256 ethForGas = address(this).balance * percentForGas / PERCENT_GAS_DENOM;
        uint256 ethForSwap = address(this).balance - ethForGas;

        // swap eth into desired token
        if (ethForSwap > 0) {
            
            V2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: ethForSwap}(
                minOut,
                ethToToken,
                recipient,
                block.timestamp + 1000
            );
        }

        if (ethForGas > 0) {
            (bool s,) = payable(recipient).call{value: ethForGas}("");
            require(s, 'Native Transfer Failed');
        }
    }

    receive() external payable {}

    // get ethToToken array
    function getEthToToken() external view returns (address[] memory) {
        return ethToToken;
    }

    function token() public view returns (address) {
        return ethToToken[ethToToken.length - 1];
    }
}