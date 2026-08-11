%% ===================== FIGURE + LAYOUT (UPDATED) =====================
% Modified Layout:
% Top Row:    Left = Fig 3.1(a),   Right = Schematic Diagram
% Bottom Row: Fig 3.2(b-e) (4 panels)
% 
% *UPDATED* to fully support separate UPV and DPV downtime fragility.
close all;
clear
repoDir = fileparts(mfilename('fullpath'));
derivedDir = fullfile(repoDir,'output','derived');
figureDir = fullfile(repoDir,'output','figures');
if ~exist(figureDir,'dir'), mkdir(figureDir); end
nScen = 7;
tech_list  = {'onshore','offshore','dpv','upv'};
combinedFile = fullfile(derivedDir,'All_VRE_Data_Combined.mat');
assert(isfile(combinedFile), ...
    'Run P3_downtime_on_VRE.m first. Missing file: %s', combinedFile);
load(combinedFile,'VRE_hist','VRE_near','VRE_far', ...
    'VRE_hist_dt','VRE_near_dt','VRE_far_dt');

%% ===================== Compute Total Losses for Fig 3.1 (GW) =====================
% We must re-calculate the total loss per scenario to plot Fig 3.1(a)
Loss_onshore_GW  = zeros(nScen, 1);
Loss_offshore_GW = zeros(nScen, 1);
Loss_dpv_GW      = zeros(nScen, 1);
Loss_upv_GW      = zeros(nScen, 1);

for s = 1:nScen
    if s == 1, V = VRE_hist; dtm = VRE_hist_dt;
    elseif ismember(s,[2 4 6]), V = VRE_near; dtm = VRE_near_dt;
    else, V = VRE_far; dtm = VRE_far_dt; end
    
    dt_frac = dtm(:,s) / 100;
    Loss_onshore_GW(s)  = sum(V.cap_GW(V.tech=="onshore").*dt_frac(V.tech=="onshore"),'omitnan');
    Loss_offshore_GW(s) = sum(V.cap_GW(V.tech=="offshore").*dt_frac(V.tech=="offshore"),'omitnan');
    Loss_dpv_GW(s)      = sum(V.cap_GW(V.tech=="dpv").*dt_frac(V.tech=="dpv"),'omitnan');
    Loss_upv_GW(s)      = sum(V.cap_GW(V.tech=="upv").*dt_frac(V.tech=="upv"),'omitnan');
end

%% ===================== Compute attribution fractions (by tech, for Fig3.2 b–e) =====================
scen_labels_x = {'Hist', 'N-SSP1', 'N-SSP2', 'N-SSP5', 'F-SSP1', 'F-SSP2', 'F-SSP5'};
nTech = numel(tech_list);
future_idx = [2 4 6 3 5 7];   % 6 futures order MUST match plotting rows
nFut = numel(future_idx);

dLoss_TC_tech  = nan(nTech, nFut);
dLoss_exp_tech = nan(nTech, nFut);
dLoss_int_tech = nan(nTech, nFut);
decomposition_residual = nan(nTech,nFut);

keyDigits = 4; 
makeKey = @(lon,lat) string(compose("%."+keyDigits+"f_%."+keyDigits+"f", round(lon, keyDigits), round(lat, keyDigits)));
s0 = 1;

