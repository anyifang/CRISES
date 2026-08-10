%% P26_Master_6Panel_BarUpdate.m
% 目的: 循环绘制 Mr = 1, 2, 4 下的全景海报 (2x3 排版) - 【物理成本模型升级版】
% 核心升级:
% 1. 成本计算升级为基于风压物理机制的平方差模型: Cost ~ lambda * [(Ud + dv)^2 - Ud^2]
% 2. 参数 Ud (基础设计风速) 和 lambda (成本系数) 基于 IEC 标准和 Clausen/Rose/Emes 等文献标定。
% 3. 经济模型更新为 Project_Life = 25年, Discount_Rate = 5%。

clear; close all;


%% ========= 0. 全局绘图样式控制 (统一字号设置) =========
Style.LabelFS     = 24;     % 子图编号 (a, b, c...) 字号
Style.LabelWeight = 'bold'; % 子图编号字重
Style.AxisLabelFS = 16;     % 坐标轴标签 (X/Y Label) 字号
Style.AxisTickFS  = 16;     % 坐标轴刻度 (Tick) 字号
Style.LegendFS    = 16;     % 图例字号
Style.AnnotFS     = 14;     % 图内注释文字字号
Style.PieTextFS   = 14;     % 饼图内文字字号

%% ========= 1. 全局与经济学参数配置 =========
scen_names = {'Hist', 'N-SSP1', 'N-SSP2', 'N-SSP5', 'F-SSP1', 'F-SSP2', 'F-SSP5'};
nScen = length(scen_names);
scen_list_P7 = [1, 2, 4, 6, 3, 5, 7];

Cost.Dep_Replace = 0.5;
Cost.CAPEX_onshore  = 1.1 * Cost.Dep_Replace;
Cost.CAPEX_offshore = 2.81 * Cost.Dep_Replace;
Cost.CAPEX_dpv      = 0.36 * Cost.Dep_Replace;
Cost.CAPEX_upv      = 0.38 * Cost.Dep_Replace;
Cost.Yield_Factor   = 0.10;

% +++ [NEW] 物理模型参数配置 (Physical Cost Model) +++
% 1. 基础设计风速 (m/s) [Source: IEC 61400-1 Class I for Wind; GB50009 for PV]
Ud.onshore  = 42.5;   % IEC Class II
Ud.offshore = 50;   % IEC Class I
Ud.dpv      = 20;   % Typical design base
Ud.upv      = 40;

% 2. 成本缩放系数 lambda [Re-calibrated based on Clausen(2007) & Rose(2012)]
% 公式: Cost_Increase % = lambda * (V_final^2 - Ud^2)
% lambda 的物理含义是：单位风压增量(m/s)^2 对应的总成本增加比例

% [Onshore]: Calibrated from Clausen(2007): 42.5->70 m/s (+27.5m/s) causes ~25% CAPEX increase
% lambda = 0.25 / (70^2 - 42.5^2) = 0.20 / 2400 ≈ 8.33e-5
lambda.onshore  = 8e-5;

% [Offshore]: Calibrated from Rose(2012): 50->70 m/s (+20m/s) causes ~20%*0.6 = 12

% % CAPEX increase NREL《2024年风能成本回顾 (Cost of Wind Energy Review: 2024
% Edition)》 onshore 55.4% offshore 32.7%   off/on 60%
% lambda = 0.12 / (70^2 - 50^2) = 0.05 / 1100 ≈ 4.54e-5
lambda.offshore = 5e-5;

% [PV]: Stone, Laurie 2020  5% C3/C4 -> C5    5%  (58 -> 70m/s) *0.88 = 10m/s
% lambda = 0.05 / (30^2 - 20^2)
% lambda = 0.05 / (50^2 - 40^2)
lambda.dpv      = 1e-4;
lambda.upv      = 5.5e-5;   % 假设光伏支架的材料成本敏感度对于分布式和集中式相近

T_base.on_buckle = 24*30;  T_base.on_yield = 40;
T_base.off_buckle = 48*30; T_base.off_yield = 80;
T_base.pv_damage = 4*30;
Y_sim = 40 * 1000 / 23.6;

tech_list = {'onshore', 'offshore', 'dpv', 'upv'};

% +++ [NEW] 经济学参数更新 (NPV Model) +++
Project_Life = 25;       % [Source: IRENA 2023, NREL]
Discount_Rate = 0.05;    % [Source: IPCC AR6 standard]
CRF = (Discount_Rate * (1 + Discount_Rate)^Project_Life) / ((1 + Discount_Rate)^Project_Life - 1);

enwind_vec = 0:20;       % Delta v (增量风速)
nPoints = length(enwind_vec);
den = Y_sim * 360;

%% ========= 2. 高级冷暖色系与 P6 原始色彩定义 =========
% --- P6 原始经典配色 (供图 a, b 使用) ---
tech_colors = [0.15 0.40 0.85;  % Onshore
    0.35 0.70 0.95;  % Offshore
    0.95 0.55 0.15;  % DPV
    0.98 0.75 0.25]; % UPV

% 【完美呼应修改】：让 c, f 的颜色完全锚定并衍生自 a, b

% 1. 陆上风电：直接使用 a/b 的 Onshore 颜色，保持 100% 视觉一致！
c_all_on = [0.15 0.40 0.85];

% 2. 光伏：由于 c/f 中合并了光伏，直接使用 a/b 中受灾主导的 DPV 橘色！
c_all_pv = [0.95 0.55 0.15];

% 3. 海上风电 (4个类别)：以 a/b 的 Offshore 颜色 [0.35 0.70 0.95] 为基准拉出渐变
% 确保它们都属于青蓝色系，并且与陆风的深正蓝色有明显的色相区别
c_gd      = [0.15 0.55 0.85]; % 广东海风: 加深版海蓝
c_fj      = [0.25 0.62 0.90]; % 福建海风: 中度过渡蓝
c_zj      = [0.35 0.70 0.95]; % 浙江海风: 【完全等于 a/b 中的 Offshore 颜色】
c_oth_off = [0.60 0.85 0.98]; % 其他海风: 浅冰蓝

group_labels = {'Offshore wind (Guangdong)', 'Offshore wind (Fujian)', 'Offshore wind (Zhejiang)', ...
    'Offshore wind (Other province)', 'Onshore wind', 'PV'};
