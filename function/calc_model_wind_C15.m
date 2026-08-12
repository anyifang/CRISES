function [model_wind, r0] = calc_model_wind_C15(lat_TC, lon_TC, vs, Cv, st_lat, st_lon, st_time, Pc , WindC15Lib)
% lat_TC, lon_TC, vs: 台风中心插值后的纬度、经度、最大风速（向量，长度等于st_time）
% Cv: 经验系数
% st_lat, st_lon: 站点经纬度（标量）
% st_time: 目标时间（与lat_TC等长）
% Pc: 台风中心气压（向量，长度等于st_time），如无则可用950
% 10min - 10 m

    Pc = 950 * ones(size(lat_TC)); % 默认中心气压


Pn = 1013; % 环境气压 hPa
Re = 6371000; % 地球半径 m
model_wind = zeros(length(st_time),1);
r0 = zeros(length(st_time),1);
for i = 1:length(st_time)
    % 台风中心
    lat_c = lat_TC(i);
    lon_c = lon_TC(i);
    v_c = vs(i);
    pc_c = Pc(i);

    % 计算vmc（台风移动速度分量，简化为相邻点距离/时间）
    if i < length(st_time)
        dlat = deg2rad(lat_TC(i+1) - lat_c);
        dlon = deg2rad(lon_TC(i+1) - lon_c);
        a = sin(dlat/2).^2 + cos(deg2rad(lat_c)) * cos(deg2rad(lat_TC(i+1))) * sin(dlon/2).^2;
        c = 2 * atan2(sqrt(a), sqrt(1-a));
        dis = Re * c; % m
        dt = hours(st_time(i+1) - st_time(i));
        if dt == 0
            vmc = 0;
        else
            vmc = dis / (dt * 3600); % m/s
        end
        % 方向角
        alpha = atan2(lat_TC(i+1) - lat_c, lon_TC(i+1) - lon_c) * 180/pi;
        if alpha < 0, alpha = alpha + 360; end
        fai = alpha;
    else
        vmc = 0;
        fai = 0;
    end

    % 站点与台风中心距离
    dlat_s = deg2rad(st_lat - lat_c);
    dlon_s = deg2rad(st_lon - lon_c);
    a_s = sin(dlat_s/2).^2 + cos(deg2rad(lat_c)) * cos(deg2rad(st_lat)) * sin(dlon_s/2).^2;
    c_s = 2 * atan2(sqrt(a_s), sqrt(1-a_s));
    r = Re * c_s;

    % Rmax
    vm = v_c - vmc;
    if vm < 15 ;    model_wind(i) = 0;continue ; end
    Rmax = Cv * 51.6 * exp(-0.0223*vm + 0.0281*lat_c) * 1000; % m
    Rmax = max (Rmax , 30*1000 );
    %Rmax = min (Rmax , 200*1000 );
     vm = max(vm , 15);
     vm = min(vm, 120);
    %Rmax = Cv * 50  * 1000;
    % B参数
    B = (vm)^2 * 1.15 * exp(1) / (Pn - pc_c) / 100;
    B = (B <= 1) + 2.5*(B >= 2.5) + B * (B > 1 && B < 2.5);

    % 科氏参数
    f = 2 * 7.2921e-5 * sin(deg2rad(lat_c));

    % Holland气压
    Pg_TC = (pc_c + (Pn - pc_c) * exp(-(Rmax/r)^B)) * 100; % Pa

    % C15风速
    Vmax =  round(vm);
    Rmaxkm =  round(Rmax/1000);
    key = sprintf('%d_%d', Vmax, Rmaxkm);
    r0(i) = Rmax * 5; %初始值
    if isKey(WindC15Lib, key)
        Wind_C15_data = WindC15Lib(key);
        rr = Wind_C15_data.rr;
        VV = Wind_C15_data.vg;
        [~,I] = min(abs(rr-r));
        r0(i) = Wind_C15_data.r0;
        vg = VV(I);
    else
        vg = 0;
    end
    if isnan(vg) || isinf(vg) || vg < 0
        vg = 0;
    end

    % 风向角
    cta = atan2(st_lat - lat_c, st_lon - lon_c) * 180/pi;
    if cta < 0, cta = cta + 360; end
    % beta修正
    if r < Rmax
        beta = 10 * (1 + r / Rmax);
    elseif r < 1.2 * Rmax
        beta = 20 + 25 * (r / Rmax - 1);
    else
        beta = 25;
    end

    % vmoc修正
    vmoc = vmc * r * Rmax / (r^2 + Rmax^2) ;
    %vmoc = vmc ;
    % Powell修正
    Vx_TC = 0.85 * vg * cosd(cta + 90 + beta) + vmoc * cosd(fai);
    Vy_TC = 0.85 * vg * sind(cta + 90 + beta) + vmoc * sind(fai);
    Vx_TC = 0.893 * Vx_TC; % 1min-> 10min
    Vy_TC = 0.893 * Vy_TC;

    % 合成风速
    model_wind(i) = sqrt(Vx_TC^2 + Vy_TC^2);
end
end
