// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {WalletBalanceProvider} from '../../../contracts/helpers/WalletBalanceProvider.sol';
import {UiPoolDataProviderV3} from '../../../contracts/helpers/UiPoolDataProviderV3.sol';
import {UiIncentiveDataProviderV3} from '../../../contracts/helpers/UiIncentiveDataProviderV3.sol';
import {IEACAggregatorProxy} from '../../../contracts/helpers/interfaces/IEACAggregatorProxy.sol';
import {AaveProtocolDataProvider} from '../../../contracts/helpers/AaveProtocolDataProvider.sol';
import {IPoolAddressesProvider} from '../../../contracts/interfaces/IPoolAddressesProvider.sol';
import 'forge-std/console.sol';

contract AaveV3GettersProcedureOne {
  struct GettersReportBatchOne {
    address walletBalanceProvider;
    address uiIncentiveDataProvider;
    address protocolDataProvider;
    address uiPoolDataProvider;
  }

  function _deployAaveV3GettersBatchOne(
    address poolAddressesProvider,
    address networkBaseTokenPriceInUsdProxyAggregator,
    address marketReferenceCurrencyPriceInUsdProxyAggregator
  ) internal returns (GettersReportBatchOne memory) {
    GettersReportBatchOne memory report;

    report.walletBalanceProvider = address(new WalletBalanceProvider());
    report.uiIncentiveDataProvider = address(new UiIncentiveDataProviderV3());
    report.protocolDataProvider = address(
      new AaveProtocolDataProvider(IPoolAddressesProvider(poolAddressesProvider))
    );
    console.log('Inside batch one');
    if (
      networkBaseTokenPriceInUsdProxyAggregator != address(0) &&
      marketReferenceCurrencyPriceInUsdProxyAggregator != address(0)
    ) {
      console.log('deploying uipooldata provider');
      report.uiPoolDataProvider = address(
        new UiPoolDataProviderV3(
          IEACAggregatorProxy(networkBaseTokenPriceInUsdProxyAggregator),
          IEACAggregatorProxy(marketReferenceCurrencyPriceInUsdProxyAggregator)
        )
      );
      console.log('deployed uipooldata provider: ', report.uiPoolDataProvider);
    }

    return report;
  }
}