cmap_6cat = [c_gd; c_fj; c_zj; c_oth_off; c_all_on; c_all_pv];

% P6 其他绘图配置
dataFile_P6 = 'LossGrid_Econ_Spatial_ProvPrice_WithAssetLoss.mat';
if ~exist(dataFile_P6, 'file'), dataFile_P6 = 'LossGrid_Econ_Spatial_ProvPrice.mat'; end
row_d_idxs = [1, 2, 3]; col_e_idxs = [1, 2, 3];
plot_order_idx_P6 = [1, 2, 4, 6, 3, 5, 7];
tech_labels = {'Onshore wind', 'Offshore wind', 'Distributed PV', 'Utility-scale PV'};
idx_L_col = 1;

%% ========= 3. 加载高精度 CF 数据与动态装机数据 =========
fprintf('Loading P6 Data...\n');
load(dataFile_P6, 'GenLossGrid', 'TotalEconGrid');

fprintf('Loading P7 Real CF and Dynamic VRE Data...\n');
CF_On  = readtable('H:\wind_turbine\VREdata\VREDepUpdate\CF\onshore_attr_era5_cell_2019.csv');
CF_Off = readtable('H:\wind_turbine\VREdata\VREDepUpdate\CF\offshore_attr_era5_cell_2019.csv');
CF_Upv = readtable('H:\wind_turbine\VREdata\VREDepUpdate\CF\upv_attr_era5_cell_2019.csv');

[VRE_far, S, prov_names] = load_and_prep_vre('./VREdata/VRE_far_filtered.mat', 'VRE_far', CF_On, CF_Off, CF_Upv, 'Y2060');
try [VRE_near, ~, ~] = load_and_prep_vre('./VREdata/VRE_near_filtered.mat', 'VRE_near', CF_On, CF_Off, CF_Upv, 'Y2030'); catch, VRE_near=VRE_far; end
try [VRE_hist, ~, ~] = load_and_prep_vre('./VREdata/VRE_hist_filtered.mat', 'VRE_hist', CF_On, CF_Off, CF_Upv, 'Y2020'); catch, VRE_hist=VRE_far; end

nProv = length(prov_names);
prov_colors = repmat([0.4 0.4 0.4], nProv, 1);
for ip = 1:nProv
    pname = lower(prov_names{ip});
    if contains(pname, 'guangdong') || contains(pname, '广东'), prov_colors(ip, :) = c_gd;
    elseif contains(pname, 'fujian') || contains(pname, '福建'), prov_colors(ip, :) = c_fj;
    elseif contains(pname, 'zhejiang') || contains(pname, '浙江'), prov_colors(ip, :) = c_zj;
    elseif contains(pname, 'jiangsu') || contains(pname, '江苏'), prov_colors(ip, :) = [0.10 0.55 0.60];
    elseif contains(pname, 'shandong') || contains(pname, '山东'), prov_colors(ip, :) = [0.30 0.65 0.75];
    end
end
color_other = [0.8 0.8 0.8];

gd_idx = find(contains(lower(string(prov_names)), 'guangdong') | contains(prov_names, '广东'), 1);
fj_idx = find(contains(lower(string(prov_names)), 'fujian') | contains(prov_names, '福建'), 1);
zj_idx = find(contains(lower(string(prov_names)), 'zhejiang') | contains(prov_names, '浙江'), 1);

%% ========= 4. 开启 Mr 循环计算与画图 =========
Mr_vals = [1, 2, 4];

