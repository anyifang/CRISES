function pd = lognormal_from_bounds_and_mean(lower, expected, upper)
%LOGNORMAL_TRUNCATED_FROM_BOUNDS_AND_MEAN  Construct truncated lognormal with exact mean and tight bounds
%
%   pd = lognormal_truncated_from_bounds_and_mean(lower, expected, upper)
%
%   Creates a TRUNCATED lognormal distribution such that:
%       - The expected value (mean) is exactly 'expected' (or extremely close)
%       - Virtually no samples (>99.9%) fall outside [lower, upper]
%
%   Method:
%     1. First fit an untruncated lognormal with exact mean = expected
%     2. Estimate sigma so that ~99.8% of the mass is already within [lower, upper]
%     3. Apply hard truncation to [lower, upper] for safety
%
%   This ensures almost no out-of-bounds values while preserving the desired mean.
%
%   Inputs:
%       lower    - strict lower bound (days)
%       expected - desired mean of the distribution (days)
%       upper    - strict upper bound (days)
%
%   Output:
%       pd       - TruncatedLognormal probability distribution object
%
%   Example:
%       pd = lognormal_truncated_from_bounds_and_mean(25, 40, 60);
%       samples = random(pd, 100000, 1);
%       mean(samples)      % ≈ 40
%       sum(samples < 25 | samples > 60)  % ≈ 0

    if nargin ~= 3
        error('Three inputs required: lower, expected, upper');
    end
    
    if lower >= expected || expected >= upper
        error('Must have lower < expected < upper');
    end
    if lower < 0
        warning('Lower bound < 0; lognormal defined only for positive values. Shifting to small positive.');
        lower = max(lower, 1e-6);
    end

    desired_mean = expected;

    % Step 1: Estimate sigma using 0.1% and 99.9% quantiles ≈ lower and upper
    % This makes the untruncated distribution already cover almost all mass in bounds
    z_low  = norminv(0.001);   % ≈ -3.0902
    z_high = norminv(0.999);   % ≈  3.0902

    sigma_from_lower = log(desired_mean / lower) / (-z_low);
    sigma_from_upper = log(upper / desired_mean) / z_high;

    % Take the minimum sigma to be conservative (tighter distribution)
    sigma = min(sigma_from_lower, sigma_from_upper);
    sigma = max(sigma, 0.05);  % prevent too narrow distribution

    % Step 2: Compute mu for exact mean in untruncated lognormal
    mu = log(desired_mean) - 0.5 * sigma^2;

    % Step 3: Create base lognormal
    pd_base = makedist('Lognormal', 'mu', mu, 'sigma', sigma);

    % Step 4: Hard truncate to [lower, upper]
    pd = truncate(pd_base, lower, upper);

    % Verification (optional, comment out if not needed)
    % fprintf('Mean ≈ %.3f (desired %.3f)\n', mean(pd), desired_mean);
    % fprintf('P(%.1f <= X <= %.1f) ≈ %.6f\n', lower, upper, cdf(pd,upper) - cdf(pd,lower));

end