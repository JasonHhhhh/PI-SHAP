function [base, doe_tbl, doe_scenarios] = hvac_build_scenarios(cfg, dirs)
base = build_base_scenario_hvac(cfg);
[doe_tbl, doe_scenarios] = build_doe_scenarios_hvac(cfg, base);

writetable(doe_tbl, fullfile(dirs.table_dir, 'doe_scenarios.csv'));

plot_scenario_profiles_hvac(cfg, base, doe_scenarios, ...
    fullfile(dirs.figure_dir, 'figure_01_scenario_profiles.png'), ...
    fullfile(dirs.figure_dir, 'figure_01_scenario_profiles.svg'));
end

function s = build_base_scenario_hvac(cfg)
t = (0:(cfg.horizon - 1))';

tout = 29 + 5.5 * sin(2 * pi * (t - 8) / 24) + 1.2 * sin(4 * pi * (t - 14) / 24);
solar = max(0, sin(pi * (t - 6) / 12)) .^ 1.35;

occ1 = zeros(cfg.horizon, 1);
occ2 = 0.05 * ones(cfg.horizon, 1);

occ1(8:18) = 1.00;
occ1(7) = 0.35;
occ1(19) = 0.25;

occ2(8:19) = 0.75;
occ2(7) = 0.25;
occ2(20) = 0.20;

price = 0.18 * ones(cfg.horizon, 1);
price(1:6) = 0.12;
price(cfg.peak_idx) = 0.34;
price(23:24) = 0.16;

s = struct();
s.Hour = t;
s.Tout = tout;
s.Solar = solar;
s.Occ = [occ1, occ2];
s.Price = price;
s.T0 = [26.6, 26.1];
s.Name = 'base_reference_day';
end

function [tbl, scenarios] = build_doe_scenarios_hvac(cfg, base)
n = cfg.n_doe;
d = 9;
X = lhs_unit_hvac(n, d, cfg.seed + 101);

temp_shift = scale_linear_hvac(X(:, 1), -2.0, 4.0);
temp_amp = scale_linear_hvac(X(:, 2), 0.85, 1.20);
solar_mult = scale_linear_hvac(X(:, 3), 0.75, 1.25);
occ1_mult = scale_linear_hvac(X(:, 4), 0.70, 1.30);
occ2_mult = scale_linear_hvac(X(:, 5), 0.70, 1.25);
peak_mult = scale_linear_hvac(X(:, 6), 0.80, 1.45);
base_price_mult = scale_linear_hvac(X(:, 7), 0.90, 1.15);
t0_off1 = scale_linear_hvac(X(:, 8), -1.20, 1.20);
t0_off2 = scale_linear_hvac(X(:, 9), -1.20, 1.20);

scenarios = repmat(struct('Hour', [], 'Tout', [], 'Solar', [], 'Occ', [], 'Price', [], 'T0', [], 'Name', ''), n, 1);

scenario_id = (1:n)';
mean_tout = zeros(n, 1);
max_tout = zeros(n, 1);
peak_price = zeros(n, 1);
mean_occ = zeros(n, 1);

for i = 1:n
    tout_center = mean(base.Tout);
    tout = tout_center + temp_shift(i) + temp_amp(i) * (base.Tout - tout_center);
    tout = tout + 0.30 * sin(2 * pi * (base.Hour + i / n) / 24);

    solar = clamp_hvac(base.Solar * solar_mult(i), 0, 1.40);

    occ1 = clamp_hvac(base.Occ(:, 1) * occ1_mult(i), 0, 1.20);
    occ2 = clamp_hvac(base.Occ(:, 2) * occ2_mult(i), 0, 1.20);

    price = clamp_hvac(base.Price * base_price_mult(i), 0.08, 0.55);
    price(cfg.peak_idx) = clamp_hvac(price(cfg.peak_idx) * peak_mult(i), 0.10, 0.65);

    s = struct();
    s.Hour = base.Hour;
    s.Tout = tout;
    s.Solar = solar;
    s.Occ = [occ1, occ2];
    s.Price = price;
    s.T0 = base.T0 + [t0_off1(i), t0_off2(i)];
    s.Name = sprintf('doe_%03d', i);

    scenarios(i) = s;

    mean_tout(i) = mean(tout);
    max_tout(i) = max(tout);
    peak_price(i) = max(price);
    mean_occ(i) = mean((occ1 + occ2) / 2);
end

tbl = table(scenario_id, temp_shift, temp_amp, solar_mult, occ1_mult, occ2_mult, ...
    peak_mult, base_price_mult, t0_off1, t0_off2, mean_tout, max_tout, peak_price, mean_occ, ...
    'VariableNames', {'ScenarioID', 'TempShift', 'TempAmp', 'SolarMult', 'Occ1Mult', 'Occ2Mult', ...
    'PeakPriceMult', 'BasePriceMult', 'T0OffsetZone1', 'T0OffsetZone2', ...
    'MeanTout', 'MaxTout', 'PeakPrice', 'MeanOcc'});
end

function X = lhs_unit_hvac(n, d, seed)
rng(seed, 'twister');
X = zeros(n, d);
edges = linspace(0, 1, n + 1);
for j = 1:d
    u = edges(1:n)' + rand(n, 1) / n;
    X(:, j) = u(randperm(n));
end
end

function y = scale_linear_hvac(x, lo, hi)
y = lo + (hi - lo) .* x;
end

function v = clamp_hvac(v, lo, hi)
v = min(max(v, lo), hi);
end

function plot_scenario_profiles_hvac(cfg, base, scenarios, png_file, svg_file)
n = numel(scenarios);
idx = unique(max(1, min(n, [1, round(n / 2), n])));

fig = figure('Color', 'w', 'Position', [120, 80, 1200, 820]);

subplot(4, 1, 1);
plot(base.Hour, base.Tout, 'k-', 'LineWidth', 1.8); hold on;
for i = 1:numel(idx)
    plot(scenarios(idx(i)).Hour, scenarios(idx(i)).Tout, '--', 'LineWidth', 1.1);
end
grid on;
ylabel('Tout (degC)');
title('HVAC 2-zone benchmark: base day and DOE profile examples');
lg = [{'Base'}, arrayfun(@(x) sprintf('DOE-%03d', x), idx, 'UniformOutput', false)];
legend(lg, 'Location', 'northwest');

subplot(4, 1, 2);
plot(base.Hour, base.Solar, 'Color', [0.85, 0.45, 0.05], 'LineWidth', 1.8);
grid on;
ylabel('Solar (-)');

subplot(4, 1, 3);
plot(base.Hour, base.Occ(:, 1), 'b-', 'LineWidth', 1.5); hold on;
plot(base.Hour, base.Occ(:, 2), 'g-', 'LineWidth', 1.5);
grid on;
ylabel('Occupancy (-)');
legend({'Zone1', 'Zone2'}, 'Location', 'northwest');

subplot(4, 1, 4);
plot(base.Hour, base.Price, 'm-', 'LineWidth', 1.8);
grid on;
xlabel('Hour');
ylabel('Price ($/kWh)');
xlim([0, cfg.horizon - 1]);

saveas(fig, png_file);
saveas(fig, svg_file);
close(fig);
end
