function downtime_computation(enhanced_wind, delayfactor)
% Memory-optimized version:
% - No num_tc × num_points temporary matrices
% - Online accumulation over TCs and GCMs
% - Use single precision for large arrays where possible
addpath './P5function'
% if nargin < 2, delayfactor = 1; end
% if nargin < 1, enhanced_wind = 0; end
% delayfactor = 0;
% enhanced_wind = 0; 


% =====================================================
% 1) Repair-time parameters (days): [min, mean, max]
% =====================================================
onshore_yielding_repair_time         = [20,   40,   60];   % days
onshore_buckling_reconstruction_time = [540,  720,  900];  % days (18–30 months)
offshore_yielding_repair_time        = onshore_yielding_repair_time * 2;  % days
offshore_buckling_reconstruction_time= onshore_buckling_reconstruction_time *2;  % days (30–48 months)
PV_repair_time_days                  = [60,   120,  180];   % days (2–6 months)

% Apply delay factor (shift all bounds by + mean*delayfactor)
onshore_yielding_repair_time          = onshore_yielding_repair_time          + onshore_yielding_repair_time(2)          * delayfactor;
onshore_buckling_reconstruction_time  = onshore_buckling_reconstruction_time  + onshore_buckling_reconstruction_time(2)  * delayfactor;
offshore_yielding_repair_time         = offshore_yielding_repair_time         + offshore_yielding_repair_time(2)         * delayfactor;
offshore_buckling_reconstruction_time = offshore_buckling_reconstruction_time + offshore_buckling_reconstruction_time(2) * delayfactor;
PV_repair_time_days                   = PV_repair_time_days                   + PV_repair_time_days(2)                   * delayfactor;

% =====================================================
% 2) Build distributions ONCE (lognormal constrained by bounds+mean)
%    (your helper in P5function)
% =====================================================
pd_onshore_y  = lognormal_from_bounds_and_mean( ...
    onshore_yielding_repair_time(1), onshore_yielding_repair_time(2), onshore_yielding_repair_time(3));
pd_onshore_b  = lognormal_from_bounds_and_mean( ...
    onshore_buckling_reconstruction_time(1), onshore_buckling_reconstruction_time(2), onshore_buckling_reconstruction_time(3));
pd_offshore_y = lognormal_from_bounds_and_mean( ...
    offshore_yielding_repair_time(1), offshore_yielding_repair_time(2), offshore_yielding_repair_time(3));
pd_offshore_b = lognormal_from_bounds_and_mean( ...
    offshore_buckling_reconstruction_time(1), offshore_buckling_reconstruction_time(2), offshore_buckling_reconstruction_time(3));
pd_PV         = lognormal_from_bounds_and_mean( ...
    PV_repair_time_days(1), PV_repair_time_days(2), PV_repair_time_days(3));

% =====================================================
% 3) Scenarios / GCM settings
% =====================================================
exp_name = {'ner','far'};  % your file naming
scenarios = {'his','ssp126','ssp245','ssp585'};

GCM_NAME = {'CanESM5','CMCC-CM2-SR5','CNRM-CM6-1',...
    'EC-Earth3','INM-CM4-8','IPSL-CM6A-LR','MPI-ESM1-2-LR',...
    'MRI-ESM2-0','NorESM2-LM','TaiESM1'};

nGCM = 10; % <-- set back to 10 when you run full ensemble

% Load points once
L = load('./qgis/china_onoffPV_sum.mat','china_onoffPV_sum');
china_onoffPV_sum = L.china_onoffPV_sum;
clear L

turbine_lon = [china_onoffPV_sum.Lon];
turbine_lat = [china_onoffPV_sum.Lat];
waterdepth  = [china_onoffPV_sum.waterdepth];

num_points  = length(china_onoffPV_sum);

% 7 scenario-states: his + (3 SSP × near/far)
nScenState = 7;

