
function _RobustBertsimas_latex()
    return """
        ```math
        \\{\\mu | \\\\
        s.t.  \\quad \\mu_i \\leq \\hat{r}_i + z_i \\Delta_i \\quad \\forall i = 1:\\mathcal{N} \\\\
        \\quad \\quad \\mu_i \\geq \\hat{r}_i - z_i \\Delta_i  \\quad \\forall i = 1:\\mathcal{N} \\\\
        \\quad \\quad z_i \\geq 0 \\quad \\forall i = 1:\\mathcal{N} \\\\
        \\quad \\quad z_i \\leq 1 \\quad \\forall i = 1:\\mathcal{N} \\\\
        \\quad \\quad \\sum_{i}^{\\mathcal{N}} z_i \\leq \\Gamma \\quad \\forall i = 1:\\mathcal{N} \\\\
        \\} \\\\
        ```
        """
end
"""
    RobustBertsimas <: AbstractMeanVariance

Bertsimas's uncertainty set:

$(_RobustBertsimas_latex())

Atributes:
- `predicted_mean::Array{Float64,1}` (latex notation \\hat{r}): Predicted mean of returns.
- `uncertainty_delta::Array{Float64,1}` (latex notation \\Delta): Uncertainty around mean.
- `bertsimas_budjet::Array{Float64,1}` (latex notation \\Gamma): Number of assets in worst case.
- `predicted_covariance::Array{Float64,2}`: Predicted covariance of returns (formulation atribute).
"""
struct RobustBertsimas <: AbstractMeanVariance
    predicted_mean::Array{Float64,1}
    predicted_covariance::Array{Float64,2}
    uncertainty_delta::Array{Float64,1}
    bertsimas_budjet::Float64
    number_of_assets::Int
end

function RobustBertsimas(;
    predicted_mean::Array{Float64,1},
    predicted_covariance::Array{Float64,2},
    uncertainty_delta::Array{Float64,1},
    bertsimas_budjet::Float64,
)
    number_of_assets = size(predicted_mean, 1)
    if number_of_assets != size(predicted_covariance, 1)
        error("size of predicted mean ($number_of_assets) different to size of predicted covariance ($(size(predicted_covariance, 1)))")
    end
    if number_of_assets != size(uncertainty_delta, 1)
        error("size of predicted mean ($number_of_assets) different to size of uncertainty deltas ($(size(uncertainty_delta,1)))")
    end

    @assert prod(uncertainty_delta .>= 0)
    @assert issymmetric(predicted_covariance)
    return RobustBertsimas(
        predicted_mean, predicted_covariance, uncertainty_delta, bertsimas_budjet, number_of_assets
    )
end

function _portfolio_return_latex_RobustBertsimas_primal()
    return """
        ```math
        \\min_{\\mu, z} \\mu ' w \\\\
        s.t.  \\quad \\mu_i \\leq \\hat{r}_i + z_i \\Delta_i \\quad \\forall i = 1:\\mathcal{N} \\quad : \\pi^-_i \\\\
        \\quad \\quad \\mu_i \\geq \\hat{r}_i - z_i \\Delta_i  \\quad \\forall i = 1:\\mathcal{N} \\quad : \\pi^+_i \\\\
        \\quad \\quad z_i \\geq 0 \\quad \\forall i = 1:\\mathcal{N} \\\\
        \\quad \\quad z_i \\leq 1 \\quad \\forall i = 1:\\mathcal{N} \\quad : \\theta_i \\\\
        \\quad \\quad \\sum_{i}^{\\mathcal{N}} z_i \\leq \\Gamma \\quad \\forall i = 1:\\mathcal{N} \\quad : \\lambda \\\\
        ```
        """
end

function _portfolio_return_latex_RobustBertsimas_dual()
    return """
        ```math
        \\max_{\\lambda, \\pi^-, \\pi^+, \\theta} \\quad  \\sum_{i}^{\\mathcal{N}} (\\hat{r}_i (\\pi^+_i \\pi^-_i) - \\theta_i ) - \\Gamma \\lambda\\\\
        s.t.  \\quad   w_i = \\pi^+_i - \\pi^-_i  \\quad \\forall i = 1:\\mathcal{N} \\\\
        \\quad \\quad  \\Delta_i (\\pi^+_i + \\pi^-_i) - \\theta_i \\leq \\lambda \\quad \\forall i = 1:\\mathcal{N} \\\\
        \\quad \\lambda \\geq 0 , \\; \\pi^- \\geq 0 , \\; \\pi^+ \\geq 0 , \\; \\theta \\geq 0 \\\\
        ```
        """
