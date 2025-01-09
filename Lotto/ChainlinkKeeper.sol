//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract AutomationBase {
  error OnlySimulatedBackend();

  /**
   * @notice method that allows it to be simulated via eth_call by checking that
   * the sender is the zero address.
   */
  function _preventExecution() internal view {
    // solhint-disable-next-line avoid-tx-origin
    if (tx.origin != address(0)) {
      revert OnlySimulatedBackend();
    }
  }

  /**
   * @notice modifier that allows it to be simulated via eth_call by checking
   * that the sender is the zero address.
   */
  modifier cannotExecute() {
    _preventExecution();
    _;
  }
}


interface AutomationCompatibleInterface {
  /**
   * @notice method that is simulated by the keepers to see if any work actually
   * needs to be performed. This method does does not actually need to be
   * executable, and since it is only ever simulated it can consume lots of gas.
   * @dev To ensure that it is never called, you may want to add the
   * cannotExecute modifier from KeeperBase to your implementation of this
   * method.
   * @param checkData specified in the upkeep registration so it is always the
   * same for a registered upkeep. This can easily be broken down into specific
   * arguments using `abi.decode`, so multiple upkeeps can be registered on the
   * same contract and easily differentiated by the contract.
   * @return upkeepNeeded boolean to indicate whether the keeper should call
   * performUpkeep or not.
   * @return performData bytes that the keeper should call performUpkeep with, if
   * upkeep is needed. If you would like to encode data to decode later, try
   * `abi.encode`.
   */
  function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);

  /**
   * @notice method that is actually executed by the keepers, via the registry.
   * The data returned by the checkUpkeep simulation will be passed into
   * this method to actually be executed.
   * @dev The input to this method should not be trusted, and the caller of the
   * method should not even be restricted to any single registry. Anyone should
   * be able call it, and the input should be validated, there is no guarantee
   * that the data passed in is the performData returned from checkUpkeep. This
   * could happen due to malicious keepers, racing keepers, or simply a state
   * change while the performUpkeep transaction is waiting for confirmation.
   * Always validate the data passed in.
   * @param performData is the data which was passed back from the checkData
   * simulation. If it is encoded, it can easily be decoded into other types by
   * calling `abi.decode`. This data should not be trusted, and should be
   * validated against the contract's current state.
   */
  function performUpkeep(bytes calldata performData) external;
}

abstract contract AutomationCompatible is AutomationBase, AutomationCompatibleInterface {}

interface IWTAGame {
    function endGame(uint256 tableId) external;
    function canEndGame(uint256 tableId) external view returns (bool);
    function validTable(uint256 tableId) external view returns (bool);
    function tableNonce() external view returns (uint256);
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

/**
    This contract will handle searching Jackpot games for a game that is able to be ended
    If it is possible to end the game, we will
 */
contract ChainlinkKeeper is AutomationCompatible, Ownable {

    IWTAGame public immutable game;

    constructor(
        address game_
    ) {
        game = IWTAGame(game_);
    }
    
    // Transfer contract tokens to an address
    function withdrawToken(address token, uint256 amount, address to) external onlyOwner {
        TransferHelper.safeTransfer(token, to, amount);
    }

    // Transfer contract ETH to an address
    function withdrawETH(uint256 amount, address to) external onlyOwner {
        TransferHelper.safeTransferETH(to, amount);
    }

    function checkUpkeep(bytes calldata) external override cannotExecute returns (bool upkeepNeeded, bytes memory performData) {
        uint256[] memory ids = tablesToExecute();
        uint len = ids.length;
        if (len > 0) {
            return (true, abi.encode(ids));
        }
        return (false, abi.encode(ids));
    }


    function performUpkeep(bytes calldata performData) external {
        uint256[] memory ids = abi.decode(performData, (uint256[]));
        uint len = ids.length;
        require(
            len > 0,
            'No Game Available To Execute'
        );
        for (uint i = 0; i < len;) {
            game.endGame(ids[i]);
            unchecked { ++i; }
        }
    }

    function tablesToExecute() public view returns (uint256[] memory tableIds) {
        uint max = game.tableNonce();
        uint len = 0;
        for (uint i = 1; i < max;) {
            if (game.validTable(i)) {
                if (game.canEndGame(i)) {
                    unchecked {
                        ++len;
                    }
                }
            }
            unchecked { ++i; }
        }
        tableIds = new uint256[](len);
        if (len == 0) {
            return tableIds;
        }
        uint count = 0;

        for (uint i = 1; i < max;) {
            if (game.validTable(i)) {
                if (game.canEndGame(i)) {
                    tableIds[count] = i;
                    unchecked { ++count; }
                }
            }
            unchecked { ++i; }
        }
    }
    
}