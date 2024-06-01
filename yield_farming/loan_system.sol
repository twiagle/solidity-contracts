// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LoanLibrary.sol";
import "./Treasury.sol";

contract LoanSystem {
    struct lockedInfo {
        address user;
        uint256 lockedAmount;
        uint256 startBlock;
        uint256 interestRate;
    }

    uint256 constant INTEREST_COEFFICIENT = 10 ** 8;
    uint256 public immutable interestLockedRate;
    uint256 public immutable interestUnLockedRate;
    uint256 public immutable lockDuration;

    IERC20 public lpToken;
    Treasury public treasury;
    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public lastRewardBlock;
    mapping(address => bytes32[]) userLockedIds;

    mapping(bytes32 => lockedInfo) lockedInfos;

    event Deposit(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount);

    event DepositWithLock(address indexed account, bytes32 indexed lockedId, uint256 lockedAmount);

    event WithdrawLocked(address indexed account, bytes32 indexed lockedId, uint256 totalAmount);

    event Reward(address indexed account, uint256 interest);

    constructor(address _lpToken, uint256 _lockDuration, uint256 _lockedRate, uint256 _unlockedRate) {
        lpToken = IERC20(_lpToken);
        treasury = new Treasury(_lpToken);
        lockDuration = _lockDuration;

        interestLockedRate = _lockedRate;
        interestUnLockedRate = _unlockedRate;
    }

    function deposit(uint256 amount) external {
        reward(msg.sender);
        lpToken.transferFrom(msg.sender, address(treasury), amount);
        balanceOf[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount);
        reward(msg.sender);
        lastRewardBlock[msg.sender] = block.number;
        balanceOf[msg.sender] -= amount;
        treasury.withdrawTo(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    function reward(address account) public returns (uint256 interest) {
        require(msg.sender == account || msg.sender == address(this));
        uint256 balance = balanceOf[account];
        uint256 period = block.number - lastRewardBlock[account];
        interest = LoanLibrary.calculateDepositInterest(balance, interestUnLockedRate, period);
        treasury.withdrawTo(account, interest);

        lastRewardBlock[msg.sender] = block.number;
        emit Reward(account, interest);
    }

    function depositWithLock(uint256 lockedAmount) external returns (bytes32 lockedId) {
        lpToken.transferFrom(msg.sender, address(treasury), lockedAmount);
        lockedInfo memory info = lockedInfo(msg.sender, lockedAmount, block.number, interestLockedRate);
        lockedId = keccak256(abi.encode(msg.sender, block.number));
        lockedInfos[lockedId] = info;
        userLockedIds[msg.sender].push(lockedId);
        emit DepositWithLock(msg.sender, lockedId, lockedAmount);
    }

    function withdrawLocked(bytes32 lockedId) external {
        lockedInfo memory info = lockedInfos[lockedId];
        require(msg.sender == info.user);
        require(block.number >= info.startBlock + lockDuration);
        uint256 totalAmount =
            LoanLibrary.calculateLockedInterest(info.lockedAmount, info.interestRate, INTEREST_COEFFICIENT);
        treasury.withdrawTo(msg.sender, totalAmount);
        deleteLockedInfo(lockedId);
        emit WithdrawLocked(msg.sender, lockedId, totalAmount);
    }

    function deleteLockedInfo(bytes32 lockedId) internal {
        address user = lockedInfos[lockedId].user;
        // 从userLockedIds中删除lockedId
        bytes32[] storage lockedIds = userLockedIds[user];
        for (uint256 i = 0; i < lockedIds.length; i++) {
            if (lockedIds[i] == lockedId) {
                // 将要删除的lockedId与数组最后一个元素交换位置，然后从数组中删除最后一个元素
                lockedIds[i] = lockedIds[lockedIds.length - 1];
                lockedIds.pop();
                break;
            }
        }
        // 从lockedInfos中删除lockedId
        delete lockedInfos[lockedId];
    }

    function getBlockNumber() external view returns (uint256) {
        return block.number;
    }

    function incrementBlockNumber() external {
        //调用一次即可让本地的block.number加一
    }
}
