clc,clear;close all;
data_all_shap_ts=load('shap_src\data_all_shap_test.mat');
data_all_shap_ts=data_all_shap_ts.data_all_shap;
load('shap_src\res_baseline.mat')
set(groot, 'defaultAxesFontName', 'Times New Roman');  % 坐标轴刻度及标签
set(groot, 'defaultTextFontName', 'Times New Roman');  % 标题、文本框等
set(groot, 'defaultLegendFontName', 'Times New Roman');% 图例
set(groot, 'defaultColorbarFontName', 'Times New Roman'); % 颜色栏
LineWidth=2.5;
% tr ss ssstage3 7 13 random1-5 top1-5 
% cc的图3张：
% tr ss ssstage：5个对比
%% 边界条件绘制
% T_solsteps = linspace(0,24,101);
% figure('Color', [1 1 1]);
% t = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
% nexttile;
% plot(T_solsteps,qbar(1:end,6)*par.c.mmscfd_to_kgps,'LineWidth', LineWidth);hold on;
% xlim([0,24])
% xlabel('$t(h)$', ...
%     'FontSize', 22, 'FontWeight', 'bold' ,'interpreter','latex');
% ylabel('$d(kg/s)$', ...
%     'FontSize', 22, 'FontWeight', 'bold' ,'interpreter','latex');
% title("$d$", ...
%     'FontWeight', 'bold','Interpreter', 'latex','FontSize',22);
% set(gca, ...
% 'FontSize', 16, ...
% 'LineWidth', 1.5, ...
% 'GridLineStyle', '--', ...
% 'GridAlpha', 0.5, ...
% 'TickLabelInterpreter','latex',...
% 'TickLabelInterpreter','latex');
%  grid on;
% nexttile;
% plot(T_solsteps,pslack(1:end)*par.c.psi_to_pascal/330/330,'LineWidth', LineWidth);hold on;
% xlim([0,24])
% xlabel('$t(h)$', ...
%     'FontSize', 22, 'FontWeight', 'bold' ,'interpreter','latex');
% ylabel("$\rho_{0}(kg/m^3)$", ...
%     'FontSize', 22, 'FontWeight', 'bold' ,'interpreter','latex');
% title("$\rho_{0}$", ...
%     'FontWeight', 'bold','Interpreter', 'latex','FontSize',22);
% set(gca, ...
% 'FontSize', 16, ...
% 'LineWidth', 1.5, ...
% 'GridLineStyle', '--', ...
% 'GridAlpha', 0.5, ...
% 'TickLabelInterpreter','latex',...
% 'TickLabelInterpreter','latex');
%  grid on;
%% 前期的决策动作对比（只看动作和v-v'）
%% baseline：% 1 tr ss ssstage：5个对比
T_solsteps = linspace(0,24,25);
figure('Color', [1 1 1]);
t = tiledlayout(1, 5, 'TileSpacing', 'compact', 'Padding', 'compact');
% 坐标轴标签设置
xlim([0,25])
xlabel('$t(h)$', ...
    'FontSize', 22, 'FontWeight', 'bold' ,'interpreter','latex');
ylabel(['$v_' num2str(i) '$'], ...
    'FontSize', 22, 'FontWeight', 'bold' ,'interpreter','latex');
set(gca, ...
'FontSize', 16, ...
'LineWidth', 1.5, ...
'GridLineStyle', '--', ...
'GridAlpha', 0.5, ...
'TickLabelInterpreter','latex',...
'TickLabelInterpreter','latex');
 grid on;

