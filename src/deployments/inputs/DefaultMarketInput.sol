// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './MarketInput.sol';

contract DefaultMarketInput is MarketInput {
  function _getMarketInput(
    address deployer
  )
    internal
    pure
    override
    returns (
      Roles memory roles,
      MarketConfig memory config,
      DeployFlags memory flags,
      MarketReport memory deployedContracts
    )
  {
    roles.marketOwner = deployer;
    roles.emergencyAdmin = deployer;
    roles.poolAdmin = deployer;

    config.marketId = 'Aave V3 Testnet Market';
    config.providerId = 8080;
    config.oracleDecimals = 8;
    config.flashLoanPremiumTotal = 0.0005e4;
    config.flashLoanPremiumToProtocol = 0.0004e4;

    // CHANGEHERE
    // Also change to this 'counter' address.
    config.networkBaseTokenPriceInUsdProxyAggregator = address(
      0x5FbDB2315678afecb367f032d93F642f64180aa3
    );

    // CHANGEHERE
    config.marketReferenceCurrencyPriceInUsdProxyAggregator = address(
      0x5FbDB2315678afecb367f032d93F642f64180aa3
    );

    return (roles, config, flags, deployedContracts);
  }
}
