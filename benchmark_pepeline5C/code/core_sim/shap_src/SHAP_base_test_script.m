clc,clear;close all
%% 读取网络结构、稳态优化参数等
fnameid=fopen('model_folder.txt');
fname = textscan(fnameid, '%s');
fclose(fnameid);
par.mfolder=fname{1}{1};
par=options_input(par);

% 读取仿真模型和优化算法的参数，不涉及气网的结构，全部返回到par中，在仿真中则不应用优化参数，仅仿真
par=options_input(par);

%load static model (nodes, pipes, comps, gnodes) from xls fliles，
% 读取稳态网络对象，把所有信息存到txt中，若txt存在若存在txt则从新的xls读取，没有xls则从csv，在保存成新的txt
if(exist([par.mfolder '\input_network.txt'])~=2 || par.out.update_from_xls==1)
    if(exist([par.mfolder '\input_network_nodes.xls'])==2 || exist([par.mfolder '\input_network_nodes.xlsx'])==2), [par.ss.n0]=gas_model_reader_xls(par); else
    [par.ss.n0]=gas_model_reader_csv(par); end     
end

%first input check
par=check_input_1(par);
if(par.flag==1), disp(par.message), return; end

%% 稳态ss优化
if(par.out.doss==1 || par.out.dosim==1)
% 单位转换 保存一个针对ss优化的气网对象数组par.ss.n0---划分网格之前的网格结构对象      
[par.ss.n0]=gas_model_reader_new(par.mfolder);   % load data from text file 从新保存的txt中
% 再次check对象是否过大
if(par.ss.n0.nv>par.out.maxnv || par.ss.n0.ne>par.out.maxne || par.ss.n0.nc>par.out.maxng || par.ss.n0.ng>par.out.maxng), return; end

%if(par.ss.n0.nv>20), return; end;
% 划分求解网格后重新定义nodes等
[par.ss.n]=gas_model_reconstruct_new(par.ss.n0,par.tr.lmax,1);  

%% Solve optimization ss :将至考虑压缩机能耗，不考虑管存
%optimization parameters
par.ss.m.cdw=50;                      %comp. ratio derivative penalty scale--->压缩机导数范数和惩罚
par.ss.m.ddw=50;                      %flex demand derivative penalty scale--->mass距离一个基准的差的
par.ss.m.odw=100;                     %objective scale
par.ss.m.maxiter=400;                 %
par.ss.m.opt_tol=1e-6;                %

%model specifications
% 归一化、进一步的参数定义、定义模型的一些细节、约束等
[par.ss]=model_spec(par.ss);

%demand function specifications
par.ss=econ_spec(par.ss,par.mfolder);

%% process 三个指标plot (必须要和论文中论述的完全一致；包括你上边的opt ss和后边的opt tr 以及 sim tr)
% all_nodes=2:4:101;
% mid_nodes=all_nodes(2:end-1);
% for mid_node=mid_nodes
%     par.(['ss_' num2str(mid_node)])=static_opt_base_ends(par.ss,mid_node); %起点
%     [par]=process_output_ss_nofd(par,['ss_' num2str(mid_node)]);
% end
% [par.ss_start]=static_opt_base_ends(par.ss,1); %起点
% par.ss=par.ss_start; % ss_start一定作为起点
% [par.ss_terminal]=static_opt_base_ends(par.ss,101); %终点
% [par]=process_output_ss_nofd(par,'ss_start');
% [par]=process_output_ss_nofd(par,'ss_terminal');
% save('shap_src\par_ss_opt.mat','par')

load('shap_src\par_ss_opt.mat')

%exit if not solved
if(par.ss.ip_info.status~=0), disp('Steady state optimization not feasible'), 
    fid=fopen([par.mfolder '\output_log.txt'],'w');
    fprintf(fid,['Steady-state solve status: ' num2str(par.ss.ip_info.status) '\n']);
    fclose(fid);
end

%process steady-state output 后处理稳态优化的结果
% if(par.out.steadystateonly==1), [par]=process_output_ss(par); if(par.out.intervals_out>0), gas_out_plots_i(par); end; return; end
% if(par.out.ss_check_exit==1), return; end
end

%% tr
%optimization parameters
par.tr.m.cdw=50;                      %comp. ratio derivative penalty scale
par.tr.m.ddw=50;                      %flex demand derivative penalty scale
par.tr.m.odw=100;                     %objective scale
par.tr.m.maxiter=400;                 %
par.tr.m.opt_tol=1e-6;                %
% 定义tr.n n0 容纳tran_sim网络对象
[par.tr.n0]=gas_model_reader_new(par.mfolder);                   % load data from text file
if(par.ss.n0.nv>par.out.maxnv || par.ss.n0.ne>par.out.maxne || par.ss.n0.nc>par.out.maxng || par.ss.n0.ng>par.out.maxng), return; end

[par.tr.n]=gas_model_reconstruct_new(par.tr.n0,par.tr.lmax,1); 

%model specifications
[par.tr]=model_spec(par.tr);

%demand function specifications
par.tr=econ_spec(par.tr,par.mfolder); % 实际以上准备工作和ss中的东西完全一样，只不过为了区分