for i = 1:5
    nexttile;
    plot(T_solsteps,par_tropt.tr.shap.cc(:,i),'LineWidth', LineWidth);hold on;
    plot(T_solsteps,par_ssopt.tr.shap.cc(:,i),'LineWidth', LineWidth);hold on;
    plot(T_solsteps,par_ss3stage.tr.shap.cc(:,i),'LineWidth', LineWidth,'LineStyle', '--');hold on;
    plot(T_solsteps,par_ss7stage.tr.shap.cc(:,i),'LineWidth', LineWidth,'LineStyle', '--');hold on;
    plot(T_solsteps,par_ss13stage.tr.shap.cc(:,i),'LineWidth', LineWidth,'LineStyle', '--');hold on;
    % 坐标轴标签设置
    xlim([0,25])
    xlabel('$t(h)$', ...
        'FontSize', 22, 'FontWeight', 'bold' ,'interpreter','latex');
    ylabel(['$v_' num2str(i) '$'], ...
        'FontSize', 22, 'FontWeight', 'bold' ,'interpreter','latex');
    set(gca, ...
    'FontSize', 16, ...
    'LineWidth', 1.5, ...
    'GridLineStyle', '--', ...
    'GridAlpha', 0.5, ...
    'TickLabelInterpreter','latex',...
    'TickLabelInterpreter','latex');
    grid on;
end
legend('tr-opt','ss-opt','ss-3stage','ss-7stage','ss-13stage','FontSize',18);
sgtitle("$v-t$", ...
    'FontWeight', 'bold','Interpreter', 'latex','FontSize',22);

figure('Color', [1 1 1]);
t = tiledlayout(1, 5, 'TileSpacing', 'compact', 'Padding', 'compact');
for i = 1:5
    nexttile;
    plot(par_tropt.tr.shap.cc(2:end,i),par_tropt.tr.shap.m_dcc_every(2:end,i),'LineWidth', LineWidth);hold on;
    plot(par_ssopt.tr.shap.cc(2:end,i),par_ssopt.tr.shap.m_dcc_every(2:end,i),'LineWidth', LineWidth);hold on;
    plot(par_ss3stage.tr.shap.cc(2:end,i),par_ss3stage.tr.shap.m_dcc_every(2:end,i),'LineWidth', LineWidth,...
        'LineStyle', '--');hold on;
    plot(par_ss7stage.tr.shap.cc(2:end,i),par_ss7stage.tr.shap.m_dcc_every(2:end,i),'LineWidth', LineWidth,...
        'LineStyle', '--');hold on;
    plot(par_ss13stage.tr.shap.cc(2:end,i),par_ss13stage.tr.shap.m_dcc_every(2:end,i),'LineWidth', LineWidth,...
        'LineStyle', '--');hold on;
    % xlim([1,1.6])
    xlabel(['$v_' num2str(i) '$'], ...
        'FontSize', 22, 'FontWeight', 'bold' ,'interpreter','latex');
    ylabel(['$\dot{v_' num2str(i) '}$'], ...
        'FontSize', 22, 'FontWeight', 'bold' ,'interpreter','latex');
        set(gca, ...
    'FontSize', 16, ...
    'LineWidth', 1.5, ...
    'GridLineStyle', '--', ...
    'GridAlpha', 0.5, ...
    'TickLabelInterpreter','latex',...
    'TickLabelInterpreter','latex');
    grid on;
end
legend('tr-opt','ss-opt','ss-3stage','ss-7stage','ss-13stage','FontSize',18);
sgtitle("$\dot{v}-v$", ...
    'FontWeight', 'bold','Interpreter', 'latex','FontSize',22);