for jf = 1:nFut
    s = future_idx(jf);  
    if ismember(s,[2 4 6]), V1 = VRE_near; dtm1 = VRE_near_dt;
    else, V1 = VRE_far; dtm1 = VRE_far_dt; end
    
    V0   = VRE_hist;
    dtm0 = VRE_hist_dt;      
    
    for ti = 1:nTech
        tech = string(tech_list{ti});
        
        idx0 = (V0.tech == tech) & isfinite(V0.lon) & isfinite(V0.lat);
        if ~any(idx0), continue; end
        lon0 = V0.lon(idx0); lat0 = V0.lat(idx0); C0 = V0.cap_GW(idx0); C0(~isfinite(C0)) = 0;
        D0_0 = dtm0(idx0, s0) / 100;   
        D1_0 = dtm0(idx0, s ) / 100;   
        
        idx1 = (V1.tech == tech) & isfinite(V1.lon) & isfinite(V1.lat);
        lon1 = V1.lon(idx1); lat1 = V1.lat(idx1); C1 = V1.cap_GW(idx1); C1(~isfinite(C1)) = 0;
        D0_1 = dtm1(idx1, s0) / 100;   
        D1_1 = dtm1(idx1, s ) / 100;   
        
        key0 = makeKey(lon0, lat0); key1 = makeKey(lon1, lat1); keyAll = unique([key0; key1], 'stable');
        [in0, loc0] = ismember(keyAll, key0); [in1, loc1] = ismember(keyAll, key1);
        
        C0u = zeros(numel(keyAll),1); C1u = zeros(numel(keyAll),1);
        D0u = nan(numel(keyAll),1); D1u = nan(numel(keyAll),1);
        
        C0u(in0) = C0(loc0(in0)); C1u(in1) = C1(loc1(in1));
        
        D0u(in1) = D0_1(loc1(in1)); D0u(~in1 & in0) = D0_0(loc0(~in1 & in0));
        D1u(in1) = D1_1(loc1(in1)); D1u(~in1 & in0) = D1_0(loc0(~in1 & in0));
        
        D0u(~isfinite(D0u)) = 0; D1u(~isfinite(D1u)) = 0;
        
        % Manuscript notation: exposure E = installed capacity C, while
        % hazard H = annual downtime ratio D. The following is exactly
        % E0*(H1-H0) + H0*(E1-E0) + (E1-E0)*(H1-H0).
        E0 = C0u; E1 = C1u;
        H0 = D0u; H1 = D1u;
        dE = E1-E0; dH = H1-H0;
        dL_TC  = sum(E0.*dH,'omitnan');   % hazard effect
        dL_exp = sum(H0.*dE,'omitnan');   % exposure effect
        dL_int = sum(dE.*dH,'omitnan');   % synergistic effect
        
        dLoss_TC_tech(ti, jf)  = dL_TC;
        dLoss_exp_tech(ti, jf) = dL_exp;
        dLoss_int_tech(ti, jf) = dL_int;
        decomposition_residual(ti,jf) = ...
            sum(E1.*H1,'omitnan')-sum(E0.*H0,'omitnan')-(dL_TC+dL_exp+dL_int);
    end
end
assert(max(abs(decomposition_residual),[],'all') < 1e-9, ...
    'Hazard-exposure-synergy decomposition does not close numerically.');

% Contribution percentages for each technology. The denominator is the
% total increase in loss, not the future total loss.
dLoss_total_tech = dLoss_TC_tech+dLoss_exp_tech+dLoss_int_tech;
assert(all(dLoss_total_tech>0,'all'), ...
    'A non-positive loss increment requires signed rather than stacked shares.');
frac_TC_tech  = 100*dLoss_TC_tech ./dLoss_total_tech;
frac_exp_tech = 100*dLoss_exp_tech./dLoss_total_tech;
frac_int_tech = 100*dLoss_int_tech./dLoss_total_tech;

% Contributions aggregated over all four VRE technologies.
dLoss_TC_all  = sum(dLoss_TC_tech,1);
dLoss_exp_all = sum(dLoss_exp_tech,1);
dLoss_int_all = sum(dLoss_int_tech,1);
dLoss_total_all = dLoss_TC_all+dLoss_exp_all+dLoss_int_all;
frac_TC_all  = 100*dLoss_TC_all ./dLoss_total_all;
frac_exp_all = 100*dLoss_exp_all./dLoss_total_all;
frac_int_all = 100*dLoss_int_all./dLoss_total_all;
assert(max(abs(frac_TC_all+frac_exp_all+frac_int_all-100))<1e-10, ...
    'Overall contribution percentages do not sum to 100%%.');