% Preallocate (single saves memory)
sum_s_on_y  = zeros(nScenState, num_points, 'single');
sum_s_on_b  = zeros(nScenState, num_points, 'single');
sum_s_off_y = zeros(nScenState, num_points, 'single');
sum_s_off_b = zeros(nScenState, num_points, 'single');
sum_s_pv    = zeros(nScenState, num_points, 'single');
sum_s_wl25  = zeros(nScenState, num_points, 'single');  % wind_larger25/24
sum_s_ih    = zeros(nScenState, num_points, 'single');  % Ih_I_ratio/24

% constants
ampl_on  = single((80/10)^(1/7));
ampl_off = single((90/10)^(1/9));
eps1     = eps('single');

% =====================================================
% 4) Main loops: online accumulation (NO num_tc×num_points)
% =====================================================
s_num = 0;

for j = 1:4
    if j == 1
        k_arr = 1;      % historical only
    else
        k_arr = [1 2];  % near/far
    end

    for k = k_arr
        s_num = s_num + 1;

        % Running sum across GCMs (online average)
        sumG_on_y  = zeros(1, num_points, 'single');
        sumG_on_b  = zeros(1, num_points, 'single');
        sumG_off_y = zeros(1, num_points, 'single');
        sumG_off_b = zeros(1, num_points, 'single');
        sumG_pv    = zeros(1, num_points, 'single');
        sumG_wl25  = zeros(1, num_points, 'single');
        sumG_ih    = zeros(1, num_points, 'single');

        for i = 1:nGCM
            % Build file tag
            if j < 2
                GCM_TAG = ['era5_e', num2str(i)];
            else
                GCM_TAG = ['era5PI_', GCM_NAME{i}, '_', scenarios{j}, '_', exp_name{k}];
            end
            disp([GCM_TAG ,'  enhanced_wind ' , num2str( enhanced_wind) ,'  delayfactor ' , num2str( delayfactor)])
            % Load only wind_result to reduce memory
            fwind = ['./P2_onoffPV_sum_result/C15_', GCM_TAG, '_wind_result_fixsstera5.mat'];
            if ~exist(fwind,'file')
                warning('Missing file: %s', fwind);
                continue
            end
            S = load(fwind, 'wind_result');
            wind_result = S.wind_result;
            clear S

            num_tc = length(wind_result);

            % Online accumulation over TCs (1×num_points only)
            acc_on_y  = zeros(1, num_points, 'single');
            acc_on_b  = zeros(1, num_points, 'single');
            acc_off_y = zeros(1, num_points, 'single');
            acc_off_b = zeros(1, num_points, 'single');
            acc_pv    = zeros(1, num_points, 'single');
            acc_wl25  = zeros(1, num_points, 'single');
            acc_ih    = zeros(1, num_points, 'single');

            for n = 1:num_tc
                maxwind = single(wind_result(n).maxwind);
                wl25    = single(wind_result(n).wind_larger25) / 24; % hours -> days
                ih      = single(wind_result(n).Ih_I_ratio)   / 24; % hours -> days

                % -------------------------
                % Onshore failure probs
                % -------------------------
                Uon = max(maxwind .* ampl_on - single(enhanced_wind), 0);
                Uon = max(Uon, eps1);

                pf_on_b = single(normcdf((log(Uon) - log(51)) / 0.0588));
                pf_on_y = single(normcdf((log(Uon) - log(40)) / 0.0588));
                pf_on_y_nob = pf_on_y .* (1 - pf_on_b);

                rt_on_y = single(random(pd_onshore_y, 1, num_points));
                rt_on_b = single(random(pd_onshore_b, 1, num_points));

                acc_on_b = acc_on_b + rt_on_b .* pf_on_b;
                acc_on_y = acc_on_y + rt_on_y .* pf_on_y_nob;

                % -------------------------
                % Offshore failure probs
                % -------------------------
                Uoff = max(maxwind .* ampl_off - single(enhanced_wind), 0);
                Uoff = max(Uoff, eps1);

                pf_off_b = single(normcdf((log(Uoff) - log(59)) / 0.0677));
                pf_off_y = single(normcdf((log(Uoff) - log(50)) / 0.0677));
                pf_off_y_nob = pf_off_y .* (1 - pf_off_b);

                rt_off_y = single(random(pd_offshore_y, 1, num_points));
                rt_off_b = single(random(pd_offshore_b, 1, num_points));

                acc_off_b = acc_off_b + rt_off_b .* pf_off_b;
                acc_off_y = acc_off_y + rt_off_y .* pf_off_y_nob;

                % -------------------------
                % PV failure prob
                % -------------------------
                PVwind = max(maxwind - single(enhanced_wind), 0);
                pf_pv  = single(max(min(0.22 * PVwind - 0.48, 100), 0) / 100);

                rt_pv  = single(random(pd_PV, 1, num_points));
                acc_pv = acc_pv + rt_pv .* pf_pv;

                % -------------------------
                % Short-term downtime
                % -------------------------
                acc_wl25 = acc_wl25 + wl25;
                acc_ih   = acc_ih   + ih;
            end

            % Add this GCM to scenario running sum
            sumG_on_y  = sumG_on_y  + acc_on_y;
            sumG_on_b  = sumG_on_b  + acc_on_b;
            sumG_off_y = sumG_off_y + acc_off_y;
            sumG_off_b = sumG_off_b + acc_off_b;
            sumG_pv    = sumG_pv    + acc_pv;
            sumG_wl25  = sumG_wl25  + acc_wl25;
            sumG_ih    = sumG_ih    + acc_ih;

            clear wind_result acc_on_y acc_on_b acc_off_y acc_off_b acc_pv acc_wl25 acc_ih
        end

        % Mean across GCMs (avoid storing nGCM×num_points)
        sum_s_on_y(s_num,:)  = sumG_on_y  / nGCM;
        sum_s_on_b(s_num,:)  = sumG_on_b  / nGCM;
        sum_s_off_y(s_num,:) = sumG_off_y / nGCM;
        sum_s_off_b(s_num,:) = sumG_off_b / nGCM;
        sum_s_pv(s_num,:)    = sumG_pv    / nGCM;
        sum_s_wl25(s_num,:)  = sumG_wl25  / nGCM;
        sum_s_ih(s_num,:)    = sumG_ih    / nGCM;

        clear sumG_on_y sumG_on_b sumG_off_y sumG_off_b sumG_pv sumG_wl25 sumG_ih
    end
end

% =====================================================
% 5) Pack results & save
% =====================================================
result_sum_effectday = struct();
result_sum_effectday.repair_time_onshore_yielding  = sum_s_on_y;
result_sum_effectday.repair_time_onshore_buckling  = sum_s_on_b;
result_sum_effectday.repair_time_offshore_yielding = sum_s_off_y;
result_sum_effectday.repair_time_offshore_buckling = sum_s_off_b;
result_sum_effectday.repair_time_PV                = sum_s_pv;
result_sum_effectday.repair_time_wind_larger25     = sum_s_wl25;
result_sum_effectday.repair_time_Ih_I_ratio        = sum_s_ih;
result_sum_effectday.turbine_lon = turbine_lon;
result_sum_effectday.turbine_lat = turbine_lat;
result_sum_effectday.waterdepth  = waterdepth;

if exist('inploy.mat','file')
    P = load('inploy.mat');
    if isfield(P,'inPoly')
        result_sum_effectday.landflag = P.inPoly;
    end
    clear P
end

outname = sprintf('./P5_effect_day_result/repair_time_distribution_Lu25_enwind%d_delay%.1f.mat', ...
    enhanced_wind, delayfactor);

save(outname, 'result_sum_effectday', '-v7.3');

end
