// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract DecentralizedStableCoinTest is Test {
    DecentralizedStableCoin dsc;
    uint256 public constant AMOUNT_LESS_THAN_ZERO = 0;
    uint256 public AMOUNT_TO_BURN = 1;
    uint256 public AMOUNT_TO_MINT = 1;
    uint256 balance;

    function setUp() public {
        dsc = new DecentralizedStableCoin();
    }

    //////////////////////////
    // Burn Function Tests //
    ////////////////////////
    function testIfAmountIsLessThanZero() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);
        dsc.burn(AMOUNT_LESS_THAN_ZERO);
    }

    function testIfAmountIsLessThanBalance() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountExceedsBalance.selector);
        dsc.burn(AMOUNT_TO_BURN);
    }

    function testOnlyOwnerCanCallBurn() public {
        vm.startPrank(msg.sender);
        vm.expectRevert("Ownable: caller is not the owner");
        dsc.burn(AMOUNT_TO_BURN);
    }

    function testBurnFunctionWorksAsExpected() public {
        dsc.mint(address(this), AMOUNT_TO_BURN);
        balance = dsc.balanceOf(address(this));
        dsc.burn(AMOUNT_TO_BURN);
        uint256 newBalance = dsc.balanceOf(address(this));
        assertEq(newBalance, balance - AMOUNT_TO_BURN);
    }

    //////////////////////////
    // Mint Function Tests //
    ////////////////////////

    function testIfToAddressIsZero() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__NotZeroAddress.selector);
        dsc.mint(address(0), AMOUNT_TO_BURN);
    }

    function testIfAmountIsLessThanZeroInMint() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);
        dsc.mint(address(this), AMOUNT_LESS_THAN_ZERO);
    }

    function testOnlyOwnerCanCallMint() public {
        vm.startPrank(msg.sender);
        vm.expectRevert("Ownable: caller is not the owner");
        dsc.mint(address(this), AMOUNT_TO_MINT);
    }

    function testMintFunctionWorksAsExpected() public {
        balance = dsc.balanceOf(address(this));
        dsc.mint(address(this), AMOUNT_TO_MINT);
        uint256 newBalance = dsc.balanceOf(address(this));
        assertEq(newBalance, balance + AMOUNT_TO_MINT);
    }
}
