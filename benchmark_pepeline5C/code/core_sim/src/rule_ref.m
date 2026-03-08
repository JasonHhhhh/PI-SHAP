%% 读取网络结构、稳态优化参数等
% fnameid=fopen('model_folder.txt');
% fname = textscan(fnameid, '%s');
% fclose(fnameid);
% par.mfolder=fname{1}{1};
% par=options_input(par);
%
% % 读取仿真模型和优化算法的参数，不涉及气网的结构，全部返回到par中，在仿真中则不应用优化参数，仅仿真
% par=options_input(par);
%
% %load static model (nodes, pipes, comps, gnodes) from xls fliles，
% % 读取稳态网络对象，把所有信息存到txt中，若txt存在若存在txt则从新的xls读取，没有xls则从csv，在保存成新的txt
% if(exist([par.mfolder '\input_network.txt'])~=2 || par.out.update_from_xls==1)
%     if(exist([par.mfolder '\input_network_nodes.xls'])==2 || exist([par.mfolder '\input_network_nodes.xlsx'])==2), [par.ss.n0]=gas_model_reader_xls(par); else
%     [par.ss.n0]=gas_model_reader_csv(par); end
% end
%
% %first input check
% par=check_input_1(par);
% if(par.flag==1), disp(par.message), return; end
%
% %% 稳态ss优化
% if(par.out.doss==1 || par.out.dosim==1)
% % 单位转换 保存一个针对ss优化的气网对象数组par.ss.n0---划分网格之前的网格结构对象
% [par.ss.n0]=gas_model_reader_new(par.mfolder);   % load data from text file 从新保存的txt中
% % 再次check对象是否过大
% if(par.ss.n0.nv>par.out.maxnv || par.ss.n0.ne>par.out.maxne || par.ss.n0.nc>par.out.maxng || par.ss.n0.ng>par.out.maxng), return; end
%
% %if(par.ss.n0.nv>20), return; end;
% % 划分求解网格后重新定义nodes等
% [par.ss.n]=gas_model_reconstruct_new(par.ss.n0,par.tr.lmax,1);
%
% %optimization parameters
% par.ss.m.cdw=50;                      %comp. ratio derivative penalty scale
% par.ss.m.ddw=50;                      %flex demand derivative penalty scale
% par.ss.m.odw=100;                     %objective scale
% par.ss.m.maxiter=400;                 %
% par.ss.m.opt_tol=1e-6;                %
%
% %model specifications
% % 归一化、进一步的参数定义、定义模型的一些细节、约束等
% [par.ss]=model_spec(par.ss);
%
% %demand function specifications
% par.ss=econ_spec(par.ss,par.mfolder);
%
% % Solve optimization
% [par.ss_start]=static_opt_base_ends(par.ss,1); %起点
% par.ss=par.ss_start;...同上
% [par.ss_terminal]=static_opt_base_ends(par.ss,-1); %终点
% [par]=process_output_ss_nofd(par);
% [par]=process_output_ss_terminal_nofd(par);
% [par]=process_output_ss_start_nofd(par);
%
% %exit if not solved
% if(par.ss.ip_info.status~=0), disp('Steady state optimization not feasible'),
%     fid=fopen([par.mfolder '\output_log.txt'],'w');
%     fprintf(fid,['Steady-state solve status: ' num2str(par.ss.ip_info.status) '\n']);
%     fclose(fid);
% end
%
% %process steady-state output 后处理稳态优化的结果
% % if(par.out.steadystateonly==1), [par]=process_output_ss(par); if(par.out.intervals_out>0), gas_out_plots_i(par); end; return; end
% % if(par.out.ss_check_exit==1), return; end
% end
%
% %% 从ss优化结果出发，以tr里给出的边界信息，开始仿真
%
% % 定义tr.n n0 容纳tran_sim网络对象
% [par.tr.n0]=gas_model_reader_new(par.mfolder);                   % load data from text file
% if(par.ss.n0.nv>par.out.maxnv || par.ss.n0.ne>par.out.maxne || par.ss.n0.nc>par.out.maxng || par.ss.n0.ng>par.out.maxng), return; end
%
% [par.tr.n]=gas_model_reconstruct_new(par.tr.n0,par.tr.lmax,1);
%
% %model specifications
% [par.tr]=model_spec(par.tr);
%
% %demand function specifications
% par.tr=econ_spec(par.tr,par.mfolder); % 实际以上准备工作和ss中的东西完全一样，只不过为了区分
%
% % 准备：setup 0：边界条件：气源压力、出口流量、压缩机压比
%
% par.sim=par.ss;
% par.sim.rtol0=1e-2; par.sim.atol0=1e-1;
% par.sim.rtol1=1e-3; par.sim.atol1=1e-2;
% par.sim.rtol=1e-5; par.sim.atol=1e-3;  %error tolerances for simulation
% %par.sim.startup=1/4.2;     %startup time (fraction of horizon)
% par.sim.startup=1/8;        %startup time (fraction of horizon)
% par.sim.nperiods=2;         %number of periods after startup
% par.sim.solsteps=24*6*2;        %solution steps per period
% par.sim.fromss=1;
%
% % 压缩机动作
% % load('E:\working\Matlab_prjs\Gas_Line_case\src\ccccc.mat');
% % 1.60000000000000
% % 1.18399927993301
% % 1.16290675532091
% % 1.10910660796442
% % 1.00097383792682
%
% % 1.60000000000000
% % 1.22613672921252
% % 1.20293731120827
% % 1.20293731182393
% % 1.00776213532559
%
% cc0_start = par.ss_start.cc0(:,1);
% [all_n_pr,~] =size(cc0_start);
% cc0_terminal = par.ss_terminal.cc0(:,1);
% par.id_v = find(abs(cc0_start - cc0_terminal)>=0.005);
% par.id_uv = find(abs(cc0_start - cc0_terminal)<0.005);
% cc0_start_iterp = cc0_start(par.id_v,:);
% cc0_terminal_iterp = cc0_terminal(par.id_v,:);
% % interval_pr = cc0_terminal_iterp-cc0_start_iterp;
% num_cpoints=5;
% upbound=zeros(4,5);
% lowbound=zeros(4,5);
% for i=1:length(cc0_start_iterp)% 四个压缩机 五个插值点
%     centor = linspace(cc0_start_iterp(i),cc0_terminal_iterp(i),7); % 区间中心
%     centor = centor(2:end-1);
%     interval = centor(2)-centor(1); % 基本区间长度
%     upbound(i,:) = centor+interval*0.49;
%     lowbound(i,:) = centor-interval*0.49;
% end
% interval_pr=upbound-lowbound;
%
%
% % id_1 = find(abs(interval_pr)>=0.005 & abs(interval_pr)<0.02);
% % id_2 = find(abs(interval_pr)>=0.02 & abs(interval_pr)<0.1);
% % id_3 = find(abs(interval_pr)>=0.1 & abs(interval_pr)<0.5);
% %% 采样，并根据前后端ss优化结果，形成压缩机动作序列
% n_control_tps = 5;
% k = 10;
% [n_pr,~] = size(par.id_v);
% doe = lhsdesign(500,n_pr*n_control_tps);
% doe = reshape(doe,500,n_pr,n_control_tps);
% finalv_doe = zeros(500,n_pr,n_control_tps);
%
% for i=1:100
%     a = reshape(doe(i,:,:),n_pr,n_control_tps);
%     b = a.*interval_pr+lowbound;
%     finalv_doe(i,:,:)=b
% end
%
%
%
% % 进行spline插值
% n_control_tps=25;
% all_data.('id_v')=par.id_v;
% all_data.('id_uv')=par.id_uv;
% plotpos=[20,20,450,450];
% for i=1:500
%     cc0 = zeros(all_n_pr,5+2);
%     cc0_mid = reshape(finalv_doe(i,:,:),n_pr,5); % 5个插值点
%     cc0_v_iterp = [cc0_start_iterp,cc0_mid, cc0_terminal_iterp];
%     cc0(par.id_v,:)=cc0_v_iterp;
%     cc0_uv_iterp = repmat(cc0_start(par.id_uv),1,5+2);
%     cc0(par.id_uv,:)=cc0_uv_iterp;
%     % 插值成为25h长度
%     xxx = linspace(1,n_control_tps,7)';
%     xx_new = linspace(1,n_control_tps,25)';
%     yi = zeros(5,25);
%     for iii=1:5
%         yi(iii,:)=spline(xxx,cc0(iii,:),xx_new);
%     end
%     cc0=yi;
%     cc0(cc0<=1)=1;
%     f1=figure(1); clf
%     set(f1,'position',plotpos,'Color',[1 1 1]);
%     subaxis(1,1,1,'MarginLeft',0.1,'SpacingHoriz',0.05,'MarginRight',0.1),
%     plot(xx_new-1,cc0(2:end,:),'LineWidth',3), axis('tight'), xlabel('Time(h)')
%     title('Compressor ratio','fontweight','bold')
%     legend('Comp_2#','Comp_3#','Comp_4#','Comp_5#');
%
% %     [par]=tran_sim_setup_0(par,cc0);
% %     % execute simulation
% %     [par.sim]=tran_sim_base_flat_noextd(par.sim);
% %     [par]=process_output_tr_nofd(par);
%     all_data.(['x',num2str(i)])=cc0;
% %     all_data.(['y',num2str(i)])=par;
% %     all_data.(['m_cost',num2str(i)])=par.tr.m_cost;
% %     all_data.(['m_var',num2str(i)])=par.tr.m_var;
% % %   all_data.(['m_ts',num2str(i)])=par.tr.m_ts;
% %     disp(['simulating ' ' sample... ' num2str(i) '..................................' ])
% end
% %     shap_f = @(cc)tran_sim_shap(cc,par); % 输入cc 5*25 = 125 展开
% %     Xall=zeros(k*n_pr*n_control_tps,25*all_n_pr); % 注意对应的顺序
% %     for i=1:k*n_pr*n_control_tps
% %         Xall(i,:)=reshape(all_data.(['x',num2str(i)]),1,125);
% %     end
% %     shap_explainer = shapley(shap_f,Xall);
% %     ex = fit(shap_explainer,Xall(1,:));
%
% % 序列树模型构建。MC测试。两种对象。
%
% % 滚动仿真，3*5一个动作？，套用强化学习智能体（可以根据对象变动，类似这种管理），开写。R里边只有一项，约束；
% % 转供对象四台压缩机，ADMM优化case搞定。开写。
% % 如何调用构建Python或matlab的树
%
%
% %% 后处理，作图
% % % 保存shap生成tree的数据集
% % par.id_v=all_data.('id_v');
% % par.id_uv=all_data.('id_uv');
% % shap_cost = zeros(1000,25,4);
% % shap_var = zeros(1000,25,4);
% % shap_mass = zeros(1000,25,4);
% % shap_supp = zeros(1000,25,4);
% % shap_error = zeros(1000,4,4);
% x_all = zeros(1000,25,4);
% for i=1:1000
%     xi = all_data.(['x',num2str(i)])';
%     xi = xi(:,par.id_v);
%     x_all(i,:,:)=xi;
% %     yi = all_data.(['y',num2str(i)]);
% %     shap_cost(i,:,:)=yi.shap_cost(:,par.id_v);
% %     shap_var(i,:,:)=yi.shap_var(:,par.id_v);
% %     shap_mass(i,:,:)=yi.shap_mass(:,par.id_v);
% %     shap_supp(i,:,:)=yi.shap_supp(:,par.id_v); % 与以上不同
% %     shap_error(i,:,:)=yi.shap_error(:,par.id_v);
% end
%
%
% [par]=process_output_tr_nofd(par);


