function out_svg = replot_try1_overview_all_seeds_min()
try_root = fullfile('shap_src_min', 'doe', 'try1');
seeds = [11 23 37];
dt_list = [0.5 1.0 1.5 2.0];
n_comp = 5;
t_plot = linspace(0, 24, 97)';

% sample colors by dt (light -> darker, clearly separated)
sample_cols = [
    0.96 0.84 0.66;  % dt=0.5 h
    0.73 0.83 0.95;  % dt=1.0 h
    0.54 0.69 0.88;  % dt=1.5 h
    0.35 0.45 0.62]; % dt=2.0 h
sample_lw = 1.3;
marker_sz = 3.6;

% mean/envelope color by seed (same color, solid vs dashed)
mean_env_cols = [
    0.82 0.18 0.18;  % seed 011
    0.10 0.55 0.20;  % seed 023
    0.12 0.12 0.12]; % seed 037

f = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters', ...
    'Position', [40 40 2380 1120]);
tlo = tiledlayout(numel(seeds), n_comp, 'TileSpacing', 'compact', 'Padding', 'loose');

for si = 1:numel(seeds)
    seed = seeds(si);
    mean_env_col = mean_env_cols(si, :);

    for cj = 1:n_comp
        ax = nexttile((si - 1) * n_comp + cj);
        hold(ax, 'on');

        y_stats = zeros(numel(t_plot), 0);
        h_dt = gobjects(numel(dt_list), 1);

        for di = 1:numel(dt_list)
            dt_hr = dt_list(di);
            dt_tag = strrep(sprintf('%.1f', dt_hr), '.', 'p');
            fp = fullfile(try_root, sprintf('seed_%03d', seed), ['dataset_dt_' dt_tag], 'actions.mat');
            S = load(fp, 'cc_samples', 't_hr');

            cc = S.cc_samples(:, cj, :);
            cc = reshape(cc, size(cc, 1), size(cc, 3));
            n_samp = size(cc, 2);

            y_dt_all = zeros(numel(t_plot), n_samp);
            for k = 1:n_samp
                y_dt_all(:, k) = interp1(S.t_hr, cc(:, k), t_plot, 'linear', 'extrap');
            end
            y_stats = [y_stats, y_dt_all]; %#ok<AGROW>

            % one representative sample line per dt level
            rng(1000 * seed + 100 * cj + 10 * di, 'twister');
            k_pick = randi(n_samp, 1, 1);
            yk_raw = cc(:, k_pick);
            h = plot(ax, t_plot, y_dt_all(:, k_pick), '-', 'Color', sample_cols(di, :), 'LineWidth', sample_lw, ...
                'Marker', 'o', 'MarkerIndices', 1:4:numel(t_plot), 'MarkerSize', marker_sz, ...
                'MarkerFaceColor', 'w', 'MarkerEdgeColor', sample_cols(di, :));
            plot(ax, S.t_hr, yk_raw, 'o', 'Color', sample_cols(di, :), ...
                'MarkerSize', marker_sz + 0.6, 'MarkerFaceColor', sample_cols(di, :), ...
                'MarkerEdgeColor', sample_cols(di, :), 'HandleVisibility', 'off');
            if cj == 1
                h_dt(di) = h;
            else
                set(h, 'HandleVisibility', 'off');
            end
        end

        y_mean = mean(y_stats, 2);
        y_q10 = prctile(y_stats, 10, 2);
        y_q90 = prctile(y_stats, 90, 2);

        h_q10 = plot(ax, t_plot, y_q10, '--', 'Color', mean_env_col, 'LineWidth', 2.8);
        plot(ax, t_plot, y_q90, '--', 'Color', mean_env_col, 'LineWidth', 2.8, 'HandleVisibility', 'off');
        h_mean = plot(ax, t_plot, y_mean, '-', 'Color', mean_env_col, 'LineWidth', 3.2);

        y_min = min(y_stats, [], 'all');
        y_max = max(y_stats, [], 'all');
        y_span = max(y_max - y_min, 1e-3);
        pad = 0.10 * y_span;

        xlim(ax, [0 24]);
        ylim(ax, [y_min - pad, y_max + pad]);
        grid(ax, 'on');
        box(ax, 'on');

        if si == numel(seeds)
            xlabel(ax, 'Time (h)', 'FontSize', 18);
        else
            xlabel(ax, '');
        end
        ylabel(ax, sprintf('r%d', cj), 'FontSize', 18);
        title(ax, sprintf('Seed %03d', seed), 'FontSize', 20, 'FontWeight', 'bold');
        set(ax, 'FontSize', 18, 'LineWidth', 1.3);

        if cj == 1
            lgd = legend(ax, [h_dt(:); h_mean; h_q10], ...
                {'sample Δt=0.5 h', 'sample Δt=1.0 h', 'sample Δt=1.5 h', 'sample Δt=2.0 h', 'mean', 'q10/q90'}, ...
                'Location', 'best', 'FontSize', 16, 'Box', 'off');
            lgd.Color = 'none';
        end
    end
end

sgtitle(tlo, 'Compressor-ratio DOE trajectories across seeds and sample Δt levels', ...
    'FontSize', 26, 'FontWeight', 'bold');

out_svg = fullfile(try_root, 'doe_seed_dt_overview.svg');
print(f, out_svg, '-dsvg');
close(f);
end
