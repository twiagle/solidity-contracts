// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library LoanLibrary {
    function calculateDepositInterest(uint256 amount, uint256 interestRate, uint256 period)
        external
        pure
        returns (uint256)
    {
        uint256 reward = (amount * period) / interestRate;
        return reward;
    }

    function calculateLockedInterest(uint256 amount, uint256 interestRate, uint256 coefficient)
        external
        pure
        returns (uint256)
    {
        uint256 interest = (amount * interestRate) / coefficient;
        return amount + interest;
    }
}
