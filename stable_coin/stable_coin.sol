// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts@4.9.3/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC20/IERC20.sol";

contract SimpleStableCoin is ERC20 {
    IERC20 public collateralToken;
    mapping(address => uint256) public totalCollateral;
    mapping(address => uint256) public remainingCollateral;
    mapping(address => uint256) private loanAmount;
    uint256 public collateralRatio;
    uint256 public liquidationRatio;
    uint256 public price;

    constructor(address _collateralToken, uint256 _collateralRatio, uint256 _liquidationRatio)
        ERC20("SimpleStableCoin", "SSC")
    {
        collateralToken = IERC20(_collateralToken);
        collateralRatio = _collateralRatio;
        liquidationRatio = _liquidationRatio;
    }

    function setPrice(uint256 _price) public {
        price = _price;
    }

    function depositCollateral(uint256 collateralAmount) external {
        collateralToken.transferFrom(msg.sender, address(this), collateralAmount);
        remainingCollateral[msg.sender] += collateralAmount;
        totalCollateral[msg.sender] += collateralAmount;
    }

    function withdrawCollateral(uint256 collateralAmount) external {
        require(remainingCollateral[msg.sender] >= collateralAmount, "Not enough collateral deposited");
        collateralToken.transfer(msg.sender, collateralAmount);
        remainingCollateral[msg.sender] -= collateralAmount;
        totalCollateral[msg.sender] -= collateralAmount;
    }

    function mintStableCoin(uint256 collateralAmount) external {
        require(remainingCollateral[msg.sender] >= collateralAmount, "Not enough collateral deposited");
        uint256 rewardStable = (collateralAmount * price * 100) / collateralRatio;
        remainingCollateral[msg.sender] -= collateralAmount;
        loanAmount[msg.sender] += rewardStable;
        _mint(msg.sender, rewardStable);
    }

    function burnStableCoin(uint256 stableCoinAmount) external {
        require(loanAmount[msg.sender] >= stableCoinAmount, "incorrect parameter");
        uint256 returnedCollateral = stableCoinAmount * collateralRatio / 100 / price;
        remainingCollateral[msg.sender] += returnedCollateral;
        loanAmount[msg.sender] -= stableCoinAmount;
        _burn(msg.sender, stableCoinAmount);
    }

    function liquidate(address user) external {
        uint256 collateralValue = totalCollateral[user] * price;

        require(collateralValue * liquidationRatio / 100 < loanAmount[user], "User is not undercollateralized");
        uint256 liquidatedCollateral = totalCollateral[user];
        totalCollateral[user] = 0;

        remainingCollateral[user] = 0;
        collateralToken.transfer(msg.sender, liquidatedCollateral);
    }
}

contract MockToken is ERC20 {
    constructor() ERC20("Me", "M") {
        _mint(msg.sender, 10 * 10 ** 18);
    }
}
