function prov_idx = local_assign_province(VRE, S, px, py)
nV    = height(VRE);
nProv = numel(S);
prov_idx = nan(nV,1);

for i = 1:nV
    lon0 = VRE.lon(i);
    lat0 = VRE.lat(i);
    tech = VRE.tech(i);

    if tech  == 'offshore'
        % 海上点：找最近省界 < 1 deg
        min_d = inf; min_ip = NaN;
        for ip = 1:nProv
            d = sqrt((lon0 - px{ip}).^2 + (lat0 - py{ip}).^2);
            dmin = min(d);
            if dmin < min_d
                min_d = dmin;
                min_ip = ip;
            end
        end
        if min_d <= 3
            prov_idx(i) = min_ip;
        else
            prov_idx(i) = NaN;
        end
    else
        % 先看是否直接落在某个省多边形内
        for ip = 1:nProv
            if inpolygon(lon0, lat0, S(ip).X, S(ip).Y)
                prov_idx(i) = ip;
                assigned = true;
                break;
            end
        end

    end
end
end