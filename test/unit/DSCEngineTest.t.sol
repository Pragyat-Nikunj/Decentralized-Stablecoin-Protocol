// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    address LIQUIDATOR = makeAddr("liquidator");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200 % overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant AMOUNT_TO_MINT = 8000e18;
    uint256 private constant AMOUNT_TO_BURN = 5000e18;
    uint256 private constant AMOUNT_TO_REDEEM = 4e18;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ////////////////////////
    // Constructor Tests //
    ///////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    //////////////////
    // Price Tests //
    ////////////////
    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000 /ETH = 30,000e18
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    //////////////////////////////
    // depositCollateral Tests //
    ////////////////////////////
    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);

        uint256 expectedTotalDSCMinted = 0;
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDSCMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testEventOfDepositCollateralEmitted() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        vm.expectEmit(true, true, true, false, address(dsce));
        emit DSCEngine.CollateralDeposited(USER, weth, AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    /////////////////////
    // Mint DSC tests //
    ///////////////////
    function testRevetIfMintDSCZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.mintDsc(0);
        vm.stopPrank();
    }

    modifier mintDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        dsce.mintDsc(AMOUNT_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testIfHealthFactorIsBroken() public depositCollateral {
        vm.startPrank(USER);
        uint256 amountToMint = 12000e18;
        (, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        uint256 expectedHealthFactor = dsce.calculateHealthFactor(amountToMint, collateralValueInUsd);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        dsce.mintDsc(amountToMint);
        vm.stopPrank();
    }

    function testIfMintDSCWorksAsExpected() public depositCollateral {
        vm.startPrank(USER);
        uint256 amountToMint = 8000e18;
        dsce.mintDsc(amountToMint);
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        assertEq(amountToMint, totalDscMinted);
        vm.stopPrank();
    }

    function testDepositCollateralAndMintDsc() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        assertEq(AMOUNT_TO_MINT, totalDscMinted);
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
        vm.stopPrank();
    }

    /////////////////////////
    // HealthFactor Tests //
    ///////////////////////
    function testIfHealthFactorWorksAsExpected() public depositCollateral {
        vm.startPrank(USER);
        uint256 amountToMint = 10000e18;
        uint256 expectedHealthFactor =
            dsce.calculateHealthFactor(amountToMint, dsce.getUsdValue(weth, AMOUNT_COLLATERAL));
        dsce.mintDsc(amountToMint);
        uint256 actualHealthFactor = dsce.getHealthFactor(USER);
        assertEq(expectedHealthFactor, actualHealthFactor);
        vm.stopPrank();
    }

    function testHealthFactorIfMintedDSCZero() public depositCollateral {
        vm.startPrank(USER);
        uint256 expectedHealthFactor = type(uint256).max;
        uint256 actualHealthFactor = dsce.getHealthFactor(USER);
        assertEq(expectedHealthFactor, actualHealthFactor);
        vm.stopPrank();
    }

    function testcalculateHealthFactorWhenNoDebt() public depositCollateral {
        vm.startPrank(USER);
        uint256 expectedHealthFactor = type(uint256).max;
        uint256 actualHealthFactor = dsce.calculateHealthFactor(0, dsce.getUsdValue(weth, AMOUNT_COLLATERAL));
        assertEq(expectedHealthFactor, actualHealthFactor);
        vm.stopPrank();
    }

    /////////////////////
    // Burn DSC Tests //
    ///////////////////
    function testRevertIfBurnDSCZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.burnDsc(0);
        vm.stopPrank();
    }

    function testIfDebtReducesWhenBurnDSC() public mintDsc {
        vm.startPrank(USER);
        uint256 beforeDSCBurnt = dsce.getDSCMinted(USER);
        dsc.approve(address(dsce), AMOUNT_TO_BURN);
        dsce.burnDsc(AMOUNT_TO_BURN);
        uint256 afterDSCBurnt = dsce.getDSCMinted(USER);
        assertEq(beforeDSCBurnt, AMOUNT_TO_BURN + afterDSCBurnt);
    }

    function testIfHealthFactorImprovesAfterBurningDSC() public mintDsc {
        vm.startPrank(USER);
        uint256 healthFactorBeforeDSCBurnt = dsce.getHealthFactor(USER);
        dsc.approve(address(dsce), AMOUNT_TO_BURN);
        dsce.burnDsc(AMOUNT_TO_BURN);
        uint256 healthFactorAfterDSCBurnt = dsce.getHealthFactor(USER);
        assert(healthFactorAfterDSCBurnt > healthFactorBeforeDSCBurnt);
        vm.stopPrank();
    }

    modifier burnDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        dsce.mintDsc(AMOUNT_TO_MINT);
        dsc.approve(address(dsce), AMOUNT_TO_BURN);
        dsce.burnDsc(AMOUNT_TO_BURN);
        vm.stopPrank();
        _;
    }

    //////////////////////////////
    // Redeem Collateral Tests //
    ////////////////////////////
    function testIfRedeemCollateralZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testIfRedeemingCollateralBreaksHealthFactor() public mintDsc {
        vm.startPrank(USER);
        uint256 amountToRedeem = dsce.getTokenAmountFromUsd(
            weth,
            dsce.getUsdValue(weth, AMOUNT_COLLATERAL)
                - (dsce.getDSCMinted(USER) * LIQUIDATION_PRECISION / LIQUIDATION_THRESHOLD)
        );
        vm.expectRevert();
        dsce.redeemCollateral(weth, amountToRedeem + 1);
        vm.stopPrank();
    }

    function testIfRedeemingCollateralRevertsBeforeBurningDSC() public mintDsc {
        vm.startPrank(USER);
        vm.expectRevert();
        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testIfRedeemCollateralWorksAsExpected() public burnDsc {
        vm.startPrank(USER);
        uint256 beforeRedeemBalance = ERC20Mock(weth).balanceOf(USER);
        dsce.redeemCollateral(weth, AMOUNT_TO_REDEEM);
        uint256 afterRedeemBalance = ERC20Mock(weth).balanceOf(USER);
        assertEq(beforeRedeemBalance, afterRedeemBalance - AMOUNT_TO_REDEEM);
        vm.stopPrank();
    }

    ////////////////////////
    // Liquidation Tests //
    //////////////////////

    function testIfLiquidationIsZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.liquidate(USER, weth, 0);
        vm.stopPrank();
    }

    function testIfLiquidationRevertsIfUserIsHealthy() public burnDsc {
        vm.startPrank(LIQUIDATOR); // Someone else tries to attack the USER
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dsce.liquidate(USER, weth, 100e18);
        vm.stopPrank();
    }

    function testLiquidationWorksWhenUnderwater() public mintDsc {
        // 1. Setup Liquidator while price is HIGH ($2,000)
        address liquidator = makeAddr("liquidator");
        ERC20Mock(weth).mint(liquidator, 30 ether);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dsce), 20 ether);
        dsce.depositCollateralAndMintDsc(weth, 20 ether, 10000e18);
        dsc.approve(address(dsce), 10000e18);
        vm.stopPrank();

        // 2. NOW crash the price so the USER is liquidatable
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(1500e8);
        uint256 beforeHealthFactor = dsce.getHealthFactor(USER);
        // 3. Liquidate
        vm.startPrank(liquidator);
        dsce.liquidate(weth, USER, 2000e18);
        uint256 afterHealthFactor = dsce.getHealthFactor(USER);
        assert(afterHealthFactor > beforeHealthFactor);
        vm.stopPrank();
    }

    function testLiquidationRevertsWhenItDoesntImproveHealthFactor() public mintDsc {
        // 1. Setup Liquidator while price is HIGH ($2,000)
        address liquidator = makeAddr("liquidator");
        ERC20Mock(weth).mint(liquidator, 30 ether);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dsce), 20 ether);
        dsce.depositCollateralAndMintDsc(weth, 20 ether, 10000e18);
        dsc.approve(address(dsce), 10000e18);
        vm.stopPrank();

        // 2. NOW crash the price so the USER is liquidatable
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(400e8);
        // 3. Liquidate
        vm.startPrank(liquidator);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
        dsce.liquidate(weth, USER, 2000e18);
        vm.stopPrank();
    }

    ///////////////////
    // Getter Tests //
    /////////////////
    function testGettersDoNotRevert() public {
        dsce.getCollateralTokens();
        dsce.getMinHealthFactor();
        dsce.getLiquidationBonus();
        dsce.getLiquidationPrecision();
        dsce.getPrecision();
        dsce.getAdditionalFeedPrecision();
        dsce.getLiquidationThreshold();
        dsce.getCollateralTokenPriceFeed(weth);
        dsce.getDsc();
    }
}