%% doe的方法和doe的效果图：lb ub 0.3压比的变化。
figure('Color','white')
t = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
% 第一张图（doe方法的示意图）
nexttile; 
x_raw = [0, 6, 12, 18, 24];    % 原始采样点
x_interp = 0:24;               % 插值点
lineColors = lines(3);          % 生成3种区分色
markerTypes = {'o', 's', 'd'};  % 圆形、方形、菱形标记
%% 生成模拟数据（三次不同波动模式）
% 随机数种子确保可重复性
rng(2023);
% 曲线1：缓和小波动
y1 = [0.5, 0.85 + 0.1*rand, 0.75 + 0.1*rand, 0.9 + 0.1*rand, 0.7];
% 曲线2：剧烈震荡
y2 = [0.5, 0.4 + 0.5*rand, 1.3 + 0.3*rand, 0.6 + 0.4*rand, 0.7];
y2(y2>1.5) = 1.5; % 限制幅值
% 曲线3：随机波动
y3 = smoothdata([1, rand(1,3)*1.2, 1], 'gaussian', 3);
y3(1)=0.5;y3(end)=0.1;
% 组合数据
Y_raw = [y1; y2; y3];
% 线性插值计算
Y_interp = zeros(3, length(x_interp));
for k = 1:3
    Y_interp(k,:) = interp1(x_raw, Y_raw(k,:), x_interp, 'linear');
end
% 可视化绘制
figure('Position', [300 300 1000 600]);
hold on;

% 预分配图例句柄
h= gobjects(3,1); 

% 分曲线绘制
for k = 1:3
    % 绘制原始数据点+实线
    h(1) = plot(x_raw, Y_raw(k,:),...
        'Color', 'b',...
        'LineWidth', LineWidth);
    h(2) = scatter(x_raw, Y_raw(k,:));
    h(2) = scatter(x_raw, Y_interp(k,:));
end

%% 图形优化
set(gca, 'FontName', 'Arial', 'FontSize', 12,...
    'LineWidth', 1.5,...
    'XTick', 0:3:24);

