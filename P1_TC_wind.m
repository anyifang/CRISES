% 算每一个风机 风机高度处的风速

clear
close all

GCM_fliename ={'era5'};
GCM_NAME = {'CanESM5','CMCC-CM2-SR5','CNRM-CM6-1',...
    'EC-Earth3', 'INM-CM4-8','IPSL-CM6A-LR','MPI-ESM1-2-LR',...
    'MRI-ESM2-0','NorESM2-LM','TaiESM1' };
GCM_NAME_ = {'CanESM5','CMCC_CM2_SR5','CNRM_CM6_1',...
    'EC_Earth3', 'INM_CM4_8','IPSL_CM6A_LR','MPI_ESM1_2_LR',...
    'MRI_ESM2_0','NorESM2_LM','TaiESM1' };
scenarios(1) = {'historical'};
% for i = 2:length(GCM_NAME)
%     scenarios(i) = {'ssp126'};
%     % scenarios(i) = {'c'}; {'ssp126'};
% end
RGB =flipud( othercolor('Spectral4',4));
exp_name = {'ner','far'};
year_span = {'197501_201412'};
  
scenarios(1) = {'his'};
scenarios(2) = {'ssp126'};
scenarios(3) = {'ssp245'};
scenarios(4) = {'ssp585'};

% 主脚本预加载
Vmax_list = 15:1:120; % 你实际用到的范围
Rmax_list = 20:1:200; % 单位：km
WindC15Lib = containers.Map;
for Vmax = Vmax_list
    for Rmaxkm = Rmax_list
        fname = ['Wind_C15_data_Vmax',num2str(Vmax),'_Rmax',num2str(Rmaxkm),'.mat'];
        if exist(fname,'file')
           S= load(fname); % 确保S.Wind_C15_data已加载
            key = sprintf('%d_%d', Vmax, Rmaxkm);
            WindC15Lib(key) = S.Wind_C15_data;
        end
    end
end

 load('./data/china_onoffPV_sum.mat')  % china_onoffPV_sum

for i = 1:10
    for j = 1:4
        if j == 1;  k_arr = 1; else ;k_arr = [1 2]; end
        for k  =k_arr
        scenarios_i = scenarios{j};
        GCM_NAME_i = [GCM_NAME{i} ];
        GCM_fliename_i = [GCM_fliename{1}];
        year_span_i =cell2mat(year_span);
        TC_data = [];
        TC_num = 0 ;
        if  j< 2
            GCM_NAME_i =[ 'era5_e',num2str(i)];
        else
            GCM_NAME_i =[ 'era5PI_'  GCM_NAME_i ,'_',scenarios_i '_' exp_name{k}];
        end
            Cv = 1.44;

             turbine_lon = [china_onoffPV_sum.Lon];
             turbine_lat = [china_onoffPV_sum.Lat];
             
            load(['.\TCdata_NWP\',GCM_NAME_i,'_landTC_25ms_fixsstera5.mat']);
            wind_result = [];
            year = [];
            parfor n = 1:length(TC_dataland)
                %parfor k = 1:4004
                disp([GCM_NAME_i,'_',scenarios_i , num2str(n/length(TC_dataland),'%.4f' ) ])
                lat = TC_dataland(n).lat;
                lon = TC_dataland(n).lon;
                wind = TC_dataland(n).wind;
                year = TC_dataland(n).year;
                month = TC_dataland(n).tc_month;
                lat = lat(wind > 25);
                lon = lon(wind > 25);
                wind = wind(wind > 25);
                selected_stations = [];
                tf_times = datetime(year, month,0 ) + hours(0:length(lat)-1);
                [~, r0] = calc_model_wind_C15(lat, lon,wind,Cv, 0, 0, tf_times,[],WindC15Lib);
                ROCI = 0.18 * r0/1000 +226;  % km
                for s = 1:length(turbine_lon)

                    st_lat = turbine_lat(s);
                    st_lon = turbine_lon(s);
                    dist = sqrt((lat - st_lat).^2 + (lon - st_lon).^2);
                    if any(dist < max(ROCI) /100 *1.3)
                        I = (dist < max(ROCI) /100 *1.3);
                        Vmaxi = function_maxVmax(wind (I));
                        tf_times = datetime(year, month,0 ) + hours(0:sum(I)-1);
                        [model_wind, r0] = calc_model_wind_C15(lat(I), lon(I),wind (I),Cv, st_lat, st_lon, tf_times,[],WindC15Lib);
                        Ih_I_ratio = function_Ih_I_ratio(lat(I), lon(I),wind (I), st_lat, st_lon, tf_times,r0);
                        wind_result(n).maxwind(s) =  max(model_wind);
                        wind_result(n).Vmax(s) =  Vmaxi;
                        wind_result(n).Ih_I_ratio(s) =  sum(Ih_I_ratio);
                        wind_result(n).wind_larger25(s) =  sum(model_wind>25 /1.2); % 25/1.2 10m -> grad
                    else
                        wind_result(n).maxwind(s) =  0;
                        wind_result(n).Vmax(s) =  0;
                        wind_result(n).Ih_I_ratio(s) = 0;
                        wind_result(n).wind_larger25(s) =  0;
                    end
                    %plot(lon , lat ); hold on
                end
                wind_result(n).year  = year;
            end
            delete(gcp('nocreate'));
            if isempty(wind_result); error(['no data in ' ,GCM_NAME_i]) ; end
            save(['./P2_onoffPV_sum_result/C15_',GCM_NAME_i ,'_wind_result_fixsstera5' ] ...
                ,'wind_result','-v7.3')
        end
    end
end

function maxVmax = function_maxVmax(Vmaxi)
maxVmax = max(Vmaxi);
end

