function Vout = local_filter_VRE(Vin, S, Land, land_X, land_Y)
    % 只保留沿海省陆上点 + 海上风电点
    tech_list_local = unique(Vin.tech);
    nProv = numel(S);

    isInCoastalLand = false(height(Vin),1);

    for i = 1:height(Vin)
        lon0 = Vin.lon(i);
        lat0 = Vin.lat(i);

        isLand = inpolygon(lon0, lat0, land_X, land_Y);

        isCoastal = false;
        for ip = 1:nProv
            if inpolygon(lon0, lat0, S(ip).X, S(ip).Y)
                isCoastal = true;
                break;
            end
        end

        isInCoastalLand(i) = isLand & isCoastal;
    end

    % 判断是否在海上
    isSea = ~inpolygon(Vin.lon, Vin.lat, land_X, land_Y);

    mask_keep = false(height(Vin),1);
    for i = 1:height(Vin)
        tech = char(Vin.tech(i));
        if strcmp(tech,'offshore')
            mask_keep(i) = isSea(i);
        else
            mask_keep(i) = isInCoastalLand(i);
        end
    end

    Vout = Vin(mask_keep,:);
end