clc,clear;close all;
data_all_shap_ts=load('shap_src\data_all_shap_test.mat');
data_all_shap_ts=data_all_shap_ts.data_all_shap;
data_all_shap_tr=load('shap_src\data_all_shap_10.mat');
data_all_shap_tr=data_all_shap_tr.data_all_shap;
load('shap_src\res_baseline.mat')
set(groot, 'defaultAxesFontName', 'Times New Roman');  % 坐标轴刻度及标签
set(groot, 'defaultTextFontName', 'Times New Roman');  % 标题、文本框等
set(groot, 'defaultLegendFontName', 'Times New Roman');% 图例
set(groot, 'defaultColorbarFontName', 'Times New Roman'); % 颜色栏
LineWidth=2.5;Markersize=50;

%% doe的方法和doe的效果
figure('Color','white')
t = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
% 第一张图（doe方法的示意图）
nexttile; 
x_raw = [0, 6, 12, 18, 24];    % 原始采样点
x_interp = 0:24;               % 插值点
% 随机数种子确保可重复性
rng(2023);
% 曲线1：
y1 = [1.3, 1.3 + 0.1*rand, 1.2 + 0.05*rand, 1.5 + 0.1*rand, 1.5];
% 曲线2：
y2 = [1.3, 1 + 0.05*rand, 1.3 + 0.2*rand, 1.15 + 0.4*rand, 1.5];
y2(y2>1.5) = 1.5; % 限制幅值
% 曲线3：
y3 = [1.3, 1.2 + 0.05*rand, 1 + 0.2*rand, 1.5 - 0.05*rand, 1.5];
% 组合数据
Y_raw = [y1; y2; y3];
% 线性插值计算
Y_interp = zeros(3, length(x_interp));
for k = 1:3
    Y_interp(k,:) = interp1(x_raw, Y_raw(k,:), x_interp, 'linear');
end
% 预分配图例句柄
h= gobjects(3,1); 
% 分曲线绘制
for k = 1:3
    % 绘制原始数据点+实线
    h(1) = plot(x_raw, Y_raw(k,:),...
        'Color', 'k',...
        'LineWidth', LineWidth,'LineStyle', '-');hold on;
    h(2) = scatter(x_raw, Y_raw(k,:),Markersize,'k','filled');hold on;
    h(3) = scatter(x_interp, Y_interp(k,:),Markersize,'k');hold on;
end
xlim([0,24]);ylim([1,1.6]);
xlabel('$t(h)$', ...
    'FontSize', 16, 'FontWeight', 'bold' ,'interpreter','latex');
ylabel('sampled v', ...
    'FontSize', 16, 'FontWeight', 'bold' ,'interpreter','latex');
legend(h, {'v sequence','sampled points','interpolated points','LHS samples'},'Location', 'northwest',...
    'FontSize', 15);
set(gca,'FontSize', 14,...
    'LineWidth', 1.5, 'Box', 'on');
grid on;
title('Illustration of DoE for $v(t)$', ...
    'FontWeight', 'bold','Interpreter', 'latex','FontSize',16);
% 第二张图（test train samples plot）
nexttile; % 分层次图例
for j=1:10
    sample_tr=data_all_shap_tr{j};
    for i_comp=1:5
        for i_time=[0,6,12,18,24]
            h1 = scatter3(i_time,i_comp,sample_tr.shap.cc(i_time+1,i_comp), Markersize,... 
        'Marker', 'o',...
        'MarkerEdgeColor', [0.7 0.1 0.1],...       % 深红边框
        'MarkerFaceColor', [1.0 0.3 0.3],...       % 亮红填充
        'MarkerFaceAlpha', 0.7);   hold on
        end
    end
end

for j=1:20
    sample_tr=data_all_shap_ts{j};
    for i_comp=1:5
        for i_time=[0,6,12,18,24]
            h2 = scatter3(i_time,i_comp,sample_tr.shap.cc(i_time+1,i_comp), Markersize,... 
            'Marker', 'd',...                          % 棱形标记
            'MarkerEdgeColor', [0.1 0.2 0.7],...       % 深蓝边线
            'LineWidth', 1.2);    hold on
        end
    end
end 
xlabel('$t(h)$', ...
    'FontSize', 16, 'FontWeight', 'bold' ,'interpreter','latex');
ylabel('i-th compressor', ...
    'FontSize', 16, 'FontWeight', 'bold' ,'interpreter','latex');
zlabel('$v$', ...
    'FontSize', 16, 'FontWeight', 'bold' ,'interpreter','latex');
set(gca,'FontSize', 14,...
    'LineWidth', 1.5, 'Box', 'on');
legend([h1,h2], {'train set','test set'},...
    'Location', 'northwest',...
    'FontSize', 15);
title('Part of sampled points','FontWeight', 'bold','Interpreter', 'latex','FontSize',16)