module PortfolioOpt

using JuMP
using LinearAlgebra
using LinearAlgebra: dot 

include("./src/mean_variance_markovitz.jl")
include("./src/mean_variance_robust.jl")
include("./src/stochastic_programming.jl")
include("./src/mean_variance_dro.jl")
include("./src/simple_rules.jl")
include("./src/data_driven_ro.jl")
include("./src/forecasts.jl")

export mean_variance_noRf_analytical,
    po_minvar_limitmean_noRf!,
    po_minvar_limitmean_Rf!,
    po_maxmean_limitvar_Rf!,
    po_minvar_limitmean_robust_bertsimas!,
    po_minvar_limitmean_robust_bental!,
    po_maxmean_limitvar_robust_bertsimas!,
    po_maxmean_limitvar_robust_bental!,
    max_sharpe,
    equal_weights,
    min_cvar_noRf!,
    max_return_lim_cvar_noRf!,
    mixed_signals_predict_return

end