grid on;
set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.4);
xlabel('时间 (小时)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('性能指标', 'FontSize', 14, 'FontWeight', 'bold');
title('采样点与插值对比', 'FontSize', 16, 'FontWeight', 'bold');

% 分层次图例
legend(h_legend,...
    {'Case1 采样点', 'Case1 插值',...
     'Case2 采样点', 'Case2 插值',...
     'Case3 采样点', 'Case3 插值'});

title(['doe-shap comp-' num2str(i)])


%% 训练集doe之后，和测试集doe的采样数据分布图对比；
% 并且说明指标之间的联系;讲清楚shap的目的
Markersize=50;
k_train=10;tree_used_step=1;level_lim=4; 
trees_id=[1:tree_used_step:23 24];
data_all_shap_tr=load('shap_src\data_all_shap_10.mat');
data_all_shap_tr=data_all_shap_tr.data_all_shap;
figure('Color', [1 1 1]);
t = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile; % pareto cst stg
h = gobjects(4,1); % 保存图形对象
for j=1:length(data_all_shap_tr)
    sample_tr=data_all_shap_tr{j};
    h(4) = scatter(sum(sample_tr.shap.ori_Jcost),sample_tr.shap.ori_Jsupp,Markersize,'b');hold on
end
h(1) = scatter(sum(par_tropt.tr.shap.ori_Jcost),par_tropt.tr.shap.ori_Jsupp,Markersize,...
    'g', 'filled','Marker', '^');hold on
h(2) = scatter(sum(par_ssopt.tr.shap.ori_Jcost),par_ssopt.tr.shap.ori_Jsupp,Markersize,...
    'r', 'filled','Marker', 's');hold on
h(3) =scatter(sum(par_ss3stage.tr.shap.ori_Jcost),par_ss3stage.tr.shap.ori_Jsupp,Markersize,'r','Marker', 's');hold on
scatter(sum(par_ss7stage.tr.shap.ori_Jcost),par_ss7stage.tr.shap.ori_Jsupp,Markersize,'r','Marker', 's');hold on
scatter(sum(par_ss13stage.tr.shap.ori_Jcost),par_ss13stage.tr.shap.ori_Jsupp,Markersize,'r','Marker', 's');hold on
xlabel('$J_{cst}$', ...
    'FontSize', 16, 'FontWeight', 'bold' ,'interpreter','latex');
ylabel('$J_{stg}$', ...
    'FontSize', 16, 'FontWeight', 'bold' ,'interpreter','latex');
set(gca,'FontSize', 14,...
    'LineWidth', 1.5, 'Box', 'on');
% 图例设置
legend(h, {'tr-opt','ss-opt','ss-stage','LHS samples'},...
    'Location', 'northwest',...
    'FontSize', 15);
title('$J_{stg}$-$J_{cst}$  distribution', ...
    'FontWeight', 'bold','Interpreter', 'latex','FontSize',16);
nexttile; %  var
for j=1:length(data_all_shap_tr)
    sample_tr=data_all_shap_tr{j};
    data(j) = sample_tr.shap.ori_Jvar;
end
mu=mean(data);sigma=std(data);
hist_bins = linspace(min(data), max(data), 15); % 动态条柱范围
x_fit = linspace(min(data)-5, max(data)+5, 200); % 拟合曲线范围
pdf_fit = normpdf(x_fit, mu, sigma); % 理论正态分布
% 绘制半透明柱状图
h_hist = histogram(data, hist_bins,...
    'FaceColor', [0.2 0.6 0.8],...    % 浅蓝色填充
    'EdgeColor', [0.1 0.3 0.5],...    % 深蓝边框
    'FaceAlpha', 0.7,...              % 70%透明度
    'LineWidth', 1.2);                % 边框线宽
hold on;
scatter(par_tropt.tr.shap.ori_Jvar,0.2,Markersize,...
    'g', 'filled','Marker', '^');hold on
scatter(par_ssopt.tr.shap.ori_Jvar,0.2,Markersize,...
    'r', 'filled','Marker', 's');hold on
scatter(par_ss3stage.tr.shap.ori_Jvar,0.2,Markersize,'r','Marker', 's');hold on
scatter(par_ss7stage.tr.shap.ori_Jvar,0.2,Markersize,'r','Marker', 's');hold on
scatter(par_ss13stage.tr.shap.ori_Jvar,0.2,Markersize,'r','Marker', 's');hold on
ylabel('Frequency', 'FontSize', 16);
xlabel('$J_{var}$', ...
    'FontSize', 16, 'FontWeight', 'bold' ,'interpreter','latex');
yyaxis right; % 次坐标轴（概率密度）
h_fit = plot(x_fit, pdf_fit,...
    'Color', 'b',...        % 红色曲线
    'LineWidth', 1.5,...              % 粗体线条
    'LineStyle', '-');                % 实线
ylabel('Probability density', 'FontSize', 16);
xlim([-5,15])
set(gca,'FontSize', 14,...
    'LineWidth', 1.5, 'Box', 'on');

title('$J_{var}$  distribution', ...
    'FontWeight', 'bold','Interpreter', 'latex','FontSize',16);
sgtitle('Metrics of sampled and reference solutions', ...
    'FontWeight', 'bold','Interpreter', 'latex','FontSize',16);
%% 训练集上完成trees的训练，并且在测试加上检验一致性，



%% 先获取k=10，t_step=1，l=4的单任务top3索引
top=3;
load(['shap_src\data\scores_all' 'k' num2str(k_train) 't' num2str(tree_used_step) 'l' num2str(level_lim) '_test.mat'])
load(['shap_src\data\scores_all_multiX_all' 'k' num2str(k_train) 't' num2str(tree_used_step) 'l' num2str(level_lim) '_test.mat'])
% 记录所有的top idx
[~, top_Indices_1] = mink(scores_all(:,1), top);
[~, top_Indices_2] = maxk(scores_all(:,2), top);
[~, top_Indices_3] = mink(scores_all(:,3), top);
%% 抽查前3个计算指标并且作图（shap-t 和 J-t 和 性能柱状图）
% Sample data: 3 methods, 2 metrics each
figure('Color', [1 1 1]);
methods = {'tr-opt','ss-opt','ss-3stage','ss-7stage','ss-13stage',...
    'rand-sample1','rand-sample2','rand-sample3',...
    'shap-top:1st','shap-top:2nd','shap-top:3rd'};
% 用初始值归一化
metric2 = [par_tropt.tr.shap.ori_Jsupp par_ssopt.tr.shap.ori_Jsupp ...
    par_ss3stage.tr.shap.ori_Jsupp par_ss7stage.tr.shap.ori_Jsupp par_ss13stage.tr.shap.ori_Jsupp ...
    data_all_shap_ts{1}.shap.ori_Jsupp...
    data_all_shap_ts{2}.shap.ori_Jsupp...
    data_all_shap_ts{3}.shap.ori_Jsupp...
    data_all_shap_ts{4}.shap.ori_Jsupp...
    data_all_shap_ts{5}.shap.ori_Jsupp...
    data_all_shap_ts{5}.shap.ori_Jsupp...
    ]./par_tropt.tr.shap.ori_Jsupp;  % First metric values
metric1 = [sum(par_tropt.tr.shap.ori_Jcost) sum(par_ssopt.tr.shap.ori_Jcost) ...
    sum(par_ss3stage.tr.shap.ori_Jcost) sum(par_ss7stage.tr.shap.ori_Jcost) sum(par_ss13stage.tr.shap.ori_Jcost) ...
    sum(data_all_shap_ts{1}.shap.ori_Jcost)...
    sum(data_all_shap_ts{2}.shap.ori_Jcost)...
    sum(data_all_shap_ts{3}.shap.ori_Jcost)...
    sum(data_all_shap_ts{4}.shap.ori_Jcost)...
    sum(data_all_shap_ts{5}.shap.ori_Jcost)...
    ]./sum(par_tropt.tr.shap.ori_Jcost);
metric3 = [sum(par_tropt.tr.shap.ori_Jvar) sum(par_ssopt.tr.shap.ori_Jvar) ...
    sum(par_ss3stage.tr.shap.ori_Jvar) sum(par_ss7stage.tr.shap.ori_Jvar) sum(par_ss13stage.tr.shap.ori_Jvar) ...
    sum(data_all_shap_ts{1}.shap.ori_Jvar)...
    sum(data_all_shap_ts{2}.shap.ori_Jvar)...
    sum(data_all_shap_ts{3}.shap.ori_Jvar)...
    sum(data_all_shap_ts{4}.shap.ori_Jvar)...
    sum(data_all_shap_ts{5}.shap.ori_Jvar)...
    ]./sum(par_tropt.tr.shap.ori_Jvar);
data = [metric1; metric2;metric3]';  % Transpose for correct grouping

% Create figure with white background
figure('Color','white', 'Position', [100 100 600 400])

% Plot grouped bars with adjusted properties
h = bar(data, 'grouped', 'BarWidth', 0.7);
set(gca, 'FontSize', 12, 'XTickLabel', methods, 'XTick', 1:numel(methods))
% ylim([0 110])  % Adjust y-axis range

% Customize bar colors (RGB values)
h(1).FaceColor = [0.2 0.6 0.8];  % Blue for Metric 1
h(2).FaceColor = [0.9 0.4 0.3];  % Red for Metric 2
h(3).FaceColor = [0.1 0.1 0.9];  % ? for Metric 3

% Add data labels
for k_ = 1:size(data, 2)
    xpos = h(k_).XEndPoints;  % Get bar center positions
    ypos = h(k_).YEndPoints;  % Get bar heights
    text(xpos, ypos, string(ypos),...
        'HorizontalAlignment','center',...
        'VerticalAlignment','bottom',...
        'FontSize',10, 'Color',[0.3 0.3 0.3])
end

% Add annotations
ylabel('Scaled Performance', 'FontSize',12)
title('Comparative Analysis (3 Metrics)', 'FontSize',14)
legend({'$J_{cst}$','$J_{stg}$','$J_{var}$'}, 'Location','northwest', 'FontSize',11)

% Add grid lines
grid on
set(gca, 'GridAlpha', 0.2)

%% 最终的决策动作对比:v-t;v-v'
% 2 random 5：5个对比
% 3 tr ss  top 5：对比

% 15个case 的
% J柱状图
% 25h曲线图

% 典型样例的v-v'的决策过程视图：tr轨迹；ss轨迹；top1-3的轨迹；随机轨迹；

%% 先对比impact k
% 每一列代表一种K
top_idx_1=[]; % 5个k top个idx
top_idx_2=[]; % 5个k top个idx
top_idx_3=[]; % 5个k top个idx
% ; %[5 8 10 12 15] ---24(tree) ---4(level)
for level_lim=[1 2 3 4]
    tree_used_step=1;% [1 2 3 4 5 6] ---k=10 ---4(level)
    % for level_lim=[1 2 3 4]
    k_train=10;
    trees_id=[1:tree_used_step:23 24]
    % level_lim=4; % [1 2 3 4]
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
        Jtop_idx_1(i,j)=sum(data_all_shap_ts{top_idx_1(i,j)}.shap.ori_Jcost)./sum(par_tropt.tr.shap.ori_Jcost);
    end
end
[M,N]=size(top_idx_2);
for i=1:M
    for j=1:N
        Jtop_idx_2(i,j)=data_all_shap_ts{top_idx_2(i,j)}.shap.ori_Jsupp./par_tropt.tr.shap.ori_Jsupp;
    end
end
[M,N]=size(top_idx_3);
for i=1:M
    for j=1:N
        Jtop_idx_3(i,j)=data_all_shap_ts{top_idx_3(i,j)}.shap.ori_Jvar./par_tropt.tr.shap.ori_Jvar;
    end
end
% 做箱型图
groupLabels = {'Ncl=2', 'Ncl=4', 'Ncl=6', 'Ncl=8'};
nGroups=4;
%% 绘制箱线图 1
data_cell={Jtop_idx_1,Jtop_idx_2,Jtop_idx_3};
names={'$J_{cst}$','$J_{stg}$','$J_{var}$'};
%% 第一步：设置全局 LaTeX 渲染 (在绘图前运行)
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');  % 坐标轴刻度
set(groot, 'defaultTextInterpreter', 'latex');          % 常规文本（如标题）
set(groot, 'defaultLegendInterpreter', 'latex');        % 图例
set(groot, 'defaultColorbarTickLabelInterpreter', 'latex');  % 颜色栏
figure('Color', [1 1 1]);
t = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for i_data=1:3
    nexttile;
    % subplot(1,3,i_data)
    data = data_cell{i_data};
    % 基础箱线图
    bp = boxplot(data, ...
        'Labels', groupLabels, ...
        'Notch', 'on', ...          % 显示凹槽比较中位数
        'Whisker', 1.5, ...         % 触须长度（IQR倍数）
        'Symbol', 'k+');

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
    % xlabel('$k values$', ...
    %     'FontSize', 25, 'FontWeight', 'bold' ,'interpreter','latex');
    ylabel(names{i_data}, ...
        'FontSize', 30, 'FontWeight', 'bold' ,'interpreter','latex');

    % 调整坐标轴属性
    set(gca, ...
        'FontSize', 14, ...
        'LineWidth', 1.2, ...
        'GridLineStyle', '--', ...
        'GridAlpha', 0.5);
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
sgtitle('Comparison of Ncl', ...
     'FontWeight', 'bold');
% set(findall(gcf, 'Type', 'axes'), 'LooseInset', [0,0,0,0]);
aaa=1;
% 评价处最终的指标以tr作为归一化标准 tr ss sstage3 7 13；随机5；top5
% 5个k的指标对比柱状图 3个指标
% 5个k的指标分布图 + 所有测试样本指标分布