%% 利用树得到规则
% 可视化、得到规则、验证规则

% 先load数据
% 处理X dX
load('D:\working\Matlab_prjs\Gas_Line_case\src\SHAPtree_data_0126.mat');
load('D:\working\Matlab_prjs\Gas_Line_case\src\SHAPtree_data_ref1.mat');
load('D:\working\Matlab_prjs\Gas_Line_case\src\SHAPtree_data_ref2.mat');
load('D:\working\Matlab_prjs\Gas_Line_case\src\SHAPtree_data_ref3.mat');
x_all=SHAPtree_data_0126.x_all;
cost=SHAPtree_data_0126.cost;
mass=SHAPtree_data_0126.mass;
var=SHAPtree_data_0126.var;
[samp_num,~] = size(mass);
identity_x = x_all(:,1:end-1,:);
diff_x = zeros(size(identity_x));
for i=1:samp_num
    for j=1:4
        x=x_all(i,:,j);
        diff0_x=diff(x);
        diff_x(i,:,j)=diff0_x';
    end
end
diff_x = diff_x.*240;
%再load模型
% 一个m 一个level

ms={cost,mass,var};
ids_ref1_ay=cell(100);
ids_ref2_ay=cell(100);
ids_ref3_ay=cell(100);
n=10;
for i_mc=1:100
    ids_rand=randperm(100,n);
    ids_ref1_ay{i_mc} = ids_rand;
end
for i_mc=1:100
    ids_rand=randperm(100,n);
    ids_ref2_ay{i_mc} = ids_rand;
end
for i_mc=1:100
    ids_rand=randperm(100,n);
    ids_ref3_ay{i_mc} = ids_rand;
end

save(['data\model_mine\ids_ref1_ay' '.mat'],'ids_ref1_ay')
save(['data\model_mine\ids_ref2_ay' '.mat'],'ids_ref2_ay')
save(['data\model_mine\ids_ref3_ay' '.mat'],'ids_ref3_ay')
a=1;