%% ------------------------------ Labels ------------------------------
tech_label = {'Onshore wind','Offshore wind','Distributed PV','Utility-scale PV'};
scenario_names =  {'Historical(1975-2014)', 'SSP1-2.6(2021-2060)','SSP1-2.6(2061-2100)', ...
                   'SSP2-4.5(2021-2060)','SSP2-4.5(2061-2100)', 'SSP5-8.5(2021-2060)','SSP5-8.5(2061-2100)'};

%% ------------------------------ Fig3.1 data ------------------------------
Loss_tot_mat0 = [Loss_onshore_GW, Loss_offshore_GW, Loss_dpv_GW, Loss_upv_GW];   % [7 x 4]
colors_bar = [0.25 0.55 0.95; 0.55 0.82 0.98; 0.98 0.65 0.20; 0.99 0.82 0.35];
%colors_bar = [ 0.98 0.65 0.20; 0.99 0.82 0.35;  0.55 0.82 0.98 ;0.25 0.55 0.95;];
colors_edge = max(colors_bar * 0.55, 0);
order = [1 2 4 6 3 5 7];
Loss_tot_mat  = Loss_tot_mat0(order,:);
scenario_plot = scen_labels_x;
nScen = numel(order);

baseRow   = 1;
baseTech  = Loss_tot_mat(baseRow,:);
baseTot   = sum(Loss_tot_mat(baseRow,:));
ratioTech = Loss_tot_mat ./ max(baseTech, eps);   
ratioTot  = sum(Loss_tot_mat,2) ./ max(baseTot, eps);
outlineColor = repmat([0.55 0.55 0.55], nScen, 1);

%% ------------------------------ Fig3.2 data & Layout ------------------------------
col_synergy = [214, 40, 40]/255;
col_human   = [242, 100, 25]/255;
col_climate = [142, 227, 245]/255;
tech_outline = colors_bar;

figure('Position',[60 60 1600 1100], 'Color', 'w'); 
% --- Layout Parameters ---
Y1 = 0.54; H1 = 0.40; X1_a = 0.12; W1_a = 0.45; X1_sch = 0.55; W1_sch = 0.35;
Y2 = 0.06; H2 = 0.36; X2 = 0.12; W_total= 0.80; gap = 0.05; W_panel= (W_total - 3*gap)/4;
y = 1:nScen;

%% ===================== TOP LEFT: Fig3.1 (a) =====================
ax1 = axes('Position',[X1_a Y1 W1_a H1],'XAxisLocation','top'); hold(ax1,'on'); box(ax1,'on');
set(ax1,'FontSize',16,'LineWidth',1.2,'TickLabelInterpreter','none');
ax1.XGrid = 'on'; ax1.YGrid = 'on'; ax1.GridAlpha = 0.10; ax1.XColor = [0 0 0]; ax1.YColor = [0 0 0];

b = barh(ax1, y, Loss_tot_mat, 'stacked', 'FaceAlpha',0.7, 'EdgeColor','none');
for ti = 1:4, b(ti).FaceColor = colors_bar(ti,:); end
ax1.YTick = y; ax1.YTickLabel = scenario_plot; ax1.YDir = 'reverse';
xlabel(ax1,'TC-induced capacity loss (GW)','FontSize',20);

% Outline boxes
stackW = sum(Loss_tot_mat,2); bw1 = b(1).BarWidth;
for i = 1:nScen
    rectangle(ax1,'Position',[0, y(i)-bw1/2, stackW(i), bw1], 'EdgeColor', outlineColor(i,:), 'LineWidth', 2.0, 'FaceColor','none');
end

% Second Axis for Ratio
ax2 = axes('Position',ax1.Position, 'Color','none', 'YAxisLocation','right', ...
    'YDir',ax1.YDir, 'YLim',ax1.YLim, 'YTick',[], 'LineWidth',1.2, 'FontSize',16, 'TickLabelInterpreter','none');
hold(ax2,'on'); ax2.XColor = [0 0 0]; ax2.YColor = [0 0 0];
a = xlabel(ax2,'Fold over historical','FontSize',20); xline(ax2, 1, 'k--', 'LineWidth', 1.2);
a.Position =a.Position + [6 -0.1  0];
stemColTech = [0.62 0.62 0.62]; stemColTot = [0.42 0.42 0.42]; mkTech = {'o','^','d','v'}; mkTot = 's';
msTech = 7.5; msTot = 8.5; lwStem = 1.6; lwStemTot = 2.2; lwEdge = 1.2;

