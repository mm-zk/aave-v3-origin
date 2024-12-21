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
      memory reserves = new ConfiguratorInputTypes.InitReserveInput[](1);

    address magicHelper = address(0x49fd2BE640DB2910c2fAb69bB8531Ab6E76127ff);

    reserves[0] = ConfiguratorInputTypes.InitReserveInput({
      aTokenImpl: report.aToken,
      variableDebtTokenImpl: report.variableDebtToken,
      useVirtualBalance: true,
      interestRateStrategyAddress: report.defaultInterestRateStrategy,
      underlyingAsset: address(0xDC11f7E700A4c898AE5CAddB1082cFfa76512aDD),
      treasury: report.treasury,
      incentivesController: address(0), // no incentives
      aTokenName: 'EXM token',
      aTokenSymbol: 'EXM',
      variableDebtTokenName: 'VAR token',
      variableDebtTokenSymbol: 'VAR',
      params: bytes(''),
      interestRateData: abi.encode(interestRate)
    });
    aa.initReserves(reserves);

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
