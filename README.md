# PortfolioOpt
Simple package with Portfolio Optimization (PO) formulations using [JuMP.jl](https://github.com/jump-dev/JuMP.jl).

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://andrewrosemberg.github.io/PortfolioOpt.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://andrewrosemberg.github.io/PortfolioOpt.jl/dev)
[![Build Status](https://travis-ci.com/andrewrosemberg/PortfolioOpt.jl.svg?branch=master)](https://travis-ci.com/andrewrosemberg/PortfolioOpt.jl)
<!-- [![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle) -->
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

## PO Strategies

There are two types of strategies implemented in this package: 
 - "End-to-End" functions that receive parameters as inputs and output the weights of a portfolio summing up to the maximum wealth defined in the parameters. These are mainly simple rules or analytical solutions to simple PO formulations: 
    - `max_sharpe` 
    - `equal_weights` 
    - `mean_variance_noRf_analytical` 
 - Modifying functions (identifiable by a `!` at the end of the function) that receive a `JuMP` model, a reference to the investment variable present in this model and the parameters of the strategy as inputs, and modifies the model by adding the necessary variables and constraints. Currently implemented ones are: 
    - `po_minvar_limitmean_noRf!` 
    - `po_minvar_limitmean_Rf!` 
    - `po_maxmean_limitvar_Rf!` 
    - `po_minvar_limitmean_robust_bertsimas!` 
    - `po_minvar_limitmean_robust_bental!` 
    - `po_maxmean_limitvar_robust_bertsimas!` 
    - `po_maxmean_limitvar_robust_bental!` 
    - `po_maxmean_delague!` 
    - `betina_robust!` 
    - `min_cvar_noRf!` 
    - `max_return_lim_cvar_noRf!`

Normally this package won't focus nor make available forecasting functionalities, but, as an exception, there is one point prediction forecasting function exported: 
 - `mixed_signals_predict_return`

## TestUtils

As an extra, some testing utilities are available through the submodule called `TestUtils`. 
Mainly:
 - `get_test_data` that returns a TimeArray of Prices for 6 assets.
 - `backtest_po` that provides a basic backtest using provided strategy and returns data.
But also:
 - `reajust_volumes`
 - `base_model`
 - `compute_solution_backtest`
 - `mean_variance`
 - `returns_montecarlo`

## Example

```julia
using COSMO
using PortfolioOpt
using PortfolioOpt.TestUtils: backtest_po, compute_solution_backtest, get_test_data, 
    mean_variance, base_model

prices = get_test_data()
numD, numA = size(prices) # A: Assets    D: Days
returns_series = percentchange(prices)

solver = optimizer_with_attributes(
    COSMO.Optimizer, "verbose" => false, "max_iter" => 900000
)

start_date = timestamp(returns_series)[100]

wealth_strategy, returns_strategy =
    backtest_po(returns_series; start_date=start_date) 
        do past_returns, current_wealth, risk_free_return

        # Prep data provided by the backtest pipeline
        numD, numA = size(past_returns)
        returns = values(past_returns)
        # calculate mean and variance for the past 60 days
        Σ, r̄ = mean_variance(returns[(end - 60):end, :])

        # Parameters
        # maximum acceptable normalized variance for our portfolio
        max_risk = 0.8
        
        # Build model 
        # creates jump model with portfolio weights variable w
        model, w = base_model(numA; allow_borrow=false)
        # modifies the problem to fromulation variable and constraints
        po_maxmean_limitvar_Rf!(model, w, Σ, r̄, max_risk, risk_free_return, 1)

        # Optimize model and retrieve solution (x = optimal w value)
        x = compute_solution_backtest(model, w, solver)

        # return invested portfolio in used currency
        return x * current_wealth
end

```

### Plot Results
```
plot(
    wealth_strategy;
    title="Culmulative Wealth",
    xlabel="Time",
    ylabel="Wealth",
    legend=:outertopright,
)
```
![](https://github.com/andrewrosemberg/PortfolioOpt/blob/master/docs/src/assets/cumwealth.png?raw=true)