for idx_Mr = 1:3
    Mr = Mr_vals(idx_Mr);
    delay_val = Mr - 1;

    fprintf('\n======================================================\n');
    fprintf('  Processing Master Dashboard for Mr = %d (Delay = %g)\n', Mr, delay_val);
    fprintf('======================================================\n');

    R_all = cell(nPoints, 1);
    for ie = 1:nPoints
        [fname, ok] = find_result_file(baseDir, enwind_vec(ie), delay_val);
        if ~ok, error('File not found for enwind=%d, delay=%g', enwind_vec(ie), delay_val); end
        tmp = load(fname, 'result_sum_effectday'); R_all{ie} = tmp.result_sum_effectday;
    end

    R0 = R_all{1}; XYt = [R0.turbine_lon(:), R0.turbine_lat(:)];
    idx_map_hist = knnsearch(XYt, [VRE_hist.lon, VRE_hist.lat]);
    idx_map_near = knnsearch(XYt, [VRE_near.lon, VRE_near.lat]);
    idx_map_far  = knnsearch(XYt, [VRE_far.lon, VRE_far.lat]);

    Prov_Loss_Tech = zeros(nProv, 4, nPoints, nScen, 'single');
    Prov_Cap_Tech  = zeros(nProv, 4, nScen);

    for ie = 1:nPoints
        R = R_all{ie};
        dt_on  = double(R.repair_time_onshore_buckling + R.repair_time_onshore_yielding + R.repair_time_wind_larger25) / den;
        dt_off = double(R.repair_time_offshore_buckling + R.repair_time_offshore_yielding + R.repair_time_wind_larger25) / den;
        dt_dpv = double(R.repair_time_DPV + R.repair_time_Ih_I_ratio) / den;
        dt_upv = double(R.repair_time_UPV + R.repair_time_Ih_I_ratio) / den;

        p_on_b  = double(R.repair_time_onshore_buckling) / (T_base.on_buckle * Mr) / Y_sim;
        p_on_y  = double(R.repair_time_onshore_yielding) / (T_base.on_yield * Mr) / Y_sim;
        p_off_b = double(R.repair_time_offshore_buckling) / (T_base.off_buckle * Mr) / Y_sim;
        p_off_y = double(R.repair_time_offshore_yielding) / (T_base.off_yield * Mr) / Y_sim;
        p_dpv_d = double(R.repair_time_DPV) / (T_base.pv_damage * Mr) / Y_sim;
        p_upv_d = double(R.repair_time_UPV) / (T_base.pv_damage * Mr) / Y_sim;

        for is = 1:nScen
            s_idx = scen_list_P7(is);
            if is == 1, V_cur = VRE_hist; k_map = idx_map_hist;
            elseif is <= 4, V_cur = VRE_near; k_map = idx_map_near;
            else, V_cur = VRE_far;  k_map = idx_map_far; end

            cap = V_cur.cap_GW; cf = V_cur.annual_cf; price = V_cur.price;
            gen_loss = zeros(height(V_cur), 1); asset_loss = zeros(height(V_cur), 1);

            idx_on = V_cur.tech == "onshore"; idx_off_m = V_cur.tech == "offshore";
            idx_dpv = V_cur.tech == "dpv"; idx_upv = V_cur.tech == "upv";

            gen_loss(idx_on) = cap(idx_on) .* dt_on(s_idx, k_map(idx_on))' .* cf(idx_on) * 8.76;
            asset_loss(idx_on) = cap(idx_on) .* (p_on_b(s_idx, k_map(idx_on))'*Cost.CAPEX_onshore + p_on_y(s_idx, k_map(idx_on))'*Cost.CAPEX_onshore*Cost.Yield_Factor);

            gen_loss(idx_off_m) = cap(idx_off_m) .* dt_off(s_idx, k_map(idx_off_m))' .* cf(idx_off_m) * 8.76;
            asset_loss(idx_off_m) = cap(idx_off_m) .* (p_off_b(s_idx, k_map(idx_off_m))'*Cost.CAPEX_offshore + p_off_y(s_idx, k_map(idx_off_m))'*Cost.CAPEX_offshore*Cost.Yield_Factor);

            gen_loss(idx_dpv) = cap(idx_dpv) .* dt_dpv(s_idx, k_map(idx_dpv))' .* cf(idx_dpv) * 8.76;
            asset_loss(idx_dpv) = cap(idx_dpv) .* (p_dpv_d(s_idx, k_map(idx_dpv))'*Cost.CAPEX_dpv);

            gen_loss(idx_upv) = cap(idx_upv) .* dt_upv(s_idx, k_map(idx_upv))' .* cf(idx_upv) * 8.76;
            asset_loss(idx_upv) = cap(idx_upv) .* (p_upv_d(s_idx, k_map(idx_upv))'*Cost.CAPEX_upv);

            Total_Loss_Row = gen_loss .* price + asset_loss;

            for ip = 1:nProv
                for t = 1:4
                    mask = (V_cur.prov_idx == ip) & (V_cur.tech == tech_list{t});
                    if any(mask)
                        Prov_Loss_Tech(ip, t, ie, is) = sum(Total_Loss_Row(mask));
                        if ie == 1, Prov_Cap_Tech(ip, t, is) = sum(cap(mask)); end
                    end
                end
            end
        end
    end

    % --- 5. 计算绝对收益 (Net Benefit) ---
    Base_allVRE = zeros(nScen, 1);
    Avoided_3prov = zeros(nScen, 1); NB_3prov = zeros(nScen, 1);
    Avoided_allVRE = zeros(nScen, 1); NB_allVRE = zeros(nScen, 1);

    for is = 1:nScen
        Base_allVRE(is) = sum(Prov_Loss_Tech(:, :, 1, is), 'all');

        avoided_sum_3 = 0; nb_sum_3 = 0;
        for ip = [gd_idx, fj_idx, zj_idx]
            tot_cap = Prov_Cap_Tech(ip, 2, is);
            if tot_cap <= 0, continue; end
            Prov_Loss = squeeze(Prov_Loss_Tech(ip, 2, :, is))';
            Prov_B = max(Prov_Loss(1) - Prov_Loss, 0);
            for k=2:nPoints, Prov_B(k) = max(Prov_B(k), Prov_B(k-1)); end

            % [UPDATED] 物理成本计算: Cost ~ lambda * [(Ud+dv)^2 - Ud^2]
            V_final = Ud.offshore + enwind_vec;
            Cost_Factor = lambda.offshore * (V_final.^2 - Ud.offshore^2);
            Prov_C = tot_cap * Cost.CAPEX_offshore * Cost_Factor * CRF;

            [max_nb, max_idx] = max(Prov_B - Prov_C);
            if max_nb > 0, nb_sum_3 = nb_sum_3 + max_nb; avoided_sum_3 = avoided_sum_3 + Prov_B(max_idx); end
        end
        NB_3prov(is) = nb_sum_3; Avoided_3prov(is) = avoided_sum_3;

        avoided_sum_all = 0; nb_sum_all = 0;
        for ip = 1:nProv
            for t = 1:4
                tot_cap = Prov_Cap_Tech(ip, t, is);
                if tot_cap <= 0, continue; end
                Prov_Loss = squeeze(Prov_Loss_Tech(ip, t, :, is))';
                Prov_B = max(Prov_Loss(1) - Prov_Loss, 0);
                for k=2:nPoints, Prov_B(k) = max(Prov_B(k), Prov_B(k-1)); end

                % [UPDATED] 物理成本计算
                tech_name = tech_list{t};
                V_final = Ud.(tech_name) + enwind_vec;
                Cost_Factor = lambda.(tech_name) * (V_final.^2 - Ud.(tech_name)^2);
                Prov_C = tot_cap * Cost.(sprintf('CAPEX_%s', tech_name)) * Cost_Factor * CRF;

                [max_nb, max_idx] = max(Prov_B - Prov_C);
                if max_nb > 0, nb_sum_all = nb_sum_all + max_nb; avoided_sum_all = avoided_sum_all + Prov_B(max_idx); end
            end
        end
        NB_allVRE(is) = nb_sum_all; Avoided_allVRE(is) = avoided_sum_all;
    end

    % --- 6. 图(e) 最优标准线: 仅画重点省份 ---
    prov_damage_base = squeeze(Prov_Loss_Tech(:, 2, 1, 7));
    major_idx = [gd_idx, fj_idx, zj_idx];
    [~, sort_order] = sort(prov_damage_base(major_idx), 'ascend');
    major_idx = major_idx(sort_order);
    num_major = length(major_idx);

    opt_dv_major = zeros(num_major, nScen);
    for r = 1:num_major
        ip = major_idx(r);
        for is = 1:nScen
            tot_cap = Prov_Cap_Tech(ip, 2, is);
            if tot_cap <= 0, continue; end
            Prov_Loss = squeeze(Prov_Loss_Tech(ip, 2, :, is))';
            Prov_B = max(Prov_Loss(1) - Prov_Loss, 0);
            for k=2:nPoints, Prov_B(k) = max(Prov_B(k), Prov_B(k-1)); end

            % [UPDATED] 物理成本计算
            V_final = Ud.offshore + enwind_vec;
            Cost_Factor = lambda.offshore * (V_final.^2 - Ud.offshore^2);
            Prov_C = tot_cap * Cost.CAPEX_offshore * Cost_Factor * CRF;

            [max_nb, max_idx] = max(Prov_B - Prov_C);
            if max_nb > 0, opt_dv_major(r, is) = enwind_vec(max_idx); end
        end
    end

    % --- 7. 图(f) 六大类堆叠数据计算 ---
    NB_cat = zeros(nScen, 6);
    for is = 1:nScen
        for ip = 1:nProv
            for t = 1:4
                tot_cap = Prov_Cap_Tech(ip, t, is);
                if tot_cap <= 0, continue; end
                Prov_Loss = squeeze(Prov_Loss_Tech(ip, t, :, is))';
                Prov_B = max(Prov_Loss(1) - Prov_Loss, 0);
                for k=2:nPoints, Prov_B(k) = max(Prov_B(k), Prov_B(k-1)); end

                % [UPDATED] 物理成本计算
                tech_name = tech_list{t};
                V_final = Ud.(tech_name) + enwind_vec;
                Cost_Factor = lambda.(tech_name) * (V_final.^2 - Ud.(tech_name)^2);
                Prov_C = tot_cap * Cost.(sprintf('CAPEX_%s', tech_name)) * Cost_Factor * CRF;

                [max_nb, ~] = max(Prov_B - Prov_C);

                if max_nb > 0
                    if t == 2 % Offshore
                        if ip == gd_idx,      NB_cat(is, 1) = NB_cat(is, 1) + max_nb;
                        elseif ip == fj_idx,  NB_cat(is, 2) = NB_cat(is, 2) + max_nb;
                        elseif ip == zj_idx,  NB_cat(is, 3) = NB_cat(is, 3) + max_nb;
                        else,                 NB_cat(is, 4) = NB_cat(is, 4) + max_nb;
                        end
                    elseif t == 1 % Onshore
                        NB_cat(is, 5) = NB_cat(is, 5) + max_nb;
                    elseif t == 3 || t == 4 % PV
                        NB_cat(is, 6) = NB_cat(is, 6) + max_nb;
                    end
                end
            end
        end
    end

    % --- 8. 绘制 2x3 完美图板 ---
    fig = figure('Position', [50, 50, 1800, 1000], 'Color', 'w');
    t = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'normal');
    x_idx = 1:nScen;

    % ====== (a) P6 Gen Loss Bar ======
    ax1 = nexttile(t, 1);
    label_L_inner = sprintf('\\Delta{\\itv}=0, {\\itM_r}=%d', Mr );
    plot_p6_panel_L(ax1, GenLossGrid, 'Power generation loss (TWh yr^-^1)', 'a', ...
        row_d_idxs, col_e_idxs, plot_order_idx_P6, idx_Mr, idx_L_col, tech_colors, scen_names, tech_labels, label_L_inner,[.7 0 0], Style);

    % ====== (b) P6 Econ Loss Bar ======
    ax2 = nexttile(t, 2);
    plot_p6_panel_L(ax2, TotalEconGrid, 'Economic loss (Billion USD yr^-^1)', 'b', ...
        row_d_idxs, col_e_idxs, plot_order_idx_P6, idx_Mr, idx_L_col, tech_colors, scen_names, tech_labels, label_L_inner,[0 0 .7], Style);

    % ====== (c) P7 Concentric Pie ======
    ax3 = nexttile(t, 3); hold(ax3, 'on'); axis(ax3, 'equal'); axis(ax3, 'off');
    data_pie = zeros(nScen, 6);
    for is = 1:nScen
        loss_gd_off = Prov_Loss_Tech(gd_idx, 2, 1, is);
        loss_fj_off = Prov_Loss_Tech(fj_idx, 2, 1, is);
        loss_zj_off = Prov_Loss_Tech(zj_idx, 2, 1, is);

        loss_all_off = sum(Prov_Loss_Tech(:, 2, 1, is), 'all');
        loss_oth_off = loss_all_off - (loss_gd_off + loss_fj_off + loss_zj_off);
        loss_all_on  = sum(Prov_Loss_Tech(:, 1, 1, is), 'all');
        loss_all_pv  = sum(Prov_Loss_Tech(:, 3, 1, is), 'all') + sum(Prov_Loss_Tech(:, 4, 1, is), 'all');

        loss_total = loss_all_off + loss_all_on + loss_all_pv;
        data_pie(is, :) = [loss_gd_off, loss_fj_off, loss_zj_off, loss_oth_off, loss_all_on, loss_all_pv] / loss_total;
    end

    r_inner_hole = 0; r_thickness = 2; r_gap = 0;
    max_r = r_inner_hole + (nScen - 1) * (r_thickness + r_gap) + r_thickness;
    ylim(ax3, [-max_r * 1.1, max_r * 1.1]);

    for is = 1:nScen
        r_in = r_inner_hole + (is - 1) * (r_thickness + r_gap);
        r_out = r_in + r_thickness;
        current_angle = -pi;
        for k = 1:6
            slice_fraction = data_pie(is, k);
            if slice_fraction <= 0, continue; end
            slice_angle = slice_fraction * 2 * pi;
            theta_vec = linspace(current_angle, current_angle - slice_angle, 100);
            X = [r_in * cos(theta_vec), fliplr(r_out * cos(theta_vec))];
            Y = [r_in * sin(theta_vec), fliplr(r_out * sin(theta_vec))];
            h_leg_pie(k)= patch(ax3, X, Y, cmap_6cat(k, :), 'EdgeColor', 'w', 'LineWidth', 4, 'HandleVisibility', 'off');

            current_angle = current_angle - slice_angle;
        end
    end
    for is = 1:nScen
        r_in = r_inner_hole + (is - 1) * (r_thickness + r_gap);
        r_out = r_in + r_thickness;
        text(ax3, 0, (r_in + r_out)/2, scen_names{is}, 'FontSize', Style.PieTextFS, 'Color', 'k', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
    end
    % h_leg_pie = gobjects(6, 1);
    % for k = 1:6, h_leg_pie(k) = plot(ax3, nan, nan, 's', 'MarkerSize', 12, 'MarkerFaceColor', cmap_6cat(k,:), 'MarkerEdgeColor', 'none'); end
r_out_label = max_r;         % 从最外圈引出      
    is_label = nScen;
for k = 1:6
        slice_fraction = data_pie(is_label, k);
        if slice_fraction <= 0
            continue; 
        end
        
        slice_angle = slice_fraction * 2 * pi;
        mid_angle = current_angle - slice_angle / 2;
        
        % 仅当该部分占比大于 1.5% 时才画引线标注，防止字重叠
        if slice_fraction > 0.015
            % 起点：色块最外侧边缘
            edge_x = r_out_label * cos(mid_angle);
            edge_y = r_out_label * sin(mid_angle);
            
            % 拐点：稍微向外延伸一点
            r_turn = r_out_label * 1.05; 
            turn_x = r_turn * cos(mid_angle);
            turn_y = r_turn * sin(mid_angle);
            
            % 终点：水平延伸
            if cos(mid_angle) >= 0
                align_str = 'left';
                end_x = turn_x + max_r * 0.15;
                text_x = end_x + max_r * 0.05;
            else
                align_str = 'right';
                end_x = turn_x - max_r * 0.15;
                text_x = end_x - max_r * 0.05;
            end
            % --- 3. 核心技巧：将长标签自动拆分为两行，避免太宽 ---
            label_str = group_labels{k};
            idx_paren = strfind(label_str, ' (');
            if ~isempty(idx_paren)
                label_cell = {label_str(1:idx_paren-1), label_str(idx_paren+1:end)};
            else
                label_cell = {label_str};
            end
            % 绘制引线
            plot(ax3, [edge_x, turn_x, end_x], [edge_y, turn_y, turn_y], '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 2);
            % 绘制带颜色的文字
            text(ax3, text_x, turn_y, label_cell, ...
                'FontSize', Style.AnnotFS, 'Color', cmap_6cat(k,:), ...
                'HorizontalAlignment', align_str, 'VerticalAlignment', 'middle', 'FontWeight', 'bold');
        end
        current_angle = current_angle - slice_angle;
    end
    text(ax3, 0, 1.01, 'c', 'Units', 'normalized', 'FontSize', Style.LabelFS, 'FontWeight', Style.LabelWeight, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');

    % ====== (d) P7 Mechanism (Updated for new Cost Model) ======
    ax4 = nexttile(t, 4); hold(ax4, 'on'); box(ax4, 'on');
    is_example = 6; % F-SSP2
    tot_cap_gd = Prov_Cap_Tech(gd_idx, 2, is_example);
    Prov_Loss_GD = squeeze(Prov_Loss_Tech(gd_idx, 2, :, is_example))';
    Prov_B_GD = max(Prov_Loss_GD(1) - Prov_Loss_GD, 0);
    for k=2:nPoints, Prov_B_GD(k) = max(Prov_B_GD(k), Prov_B_GD(k-1)); end

    % [UPDATED] 物理成本计算 (Discrete Points)
    V_final_vec = Ud.offshore + enwind_vec;
    Cost_Factor_vec = lambda.offshore * (V_final_vec.^2 - Ud.offshore^2);
    Prov_C_GD = tot_cap_gd * Cost.CAPEX_offshore * Cost_Factor_vec * CRF;
    Prov_NB_GD = Prov_B_GD - Prov_C_GD;

    % Smooth Curve Calculation
    dv_smooth = linspace(0, 15, 100);
    B_smooth = spline(enwind_vec, Prov_B_GD, dv_smooth);

    % [UPDATED] 物理成本计算 (Smooth)
    V_final_smooth = Ud.offshore + dv_smooth;
    Cost_Factor_smooth = lambda.offshore * (V_final_smooth.^2 - Ud.offshore^2);
    C_smooth = tot_cap_gd * Cost.CAPEX_offshore * Cost_Factor_smooth * CRF;
    NB_smooth = B_smooth - C_smooth;

    fill(ax4, [dv_smooth, fliplr(dv_smooth)], [zeros(size(NB_smooth)), fliplr(NB_smooth)], ...
        c_oth_off,'FaceAlpha', 0.3, 'EdgeColor', 'none', 'HandleVisibility', 'off');

    plot(ax4, dv_smooth, B_smooth, '-', 'Color', c_gd, 'LineWidth', 2.5, 'DisplayName', 'Avoided loss');
    plot(ax4, dv_smooth, C_smooth, '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.5, 'DisplayName', 'Retrofit cost');
    plot(ax4, dv_smooth, NB_smooth, '-', 'Color', 'k', 'LineWidth', 3.5, 'DisplayName', 'Net benefit');

    [max_nb_gd, max_idx_gd] = max(Prov_NB_GD);
    opt_v = enwind_vec(max_idx_gd);
    if max_nb_gd > 0
        plot(ax4, [opt_v, opt_v], [0, max_nb_gd], 'k:', 'LineWidth', 2.0, 'HandleVisibility', 'off');
        plot(ax4, opt_v, max_nb_gd, 'p', 'MarkerSize', 16, 'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5, 'DisplayName', 'Optimal point');
    end
    xlabel(ax4, 'Structural strengthening \Deltav (m s^{-1})', 'FontSize', Style.AxisLabelFS);
    ylabel(ax4, 'Annualized value (Billion USD yr^-^1)', 'FontSize', Style.AxisLabelFS);
    grid(ax4, 'on'); xlim(ax4, [0, 15]); ylim(ax4, [0, max(max_nb_gd*1.8, 1)]);
    legend(ax4, 'Location', 'northwest', 'FontSize', Style.LegendFS, 'Box', 'off');
    box on
    text(ax4, -0.05, 1.01, 'd', 'Units', 'normalized', 'FontSize', Style.LabelFS, 'FontWeight', Style.LabelWeight, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');

    % ====== (e) P7 Optimal dv ======
    ax5 = nexttile(t, 5); hold(ax5, 'on'); box(ax5, 'on');
    jitter_offsets = linspace(-0.15, 0.15, num_major);
    label_arr = {'o','^','sq'};
    for r = num_major:-1:1
        c_color = prov_colors(major_idx(r), :);
        x_jittered = x_idx + jitter_offsets(r);

        y_data = opt_dv_major(r, :);
        %y_data(1) = NaN; % 历史时期置为 NaN

        plot(ax5, x_jittered, y_data, '-', 'LineWidth', 2.5, 'Color', [c_color 0.6], 'HandleVisibility', 'off');
        plot(ax5, x_jittered, y_data, label_arr{r}, 'MarkerSize', 12, 'LineWidth', 1.5, ...
            'MarkerFaceColor', c_color, 'MarkerEdgeColor', 'w', 'DisplayName', [' Offshore wind' , ' (', prov_names{major_idx(r)},')']);
    end
    ylabel(ax5, 'Optimal \Deltav (m s^{-1})', 'FontSize', Style.AxisLabelFS);
    xticks(ax5, x_idx); xticklabels(ax5, scen_names); xtickangle(ax5, 30);
    ax5.XGrid = 'off'; ax5.YGrid = 'on';
    for xv = 1.5 : 1 : 6.5, xline(ax5, xv, ':', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.2, 'HandleVisibility', 'off'); end
    xlim(ax5, [0.5, 7.5]); ylim(ax5, [0, 20]);
    [~, ~] = legend(ax5, 'Location', 'northwest', 'FontSize', Style.LegendFS, 'Box', 'off');
    text(ax5, -0.05, 1.01, 'e', 'Units', 'normalized', 'FontSize', Style.LabelFS, 'FontWeight', Style.LabelWeight, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');

    % ====== (f) P7 Stacked Benefit ======
    ax6 = nexttile(t, 6); hold(ax6, 'on'); box(ax6, 'on');
    Y_stack = [NB_cat(:,6), NB_cat(:,5), NB_cat(:,4), NB_cat(:,3), NB_cat(:,2), NB_cat(:,1)];
    %Y_stack(1, :) = NaN;

    cmap_stack = [c_all_pv; c_all_on; c_oth_off; prov_colors(zj_idx,:); prov_colors(fj_idx,:); prov_colors(gd_idx,:)];

    h_bar = bar(ax6, x_idx, Y_stack, 'stacked');
    for i = 1:length(h_bar)
        h_bar(i).FaceColor = cmap_stack(i,:);
        h_bar(i).FaceAlpha = 0.85;
        h_bar(i).EdgeColor = 'w';
        h_bar(i).LineWidth = 0.5;
    end

    ylabel(ax6, 'Total net benefit (Billion USD yr^-^1)', 'FontSize', Style.AxisLabelFS);
    xticks(ax6, x_idx); xticklabels(ax6, scen_names); xtickangle(ax6, 30);
    ax6.XGrid = 'off'; ax6.YGrid = 'on';
    for xv = 1.5 : 1 : 6.5, xline(ax6, xv, ':', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.2, 'HandleVisibility', 'off'); end
    xlim(ax6, [0.5, 7.5]);

    h_legend_array = gobjects(length(h_bar), 1);
    for k = 1:length(h_bar), h_legend_array(k) = h_bar(k); end
    legend(ax6, h_legend_array(end:-1:1), group_labels, 'Location', 'northwest', 'FontSize', Style.LegendFS, 'Box', 'off');
    text(ax6, -0.05, 1.01, 'f', 'Units', 'normalized', 'FontSize', Style.LabelFS, 'FontWeight', Style.LabelWeight, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');

    % ================= 全局调整 =================
    set([ax1, ax2, ax4, ax5, ax6], 'FontSize', Style.AxisTickFS);

    filename = sprintf('Fig4_Mr%d.png', Mr);
    exportgraphics(fig, filename, 'Resolution', 300);
    fprintf('>>> Saved %s <<<\n', filename);


    if Mr == 2
        fprintf('\n\n======================================================\n');
        fprintf('  [TEXT GENERATOR] Generating Manuscript Paragraph \n');
        fprintf('======================================================\n\n');

        % 1. 历史时期海上风电损失占比
        hist_total_loss = sum(Prov_Loss_Tech(:, :, 1, 1), 'all');
        hist_offshore_loss = sum(Prov_Loss_Tech(:, 2, 1, 1), 'all');
        hist_off_pct = hist_offshore_loss / hist_total_loss * 100;

        % 2. 未来时期 (Scenarios 2-7) 统计指标范围
        fut_off_pct = zeros(1, 6);
        fut_gd_fj_zj_pct = zeros(1, 6);
        net_benefit_pct = zeros(1, 6);

        for is = 2:7
            scen_total_loss = sum(Prov_Loss_Tech(:, :, 1, is), 'all');
            scen_offshore_loss = sum(Prov_Loss_Tech(:, 2, 1, is), 'all');

            loss_all_on  = sum(Prov_Loss_Tech(:, 1, 1, is), 'all');
            loss_all_pv  = sum(Prov_Loss_Tech(:, 3, 1, is), 'all') + sum(Prov_Loss_Tech(:, 4, 1, is), 'all');
            scen_total_loss2 = scen_offshore_loss+loss_all_on+loss_all_pv;
            fut_off_pct(is-1) = scen_offshore_loss / scen_total_loss * 100;


            loss_gd_off = Prov_Loss_Tech(gd_idx, 2, 1, is);
            loss_fj_off = Prov_Loss_Tech(fj_idx, 2, 1, is);
            loss_zj_off = Prov_Loss_Tech(zj_idx, 2, 1, is);
            fut_gd_fj_zj_pct(is-1) = (loss_gd_off + loss_fj_off + loss_zj_off) / scen_total_loss * 100;

            % 净收益抵消总损失的比例 = Max Net Benefit / Baseline Total Loss
            net_benefit_pct(is-1) = NB_allVRE(is) / scen_total_loss * 100;
        end

        % 3. 广东海上风电最佳 Delta v 范围
        opt_dv_gd = zeros(1, 7);
        for is = 1:nScen
            tot_cap_gd = Prov_Cap_Tech(gd_idx, 2, is);
            if tot_cap_gd > 0
                Prov_Loss = squeeze(Prov_Loss_Tech(gd_idx, 2, :, is))';
                Prov_B = max(Prov_Loss(1) - Prov_Loss, 0);
                for k=2:nPoints, Prov_B(k) = max(Prov_B(k), Prov_B(k-1)); end
                V_final = Ud.offshore + enwind_vec;
                Cost_Factor = lambda.offshore * (V_final.^2 - Ud.offshore^2);
                Prov_C = tot_cap_gd * Cost.CAPEX_offshore * Cost_Factor * CRF;
                [max_nb, max_idx] = max(Prov_B - Prov_C);
                if max_nb > 0, opt_dv_gd(is) = enwind_vec(max_idx); end
            end
        end
        gd_near_dv = opt_dv_gd(2:4); % Near (N-SSP1,2,5)
        gd_far_dv  = opt_dv_gd(5:7); % Far (F-SSP1,2,5)

        % --- 打印最终文本 ---
        fprintf('Capacity reductions directly translate into power-generation and economic losses. Because offshore wind has a substantially higher capacity factor, its capacity reductions disproportionately amplify the overall generation losses. Specifically, far-future generation losses surge to 10-20 times the historical baseline of 7 TWh yr^-^1 (Fig. 5a), an escalation rate that outpaces the physical capacity loss (Fig. 4a). Correspondingly, total economic losses escalate by 10- to 18-fold compared to the historical 0.7 billion USD yr^-^1 (Fig. 5b). The composition of these economic losses undergoes a significant shift: the share of offshore wind loss jumps from %.1f%% in the historical period to %.1f%%-%.1f%% under future scenarios (Fig. 5c). Notably, these future losses are heavily concentrated in the offshore wind fleets of Guangdong, Fujian, and Zhejiang, which collectively account for %.1f%%-%.1f%% of the total VRE economic losses.\n\n', ...
            hist_off_pct, min(fut_off_pct), max(fut_off_pct), min(fut_gd_fj_zj_pct), max(fut_gd_fj_zj_pct));

        fprintf('To mitigate these escalating losses driven by shifting tropical cyclone climatology, we pinpointed the optimal structural retrofitting strategy for VRE infrastructure. By balancing the retrofit-induced cost against the avoided damage, we determined the optimal design wind speed that maximizes the net economic benefit (Fig. 5d). This optimal design wind speed naturally rises with intensifying global warming (Fig. 5e). For instance, the offshore wind turbines in Guangdong require an optimal design wind speed increment (\\Deltav) of %d-%d m/s for the near-future (2021-2060) and %d-%d m/s for the far-future (2061-2100) relative to the existing IEC 61400-1 Class I baseline. Therefore, design standards for wind turbines in typhoon-prone regions must be dynamically adapted to specific climate projections. Implementing these optimal structural upgrades substantially mitigates VRE vulnerabilities, yielding a maximized net benefit that offsets %.1f%%-%.1f%% of the total projected economic losses.\n\n', ...
            min(gd_near_dv), max(gd_near_dv), min(gd_far_dv), max(gd_far_dv), min(net_benefit_pct), max(net_benefit_pct));
    end

    % ==========================================================
    % 自动计算：风光损失的不对称性 (用于论文填空)
    % ==========================================================
    % 提取历史基准 (is = 1)
    if Mr == 2
        hist_wind_loss = sum(Prov_Loss_Tech(:, 1:2, 1, 1), 'all');  % 1:陆风, 2:海风
        hist_solar_loss = sum(Prov_Loss_Tech(:, 3:4, 1, 1), 'all'); % 3:分布式光伏, 4:集中式光伏

        % 提取远期未来 (Far-future: is = 5, 6, 7 分别对应 F-SSP1, F-SSP2, F-SSP5)
        far_fut_scens = [5, 6, 7];
        wind_inc_folds = zeros(1, 3);
        solar_inc_folds = zeros(1, 3);
        wind_vs_solar_ratios = zeros(1, 3);
        wind_increase_contri = zeros(1, 3);
        for k = 1:3
            is = far_fut_scens(k);
            fut_wind = sum(Prov_Loss_Tech(:, 1:2, 1, is), 'all');
            fut_solar = sum(Prov_Loss_Tech(:, 3:4, 1, is), 'all');

            wind_inc_folds(k) = fut_wind / hist_wind_loss;
            solar_inc_folds(k) = fut_solar / hist_solar_loss;
            wind_vs_solar_ratios(k) = (fut_wind - hist_wind_loss)/ (fut_solar - hist_solar_loss);
            wind_increase_contri(k) = (fut_wind - hist_wind_loss) / ( (fut_wind - hist_wind_loss) +  (fut_solar - hist_solar_loss));
        end

        fprintf('\n=== 论文填空数据 (风光损失不对称性) ===\n');
        fprintf('风电增加倍数 [X1]-[X2]: %.1f to %.1f \n', min(wind_inc_folds), max(wind_inc_folds));
        fprintf('光电增加倍数 [Y1]-[Y2]: %.1f to %.1f \n', min(solar_inc_folds), max(solar_inc_folds));
        fprintf('风电增加的损失是光电的倍数 [Z1]-[Z2]: %.1f to %.1f \n', min(wind_vs_solar_ratios), max(wind_vs_solar_ratios));
        fprintf('风电贡献了多少的增加的损失hi [Z1]-[Z2]: %.2f to %.2f \n', min(wind_increase_contri), max(wind_increase_contri));
        fprintf('=======================================\n');

    end

end

fprintf('\nAll computations and plots successfully completed!\n');

%% =========================================================================
% P6 HELPER FUNCTIONS
% =========================================================================
function plot_p6_panel_L(ax, LossGrid, yLabelTotal, label_char, row_d_idxs, col_e_idxs, plot_order_idx, ...
    idx_Mr, idx_L_col, tech_colors, scen_labels_x, tech_labels, label_L_inner,boxcolor, Style)
nScen = length(scen_labels_x); nTech = length(tech_labels);
d_idx_spec = row_d_idxs(idx_Mr);
e_idx_spec = col_e_idxs(idx_L_col);
raw_spec = squeeze(LossGrid(:, plot_order_idx, d_idx_spec, e_idx_spec));
barData_Spec = raw_spec';
totalHeight_Spec = sum(barData_Spec, 2);
val_hist = totalHeight_Spec(1);
if val_hist == 0, val_hist = 1; end
ratioData_Spec = totalHeight_Spec / val_hist;

ylim_fold = 35;
unified_ymax = val_hist * ylim_fold;
if unified_ymax < val_hist, unified_ymax = val_hist * 1.5; end

yyaxis(ax, 'left'); box(ax, 'on'); ax.YColor = 'k';


hold(ax, 'on'); bar_width = 0.8;
for i = 1:nScen
    rectangle(ax, 'Position', [i-bar_width/2, 0, bar_width, totalHeight_Spec(i)], 'EdgeColor', boxcolor, 'LineWidth', 3, 'FaceColor', 'none');
end

bL = bar(ax, barData_Spec, 'stacked', 'FaceColor', 'flat', 'EdgeColor', 'none', 'FaceAlpha', 1);
for k = 1:nTech, bL(k).CData = tech_colors(k, :); end
ylabel(ax, yLabelTotal, 'FontSize', Style.AxisLabelFS, 'Color', 'k');
ylim(ax, [0, unified_ymax]);

yyaxis(ax, 'right'); hold(ax, 'on'); ax.YColor = 'k';
%ratioData_Spec(1) = NaN;
lL = plot(ax, 1:nScen, ratioData_Spec, '-o', 'Color', boxcolor, 'LineWidth', 2.5, 'MarkerSize',10, 'MarkerFaceColor', 'w');
ylabel(ax, 'Fold over historical', 'FontSize', Style.AxisLabelFS, 'Color', 'k');
ylim(ax, [0, 25]);

grid(ax, 'on'); ax.XGrid = 'off'; ax.YGrid = 'on';
for xv = 1.5:1:6.5, xline(ax, xv, ':', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.2, 'HandleVisibility', 'off'); end

text(ax, 0.96, 0.96, label_L_inner, 'Units', 'normalized', 'FontSize', Style.LegendFS, 'Interpreter', 'tex', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
xlim(ax, [0.5, 7.5]);

set(ax, 'XTick', 1:nScen, 'XTickLabel', scen_labels_x); xtickangle(ax, 30);
legend(ax, [bL(:); lL], [tech_labels, {'Ratio to Hist'}], 'Location', 'northwest', 'Box', 'off', 'FontSize', Style.LegendFS);
text(ax, -0.05, 1.01, label_char, 'Units', 'normalized', 'FontSize', Style.LabelFS, 'FontWeight', Style.LabelWeight, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
end

%% =========================================================================
% DATA LOADING HELPER FUNCTION
% =========================================================================
function [V, S, p_names] = load_and_prep_vre(matPath, varName, CF_On, CF_Off, CF_Upv, yearStr)
data = load(matPath, varName);
V = data.(varName);
if ~ismember('annual_cf', V.Properties.VariableNames), V.annual_cf = zeros(height(V), 1); end

idx_on = (V.tech == "onshore");
if any(idx_on), V.annual_cf(idx_on) = CF_On.annual_cf(knnsearch([CF_On.lon, CF_On.lat], [V.lon(idx_on), V.lat(idx_on)])); end

idx_off = (V.tech == "offshore");
if any(idx_off), V.annual_cf(idx_off) = CF_Off.annual_cf(knnsearch([CF_Off.lon, CF_Off.lat], [V.lon(idx_off), V.lat(idx_off)])); end

idx_pv = (V.tech == "dpv" | V.tech == "upv");
if any(idx_pv), V.annual_cf(idx_pv) = CF_Upv.annual_cf(knnsearch([CF_Upv.lon, CF_Upv.lat], [V.lon(idx_pv), V.lat(idx_pv)])); end

V.annual_cf(V.tech == "onshore" & (V.annual_cf == 0 | isnan(V.annual_cf))) = 0.25;
V.annual_cf((V.tech == "dpv" | V.tech == "upv") & (V.annual_cf == 0 | isnan(V.annual_cf))) = 0.15;

[V, S, p_names] = assign_price_and_get_prov(V, yearStr);
end

function [V, S, p_names] = assign_price_and_get_prov(V, yearStr)
fName = 'Coastal_Prov_ElecPrice.mat';
if ~exist(fName, 'file'), dataFile_P6 = 'LossGrid_Econ_Spatial_ProvPrice.mat'; end
% Note: If file doesn't exist, we assume logic handled outside or file is present.
% Simplified here for brevity as helper function logic is standard.
try data = load(fName); catch, data = load('Coastal_Prov_ElecPrice.mat'); end

if isfield(data, 'res_price'), P_Table = data.res_price; else, P_Table = data.Prov_Price_Table; end
if ~ismember(yearStr, P_Table.Properties.VariableNames), price_vec_rmb = P_Table{:, 1}; else, price_vec_rmb = P_Table.(yearStr); end

shpPath = 'H:\wind_turbine\Qgis\coastal_provinvce_Project.shp';
if exist(shpPath, 'file'), S = shaperead(shpPath); else, error('Shapefile not found.'); end
nProv = numel(S);
centroid_lats = zeros(nProv, 1);
for i = 1:nProv, centroid_lats(i) = mean(S(i).Y(~isnan(S(i).Y))); end
[~, sort_idx] = sort(centroid_lats, 'descend');
S = S(sort_idx);
price_map_usd = nan(nProv, 1);
prov_names_in_table = P_Table.Properties.RowNames;
avg_p_usd = mean(price_vec_rmb) * 0.14;
p_names = cell(1, nProv);
for i = 1:nProv
    sName = '';
    if isfield(S, 'NAME'), sName = S(i).NAME; elseif isfield(S, 'Name'), sName = S(i).Name; elseif isfield(S, 'en_name'), sName = S(i).en_name; end
    p_names{i} = sName;
    idx_table = -1;
    for k = 1:length(prov_names_in_table)
        if contains(sName, prov_names_in_table{k}, 'IgnoreCase', true) || contains(prov_names_in_table{k}, sName, 'IgnoreCase', true)
            idx_table = k; break;
        end
    end
    if idx_table > 0, price_map_usd(i) = price_vec_rmb(idx_table) * 0.145; else, price_map_usd(i) = avg_p_usd; end
end
ids = V.prov_idx; valid_mask = ~isnan(ids) & ids >= 1 & ids <= nProv;
V.price = nan(height(V), 1);
V.price(valid_mask) = price_map_usd(ids(valid_mask));
if any(~valid_mask), V.price(~valid_mask) = avg_p_usd; end
end

function [fname, ok] = find_result_file(baseDir, enwind, delay)
ok = false; fname = '';
cand = {sprintf('repair_time_distribution_C23_enwind%d_delay%.1f.mat', enwind, delay), ...
    sprintf('repair_time_distribution_C23_enwind%d_delay%g.mat', enwind, delay)};
for k = 1:numel(cand), f = fullfile(baseDir, cand{k}); if exist(f,'file'), fname = f; ok = true; return; end; end
end