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
% tr ss ssstage3 7 13 random1-5 top1-5 
% cc的图3张：
% tr ss ssstage：5个对比
%% 前期的决策动作对比（只看动作和v-v'）
%% baseline：% 1 tr ss ssstage：5个对比
T_solsteps = linspace(0,24,25);
figure('Color', [1 1 1]);
t = tiledlayout(1, 5, 'TileSpacing', 'compact', 'Padding', 'compact');
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

%% 训练集doe之后，和测试集doe的采样数据分布图对比；
% 并且说明指标之间的联系;讲清楚shap的目的
k_train=10;tree_used_step=1;level_lim=4; 
trees_id=[1:tree_used_step:23 24];
figure('Color', [1 1 1]);
t = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile; % pareto cst stg
h = gobjects(4,1); % 保存图形对象
data_all_shap_tr_5=load('shap_src\data_all_shap_5.mat');
data_all_shap_tr_5=data_all_shap_tr_5.data_all_shap;
for j=1:length(data_all_shap_tr_5)
    sample_tr=data_all_shap_tr_5{j};
    h(4) = scatter(sum(sample_tr.shap.ori_Jcost),sample_tr.shap.ori_Jsupp,Markersize,'b');hold on
end
h(1) = scatter(sum(par_tropt.tr.shap.ori_Jcost),par_tropt.tr.shap.ori_Jsupp,Markersize,...
    'g', 'filled','Marker', '^');hold on
h(2) = scatter(sum(par_ssopt.tr.shap.ori_Jcost),par_ssopt.tr.shap.ori_Jsupp,Markersize,...
    'r', 'filled','Marker', 's');hold on
h(3) =scatter(sum(par_ss3stage.tr.shap.ori_Jcost),par_ss3stage.tr.shap.ori_Jsupp,Markersize,'r','Marker', 's');hold on
scatter(sum(par_ss7stage.tr.shap.ori_Jcost),par_ss7stage.tr.shap.ori_Jsupp,Markersize,'r','Marker', 's');hold on
scatter(sum(par_ss13stage.tr.shap.ori_Jcost),par_ss13stage.tr.shap.ori_Jsupp,Markersize,'r','Marker', 's');hold on
xlabel('$J_{cst}(J)$', ...
    'FontSize', 16, 'FontWeight', 'bold' ,'interpreter','latex');
ylabel('$J_{stg}(kg)$', ...
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
%% 训练集上完成trees的训练，并且在测试加上检验一致性（正相关）
load(['shap_src\data\scores_all' 'k' num2str(k_train) 't' num2str(tree_used_step) 'l' num2str(level_lim) '_test.mat'])
load(['shap_src\data\scores_all_multiX_all' 'k' num2str(k_train) 't' num2str(tree_used_step) 'l' num2str(level_lim) '_test.mat'])
for j=1:length(data_all_shap_ts)
    sample_tr=data_all_shap_ts{j};
    data_var(j) = sample_tr.shap.ori_Jvar;
    data_supp(j) = sample_tr.shap.ori_Jsupp;
    data_cost(j) = sum(sample_tr.shap.ori_Jcost);
end
figure('Color', [1 1 1]);
t = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
corrMatrix = corrcoef(data_cost, scores_all(:,1));r = corrMatrix(1,2)
scatter(data_cost,scores_all(:,1),Markersize,'k','filled');hold on;
xlabel('$J_{cst}(J)$', ...
    'FontSize', 16, 'FontWeight', 'bold' ,'interpreter','latex');
ylabel('$S_{cst}$', ...
    'FontSize', 16, 'FontWeight', 'bold' ,'interpreter','latex');
set(gca,'FontSize', 14,...
    'LineWidth', 1.5, 'Box', 'on');
legend('$Cost$','Location', 'northwest',...
    'FontSize', 15,'Interpreter', 'latex')
title('Rp=0.79', ...
    'FontWeight', 'bold','Interpreter', 'latex','FontSize',16);
nexttile;
corrMatrix = corrcoef(data_supp, scores_all(:,2));r = corrMatrix(1,2)
scatter(data_supp,scores_all(:,2),Markersize,'g','filled');hold on;
xlabel('$J_{stg}(kg)$', ...
    'FontSize', 16, 'FontWeight', 'bold' ,'interpreter','latex');
ylabel('$S_{stg}$', ...
    'FontSize', 16, 'FontWeight', 'bold' ,'interpreter','latex');
set(gca,'FontSize', 14,...
    'LineWidth', 1.5, 'Box', 'on');
legend('$Storage$','Location', 'northwest',...
    'FontSize', 15,'Interpreter', 'latex')
title('Rp=0.65', ...
    'FontWeight', 'bold','Interpreter', 'latex','FontSize',16);
nexttile;
corrMatrix = corrcoef(data_var, scores_all(:,3));r = corrMatrix(1,2)
scatter(data_var,scores_all(:,3),Markersize,'r','filled');hold on;
xlabel('$J_{var}$', ...
    'FontSize', 16, 'FontWeight', 'bold' ,'interpreter','latex');
ylabel('$S_{var}$', ...
    'FontSize', 16, 'FontWeight', 'bold' ,'interpreter','latex');
set(gca,'FontSize', 14,...
    'LineWidth', 1.5, 'Box', 'on');
legend('$Var$','Location', 'northwest',...
    'FontSize', 15,'Interpreter', 'latex')
title('Rp=0.63', ...
    'FontWeight', 'bold','Interpreter', 'latex','FontSize',16);
sgtitle('Consistency of $J$ and $S$ on test set', ...
    'FontWeight', 'bold','Interpreter', 'latex','FontSize',16);


