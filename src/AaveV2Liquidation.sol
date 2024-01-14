// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {ILendingPoolAddressesProvider} from "./aave-v2-updated/ILendingPoolAddressesProvider.sol";
import {ILendingPoolAddressesProvider} from "./aave-v2-updated/ILendingPoolAddressesProvider.sol";
import {FlashLoanReceiverBase} from "./aave-v2-updated/FlashLoanReceiverBase.sol";
import {ILendingPool} from "./aave-v2-updated/ILendingPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AaveV2Liquidation is FlashLoanReceiverBase, Ownable {
    ISwapRouter public iSwapRouter;

    constructor(address _owner, ILendingPoolAddressesProvider _addressProvider, ISwapRouter _iSwapRouter)
        Ownable(_owner)
        FlashLoanReceiverBase(_addressProvider)
    {
        iSwapRouter = _iSwapRouter;
    }

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function withdrawERC20(address token) public onlyOwner {
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    function liquidateUser(
        address _user,
        address _collateralAsset,
        address _debtAsset,
        uint256 _debtToCover,
        bool _receiveAToken,
        uint24 _uniswapPoolFee
    ) external {
        address[] memory tokensToBorrow = new address[](1);
        tokensToBorrow[0] = _debtAsset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _debtToCover;
        bytes memory data = abi.encode(_user, _collateralAsset, _receiveAToken, _uniswapPoolFee);
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0; // 0 = no debt to refinance , 1 = stable debt, 2 = variable debta
        LENDING_POOL.flashLoan(
            address(this),
            tokensToBorrow,
            amounts,
            modes, // 0 = no debt to refinance , 1 = stable debt, 2 = variable debt
            address(this),
            data,
            0 // referral code
        );
    }

    /**
     * @notice this function is called after your contract has received the flash loaned amount
     * @dev Ensure that the contract can return the debt + premium, e.g., has
     *      enough funds to repay and has approved the Pool to pull the total amount
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        (address user, address collateralAsset, bool receiveAToken, uint24 uniswapPoolFee) =
            abi.decode(params, (address, address, bool, uint24));

        IERC20(assets[0]).approve(address(LENDING_POOL), type(uint256).max); // approve to repay user's debt and  the FLASHLOAN
        LENDING_POOL.liquidationCall(collateralAsset, assets[0], user, amounts[0], receiveAToken);
        if (assets[0] != collateralAsset) {
            swapCollateralReceivedToFlashloanDebtAsset(
                collateralAsset, IERC20(collateralAsset).balanceOf(address(this)), assets[0], uniswapPoolFee
            );
        }
        return true;
    }

    function swapCollateralReceivedToFlashloanDebtAsset(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        uint24 _uniswapPoolFees
    ) private {
        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: _uniswapPoolFees,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // Approve the router to spend our token.
        TransferHelper.safeApprove(_tokenIn, address(iSwapRouter), _amountIn);

        // The call to `exactInputSingle` executes the swap.
        iSwapRouter.exactInputSingle(params);
    }
}