%% 从ss优化结果出发，固定开始和结束的动作，搜索过渡过程tr中23个动作的最优解
% par.tr.m.use_init_state=1;% 固定开始和结束的ss opt动作
% par.tr.ss_start=par.ss_start;
% par.tr.ss_terminal=par.ss_terminal;
% [par.tr]=tran_opt_base_shap(par.tr);
% save('shap_src\par_baseline_opt.mat','par')
load('shap_src\par_baseline_opt.mat')
%% 基准方法动作整理：25序列的ccc_tropt ccc_ssopt
% 先ss(ss是处理过的结果，这里的tr不做处理直接计算)
all_nodes=2:4:101;
mid_nodes=all_nodes(2:end-1);
allcc=[];allcost_comp=[]; %5个压缩机每一时刻都有一个cost（功率）
allmass_pipes=[];  % 每一时刻的整个管线的管存
for mid_node=mid_nodes
    cc_this=par.(['ss_' num2str(mid_node)]).cc0(:,2); %起点
    cpow_this=par.out.(['ss_' num2str(mid_node)]).cpowopt(2,:); %起点
    mass_this=sum(par.out.(['ss_' num2str(mid_node)]).pipe_mass_0(2,:)); %起点
    allmass_pipes=[allmass_pipes mass_this];
    allcost_comp=[allcost_comp cpow_this'];
    allcc=[allcc cc_this];
end

% 实际上是三个指标
T_interval_101=linspace(0,par.tr.c.T,length(all_nodes))./3600;
allcc=[par.ss_start.cc0(:,2) allcc par.ss_terminal.cc0(:,2)]';
allcost_comp=[par.out.ss_start.cpowopt(2,:)' allcost_comp par.out.ss_terminal.cpowopt(2,:)']';
allmass_pipes=[sum(par.out.ss_start.pipe_mass_0(2,:)) allmass_pipes sum(par.out.ss_terminal.pipe_mass_0(2,:))]';

% ss 第一种：25个ss opt节点都用到；用12个；用6个；用3个。
% tr 只有一种
ccc_tropt=par.tr.cc0';
ccc_ssopt=allcc;
ccc_ssopt(end,:)=ccc_tropt(end,:);
% 估计一下能耗
pow_tropt=sum(sum(ccc_tropt));
pow_ssopt=sum(sum(ccc_ssopt));

% 先对这两种进行tr仿真
% 准备：setup 0：边界条件：气源压力、出口流量、压缩机压比
par.sim=par.ss;
par.sim.rtol0=1e-2; par.sim.atol0=1e-1;
par.sim.rtol1=1e-3; par.sim.atol1=1e-2;
par.sim.rtol=1e-5; par.sim.atol=1e-3;  %error tolerances for simulation
%par.sim.startup=1/4.2;     %startup time (fraction of horizon)
par.sim.startup=1/8;        %startup time (fraction of horizon)
par.sim.nperiods=2;         %number of periods after startup
par.sim.solsteps=24*6*2;        %solution steps per period
par.sim.fromss=1;
T_solsteps = linspace(0,24,par.sim.solsteps+1);

[par_tropt]=tran_sim_setup_0(par,ccc_tropt');
[par_ssopt]=tran_sim_setup_0(par,ccc_ssopt');
% execute simulation
[par_tropt.sim]=tran_sim_base_flat_noextd(par_tropt.sim);
[par_ssopt.sim]=tran_sim_base_flat_noextd(par_ssopt.sim);
[par_tropt]=process_output_tr_nofd_sim(par_tropt);
[par_ssopt]=process_output_tr_nofd_sim(par_ssopt);

% tr ss opt结果：都满足约束，然而在三个性能方向上的对比
% sum(par_tropt.tr.m_cost) % best (low)   1.1809e+09
% sum(par_ssopt.tr.m_cost) % lowest (high)   1.7916e+09
% sum(par_tropt.tr.m_supp) % best (low)   4.9247e+04
% sum(par_ssopt.tr.m_supp) % lowest (high)   7.9291e+04
% sum(par_tropt.tr.m_mass) % best (low)   3.2011e+04
% sum(par_ssopt.tr.m_mass) % lowest (low)   3.4512e+04

% （必须使得tr有效）
% 找到tr&ss gap 在 gap中建立一种生成较好决策的序列决策树

% 并不对每一个指标使用：这里将cost作为obj；将mass约束和v'作为惩罚项的一部分
% 绘图表示opt ss 和 tr的结果是满足某个约束的（v' mass）

% 指标2 mass keep：储能、保供能力（一般会保留管存势能，多使用压缩机cost；是一个约束）
% 指标3 设备友好，寿命约束，运行稳定性

%% 从ss和tr优化结果出发，以tr里给出的边界信息，采样、开始；建立数据集
% 先建立那个经验性的stage启动的baseline方法
% 1 slop; 2 stage- 取ss opt 2阶段、5阶段、11阶段、23阶段（全）
% 生成所有的cc 都是 5*25，直接可以被sim调用

all_nodes_3stage=1:12:25;
all_nodes_7stage=1:4:25;
all_nodes_13stage=1:2:25;
all_nodes_allstage=1:25;

allcc_3stage=[];
for i=1:length(all_nodes_3stage)-1
    allcc_3stage(all_nodes_3stage(i):all_nodes_3stage(i+1))=all_nodes_3stage(i);
end
allcc_7stage=[];
for i=1:length(all_nodes_7stage)-1
    allcc_7stage(all_nodes_7stage(i):all_nodes_7stage(i+1))=all_nodes_7stage(i);
end
allcc_13stage=[];
for i=1:length(all_nodes_13stage)-1
    allcc_13stage(all_nodes_13stage(i):all_nodes_13stage(i+1))=all_nodes_13stage(i);
end

ccc_ss3stage=ccc_ssopt(allcc_3stage,:);
ccc_ss7stage=ccc_ssopt(allcc_7stage,:);
ccc_ss13stage=ccc_ssopt(allcc_13stage,:);

ccc_ss3stage(end,:)=ccc_ssopt(end,:);
ccc_ss7stage(end,:)=ccc_ssopt(end,:);
ccc_ss13stage(end,:)=ccc_ssopt(end,:);
for i=1:25
    w1=(i-1)/24;w2=1-w1;
    ccc_ssslope(i,:)=w1.*ccc_ssopt(end,:)+w2.*ccc_ssopt(1,:);
end

%sim
[par_ss3stage]=tran_sim_setup_0(par,ccc_ss3stage');
[par_ss7stage]=tran_sim_setup_0(par,ccc_ss7stage');
[par_ss13stage]=tran_sim_setup_0(par,ccc_ss13stage');
[par_ssslope]=tran_sim_setup_0(par,ccc_ssslope');
% execute simulation
[par_ss3stage.sim]=tran_sim_base_flat_noextd(par_ss3stage.sim);
[par_ss7stage.sim]=tran_sim_base_flat_noextd(par_ss7stage.sim);
[par_ss13stage.sim]=tran_sim_base_flat_noextd(par_ss13stage.sim);
[par_ssslope.sim]=tran_sim_base_flat_noextd(par_ssslope.sim);

[par_ss3stage]=process_output_tr_nofd_sim(par_ss3stage);
[par_ss7stage]=process_output_tr_nofd_sim(par_ss7stage);
[par_ss13stage]=process_output_tr_nofd_sim(par_ss13stage);
[par_ssslope]=process_output_tr_nofd_sim(par_ssslope);
% res_baseline.par_ssopt=par_ssopt;
% res_baseline.par_ss3stage=par_ss3stage;
% res_baseline.par_ss7stage=par_ss7stage;
% res_baseline.par_ss13stage=par_ss13stage;
% res_baseline.par_tropt=par_tropt;
% res_baseline.par_ssopt=par_ssopt;
% save('shap_src\res_baseline.mat','par_ss3stage','par_ss7stage','par_ss13stage','par_ssslope',...
%     'par_tropt','par_ssopt')
load('shap_src\res_baseline.mat')

%% plot 分析一下基准
figure('Color', 'white');
plot(T_solsteps,par_tropt.tr.m_cc);hold on;
plot(T_solsteps,par_ssopt.tr.m_cc,'LineStyle','--');hold on;
plot(T_solsteps,par_ss3stage.tr.m_cc,'LineStyle','--');hold on;
plot(T_solsteps,par_ss7stage.tr.m_cc,'LineStyle','--');hold on;
plot(T_solsteps,par_ss13stage.tr.m_cc,'LineStyle','--');hold on;
plot(T_solsteps,par_ssslope.tr.m_cc,'LineStyle','--');hold on;
xlabel('t(h)');ylabel('cc');
tropt_diffcc = diff(par_tropt.tr.m_cc)./(T_solsteps(2)-T_solsteps(1));
ssopt_diffcc = diff(par_ssopt.tr.m_cc)./(T_solsteps(2)-T_solsteps(1));
ss3stage_diffcc = diff(par_ss3stage.tr.m_cc)./(T_solsteps(2)-T_solsteps(1));
ss7stage_diffcc = diff(par_ss7stage.tr.m_cc)./(T_solsteps(2)-T_solsteps(1));
ss13stage_diffcc = diff(par_ss13stage.tr.m_cc)./(T_solsteps(2)-T_solsteps(1));
ssslope_diffcc = diff(par_ssslope.tr.m_cc)./(T_solsteps(2)-T_solsteps(1));
figure('Color', 'white');
plot(T_solsteps(1:end-1),ssopt_diffcc);hold on;
plot(T_solsteps(1:end-1),tropt_diffcc,'LineStyle','--');hold on;
plot(T_solsteps(1:end-1),ss3stage_diffcc,'LineStyle','--');hold on;
plot(T_solsteps(1:end-1),ss7stage_diffcc,'LineStyle','--');hold on;
plot(T_solsteps(1:end-1),ss13stage_diffcc,'LineStyle','--');hold on;
plot(T_solsteps(1:end-1),ssslope_diffcc,'LineStyle','--');hold on;
legend('tr','ss','3-ss','7-ss','13-ss','slope-ss')
xlabel('t(h)');ylabel('cc');
figure('Color', 'white');
plot(T_solsteps,par_tropt.tr.m_cost);hold on;
plot(T_solsteps,par_ssopt.tr.m_cost,'LineStyle','--');hold on;
plot(T_solsteps,par_ss3stage.tr.m_cost,'LineStyle','--');hold on;
plot(T_solsteps,par_ss7stage.tr.m_cost,'LineStyle','--');hold on;
plot(T_solsteps,par_ss13stage.tr.m_cost,'LineStyle','--');hold on;
plot(T_solsteps,par_ssslope.tr.m_cost,'LineStyle','--');hold on;
legend('tr','ss','3-ss','7-ss','13-ss','slope-ss')
xlabel('t(h)');ylabel('pow');
figure('Color', 'white');
plot(T_solsteps,par_tropt.tr.m_supp);hold on;
plot(T_solsteps,par_ssopt.tr.m_supp,'LineStyle','--');hold on;
plot(T_solsteps,par_ss3stage.tr.m_supp);hold on;
plot(T_solsteps,par_ss7stage.tr.m_supp,'LineStyle','--');hold on;
plot(T_solsteps,par_ss13stage.tr.m_supp);hold on;
plot(T_solsteps,par_ssslope.tr.m_supp,'LineStyle','--');hold on;
legend('tr','ss','3-ss','7-ss','13-ss','slope-ss')
xlabel('t(h)');ylabel('supp flux');
figure('Color', 'white');
plot(T_solsteps,par_tropt.tr.m_mass);hold on;
plot(T_solsteps,par_ssopt.tr.m_mass,'LineStyle','--');hold on;
plot(T_solsteps,par_ss3stage.tr.m_mass,'LineStyle','--');hold on;
plot(T_solsteps,par_ss7stage.tr.m_mass,'LineStyle','--');hold on;
plot(T_solsteps,par_ss13stage.tr.m_mass,'LineStyle','--');hold on;
plot(T_solsteps,par_ssslope.tr.m_mass,'LineStyle','--');hold on;
legend('tr','ss','3-ss','7-ss','13-ss','slope-ss')
xlabel('t(h)');ylabel('mass pipes');
figure('Color', 'white');
plot(T_solsteps,par_tropt.tr.m_var);hold on;
plot(T_solsteps,par_ssopt.tr.m_var,'LineStyle','--');hold on;
plot(T_solsteps,par_ss3stage.tr.m_var,'LineStyle','--');hold on;
plot(T_solsteps,par_ss7stage.tr.m_var,'LineStyle','--');hold on;
plot(T_solsteps,par_ss13stage.tr.m_var,'LineStyle','--');hold on;
plot(T_solsteps,par_ssslope.tr.m_var,'LineStyle','--');hold on;
legend('tr','ss','3-ss','7-ss','13-ss','slope-ss')
xlabel('t(h)');ylabel('var flow');

% 一张柱状图概括所有baseline的性能

% Sample data: 3 methods, 2 metrics each
methods = {'tr','3-ss','7-ss','13-ss','ss','slope-ss'};
% 用初始值归一化
metric1 = [par_tropt.tr.shap.ori_Jsupp  par_ss3stage.tr.shap.ori_Jsupp...
    par_ss7stage.tr.shap.ori_Jsupp par_ss13stage.tr.shap.ori_Jsupp par_ssopt.tr.shap.ori_Jsupp ...
    par_ssslope.tr.shap.ori_Jsupp]./par_tropt.tr.shap.ori_Jsupp;  % First metric values
metric2 = [sum(par_tropt.tr.shap.ori_Jcost)  sum(par_ss3stage.tr.shap.ori_Jcost)...
    sum(par_ss7stage.tr.shap.ori_Jcost) sum(par_ss13stage.tr.shap.ori_Jcost) sum(par_ssopt.tr.shap.ori_Jcost) ...
    sum(par_ssslope.tr.shap.ori_Jcost)]./sum(par_tropt.tr.shap.ori_Jcost);  % First metric values
metric3 = [sum(par_tropt.tr.shap.ori_Jvar)  sum(par_ss3stage.tr.shap.ori_Jvar)...
    sum(par_ss7stage.tr.shap.ori_Jvar) sum(par_ss13stage.tr.shap.ori_Jvar) sum(par_ssopt.tr.shap.ori_Jvar) ...
    sum(par_ssslope.tr.shap.ori_Jvar)]./sum(par_tropt.tr.shap.ori_Jvar);  % First metric values
data = [metric1; metric2;metric3]';  % Transpose for correct grouping

% Create figure with white background
figure('Color','white', 'Position', [100 100 600 400])

% Plot grouped bars with adjusted properties
h = bar(data, 'grouped', 'BarWidth', 0.7);
set(gca, 'FontSize', 12, 'XTickLabel', methods, 'XTick', 1:numel(methods))
% ylim([0 110])  % Adjust y-axis range

% Customize bar colors (RGB values)
h(1).FaceColor = [0.2 0.6 0.7];  % Blue for Metric 1
h(2).FaceColor = [0.9 0.4 0.3];  % Red for Metric 2
h(3).FaceColor = [0.1 0.1 0.9];  % ? for Metric 3
% Add data labels
for k = 1:size(data, 2)
    xpos = h(k).XEndPoints;  % Get bar center positions
    ypos = h(k).YEndPoints;  % Get bar heights
    text(xpos, ypos, string(ypos),...
        'HorizontalAlignment','center',...
        'VerticalAlignment','bottom',...
        'FontSize',10, 'Color',[0.3 0.3 0.3])
end

% Add annotations
ylabel('Performance', 'FontSize',12)
title('Comparative Analysis of Methods (3 Metrics)', 'FontSize',14)
legend({'mass', 'cost', 'var'}, 'Location','northwest', 'FontSize',11)

% Add grid lines
grid on
set(gca, 'GridAlpha', 0.2)

% 开头结尾固定 23 * 5个点需要去选择 n=115 samples：30*n CV-dataset:5:1 
% --->构建23个决策tree分别代表各个时间点的规则

%% 建立shap数据集用来训练decision tree；并且plot一下做分析
% 采样很稀疏的数据：1-3-1  :15 samples 15*100--->暂且1500

cc0_start = ccc_ssopt(1,:);
cc0_ternimal = ccc_ssopt(end,:);

% pr的区间长度是0.3:
cc_lb=[1.3 1 1 1 1];cc_ub=[1.6 1.3 1.3 1.3 1.3];
n_tp=3;n_cc=5;k=20;
num_sampls=n_tp*n_cc*k;
doe = lhsdesign(num_sampls,n_tp*n_cc);
doe = reshape(doe,num_sampls,n_tp,n_cc);
cc1mid3=doe(:,:,1)*0.3+cc_lb(1);  % 压缩机1
cc2mid3=doe(:,:,2)*0.3+cc_lb(2);  % 压缩机2
cc3mid3=doe(:,:,3)*0.3+cc_lb(3);  % 压缩机3
cc4mid3=doe(:,:,4)*0.3+cc_lb(4);  % 压缩机4
cc5mid3=doe(:,:,5)*0.3+cc_lb(5);  % 压缩机5

% 整理出所有的5*25 cc
t_interp_span=0:6:24;
t_interp_new=0:24;
cc_all_shap={};
for i=1:num_sampls
    cccc1=interp1(t_interp_span,[cc0_start(1) cc1mid3(i,:) cc0_ternimal(1)],t_interp_new);
    cccc2=interp1(t_interp_span,[cc0_start(2) cc2mid3(i,:) cc0_ternimal(2)],t_interp_new);
    cccc3=interp1(t_interp_span,[cc0_start(3) cc3mid3(i,:) cc0_ternimal(3)],t_interp_new);
    cccc4=interp1(t_interp_span,[cc0_start(4) cc4mid3(i,:) cc0_ternimal(4)],t_interp_new);
    cccc5=interp1(t_interp_span,[cc0_start(5) cc5mid3(i,:) cc0_ternimal(5)],t_interp_new);
    cccc=[cccc1;cccc2;cccc3;cccc4;cccc5];
    cc_all_shap{i}=cccc;
end
% 画出来看看所采样的pr
% 概括所有5个压缩机动作和动作导数变化
%% 获取数据集
% for j=1:num_sampls
%     j
%     ccc_plot=cc_all_shap{j};
%     [par0]=tran_sim_setup_0(par,ccc_plot);
%     % execute simulation
%     [par0.sim]=tran_sim_base_flat_noextd(par0.sim);
%     [par0]=process_output_tr_nofd_sim(par0);
%     % 提取shap部分的数据
%     data_all_shap{j}=par0.tr;
% end
% save('shap_src\data_all_shap_test.mat','data_all_shap')
load('shap_src\data_all_shap_test.mat')

figure('Color','white', 'Position', [100 100 600 400])
for i = 1:5
    for j=1:num_sampls
    subplot(2,3,i);
    ccc_plot=cc_all_shap{j};
    plot(t_interp_new,ccc_plot(i,:));hold on;
    end
    xlim([0 24]);
    ylim([cc_lb(i) cc_ub(i)])
    title(['doe-shap comp-' num2str(i)])
end

%% 抽查前5个计算指标并且作图（shap 和 轨迹 和 性能柱状图）
% Sample data: 3 methods, 2 metrics each
methods = {'tr','ss','ss-3','ss-7','ss-13','sample 1','sample 2','sample 3','sample 4','sample 5'};
% 用初始值归一化
metric1 = [par_tropt.tr.shap.ori_Jsupp par_ssopt.tr.shap.ori_Jsupp ...
    par_ss3stage.tr.shap.ori_Jsupp par_ss3stage.tr.shap.ori_Jsupp par_ss3stage.tr.shap.ori_Jsupp ...
    data_all_shap{1}.shap.ori_Jsupp...
    data_all_shap{2}.shap.ori_Jsupp...
    data_all_shap{3}.shap.ori_Jsupp...
    data_all_shap{4}.shap.ori_Jsupp...
    data_all_shap{5}.shap.ori_Jsupp...
    ]./par_tropt.tr.shap.ori_Jsupp;  % First metric values
metric2 = [sum(par_tropt.tr.shap.ori_Jcost) sum(par_ssopt.tr.shap.ori_Jcost) ...
    sum(par_ss3stage.tr.shap.ori_Jcost) sum(par_ss3stage.tr.shap.ori_Jcost) sum(par_ss3stage.tr.shap.ori_Jcost) ...
    sum(data_all_shap{1}.shap.ori_Jcost)...
    sum(data_all_shap{2}.shap.ori_Jcost)...
    sum(data_all_shap{3}.shap.ori_Jcost)...
    sum(data_all_shap{4}.shap.ori_Jcost)...
    sum(data_all_shap{5}.shap.ori_Jcost)...
    ]./sum(par_tropt.tr.shap.ori_Jcost);  
    % First metric values
metric3 = [sum(par_tropt.tr.shap.ori_Jvar) sum(par_ssopt.tr.shap.ori_Jvar) ...
    sum(par_ss3stage.tr.shap.ori_Jvar) sum(par_ss3stage.tr.shap.ori_Jvar) sum(par_ss3stage.tr.shap.ori_Jvar) ...
    sum(data_all_shap{1}.shap.ori_Jvar)...
    sum(data_all_shap{2}.shap.ori_Jvar)...
    sum(data_all_shap{3}.shap.ori_Jvar)...
    sum(data_all_shap{4}.shap.ori_Jvar)...
    sum(data_all_shap{5}.shap.ori_Jvar)...
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
for k = 1:size(data, 2)
    xpos = h(k).XEndPoints;  % Get bar center positions
    ypos = h(k).YEndPoints;  % Get bar heights
    text(xpos, ypos, string(ypos),...
        'HorizontalAlignment','center',...
        'VerticalAlignment','bottom',...
        'FontSize',10, 'Color',[0.3 0.3 0.3])
end

% Add annotations
ylabel('Performance', 'FontSize',12)
title('Comparative Analysis of Methods (3 Metrics)', 'FontSize',14)
legend({'mass', 'cost','var'}, 'Location','northwest', 'FontSize',11)

% Add grid lines
grid on
set(gca, 'GridAlpha', 0.2)

% 概括所有5个压缩机动作和动作导数变化
figure('Color','white', 'Position', [100 100 600 400])
for i = 1:5
subplot(2,3,i);

plot(par_tropt.tr.shap.cc(2:end,i),par_tropt.tr.shap.m_dcc_every(2:end,i));hold on;
plot(par_ssopt.tr.shap.cc(2:end,i),par_ssopt.tr.shap.m_dcc_every(2:end,i));hold on;

plot(par_ss3stage.tr.shap.cc(2:end,i),par_ss3stage.tr.shap.m_dcc_every(2:end,i));hold on;
plot(par_ss7stage.tr.shap.cc(2:end,i),par_ss7stage.tr.shap.m_dcc_every(2:end,i));hold on;
plot(par_ss13stage.tr.shap.cc(2:end,i),par_ss13stage.tr.shap.m_dcc_every(2:end,i));hold on;

plot(data_all_shap{1}.shap.cc(2:end,i),data_all_shap{1}.shap.m_dcc_every(2:end,i),'LineStyle','--');hold on;
plot(data_all_shap{2}.shap.cc(2:end,i),data_all_shap{2}.shap.m_dcc_every(2:end,i),'LineStyle','--');hold on;
plot(data_all_shap{3}.shap.cc(2:end,i),data_all_shap{3}.shap.m_dcc_every(2:end,i),'LineStyle','--');hold on;
plot(data_all_shap{4}.shap.cc(2:end,i),data_all_shap{4}.shap.m_dcc_every(2:end,i),'LineStyle','--');hold on;
plot(data_all_shap{5}.shap.cc(2:end,i),data_all_shap{5}.shap.m_dcc_every(2:end,i),'LineStyle','--');hold on;
% set(gca, 'YScale', 'log'); % 关键代码：设置 y 轴为对数刻度
title(['comp-' num2str(i)])
scatter(par_ssopt.tr.shap.cc(2,i),0);hold on
end
legend('tr','ss','ss-3','ss-7','ss-13','sample 1','sample 2','sample 3','sample 4','sample 5')
sgtitle("v-v'(cc)", 'FontSize',14)

%% 绘制shap的图作对比，得出tree的构建规则和shap的后处理规则，使得得到ss和opt之间的局部优化解
% shap: tr ss 'sample 1','sample 2','sample 3','sample 4','sample 5'
% 概括所有5个压缩机动作和shap值的变化
figure('Color','white', 'Position', [100 100 600 400])
for i = 1:5
subplot(2,3,i);

plot(1:24,par_tropt.tr.shap.item_shap_cost(:,i));hold on;
plot(1:24,par_ssopt.tr.shap.item_shap_cost(:,i));hold on;

plot(1:24,data_all_shap{1}.shap.item_shap_cost(:,i),'LineStyle','--');hold on;
plot(1:24,data_all_shap{2}.shap.item_shap_cost(:,i),'LineStyle','--');hold on;
plot(1:24,data_all_shap{3}.shap.item_shap_cost(:,i),'LineStyle','--');hold on;
plot(1:24,data_all_shap{4}.shap.item_shap_cost(:,i),'LineStyle','--');hold on;
plot(1:24,data_all_shap{5}.shap.item_shap_cost(:,i),'LineStyle','--');hold on;
title(["comp-"; num2str(i)], 'FontSize',8)
% set(gca, 'YScale', 'log'); % 关键代码：设置 y 轴为对数刻度
end
legend('tr','ss','sample 1','sample 2','sample 3','sample 4','sample 5')
subplot(2,3,6);
plot(1:24,sum(par_tropt.tr.shap.item_shap_cost(:,:)'));hold on;
plot(1:24,sum(par_ssopt.tr.shap.item_shap_cost(:,:)'));hold on;
plot(1:24,sum(data_all_shap{1}.shap.item_shap_cost(:,:)'),'LineStyle','--');hold on;
plot(1:24,sum(data_all_shap{2}.shap.item_shap_cost(:,:)'),'LineStyle','--');hold on;
plot(1:24,sum(data_all_shap{3}.shap.item_shap_cost(:,:)'),'LineStyle','--');hold on;
plot(1:24,sum(data_all_shap{4}.shap.item_shap_cost(:,:)'),'LineStyle','--');hold on;
plot(1:24,sum(data_all_shap{5}.shap.item_shap_cost(:,:)'),'LineStyle','--');hold on;
title("all 5", 'FontSize',8)
sgtitle("cost shap", 'FontSize',14)

figure('Color','white', 'Position', [100 100 600 400])
for i = 1:5
subplot(2,3,i);

plot(1:24,par_tropt.tr.shap.item_shap_supp(:,i));hold on;
plot(1:24,par_ssopt.tr.shap.item_shap_supp(:,i));hold on;

plot(1:24,data_all_shap{1}.shap.item_shap_supp(:,i),'LineStyle','--');hold on;
plot(1:24,data_all_shap{2}.shap.item_shap_supp(:,i),'LineStyle','--');hold on;
plot(1:24,data_all_shap{3}.shap.item_shap_supp(:,i),'LineStyle','--');hold on;
plot(1:24,data_all_shap{4}.shap.item_shap_supp(:,i),'LineStyle','--');hold on;
plot(1:24,data_all_shap{5}.shap.item_shap_supp(:,i),'LineStyle','--');hold on;
title(["comp-"; num2str(i)], 'FontSize',8)
% set(gca, 'YScale', 'log'); % 关键代码：设置 y 轴为对数刻度
end
legend('tr','ss','sample 1','sample 2','sample 3','sample 4','sample 5')
subplot(2,3,6);
plot(1:24,sum(par_tropt.tr.shap.item_shap_supp(:,:)'));hold on;
plot(1:24,sum(par_ssopt.tr.shap.item_shap_supp(:,:)'));hold on;
plot(1:24,sum(data_all_shap{1}.shap.item_shap_supp(:,:)'),'LineStyle','--');hold on;
plot(1:24,sum(data_all_shap{2}.shap.item_shap_supp(:,:)'),'LineStyle','--');hold on;
plot(1:24,sum(data_all_shap{3}.shap.item_shap_supp(:,:)'),'LineStyle','--');hold on;
plot(1:24,sum(data_all_shap{4}.shap.item_shap_supp(:,:)'),'LineStyle','--');hold on;
plot(1:24,sum(data_all_shap{5}.shap.item_shap_supp(:,:)'),'LineStyle','--');hold on;
title("all 5", 'FontSize',8)
sgtitle("supp shap", 'FontSize',14)

figure('Color','white', 'Position', [100 100 600 400])
for i = 1:5
subplot(2,3,i);

plot(1:24,par_tropt.tr.shap.item_shap_var(:,i));hold on;
plot(1:24,par_ssopt.tr.shap.item_shap_var(:,i));hold on;

plot(1:24,data_all_shap{1}.shap.item_shap_var(:,i),'LineStyle','--');hold on;
plot(1:24,data_all_shap{2}.shap.item_shap_var(:,i),'LineStyle','--');hold on;
plot(1:24,data_all_shap{3}.shap.item_shap_var(:,i),'LineStyle','--');hold on;
plot(1:24,data_all_shap{4}.shap.item_shap_var(:,i),'LineStyle','--');hold on;
plot(1:24,data_all_shap{5}.shap.item_shap_var(:,i),'LineStyle','--');hold on;
title(["comp-"; num2str(i)], 'FontSize',8)
% set(gca, 'YScale', 'log'); % 关键代码：设置 y 轴为对数刻度
end
legend('tr','ss','sample 1','sample 2','sample 3','sample 4','sample 5')
subplot(2,3,6);
plot(1:24,sum(par_tropt.tr.shap.item_shap_var(:,:)'));hold on;
plot(1:24,sum(par_ssopt.tr.shap.item_shap_var(:,:)'));hold on;
plot(1:24,sum(data_all_shap{1}.shap.item_shap_var(:,:)'),'LineStyle','--');hold on;
plot(1:24,sum(data_all_shap{2}.shap.item_shap_var(:,:)'),'LineStyle','--');hold on;
plot(1:24,sum(data_all_shap{3}.shap.item_shap_var(:,:)'),'LineStyle','--');hold on;
plot(1:24,sum(data_all_shap{4}.shap.item_shap_var(:,:)'),'LineStyle','--');hold on;
plot(1:24,sum(data_all_shap{5}.shap.item_shap_var(:,:)'),'LineStyle','--');hold on;
title("all 5", 'FontSize',8)
sgtitle("supp var", 'FontSize',14)

%% 汇总所有性能散点图
figure('Color','white', 'Position', [100 100 600 400])
for j=1:num_sampls
    sample_tr=data_all_shap{j};
    %% sim all samples
    scatter(sum(sample_tr.shap.ori_Jcost),sample_tr.shap.ori_Jsupp,'b', 'filled');hold on
end
legend('samples')
scatter(sum(par_tropt.tr.shap.ori_Jcost),par_tropt.tr.shap.ori_Jsupp,'g', 'filled');hold on
scatter(sum(par_ssopt.tr.shap.ori_Jcost),par_ssopt.tr.shap.ori_Jsupp,'r', 'filled');hold on
scatter(sum(par_ss3stage.tr.shap.ori_Jcost),par_ss3stage.tr.shap.ori_Jsupp,'b');hold on
scatter(sum(par_ss7stage.tr.shap.ori_Jcost),par_ss7stage.tr.shap.ori_Jsupp,'g');hold on
scatter(sum(par_ss13stage.tr.shap.ori_Jcost),par_ss13stage.tr.shap.ori_Jsupp,'r');hold on
xlabel('cost');ylabel('supp');title('solution set')

figure('Color','white', 'Position', [100 100 600 400])
for j=1:num_sampls
    sample_tr=data_all_shap{j};
    %% sim all samples
    scatter(sum(sample_tr.shap.ori_Jcost),sample_tr.shap.ori_Jvar,'b', 'filled');hold on
end
legend('samples')
scatter(sum(par_tropt.tr.shap.ori_Jcost),par_tropt.tr.shap.ori_Jvar,'g', 'filled');hold on
scatter(sum(par_ssopt.tr.shap.ori_Jcost),par_ssopt.tr.shap.ori_Jvar,'r', 'filled');hold on
scatter(sum(par_ss3stage.tr.shap.ori_Jcost),par_ss3stage.tr.shap.ori_Jvar,'b');hold on
scatter(sum(par_ss7stage.tr.shap.ori_Jcost),par_ss7stage.tr.shap.ori_Jvar,'g');hold on
scatter(sum(par_ss13stage.tr.shap.ori_Jcost),par_ss13stage.tr.shap.ori_Jvar,'r');hold on
xlabel('cost');ylabel('var');title('solution set')

figure('Color','white', 'Position', [100 100 600 400])
for j=1:num_sampls
    sample_tr=data_all_shap{j};
    %% sim all samples
    scatter(sample_tr.shap.ori_Jsupp,sample_tr.shap.ori_Jvar,'b', 'filled');hold on
end
legend('samples')
scatter(par_tropt.tr.shap.ori_Jsupp,par_tropt.tr.shap.ori_Jvar,'g', 'filled');hold on
scatter(par_ssopt.tr.shap.ori_Jsupp,par_ssopt.tr.shap.ori_Jvar,'r', 'filled');hold on
scatter(par_ss3stage.tr.shap.ori_Jsupp,par_ss3stage.tr.shap.ori_Jvar,'b');hold on
scatter(par_ss7stage.tr.shap.ori_Jsupp,par_ss7stage.tr.shap.ori_Jvar,'g');hold on
scatter(par_ss13stage.tr.shap.ori_Jsupp,par_ss13stage.tr.shap.ori_Jvar,'r');hold on
xlabel('supp');ylabel('var');title('solution set')

%% 建立决策树，形成规则筛选，模拟实现动态调整（带有一定随机性的决策生成）
% 让shap建立决策树，将决策向tr opt推动（强调cost）；当然也可以向大mass推动。
% 如何实现，观察shap的分布。怎么实现这一过程？
% 认为shap描述了动态过程中让mass  cost指标变化的方向和相对的贡献度大小；
% 希望某一个值小，则向negative推进；希望某一个值大，则向positive推进；
% 23个决策时序的tree：
% in：当前时刻的v1-v5;v1'-v5'（代表历史的信息） ：10个输入特征
% out：positive negative （global）；多标签则分级处理 ：2*n_level种类别 n_level直接选4
% 得到处理样本的基准值
k_train=10; %[5 8 10 12 15] ---24(tree) ---4(level)
tree_used_step=1;% [1 2 3 4 5 6] ---k=10 ---4(level)
% for level_lim=[1 2 3 4]
trees_id=[1:tree_used_step:23 24];
level_lim=4; % [1 2 3 4]
%% 获取训练集的std 和mean信息
load(['shap_src\datastd_all_shap_' num2str(k_train) '.mat'])
for i=1:num_sampls
    shap_cc(i,:,:)=data_all_shap{i}.shap.cc(2:end,:);
    shap_dcc(i,:,:)=data_all_shap{i}.shap.m_dcc_every(2:end,:);
    % 需要做norm处理，所处理的基准是已知的ss值的每一个位置的均值
    shap_cost_norm(i,:)=mean((data_all_shap{i}.shap.item_shap_cost(:,:)-mean_cost)./std_cost,2);
    shap_supp_norm(i,:)=mean((data_all_shap{i}.shap.item_shap_supp(:,:)-mean_supp)./std_supp,2);
    shap_var_norm(i,:)=mean((data_all_shap{i}.shap.item_shap_var(:,:)-mean_var)./std_var,2);
    shap_Jcost(i)=mean(data_all_shap{i}.shap.ori_Jcost);
    shap_Jsupp(i)=data_all_shap{i}.shap.ori_Jsupp;
    shap_Jvar(i)=data_all_shap{i}.shap.ori_Jvar;
end

scores_all=[];
scores_multiX_all=[];
trees={};
for i=1:24
    for j=1:num_sampls
        for v=1:3 % cost supp var
        load(['shap_src\data\ctree_' num2str(i) '_m' num2str(v) '_ls' num2str(k_train) '.mat'],'tree')
        trees{i,j,v}=tree;
        end
    end
end
tic
for j=1:num_sampls
    % 取出tree的进口特征：v v'
    % shap_cc(i,:,:)=data_all_shap{i}.shap.cc(2:end,:);
    % shap_dcc(i,:,:)=data_all_shap{i}.shap.m_dcc_every(2:end,:);
    scores_multiX=[0,0,0];
    scores=[0,0,0];
    for v=1:3 % cost supp var
        for i=trees_id % 1-24内的时间步
            x_this=squeeze(shap_cc(j,i,:));
            dx_this=squeeze(shap_dcc(j,i,:));
            tree=trees{i,j,v};
            sc_this=predict(tree, [x_this; dx_this]');
            sc_this=str2num(sc_this{:});
            if sc_this>level_lim
                sc_this=level_lim;
            end
            scores_multiX(v)=scores_multiX(v)+(sc_this)*mean(x_this);
            scores(v)=scores(v)+(sc_this);
        end
    end
    scores_all=[scores_all; scores];scores_multiX_all=[scores_multiX_all; scores_multiX];
end
toc
% save(['shap_src\data\scores_all' 'k' num2str(k_train) 't' num2str(tree_used_step) 'l' num2str(level_lim) '_test.mat'],'scores_all')
% save(['shap_src\data\scores_all_multiX_all' 'k' num2str(k_train) 't' num2str(tree_used_step) 'l' num2str(level_lim) '_test.mat'],'scores_multiX_all')
% end
load(['shap_src\data\scores_all' 'k' num2str(k_train) 't' num2str(tree_used_step) 'l' num2str(level_lim) '_test.mat'])
load(['shap_src\data\scores_all_multiX_all' 'k' num2str(k_train) 't' num2str(tree_used_step) 'l' num2str(level_lim) '_test.mat'])

%% 测试集
%% 根据指标需求ranking,是否符合规律，符合后 加入：进口压力的随机性；重跑case绘制shap-ranking后的指标和过程结果图
%% 先对比一下训练集上shap评分和指标的一致性
score1=sum(shap_cost_norm,2);
score2=sum(shap_supp_norm,2);
score3=sum(shap_var_norm,2);
figure;scatter(score1,shap_Jcost);
figure;scatter(score2,shap_Jsupp);
figure;scatter(score3,shap_Jvar);

%% top
top=5;
%% 将top5的case取出绘制总性能图和v-v'图的对比
% 取出后 5个 top 都做总性能图 与 random sample 5个（前5）；tr ss ss-stage3 5 7 总共是 15 种方法
% 3 个指标的top 3张图指标；3张图指标变化曲线；3张图的v-v'
%% cost取top
[top_Values0, top_Indices0] = mink(shap_Jcost', top);
% 一定要保证的是正比例关系；基于shap+tree的泛化搜索才有意义！！！
[top_Values1, top_Indices1] = mink(scores_multiX_all(:,1), top);
[top_Values2, top_Indices2] = mink(scores_all(:,1), top);
% 画出来：
figure('Color','white', 'Position', [100 100 600 400])
for j=1:num_sampls
    sample_tr=data_all_shap{j};
    %% sim all samples
    scatter(sum(sample_tr.shap.ori_Jcost),sample_tr.shap.ori_Jsupp,'b');hold on
end
for j=top_Indices0'
    sample_tr=data_all_shap{j};
    scatter(sum(sample_tr.shap.ori_Jcost),sample_tr.shap.ori_Jsupp,'b', 'filled');hold on
end
for j=top_Indices1'
    sample_tr=data_all_shap{j};
    scatter(sum(sample_tr.shap.ori_Jcost),sample_tr.shap.ori_Jsupp,'k', 'filled');hold on
end
for j=top_Indices2'
    sample_tr=data_all_shap{j};
    scatter(sum(sample_tr.shap.ori_Jcost),sample_tr.shap.ori_Jsupp,'y', 'filled');hold on
end
scatter(sum(par_tropt.tr.shap.ori_Jcost),par_tropt.tr.shap.ori_Jsupp,'g', 'filled');hold on
scatter(sum(par_ssopt.tr.shap.ori_Jcost),par_ssopt.tr.shap.ori_Jsupp,'r', 'filled');hold on
xlabel('cost');ylabel('supp');title('solution set')

%% supp取top
[top_Values0, top_Indices0] = maxk(shap_Jsupp', top);
% 一定要保证的是正比例关系；基于shap+tree的泛化搜索才有意义！！！
[top_Values1, top_Indices1] = maxk(scores_multiX_all(:,2), top);
[top_Values2, top_Indices2] = maxk(scores_all(:,2), top);
% 画出来：
figure('Color','white', 'Position', [100 100 600 400])
for j=1:num_sampls
    sample_tr=data_all_shap{j};
    %% sim all samples
    scatter(sum(sample_tr.shap.ori_Jcost),sample_tr.shap.ori_Jsupp,'b');hold on
end
for j=top_Indices0'
    sample_tr=data_all_shap{j};
    scatter(sum(sample_tr.shap.ori_Jcost),sample_tr.shap.ori_Jsupp,'b', 'filled');hold on
end
for j=top_Indices2'
    sample_tr=data_all_shap{j};
    scatter(sum(sample_tr.shap.ori_Jcost),sample_tr.shap.ori_Jsupp,'y', 'filled');hold on
end
scatter(sum(par_tropt.tr.shap.ori_Jcost),par_tropt.tr.shap.ori_Jsupp,'g', 'filled');hold on
scatter(sum(par_ssopt.tr.shap.ori_Jcost),par_ssopt.tr.shap.ori_Jsupp,'r', 'filled');hold on
scatter(sum(par_ss3stage.tr.shap.ori_Jcost),par_tropt.tr.shap.ori_Jsupp,'r');hold on
scatter(sum(par_ss7stage.tr.shap.ori_Jcost),par_ssopt.tr.shap.ori_Jsupp,'r');hold on
scatter(sum(par_ss13stage.tr.shap.ori_Jcost),par_ssopt.tr.shap.ori_Jsupp,'r');hold on
xlabel('cost');ylabel('supp');title('solution set')

%% cost取top_
[top_Values0, top_Indices0] = mink(shap_Jvar', top);
% 一定要保证的是正比例关系；基于shap+tree的泛化搜索才有意义！！！
[top_Values1, top_Indices1] = mink(scores_multiX_all(:,3), top);
[top_Values2, top_Indices2] = mink(scores_all(:,3), top);
% 水平相似；---改成箱型图类似
figure('Color','white', 'Position', [100 100 600 400])

scatter(-1,sum(par_tropt.tr.shap.ori_Jvar),'g', 'filled');hold on
scatter(0,sum(par_ssopt.tr.shap.ori_Jvar),'r', 'filled');hold on

for j=top_Indices0'
    sample_tr=data_all_shap{j};
    scatter(1,sum(sample_tr.shap.ori_Jvar),'b', 'filled');hold on
end
for j=top_Indices1'
    sample_tr=data_all_shap{j};
    scatter(2,sum(sample_tr.shap.ori_Jvar),'k', 'filled');hold on
end
for j=top_Indices2'
    sample_tr=data_all_shap{j};
    scatter(3,sum(sample_tr.shap.ori_Jvar),'y', 'filled');hold on
end
for j=1:num_sampls
    sample_tr=data_all_shap{j};
    %% sim all samples
    scatter(4,sum(sample_tr.shap.ori_Jvar),'b');hold on
end

%% 设计两种场景：1 opt supp 2 opt cost s.t. var的scoring在中位数之前 
% 2个场景的top 2张图指标；2张图指标变化曲线；2张图的v-v'
% 先取出两个场景的索引


%% 如果是蒙特卡洛，最终可以用概率分布的形式呈现
aaaaa=1;