end

"""
    portfolio_return!(model::JuMP.Model, w, formulation::RobustBertsimas)

Returns worst case return (WCR) in Bertsimas's uncertainty set ([`RobustBertsimas`](@ref)).

WCR is defined by the following primal problem: 

$(_portfolio_return_latex_RobustBertsimas_primal())

Which is equivalent to the following dual problem:

$(_portfolio_return_latex_RobustBertsimas_dual())

To avoid solving an optimization problem we enforece the dual constraints in 
the upper level problem and return the objective expression (a lower bound of the optimum).

Arguments:
 - `model::JuMP.Model`: JuMP upper level portfolio optimization model.
 - `w`: portfolio optimization investment variable ("weights").
 - `formulation::RobustBertsimas`: Struct containing atributes of Bertsimas's uncertainty set.
"""
function portfolio_return!(model::JuMP.Model, w, formulation::RobustBertsimas)
    # parameters
    r̄ = formulation.predicted_mean
    numA = formulation.number_of_assets
    Δ = formulation.uncertainty_delta
    Λ = formulation.bertsimas_budjet
    # dual variables
    @variable(model, λ >= 0)
    @variable(model, π_neg[i=1:numA] >= 0)
    @variable(model, π_pos[i=1:numA] >= 0)
    @variable(model, θ[i=1:numA] >= 0)
    # constraints: from duality
    @constraints(
        model,
        begin
            constrain_dual1[i=1:numA], w[i] == π_pos[i] - π_neg[i]
        end
    )
    @constraints(
        model,
        begin
            constrain_dual2[i=1:numA], Δ[i] * (π_pos[i] + π_neg[i]) - θ[i] <= λ
        end
    )

    return sum(r̄[i] * (π_pos[i] - π_neg[i]) for i in 1:numA) - sum(θ[i] for i in 1:numA)
end

##################################
"""BenTal's uncertainty set"""
struct RobustBenTal <: AbstractMeanVariance
    predicted_mean::Array{Float64,1}
    predicted_covariance::Array{Float64,2}
    uncertainty_delta::Float64
    number_of_assets::Int
end

function RobustBenTal(;
    predicted_mean::Array{Float64,1},
    predicted_covariance::Array{Float64,2},
    uncertainty_delta::Float64,
)
    number_of_assets = size(predicted_mean, 1)
    if number_of_assets != size(predicted_covariance, 1)
        error("size of predicted mean ($number_of_assets) different to size of predicted covariance ($(size(predicted_covariance, 1)))")
    end

    @assert uncertainty_delta >= 0
    @assert issymmetric(predicted_covariance)
    return RobustBenTal(
        predicted_mean, predicted_covariance, uncertainty_delta, number_of_assets
    )
end

function _portfolio_return_latex_RobustBenTal_dual()
    return """
        ```math
        \\max_{\\theta} \\quad  w ' \\hat{r} - \\theta ' \\delta \\\\
        s.t.  \\quad   ||Σ^{\\frac{1}{2}}  w || \\leq \\delta \\\\
        ```
        """
end

"""
    portfolio_return!(model::JuMP.Model, w, formulation::RobustBenTal)

Returns worst case return in BenTal's uncertainty set, defined by the following dual problem: 

$(_portfolio_return_latex_RobustBenTal_dual())
"""
function portfolio_return!(model::JuMP.Model, w, formulation::RobustBenTal)
    # parameters
    r̄ = formulation.predicted_mean
    numA = formulation.number_of_assets
    δ = formulation.uncertainty_delta
    sqrt_Σ = sqrt(formulation.predicted_covariance)
    # dual variables
    @variable(model, θ)
    # constraints: from duality
    norm_2_pi = @variable(model)
    @constraint(model, [norm_2_pi; sqrt_Σ * w] in JuMP.SecondOrderCone())
    @constraint(model, norm_2_pi <= θ)

    return dot(w, r̄) - θ * δ
end
