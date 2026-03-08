clc,clear;close all;
load('shap_src\data_all_shap_test.mat')
load('shap_src\res_baseline.mat')
top=20;
%% 先对比impact k
% 每一列代表一种K
top_idx_1=[]; % 5个k top个idx
top_idx_2=[]; % 5个k top个idx
top_idx_3=[]; % 5个k top个idx
% ; %[5 8 10 12 15] ---24(tree) ---4(level)
for tree_used_step=[6 5 4 3 1]
    % tree_used_step=1;% [1 2 3 4 5 6] ---k=10 ---4(level)
    % for level_lim=[1 2 3 4]
    k_train=10;
    trees_id=[1:tree_used_step:23 24];
    level_lim=4; % [1 2 3 4]
    load(['shap_src\data\scores_all' 'k' num2str(k_train) 't' num2str(tree_used_step) 'l' num2str(level_lim) '_test.mat'])
    load(['shap_src\data\scores_all_multiX_all' 'k' num2str(k_train) 't' num2str(tree_used_step) 'l' num2str(level_lim) '_test.mat'])
    % 记录所有的top idx
    [~, top_Indices_1] = mink(scores_all(:,1), top);
    [~, top_Indices_2] = maxk(scores_all(:,2), top);
    [~, top_Indices_3] = mink(scores_all(:,3), top);
    % 取出top_Indices
    top_idx_1=[top_idx_1 top_Indices_1];
    top_idx_2=[top_idx_2 top_Indices_2];
    top_idx_3=[top_idx_3 top_Indices_3];
    a=1;
end
% 得到对应指标
[M,N]=size(top_idx_1);
for i=1:M
    for j=1:N
        Jtop_idx_1(i,j)=sum(data_all_shap{top_idx_1(i,j)}.shap.ori_Jcost)./sum(par_tropt.tr.shap.ori_Jcost);
    end
end
[M,N]=size(top_idx_2);
for i=1:M
    for j=1:N
        Jtop_idx_2(i,j)=data_all_shap{top_idx_2(i,j)}.shap.ori_Jsupp./par_tropt.tr.shap.ori_Jsupp;
    end
end
[M,N]=size(top_idx_3);
for i=1:M
    for j=1:N
        Jtop_idx_3(i,j)=data_all_shap{top_idx_3(i,j)}.shap.ori_Jvar./par_tropt.tr.shap.ori_Jvar;
    end
end
% 做箱型图
groupLabels = {'5', '7', '9', '13', '24'};
nGroups=5;
%% 绘制箱线图 1
data_cell={Jtop_idx_1,Jtop_idx_2,Jtop_idx_3};
names={'$J_{cst}$','$J_{stg}$','$J_{var}$'};
figure('Color', [1 1 1]);
t = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
set(groot, 'defaultAxesFontName', 'Times New Roman');  % 坐标轴刻度及标签
set(groot, 'defaultTextFontName', 'Times New Roman');  % 标题、文本框等
set(groot, 'defaultLegendFontName', 'Times New Roman');% 图例
set(groot, 'defaultColorbarFontName', 'Times New Roman'); % 颜色栏
for i_data=1:3
    nexttile;
    % subplot(1,3,i_data)
    data = data_cell{i_data};
    % 基础箱线图
    bp = boxplot(data, ...
        'Labels',groupLabels,...
        'Notch', 'on', ...          % 显示凹槽比较中位数
        'Whisker', 1.5, ...         % 触须长度（IQR倍数）
        'Symbol', 'k+');
    % xlabel(gca, groupLabels, ...
    %     'Interpreter', 'latex'); 
    % 美化箱线图样式
    set(bp, 'LineWidth', 1.5);     % 统一线条粗细

    % 设置箱体颜色（RGB格式）
    colors = [0.2 0.6 0.8;
        0.8 0.4 0.2;
        0.4 0.8 0.4;
        0.9 0.7 0.1;
        0.6 0.3 0.7];

    h = findobj(gca, 'Tag', 'Box');  % 获取所有箱体对象
    for k = 1:length(h)
        patch(get(h(k), 'XData'), get(h(k), 'YData'),...
            colors(k,:), 'FaceAlpha', 0.4, 'EdgeColor', 'none');
    end

    hold on;  % 保持图形状态

    %% 计算并绘制均值连线
    means = mean(data);  % 计算每组均值

    % 绘制连线（红色虚线）
    plot(1:nGroups, means, ...
        'Color', [0.9 0.1 0.1], ...  % RGB颜色
        'LineWidth', 1.5, ...
        'Marker', 'o', ...
        'MarkerSize', 6, ...
        'MarkerFaceColor', [1 1 1], ...
        'MarkerEdgeColor', [0.7 0 0], ...
        'LineStyle', '--');

    %% 图形美化
    % 坐标轴标签设置
    xlabel('$N_{r}$', ...
        'FontSize', 18, 'FontWeight', 'bold' ,'interpreter','latex');
    ylabel(names{i_data}, ...
        'FontSize', 18, 'FontWeight', 'bold' ,'interpreter','latex');

    % 调整坐标轴属性
    set(gca, ...
        'FontSize', 14, ...
        'LineWidth', 1.2, ...
        'GridLineStyle', '--', ...
        'GridAlpha', 0.5, ...
        'TickLabelInterpreter','latex',...
        'TickLabelInterpreter','latex');
    grid on;

    % 设置Y轴范围
    % ylim([min(data(:))-1, max(data(:))+1]);

    % % 添加图例
    % legend({'均值连线'}, ...
    %     'FontSize', 12, ...
    %     'Location', 'northwest', ...
    %     'EdgeColor', 'none');

end
% 添加标题
sgtitle('Comparison of $N_{r}$', ...
     'FontWeight', 'bold','Interpreter', 'latex','FontSize',18);
aaa=1;
% 评价处最终的指标以tr作为归一化标准 tr ss sstage3 7 13；随机5；top5
% 5个k的指标对比柱状图 3个指标
% 5个k的指标分布图 + 所有测试样本指标分布