for i = 1:nScen
    yi = y(i);
    for ti = 1:4, plot(ax2, [1 ratioTech(i,ti)], [yi yi], '-', 'Color', stemColTech, 'LineWidth', lwStem); end
    plot(ax2, [1 ratioTot(i)], [yi yi], '-', 'Color', stemColTot, 'LineWidth', lwStemTot);
end

hMark = gobjects(4,1);
for ti = 1:4
    plot(ax2, ratioTech(:,ti), y, mkTech{ti}, 'LineStyle','none', 'MarkerSize', msTech, 'MarkerFaceColor', colors_bar(ti,:), 'MarkerEdgeColor', colors_edge(ti,:), 'LineWidth', lwEdge);
    hMark(ti) = plot(ax1, NaN, NaN, mkTech{ti}, 'LineStyle','none', 'MarkerSize', msTech, 'MarkerFaceColor', colors_bar(ti,:), 'MarkerEdgeColor', colors_edge(ti,:), 'LineWidth', lwEdge);
end
plot(ax2, ratioTot, y, mkTot, 'LineStyle','none', 'MarkerSize', msTot, 'MarkerFaceColor', [0 0 0], 'MarkerEdgeColor', [0 0 0], 'LineWidth', 1.2);
hTot = plot(ax1, NaN, NaN, mkTot, 'LineStyle','none', 'MarkerSize', msTot, 'MarkerFaceColor', [0 0 0], 'MarkerEdgeColor',[0 0 0], 'LineWidth',1.2);

allR = [ratioTech(:); ratioTot(:)]; allR = allR(isfinite(allR) & allR>0);
xmin = max(min(allR)*0.90, 1e-3); xmax = max(allR)*1.20;
ax2.XScale = 'log';
xlim(ax2,[xmin xmax]);

text(ax1, -0.05, 1.05, 'a', 'Units','normalized', 'FontWeight','bold','FontSize',24, 'HorizontalAlignment','left');

labelsBar  = cellfun(@(s)[s ' (GW)'], tech_label, 'UniformOutput', false);
labelsLine = cellfun(@(s)[s ' (fold)'], tech_label, 'UniformOutput', false);
lgdA = legend(ax1, [b(1) b(2) b(3) b(4) , hMark(1) hMark(2) hMark(3) hMark(4) hTot], ...
    {labelsBar{:}, labelsLine{:}, 'Total (ratio)'}, 'Location','northeast', 'Box','off', 'NumColumns',1, 'FontSize',14);
%lgdA.Position(2) = Y1 + H1 - 0.20; 

