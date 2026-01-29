% P6_run_one.m
enhanced_wind = str2double(getenv('ENH'));
delayfactor   = str2double(getenv('DELAY'));

fprintf('Running: enhanced_wind=%g, delayfactor=%g\n', enhanced_wind, delayfactor);

try
    downtime_computation(enhanced_wind, delayfactor);
catch ME
    disp(getReport(ME,'extended'));
    exit(1);
end

exit(0);
