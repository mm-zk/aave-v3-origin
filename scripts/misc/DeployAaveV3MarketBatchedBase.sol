// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import 'forge-std/StdJson.sol';
import 'forge-std/console.sol';

import '../../src/deployments/interfaces/IMarketReportTypes.sol';
import {IMetadataReporter} from '../../src/deployments/interfaces/IMetadataReporter.sol';
import {DeployUtils} from '../../src/deployments/contracts/utilities/DeployUtils.sol';
import {AaveV3BatchOrchestration} from '../../src/deployments/projects/aave-v3-batched/AaveV3BatchOrchestration.sol';
import {MarketInput} from '../../src/deployments/inputs/MarketInput.sol';
import {AaveV3SetupBatch} from '../../src/deployments/projects/aave-v3-batched/batches/AaveV3SetupBatch.sol';

abstract contract DeployAaveV3MarketBatchedBase is DeployUtils, MarketInput, Script {
  using stdJson for string;

  function run() external {
    Roles memory roles;
    MarketConfig memory config;
    DeployFlags memory flags;
    MarketReport memory report;

    console.log('Aave V3 Batch Deployment');
    console.log('sender', msg.sender);

    (roles, config, flags, report) = _getMarketInput(msg.sender);

    _loadWarnings(config, flags);

    vm.startBroadcast();
    report = AaveV3BatchOrchestration.deployAaveV3(msg.sender, roles, config, flags, report);

    IPoolConfigurator aa = IPoolConfigurator(report.poolConfiguratorProxy);

    IDefaultInterestRateStrategyV2.InterestRateData
      memory interestRate = IDefaultInterestRateStrategyV2.InterestRateData({
        optimalUsageRatio: 8000,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 700,
        variableRateSlope2: 7500
      });

    ConfiguratorInputTypes.InitReserveInput[]
      memory reserves = new ConfiguratorInputTypes.InitReserveInput[](2);

    // 'Counter' script
    // CHANGEHERE
    address magicHelper = address(0x5FbDB2315678afecb367f032d93F642f64180aa3);

    //address magicHelper = address(0x49fd2BE640DB2910c2fAb69bB8531Ab6E76127ff);
    // CHANGEHERE
    address firstERC = address(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
    // CHANGEHERE
    address secondERC = address(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);

    reserves[0] = ConfiguratorInputTypes.InitReserveInput({
      aTokenImpl: report.aToken,
      variableDebtTokenImpl: report.variableDebtToken,
      useVirtualBalance: true,
      interestRateStrategyAddress: report.defaultInterestRateStrategy,
      // Manually deployed - via helper.
      underlyingAsset: firstERC,
      treasury: report.treasury,
      incentivesController: address(0), // no incentives
      aTokenName: 'EXM token',
      aTokenSymbol: 'EXM',
      variableDebtTokenName: 'VAR token',
      variableDebtTokenSymbol: 'VAR',
      params: bytes(''),
      interestRateData: abi.encode(interestRate)
    });
    reserves[1] = ConfiguratorInputTypes.InitReserveInput({
      aTokenImpl: report.aToken,
      variableDebtTokenImpl: report.variableDebtToken,
      useVirtualBalance: true,
      interestRateStrategyAddress: report.defaultInterestRateStrategy,
      // Manually deployed - via helper.
      underlyingAsset: secondERC,
      treasury: report.treasury,
      incentivesController: address(0), // no incentives
      aTokenName: 'EXM token2',
      aTokenSymbol: 'EX2',
      variableDebtTokenName: 'VAR token2',
      variableDebtTokenSymbol: 'VA2',
      params: bytes(''),
      interestRateData: abi.encode(interestRate)
    });

    aa.initReserves(reserves);

    aa.configureReserveAsCollateral(firstERC, 7500, 8000, 10500);
    aa.setReserveBorrowing(secondERC, true);

    IAaveOracle aaveOracle = IAaveOracle(report.aaveOracle);
    aaveOracle.setFallbackOracle(magicHelper);

    vm.stopBroadcast();

    IUiPoolDataProviderV3 uiPoolProvider = IUiPoolDataProviderV3(report.uiPoolDataProvider);
    uiPoolProvider.getReservesData(IPoolAddressesProvider(report.poolAddressesProvider));

    IUiIncentiveDataProviderV3 uiIncentivesProvider = IUiIncentiveDataProviderV3(
      report.uiIncentiveDataProvider
    );
    uiIncentivesProvider.getReservesIncentivesData(
      IPoolAddressesProvider(report.poolAddressesProvider)
    );

    // Write market deployment JSON report at /reports
    IMetadataReporter metadataReporter = IMetadataReporter(
      _deployFromArtifacts('MetadataReporter.sol:MetadataReporter')
    );
    metadataReporter.writeJsonReportMarket(report);
  }

  function _loadWarnings(MarketConfig memory config, DeployFlags memory flags) internal pure {
    if (config.paraswapAugustusRegistry == address(0)) {
      console.log(
        'Warning: Paraswap Adapters will be skipped at deployment due missing config.paraswapAugustusRegistry'
      );
    }
    if (
      (flags.l2 &&
        (config.l2SequencerUptimeFeed == address(0) ||
          config.l2PriceOracleSentinelGracePeriod == 0))
    ) {
      console.log(
        'Warning: L2 Sequencer uptime feed wont be set at deployment due missing config.l2SequencerUptimeFeed config.l2PriceOracleSentinelGracePeriod'
      );
    }
    if (
      config.networkBaseTokenPriceInUsdProxyAggregator == address(0) ||
      config.marketReferenceCurrencyPriceInUsdProxyAggregator == address(0)
    ) {
      console.log(
        'Warning: UiPoolDataProvider will be skipped at deployment due missing config.networkBaseTokenPriceInUsdProxyAggregator or config.marketReferenceCurrencyPriceInUsdProxyAggregator'
      );
    }
    if (config.wrappedNativeToken == address(0)) {
      console.log(
        'Warning: WrappedTokenGateway will be skipped at deployment due missing config.wrappedNativeToken'
      );
    }
  }
}