%% ===================== BOTTOM ROW: Fig3.2 (b-e) =====================
axAttr = gobjects(nTech,1); panelLab = {'c','d','e','f'};
for ti = 1:nTech
    pos = [X2 + (ti-1)*(W_panel+gap), Y2, W_panel, H2];
    ax = axes('Position',pos); axAttr(ti) = ax; hold(ax,'on'); box(ax,'on');
    set(ax,'FontSize',16,'LineWidth',1.1,'TickLabelInterpreter','none');
    ax.XColor = [0 0 0]; ax.YColor = [0 0 0];
    
    Y_plot = nan(nScen,3); Y_plot(2:7,:) = [ frac_TC_tech(ti,:)' , frac_exp_tech(ti,:)' , frac_int_tech(ti,:)' ];
    
    bh = barh(ax, y, Y_plot, 'stacked', 'BarWidth',0.70, 'FaceAlpha',0.70);
    bh(1).FaceColor = col_climate; bh(2).FaceColor = col_human; bh(3).FaceColor = col_synergy;
    for jj = 1:numel(bh), bh(jj).EdgeColor = 'none'; end
    
    xlim(ax,[0 100]); xticks(ax,0:25:100); bw2 = bh(1).BarWidth;
    rectangle(ax,'Position',[0, y(1)-bw2/2, 100, bw2], 'EdgeColor',[0.70 0.70 0.70], 'LineWidth',2, 'LineStyle','--', 'FaceColor',[0.96 0.96 0.96]);
    
    totalW = sum(Y_plot,2,'omitnan');
    for k = 2:nScen
        if ~isfinite(totalW(k)) || totalW(k)<=0, continue; end
        rectangle(ax,'Position',[0, y(k)-bw2/2, totalW(k), bw2], 'EdgeColor',  [0.70 0.70 0.70], 'LineWidth',2.0, 'FaceColor','none');
    end
    
    ax.YLim = ax1.YLim; ax.YDir = ax1.YDir; ax.YTick = y; ax.YTickLabel = []; 
    ax.XGrid = 'on'; ax.YGrid = 'on'; ax.GridAlpha = 0.10;
    
    text(ax, -0.1, 1.05, panelLab{ti}, 'Units','normalized', 'FontWeight','bold','FontSize',24, 'HorizontalAlignment','left');
    if ti ==1, ax.YTickLabel = scenario_plot; end
    
    text(ax, 50, 0.25, tech_label{ti}, 'HorizontalAlignment','center', 'VerticalAlignment','middle', 'FontSize',16, 'Color',tech_outline(ti,:), 'FontWeight','bold');
end

a = annotation(gcf,'textbox', [0.5 - 0.15, Y2 - 0.06, 0.4, 0.04], ...
    'String','Contribution of increasing capacity loss (%)', ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', 'EdgeColor','none', 'FontSize',20);
a.Position =a.Position + [0 -0.005 0 0];
hL1 = plot(axAttr(1), NaN, NaN, 's', 'MarkerSize',9, 'MarkerFaceColor',col_climate, 'MarkerEdgeColor','none');
hL2 = plot(axAttr(1), NaN, NaN, 's', 'MarkerSize',9, 'MarkerFaceColor',col_human,   'MarkerEdgeColor','none');
hL3 = plot(axAttr(1), NaN, NaN, 's', 'MarkerSize',9, 'MarkerFaceColor',col_synergy, 'MarkerEdgeColor','none');
lgdB = legend(axAttr(4), [bh(1) bh(2) bh(3)], {'Hazard effect','Exposure effect','Synergistic effect'}, 'Box','off','Orientation','horizontal','FontSize',16);
lgdB.Position = [X2+1*(W_panel+gap)+0.06, Y2+H2+0.02, 0.3, 0.03]; 

%% Export
figFile = fullfile(figureDir,'Fig3_Combined_Layout.png');
exportgraphics(gcf,figFile,'Resolution',300);

futureScenarioNames = {'N-SSP1-2.6','N-SSP2-4.5','N-SSP5-8.5', ...
                       'F-SSP1-2.6','F-SSP2-4.5','F-SSP5-8.5'};
T_overall_contribution = table(string(futureScenarioNames(:)), ...
    dLoss_TC_all(:),dLoss_exp_all(:),dLoss_int_all(:),dLoss_total_all(:), ...
    frac_TC_all(:),frac_exp_all(:),frac_int_all(:), ...
    'VariableNames',{'Scenario','Hazard_GW','Exposure_GW','Synergy_GW', ...
    'TotalIncrease_GW','Hazard_pct','Exposure_pct','Synergy_pct'});
writetable(T_overall_contribution, ...
    fullfile(derivedDir,'Fig3_overall_contribution_percentages.csv'));
decompositionFile = fullfile(derivedDir,'Fig3_decomposition.mat');
save(decompositionFile,'dLoss_TC_tech','dLoss_exp_tech','dLoss_int_tech', ...
    'dLoss_TC_all','dLoss_exp_all','dLoss_int_all','dLoss_total_all', ...
    'frac_TC_tech','frac_exp_tech','frac_int_tech', ...
    'frac_TC_all','frac_exp_all','frac_int_all','T_overall_contribution', ...
    'decomposition_residual','tech_list','futureScenarioNames');
fprintf('Fig. 3 completed.\n  %s\n  %s\n',figFile,decompositionFile);
