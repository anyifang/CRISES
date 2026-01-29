function VRE_dt = local_interp_downtime_to_VRE(VRE, tech_list, ...
    dt_on, dt_off, dt_pv, t_lon, t_lat)

    nV    = height(VRE);
    nScen = size(dt_on,1);
    VRE_dt = nan(nV, nScen);

    for tt = 1:length(tech_list)
        tech = tech_list{tt};
        idx_tech = (VRE.tech == tech);
        if ~any(idx_tech), continue; end

        lonp = VRE.lon(idx_tech);
        latp = VRE.lat(idx_tech);

        for s = 1:nScen
            switch tech
                case 'onshore'
                    Z = dt_on(s,:).';
                case 'offshore'
                    Z = dt_off(s,:).';
                case {'dpv','upv'}
                    Z = dt_pv(s,:).';
                otherwise
                    error('Unknown tech %s', tech);
            end

            F = scatteredInterpolant(t_lon', t_lat', Z, 'natural','none');
            vals = F(lonp, latp);

            nanMask = isnan(vals);
            if any(nanMask)
                vals(nanMask) = griddata(t_lon, t_lat, Z, lonp(nanMask), latp(nanMask), 'nearest');
            end

            VRE_dt(idx_tech, s) = vals;
        end
    end
end
