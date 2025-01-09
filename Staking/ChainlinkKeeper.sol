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

interface IDistributor {
    function pendingDistribution() external view returns (uint256);
    function distribute() external;
}


/**
    This contract will handle searching Jackpot games for a game that is able to be ended
    If it is possible to end the game, we will
 */
contract ChainlinkKeeper is Ownable, AutomationCompatible {

    address public distributor;
    uint256 public timeDelay = 10 minutes;
    uint256 public lastTime;

    constructor(address distributor_, uint256 timeBuffer) {
        distributor = distributor_;
        lastTime = block.timestamp + timeBuffer;
    }

    function setDistributor(address distributor_) external onlyOwner {
        distributor = distributor_;
    }

    function setTimeDelay(uint256 timeDelay_) external onlyOwner {
        timeDelay = timeDelay_;
    }

    function resetTimer() external onlyOwner {
        lastTime = block.timestamp;
    }

    function setLastTime(uint256 lastTime_) external onlyOwner {
        lastTime = lastTime_;
    }

    function setFutureTime(uint256 timeInFuture) external onlyOwner {
        lastTime = block.timestamp + timeInFuture;
    }

    function checkUpkeep(bytes calldata) external override cannotExecute returns (bool upkeepNeeded, bytes memory performData) {
        uint256 pendingDistribution = IDistributor(distributor).pendingDistribution();
        return (pendingDistribution > 0 && timeSince() > timeDelay, new bytes(0));
    }

    function performUpkeep(bytes calldata) external {
        lastTime = block.timestamp;
        IDistributor(distributor).distribute();
    }

    function timeSince() public view returns (uint256) {
        return block.timestamp > lastTime ? block.timestamp - lastTime : 0;
    }
}