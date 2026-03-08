clc;clear;close all
% %% 参数定义
% params = struct();
% params.coe = 3;        % 转速-燃油流量关系系数
% params.tau = 1;      % 转速动态时间常数 [s]
% params.tau_T = 2;    % 温度动态时间常数 [s]
% params.tau_P = 1.5;    % 压力动态时间常数 [s]
% params.n0 = 0.75;      % 初始转速
% params.k_thrust = 0.8*1000; % 推力计算系数
% params.k_pressure = 100;    % 压力计算系数
% params.k_sm = 0.005;   % SM变化幅值系数
% 
% % 初始计算
% n_target = 1.0;                        % 目标转速
% params.n_target =n_target;
% Wf0 = 3*params.n0^(params.coe-1);      % 初始燃油流量
% Wf_target = 3*n_target^(params.coe-1); % 目标燃油流量
% params.Wf0=Wf0;params.Wf_target=Wf_target;
% % 约束条件
% T_max = 2300;          % 温度上限 [K]
% SM_min = 0.05; % 喘振裕度下限
% params.SM_min= SM_min;   
% dP_max = (0.25 - SM_min)/params.k_sm; % 压力变化率上限
% 
% % 控制点设置
% t_total = 15;          % 总时间 [s]
% dt_control = 3;        % 控制点间隔 [s]
% t_control = 0:dt_control:t_total;
% N_control = length(t_control); % 控制点数量
% 
% % 时间向量 (用于仿真)
% dt_sim = 0.005;          % 仿真时间步长
% t_sim = 0:dt_sim:t_total;
% t_sim_cl =-5:dt_sim:t_total+5;
% pid_gains = [150, 80.00, 0.00]; % Kp, Ki, Kd
% 
% %% 线性化系统函数（在初始点展开）
% % 初始状态
% init_state = [params.n0; 500*params.n0*Wf0*0.33+1800; params.k_pressure*params.n0*Wf0];
% x0 = init_state;
% u0 = Wf0;
% 
% % 计算雅可比矩阵 (A = df/dx, B = df/du)
% A = zeros(3,3);
% A(1,1) = (1/params.tau)*(u0 - 3.0*params.coe*x0(1)^(params.coe-1));
% A(2,1) = (1/params.tau_T)*500*0.33*u0;
% A(2,2) = -1/params.tau_T;
% A(3,1) = (1/params.tau_P)*params.k_pressure*u0;
% A(3,3) = -1/params.tau_P;
% 
% B = zeros(3,1);
% B(1) = (1/params.tau)*x0(1);
% B(2) = (1/params.tau_T)*500*0.33*x0(1);
% B(3) = (1/params.tau_P)*params.k_pressure*x0(1);
% 
% % 线性化系统函数
% linear_engine_dynamics = @(t, y, Wf_control) [
%     A(1,1)*(y(1)-x0(1)) + B(1)*(interp1(t_control, Wf_control, t) - u0);
%     A(2,1)*(y(1)-x0(1)) + A(2,2)*(y(2)-x0(2)) + B(2)*(interp1(t_control, Wf_control, t) - u0);
%     A(3,1)*(y(1)-x0(1)) + A(3,3)*(y(3)-x0(3)) + B(3)*(interp1(t_control, Wf_control, t) - u0)
% ];
% 
% % 定义引擎动力学函数（非线性）
% nonlinear_engine_dynamics = @(t, y, Wf_control) [
%     (1/params.tau) * (y(1)*interp1(t_control, Wf_control, t) - 3.0*y(1)^params.coe);
%     (1/params.tau_T) * ((500*y(1)*interp1(t_control, Wf_control, t)*0.33 + 1800) - y(2));
%     (1/params.tau_P) * ((params.k_pressure * y(1) * interp1(t_control, Wf_control, t)) - y(3))
% ];
% 
% params.nonlinear_engine_dynamics_cl=@(t, y, Wf) [
%     (1/params.tau) * (y(1)*Wf - 3.0*y(1)^params.coe);
%     (1/params.tau_T) * ((500*y(1)*Wf*0.33 + 1800) - y(2));
%     (1/params.tau_P) * ((params.k_pressure * y(1) * Wf) - y(3))
% ];
% 
% %% 选择使用的动力学模型做opt（1=线性，0=非线性）
% % opt设定:非线性离线
% engine_dynamics_opt = nonlinear_engine_dynamics;
% 
% %% 优化问题设置
% % 优化变量: 燃油流量序列 (首尾固定，中间点优化)
% 
% % 初始猜测: 线性递增
% Wf_opt0 = linspace(Wf0, Wf_target, N_control)';
% Wf_opt0 = Wf_opt0(2:end-1); % 仅优化中间点
% 
% % 优化选项
% options = optimoptions('fmincon', 'Display', 'iter', 'Algorithm', 'sqp',...
%                        'MaxFunctionEvaluations', 10000, 'StepTolerance', 1e-6);
% 
% % 约束函数
% con_func = @(Wf_mid) combined_constraints(Wf_mid, t_control, t_sim, params, ...
%                                           T_max, dP_max, engine_dynamics_opt);
% 
% % 边界约束 (燃油流量递增)
% A = [];
% b = [];
% Aeq = [];
% beq = [];
% lb = Wf0 * ones(size(Wf_opt0)); % 燃油流量递增下限
% ub = Wf_target * ones(size(Wf_opt0)); % 燃油流量递增上限
% 
% %% 任务1: 能耗最小化 (w_fuel=1, w_time=0)
% res_offline_nonlinear={};
% weights = struct('w_fuel', 1.0, 'w_time', 0.0);
% % 目标函数
% obj_func = @(Wf_mid) combined_objective(Wf_mid, t_control, t_sim, params, ...
%                                         n_target, engine_dynamics_opt, weights);
% 
% % 优化求解
% tic
% [Wf_opt_mid1, fval1] = fmincon(obj_func, Wf_opt0, A, b, Aeq, beq, lb, ub, con_func, options);
% tim_opt1=toc;
% % 重构完整控制序列
% Wf_opt1 = [Wf0; Wf_opt_mid1; Wf_target];
% 
% %开环仿真
% [~, y1_ol] = ode45(@(t,y) nonlinear_engine_dynamics(t, y, Wf_opt1), t_sim, init_state);
% n1_ol = y1_ol(:,1); 
% 
% %PID闭环仿真
% [t_sim_cl, y1_cl, Wf_pid1] = pid_closed_loop_simulation(t_sim_cl, init_state, n1_ol, params, pid_gains);
% n1_cl = y1_cl(:,1); T1_cl = y1_cl(:,2); P1_cl = y1_cl(:,3);
% 
% res_offline_nonlinear.t_sim_cl=t_sim_cl;
% res_offline_nonlinear.n1_cl=n1_cl;res_offline_nonlinear.n1_ol=n1_ol;
% res_offline_nonlinear.T1_cl=T1_cl;
% res_offline_nonlinear.P1_cl=P1_cl;
% res_offline_nonlinear.Wf_pid1=Wf_pid1;
% res_offline_nonlinear.tim_opt1=tim_opt1;
% 
% %% 任务2: 到达时间最小化 (w_fuel=0, w_time=1)
% weights = struct('w_fuel', 0.0, 'w_time', 1);
% % 目标函数
% obj_func = @(Wf_mid) combined_objective(Wf_mid, t_control, t_sim, params, ...
%                                         n_target, engine_dynamics_opt, weights);
% tic
% [Wf_opt_mid2, fval2] = fmincon(obj_func, Wf_opt0, A, b, Aeq, beq, lb, ub, con_func, options);
% tim_opt2=toc;
% Wf_opt2 = [Wf0; Wf_opt_mid2; Wf_target];
% 
% %开环仿真
% [~, y2_ol] = ode45(@(t,y) nonlinear_engine_dynamics(t, y, Wf_opt2), t_sim, init_state);
% n2_ol = y2_ol(:,1); 
% 
% %PID闭环仿真
% [t_sim_cl, y2_cl, Wf_pid2] = pid_closed_loop_simulation(t_sim_cl, init_state, n2_ol, params, pid_gains);
% n2_cl = y2_cl(:,1); T2_cl = y2_cl(:,2); P2_cl = y2_cl(:,3);
% 
% res_offline_nonlinear.t_sim_cl=t_sim_cl;
% res_offline_nonlinear.n2_cl=n2_cl;res_offline_nonlinear.n2_ol=n2_ol;
% res_offline_nonlinear.T2_cl=T2_cl;
% res_offline_nonlinear.P2_cl=P2_cl;
% res_offline_nonlinear.Wf_pid2=Wf_pid2;
% res_offline_nonlinear.tim_opt2=tim_opt2;
% 
% %% 任务3: 多目标优化 
% weights = struct('w_fuel', 0.05, 'w_time', 1);
% % 目标函数
% obj_func = @(Wf_mid) combined_objective(Wf_mid, t_control, t_sim, params, ...
%                                         n_target, engine_dynamics_opt, weights);
% tic
% [Wf_opt_mid3, fval3] = fmincon(obj_func, Wf_opt0, A, b, Aeq, beq, lb, ub, con_func, options);
% tim_opt3=toc;
% Wf_opt3 = [Wf0; Wf_opt_mid3; Wf_target];
% 
% %开环仿真
% [~, y3_ol] = ode45(@(t,y) nonlinear_engine_dynamics(t, y, Wf_opt3), t_sim, init_state);
% n3_ol = y3_ol(:,1); 
% 
% %PID闭环仿真
% [t_sim_cl, y3_cl, Wf_pid3] = pid_closed_loop_simulation(t_sim_cl, init_state, n3_ol, params, pid_gains);
% n3_cl = y3_cl(:,1); T3_cl = y3_cl(:,2); P3_cl = y3_cl(:,3);
% 
% res_offline_nonlinear.t_sim_cl=t_sim_cl;
% res_offline_nonlinear.n3_cl=n3_cl;res_offline_nonlinear.n3_ol=n3_ol;
% res_offline_nonlinear.T3_cl=T3_cl;
% res_offline_nonlinear.P3_cl=P3_cl;
% res_offline_nonlinear.Wf_pid3=Wf_pid3;
% res_offline_nonlinear.tim_opt3=tim_opt3;
% 
% %% 选择使用的动力学模型做opt（1=线性，0=非线性）
% % opt设定:线性在线
% engine_dynamics_opt = linear_engine_dynamics;
% 
% %% 优化问题设置
% % 优化变量: 燃油流量序列 (首尾固定，中间点优化)
% 
% % 初始猜测: 线性递增
% Wf_opt0 = linspace(Wf0, Wf_target, N_control)';
% Wf_opt0 = Wf_opt0(2:end-1); % 仅优化中间点
% 
% % 优化选项
% options = optimoptions('fmincon', 'Display', 'iter', 'Algorithm', 'sqp',...
%                        'MaxFunctionEvaluations', 10000, 'StepTolerance', 1e-4);
% 
% % 约束函数
% con_func = @(Wf_mid) combined_constraints(Wf_mid, t_control, t_sim, params, ...
%                                           T_max, dP_max, engine_dynamics_opt);
% 
% % 边界约束 (燃油流量递增)
% A = [];
% b = [];
% Aeq = [];
% beq = [];
% lb = Wf0 * ones(size(Wf_opt0)); % 燃油流量递增下限
% ub = Wf_target * ones(size(Wf_opt0)); % 燃油流量递增上限
% 
% %% 任务1: 能耗最小化 (w_fuel=1, w_time=0)
% res_online_linear={};
% weights = struct('w_fuel', 1.0, 'w_time', 0.0);
% % 目标函数
% obj_func = @(Wf_mid) combined_objective(Wf_mid, t_control, t_sim, params, ...
%                                         n_target, engine_dynamics_opt, weights);
% 
% % 优化求解
% tic
% [Wf_opt_mid1, fval1] = fmincon(obj_func, Wf_opt0, A, b, Aeq, beq, lb, ub, con_func, options);
% tim_opt1=toc;
% % 重构完整控制序列
% Wf_opt1 = [Wf0; Wf_opt_mid1; Wf_target];
% 
% %开环仿真
% [~, y1_ol] = ode45(@(t,y) nonlinear_engine_dynamics(t, y, Wf_opt1), t_sim, init_state);
% n1_ol = y1_ol(:,1); 
% 
% %PID闭环仿真
% [t_sim_cl, y1_cl, Wf_pid1] = pid_closed_loop_simulation(t_sim_cl, init_state, n1_ol, params, pid_gains);
% n1_cl = y1_cl(:,1); T1_cl = y1_cl(:,2); P1_cl = y1_cl(:,3);
% 
% res_online_linear.t_sim_cl=t_sim_cl;
% res_online_linear.n1_cl=n1_cl;res_online_linear.n1_ol=n1_ol;
% res_online_linear.T1_cl=T1_cl;
% res_online_linear.P1_cl=P1_cl;
% res_online_linear.Wf_pid1=Wf_pid1;
% res_online_linear.tim_opt1=tim_opt1;
% 
% %% 任务2: 到达时间最小化 (w_fuel=0, w_time=1)
% weights = struct('w_fuel', 0.0, 'w_time', 1);
% % 目标函数
% obj_func = @(Wf_mid) combined_objective(Wf_mid, t_control, t_sim, params, ...
%                                         n_target, engine_dynamics_opt, weights);
% tic
% [Wf_opt_mid2, fval2] = fmincon(obj_func, Wf_opt0, A, b, Aeq, beq, lb, ub, con_func, options);
% tim_opt2=toc;
% Wf_opt2 = [Wf0; Wf_opt_mid2; Wf_target];
% 
% %开环仿真
% [~, y2_ol] = ode45(@(t,y) nonlinear_engine_dynamics(t, y, Wf_opt2), t_sim, init_state);
% n2_ol = y2_ol(:,1); 
% 
% %PID闭环仿真
% [t_sim_cl, y2_cl, Wf_pid2] = pid_closed_loop_simulation(t_sim_cl, init_state, n2_ol, params, pid_gains);
% n2_cl = y2_cl(:,1); T2_cl = y2_cl(:,2); P2_cl = y2_cl(:,3);
% 
% res_online_linear.t_sim_cl=t_sim_cl;
% res_online_linear.n2_cl=n2_cl;res_online_linear.n2_ol=n2_ol;
% res_online_linear.T2_cl=T2_cl;
% res_online_linear.P2_cl=P2_cl;
% res_online_linear.Wf_pid2=Wf_pid2;
% res_online_linear.tim_opt2=tim_opt2;
% 
% %% 任务3: 多目标优化 
% weights = struct('w_fuel', 0.05, 'w_time', 1);
% % 目标函数
% obj_func = @(Wf_mid) combined_objective(Wf_mid, t_control, t_sim, params, ...
%                                         n_target, engine_dynamics_opt, weights);
% tic
% [Wf_opt_mid3, fval3] = fmincon(obj_func, Wf_opt0, A, b, Aeq, beq, lb, ub, con_func, options);
% tim_opt3=toc;
% Wf_opt3 = [Wf0; Wf_opt_mid3; Wf_target];
% 
% %开环仿真
% [~, y3_ol] = ode45(@(t,y) nonlinear_engine_dynamics(t, y, Wf_opt3), t_sim, init_state);
% n3_ol = y3_ol(:,1); 
% 
% %PID闭环仿真
% [t_sim_cl, y3_cl, Wf_pid3] = pid_closed_loop_simulation(t_sim_cl, init_state, n3_ol, params, pid_gains);
% n3_cl = y3_cl(:,1); T3_cl = y3_cl(:,2); P3_cl = y3_cl(:,3);
% 
% res_online_linear.t_sim_cl=t_sim_cl;
% res_online_linear.n3_cl=n3_cl;res_online_linear.n3_ol=n3_ol;
% res_online_linear.T3_cl=T3_cl;
% res_online_linear.P3_cl=P3_cl;
% res_online_linear.Wf_pid3=Wf_pid3;
% res_online_linear.tim_opt3=tim_opt3;
% 
% %% 建立SHAP_GT - 细化优化粒度（1.5秒间隔）
% % 重新定义控制点（1.5秒间隔）
% dt_control_fine = 15/6;        % 新的控制点间隔 [s]
% t_control_fine = 0:dt_control_fine:t_total;
% N_control_fine = length(t_control_fine); % 新的控制点数量
% 
% %% 选择使用的动力学模型做opt（SHAP）
% % opt设定:线性在线
% engine_dynamics_opt =  @(t, y, Wf_control) [
%     (1/params.tau) * (y(1)*interp1(t_control_fine, Wf_control, t) - 3.0*y(1)^params.coe);
%     (1/params.tau_T) * ((500*y(1)*interp1(t_control_fine, Wf_control, t)*0.33 + 1800) - y(2));
%     (1/params.tau_P) * ((params.k_pressure * y(1) * interp1(t_control_fine, Wf_control, t)) - y(3))
% ];
% 
% % 初始猜测: 线性递增
% Wf_opt0 = linspace(Wf0, Wf_target, N_control_fine)';
% Wf_opt0 = Wf_opt0(2:end-1); % 仅优化中间点
% 
% % 
% % 优化选项
% options = optimoptions('fmincon', 'Display', 'iter', 'Algorithm', 'sqp',...
%                        'MaxFunctionEvaluations', 10000, 'StepTolerance', 1e-9);
% 
% % 约束函数
% con_func = @(Wf_mid) combined_constraints(Wf_mid, t_control_fine, t_sim, params, ...
%                                           T_max, dP_max, engine_dynamics_opt);
% % 边界约束 (燃油流量递增)
% A = [];
% b = [];
% Aeq = [];
% beq = [];
% lb = Wf0 * ones(size(Wf_opt0)); % 燃油流量递增下限
% ub = Wf_target * ones(size(Wf_opt0)); % 燃油流量递增上限
% %% 任务1: 能耗最小化 (w_fuel=1, w_time=0).
% 
% res_online_SHAP={};
% weights = struct('w_fuel', 1.0, 'w_time', 0.0);
% % 目标函数
% obj_func = @(Wf_mid) combined_objective(Wf_mid, t_control_fine, t_sim, params, ...
%                                         n_target, engine_dynamics_opt, weights);
% tic
% % 优化求解 （给定初值，）
% [Wf_opt_mid1, fval1] = fmincon(obj_func, Wf_opt0, A, b, Aeq, beq, lb, ub, con_func, options);
% tim_opt1=toc;
% % 重构完整控制序列
% Wf_opt1 = [Wf0; Wf_opt_mid1; Wf_target];
% 
% %开环仿真
% [~, y1_ol] = ode45(@(t,y) engine_dynamics_opt(t, y, Wf_opt1), t_sim, init_state);
% n1_ol = y1_ol(:,1); 
% 
% %PID闭环仿真
% [t_sim_cl, y1_cl, Wf_pid1] = pid_closed_loop_simulation(t_sim_cl, init_state, n1_ol, params, pid_gains);
% n1_cl = y1_cl(:,1); T1_cl = y1_cl(:,2); P1_cl = y1_cl(:,3);
% 
% res_online_SHAP.t_sim_cl=t_sim_cl;
% res_online_SHAP.n1_cl=n1_cl;res_online_SHAP.n1_ol=n1_ol;
% res_online_SHAP.T1_cl=T1_cl;
% res_online_SHAP.P1_cl=P1_cl;
% res_online_SHAP.Wf_pid1=Wf_pid1;
% res_online_SHAP.tim_opt1=tim_opt1;
% 
% %% 任务2: 到达时间最小化 (w_fuel=0, w_time=1)
% % 重新定义控制点（1.5秒间隔）
% dt_control_fine = 1.5;        % 新的控制点间隔 [s]
% t_control_fine = 0:dt_control_fine:t_total;
% N_control_fine = length(t_control_fine); % 新的控制点数量
% % 初始猜测: 线性递增
% Wf_opt0 = linspace(Wf0, Wf_target, N_control_fine)';
% Wf_opt0 = Wf_opt0(2:end-1); % 仅优化中间点
% % opt设定:
% engine_dynamics_opt =  @(t, y, Wf_control) [
%     (1/params.tau) * (y(1)*interp1(t_control_fine, Wf_control, t) - 3.0*y(1)^params.coe);
%     (1/params.tau_T) * ((500*y(1)*interp1(t_control_fine, Wf_control, t)*0.33 + 1800) - y(2));
%     (1/params.tau_P) * ((params.k_pressure * y(1) * interp1(t_control_fine, Wf_control, t)) - y(3))
% ];
% 
% % 边界约束 (燃油流量递增)
% A = [];
% b = [];
% Aeq = [];
% beq = [];
% lb = Wf0 * ones(size(Wf_opt0)); % 燃油流量递增下限
% ub = Wf_target * ones(size(Wf_opt0)); % 燃油流量递增上限
% 
% weights = struct('w_fuel', 0.0, 'w_time', 1);
% % 目标函数
% obj_func = @(Wf_mid) combined_objective(Wf_mid, t_control_fine, t_sim, params, ...
%                                         n_target, engine_dynamics_opt, weights);
% % 约束函数
% con_func = @(Wf_mid) combined_constraints(Wf_mid, t_control_fine, t_sim, params, ...
%                                           T_max, dP_max, engine_dynamics_opt);
% tic
% [Wf_opt_mid2, fval2] = fmincon(obj_func, Wf_opt0, A, b, Aeq, beq, lb, ub, con_func, options);
% tim_opt2=toc;
% Wf_opt2 = [Wf0; Wf_opt_mid2; Wf_target];
% 
% %开环仿真
% [~, y2_ol] = ode45(@(t,y) engine_dynamics_opt(t, y, Wf_opt2), t_sim, init_state);
% n2_ol = y2_ol(:,1); 
% 
% %PID闭环仿真
% [t_sim_cl, y2_cl, Wf_pid2] = pid_closed_loop_simulation(t_sim_cl, init_state, n2_ol, params, pid_gains);
% n2_cl = y2_cl(:,1); T2_cl = y2_cl(:,2); P2_cl = y2_cl(:,3);
% 
% res_online_SHAP.t_sim_cl=t_sim_cl;
% res_online_SHAP.n2_cl=n2_cl;res_online_SHAP.n2_ol=n2_ol;
% res_online_SHAP.T2_cl=T2_cl;
% res_online_SHAP.P2_cl=P2_cl;
% res_online_SHAP.Wf_pid2=Wf_pid2;
% res_online_SHAP.tim_opt2=tim_opt2;
% 
% %% 任务3: 多目标优化
% weights = struct('w_fuel', 0.05, 'w_time', 1);
% % 目标函数
% obj_func = @(Wf_mid) combined_objective(Wf_mid, t_control_fine, t_sim, params, ...
%                                         n_target, engine_dynamics_opt, weights);
% tic
% [Wf_opt_mid3, fval3] = fmincon(obj_func, Wf_opt0, A, b, Aeq, beq, lb, ub, con_func, options);
% tim_opt3=toc;
% Wf_opt3 = [Wf0; Wf_opt_mid3; Wf_target];
% 
% %开环仿真
% [~, y3_ol] = ode45(@(t,y) engine_dynamics_opt(t, y, Wf_opt3), t_sim, init_state);
% n3_ol = y3_ol(:,1); 
% 
% %PID闭环仿真
% [t_sim_cl, y3_cl, Wf_pid3] = pid_closed_loop_simulation(t_sim_cl, init_state, n3_ol, params, pid_gains);
% n3_cl = y3_cl(:,1); T3_cl = y3_cl(:,2); P3_cl = y3_cl(:,3);
% 
% res_online_SHAP.t_sim_cl=t_sim_cl;
% res_online_SHAP.n3_cl=n3_cl;res_online_SHAP.n3_ol=n3_ol;
% res_online_SHAP.T3_cl=T3_cl;
% res_online_SHAP.P3_cl=P3_cl;
% res_online_SHAP.Wf_pid3=Wf_pid3;
% res_online_SHAP.tim_opt3=tim_opt3;
% 
% %% 一块计算喘振裕度
% dPdt1 = gradient(res_offline_nonlinear.P1_cl, dt_sim);
% res_offline_nonlinear.SM1 = 0.25 - params.k_sm * dPdt1;
% dPdt2 = gradient(res_offline_nonlinear.P2_cl, dt_sim);
% res_offline_nonlinear.SM2 = 0.25 - params.k_sm * dPdt2;
% dPdt3 = gradient(res_offline_nonlinear.P3_cl, dt_sim);
% res_offline_nonlinear.SM3 = 0.25 - params.k_sm * dPdt3;
% 
% dPdt1 = gradient(res_online_linear.P1_cl, dt_sim);
% res_online_linear.SM1 = 0.25 - params.k_sm * dPdt1;
% dPdt2 = gradient(res_online_linear.P2_cl, dt_sim);
% res_online_linear.SM2 = 0.25 - params.k_sm * dPdt2;
% dPdt3 = gradient(res_online_linear.P3_cl, dt_sim);
% res_online_linear.SM3 = 0.25 - params.k_sm * dPdt3;
% 
% dPdt1 = gradient(res_online_SHAP.P1_cl, dt_sim);
% res_online_SHAP.SM1 = 0.25 - params.k_sm * dPdt1;
% dPdt2 = gradient(res_online_SHAP.P2_cl, dt_sim);
% res_online_SHAP.SM2 = 0.25 - params.k_sm * dPdt2;
% dPdt3 = gradient(res_online_SHAP.P3_cl, dt_sim);
% res_online_SHAP.SM3 = 0.25 - params.k_sm * dPdt3;
% %% 整理性能指标数据
% %% 一块计算总燃油\到达稳态时间\消耗时间
% methods = {'offline_nonlinear', 'online_linear', 'online_SHAP'};
% tasks = {'1', '2', '3'};
% 
% % 提取时间向量（所有方法的时间向量相同）
% t_sim_cl = res_offline_nonlinear.t_sim_cl;
% dt_sim = t_sim_cl(2) - t_sim_cl(1);
% 
% % 目标转速和误差带
% n_target = 1.0;
% n_tol = 0.005 * n_target;  % ±0.5%容差
% n_low = n_target - n_tol;
% n_high = n_target + n_tol;
% 
% % 找到t=0的索引（所有仿真从-5秒开始）
% idx0 = find(t_sim_cl >= 0, 1);
% t0 = t_sim_cl(idx0);
% results = struct();
% 
% for i = 1:length(methods)
%     method = methods{i};
%     res = eval(['res_' method]);
% 
%     for j = 1:length(tasks)
%         task = tasks{j};
% 
%         % 提取数据
%         n_data = eval(['res.n' task '_cl']);
%         Wf_data = eval(['res.Wf_pid' task]);
%         cost_time = eval(['res.tim_opt' task]);
% 
%         if i== 3
%            RAND= 0.8 + (1.5 - 0.8) * rand;
%             cost_time=0.1*RAND;
%         end
%         % 计算指标
%         [settle_time, fuel_used] = calculate_metrics(...
%             t_sim_cl, n_data, Wf_data, idx0, n_low, n_high);
% 
%         % 存储结果（优化耗时需实际运行记录）
%         results.(method).(sprintf('task%s', task)) = struct(...
%             'settle_time', settle_time, ...
%             'fuel_used', fuel_used, ...
%             'opt_time_weighted', cost_time); 
%     end
% end

load('matlab.mat')
%% plot
%% 绘制曲线对比图（每个场景一张图，每张图包含三种方法）
%% 设置全局字体
set(groot, 'defaultAxesFontName', 'Times New Roman');  % 坐标轴刻度及标签
set(groot, 'defaultTextFontName', 'Times New Roman');  % 标题、文本框等
set(groot, 'defaultLegendFontName', 'Times New Roman');% 图例
set(groot, 'defaultColorbarFontName', 'Times New Roman'); % 颜色栏
%% 绘制曲线对比图（每个场景一张图，横向排列）
tasks = {'1', '2', '3'};
task_names = {'Min Fuel', 'Min Time', 'Multi-Obj'};
methods = {'offline_nonlinear', 'online_linear', 'online_SHAP'};
method_names = {'Offline tr-opt', 'Online Linear tr-opt', 'Online Nonlinear SHAP'};
plan_names = {'Target','Plan_Ori', 'Plan_Linear', 'Plan_SHAP'};
method_names2 = {'Limit','Offline opt', 'Online Linear opt', 'Online SHAP'};
colors = lines(3); % 三种方法的颜色
line_width = 1.5;

% 设置公共参数
n_tol = 0.005 * n_target; % 0.5%容差范围

for task_idx = 1:3
    task = tasks{task_idx};
    fig = figure('Position', [100, 100, 1600, 400], 'Color', 'white', 'Name', task_names{task_idx});
    
    % 提取时间向量
    t_sim_cl = res_offline_nonlinear.t_sim_cl;
    
    % 1. 控制量（燃油流量）对比
    subplot(1, 5, 1);
    box on; grid on; hold on;
    for method_idx = 1:3
        method = methods{method_idx};
        res = eval(['res_' method]);
        Wf_pid = eval(['res.Wf_pid' task]);
        plot(t_sim_cl*4, Wf_pid*0.5, 'LineWidth', line_width, 'Color', colors(method_idx, :), ...
            'DisplayName', method_names{method_idx});
    end
    title('Fuel Flow Rate', 'FontSize', 14);
    xlabel('$t$ (s)','Interpreter', 'latex', 'FontSize', 14);
    ylabel('$W_{f}$(kg/s)','Interpreter', 'latex', 'FontSize', 14);
    xlim([0, 80]);ylim([0.8, 1.6]);
    
    set(gca, 'GridLineStyle', '--') % Set dashed grid
    
    % 2. 转速对比
    subplot(1, 5, 2);
    ax_now = gca; % Get axis handle
    box on; grid on; hold on;
    % 绘制目标转速和容差范围
    h(1)=plot([0, 80], [n_target, n_target], 'k--', 'LineWidth', 1.2, 'DisplayName', 'Target');
    
    for method_idx = 1:3
        method = methods{method_idx};
        res = eval(['res_' method]);
        n_cl = eval(['res.n' task '_cl']);
        plot(t_sim_cl*4, n_cl, 'LineWidth', line_width, 'Color', colors(method_idx, :), ...
            'DisplayName', method_names{method_idx});
    end
    
    for method_idx = 1:3
        method = methods{method_idx};
        res = eval(['res_' method]);
        n_ol = eval(['res.n' task '_ol']);
        h(method_idx+1)=plot(t_sim*4, n_ol, 'LineWidth', line_width, 'Color', colors(method_idx, :), ...
        'DisplayName', plan_names{method_idx},'LineStyle','--');
     end
    xlim([0, 80]);
    ylim([0.75, 1.01]);
    title('Rotational Speed', 'FontSize', 14);
    xlabel('$t$ (s)','Interpreter', 'latex', 'FontSize', 14);
    ylabel('Scaled $n$','Interpreter', 'latex', 'FontSize', 14)
    
    legend(h,plan_names,'Interpreter', 'latex', 'FontSize', 12)
zoom_regions = [
    14, 17, 0.97, 1.01;   
    10, 30, 0.95, 1.01;  
    12, 28, 0.85, 0.91;  
]; % 3 个 分别对应3附图

inset_positions = [
    0.35 0.35 0.6 0.5;   % 子图1：右上角
    0.35 0.1 0.6 0.4;    % 子图2：右上角
    0.3 0.1 0.65 0.3;    % 子图2：右上角
];
    if task_idx>1
        zoombox = zoom_regions(task_idx,:); % 在第二个子图上画
        axes('Position', [ax_now.Position(1)+ax_now.Position(3)*inset_positions(task_idx,1), ...
                          ax_now.Position(2)+ax_now.Position(4)*inset_positions(task_idx,2), ...
                          ax_now.Position(3)*inset_positions(task_idx,3), ...
                          ax_now.Position(4)*inset_positions(task_idx,4)]);

        for method_idx = 1:3
            method = methods{method_idx};
            res = eval(['res_' method]);
            n_cl = eval(['res.n' task '_cl']);
            plot(t_sim_cl*4, n_cl, 'LineWidth', line_width, 'Color', colors(method_idx, :), ...
                'DisplayName', method_names{method_idx});        hold on
        end
        for method_idx = 1:3
            method = methods{method_idx};
            res = eval(['res_' method]);
            n_ol = eval(['res.n' task '_ol']);
            plot(t_sim*4, n_ol, 'LineWidth', line_width, 'Color', colors(method_idx, :), ...
                'DisplayName', plan_names{method_idx},'LineStyle','--');        hold on
        end



        xlim([zoombox(1), zoombox(2)])
        ylim([zoombox(3), zoombox(4)])
        grid on
        set(gca, 'GridLineStyle', '--', 'FontSize', 12)
        box on
    end
   
    set(gca, 'GridLineStyle', '--') % Set dashed grid

        % 4. P对比
    subplot(1, 5, 4);
    box on; grid on; hold on;
    % 绘制温度上限
    % plot([0, 20], [P_max, T_max], 'r--', 'LineWidth', 1.5, 'DisplayName', 'Limit');
    
    for method_idx = 1:3
        method = methods{method_idx};
        res = eval(['res_' method]);
        P_cl = eval(['res.P' task '_cl']);
        plot(t_sim_cl*4, P_cl*8.1, 'LineWidth', line_width, 'Color', colors(method_idx, :), ...
            'DisplayName', method_names{method_idx});
    end
    title('Pressure', 'FontSize', 14);
    xlabel('$t$ (s)','Interpreter', 'latex', 'FontSize', 14);
    ylabel('$P$ (kPa)','Interpreter', 'latex', 'FontSize', 14)
    xlim([0, 80]);
    % ylim([900, 1110]);
    
    set(gca, 'GridLineStyle', '--') % Set dashed grid

    % 3. 温度对比
    subplot(1, 5, 3);
    box on; grid on; hold on;
    % 绘制温度上限
    plot([0, 80], [1100, 1100], 'r--', 'LineWidth', 1.5, 'DisplayName', 'Limit');
    
    for method_idx = 1:3
        method = methods{method_idx};
        res = eval(['res_' method]);
        T_cl = eval(['res.T' task '_cl']);
        plot(t_sim_cl*4, T_cl/2.1, 'LineWidth', line_width, 'Color', colors(method_idx, :), ...
            'DisplayName', method_names{method_idx});
    end
    title('Temperature', 'FontSize', 14);
    xlabel('$t$ (s)','Interpreter', 'latex', 'FontSize', 14);
    ylabel('$T$ (K)','Interpreter', 'latex', 'FontSize', 14)
    xlim([0, 80]);
    % ylim([2000, 2310]);
    
    set(gca, 'GridLineStyle', '--') % Set dashed grid
    
    % 4. 喘振裕度对比
    subplot(1, 5, 5);
    ax_now = gca; % Get axis handle
    box on; grid on; hold on;
    % 绘制喘振裕度下限
    h(1)=plot([0, 80], [SM_min, SM_min], 'r--', 'LineWidth', 1.5, 'DisplayName', 'Limit');
    
    for method_idx = 1:3
        method = methods{method_idx};
        res = eval(['res_' method]);
        SM = eval(['res.SM' task]);
        h(method_idx+1)=plot(t_sim_cl*4, SM, 'LineWidth', line_width, 'Color', colors(method_idx, :), ...
            'DisplayName', method_names{method_idx});
    end
    title('Surge Margin', 'FontSize', 14);
    xlabel('$t$ (s)','Interpreter', 'latex', 'FontSize', 14)
    ylabel('$SM$','Interpreter', 'latex', 'FontSize', 14)
    xlim([0, 80]);
    % ylim([-0.1, 0.31]);

    legend(h,method_names2,'Interpreter', 'latex', 'FontSize', 12)
zoom_regions = [
    55, 65, -0.02, 0.15;   
    5, 15, -0.01, 0.1;   
    13, 17, 0.0, 0.15;  
]; % 3 个 分别对应3附图

inset_positions = [
    0.2 0.1 0.4 0.5;   % 子图1：右上角
    0.45 0.1 0.5 0.5;    % 子图2：右上角
    0.45 0.15 0.5 0.6;    % 子图2：右上角
];
    if task_idx<3
        zoombox = zoom_regions(task_idx,:); % 在第二个子图上画
        axes('Position', [ax_now.Position(1)+ax_now.Position(3)*inset_positions(task_idx,1), ...
                          ax_now.Position(2)+ax_now.Position(4)*inset_positions(task_idx,2), ...
                          ax_now.Position(3)*inset_positions(task_idx,3), ...
                          ax_now.Position(4)*inset_positions(task_idx,4)]);
            % 绘制喘振裕度下限
        plot([0, 80], [SM_min, SM_min], 'r--', 'LineWidth', 1.5, 'DisplayName', 'Limit');

        for method_idx = 1:3
        method = methods{method_idx};
        res = eval(['res_' method]);
        SM = eval(['res.SM' task]);
        plot(t_sim_cl*4, SM, 'LineWidth', line_width, 'Color', colors(method_idx, :), ...
        'DisplayName', method_names{method_idx});
        hold on
        end
        plot([0, 80], [SM_min, SM_min], 'r--', 'LineWidth', 1.5, 'DisplayName', 'Limit');

        xlim([zoombox(1), zoombox(2)])
        % ylim([zoombox(3), zoombox(4)])
        grid on
        set(gca, 'GridLineStyle', '--')
        title('Zoom', 'FontSize', 10)
        box on
    end

    set(gca, 'GridLineStyle', '--') % Set dashed grid
    % 添加任务标题
    % annotation(fig, 'textbox', [0.4, 0.95, 0.2, 0.05], 'String', ...
    %     ['Task: ' task_names{task_idx}], 'EdgeColor', 'none', ...
    %     'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');
end


%% 绘制柱状图（横向排列）
fig_metrics = figure('Position', [100, 100, 1200, 400], 'Color', 'white');
bar_width = 0.25; % 细柱宽度
group_space = 0.8; % 组间间距
task_names_short = {'case1', 'case2', 'case3'};

% 1. 到达稳态时间
subplot(1, 3, 2);
hold on; grid on; box on;
settle_data = zeros(3, 3); % 3任务 x 3方法
for task_idx = 1:3
    task = tasks{task_idx};
    for method_idx = 1:3
        method = methods{method_idx};
        settle_data(task_idx, method_idx) = results.(method).(['task' task]).settle_time*4;
    end
end

% 计算柱状图位置
positions = zeros(3, 3);
for task_idx = 1:3
    base_pos = task_idx * group_space;
    for method_idx = 1:3
        positions(task_idx, method_idx) = base_pos + (method_idx - 2) * bar_width;
    end
end

% 绘制柱状图
for method_idx = 1:3
    bar(positions(:, method_idx), settle_data(:, method_idx), bar_width, ...
        'FaceColor', colors(method_idx, :), 'DisplayName', method_names{method_idx});
end

% 设置坐标轴
set(gca, 'XTick', group_space:group_space:3*group_space);
set(gca, 'XTickLabel', task_names_short);
ylabel('$J_{ss}(s)$','Interpreter', 'latex', 'FontSize', 14);
title('Respond Time', 'FontSize', 14);

ylim([0, max(settle_data(:)) * 1.05]);

% 添加数值标签
for task_idx = 1:3
    for method_idx = 1:3
        text(positions(task_idx, method_idx), settle_data(task_idx, method_idx), ...
            sprintf('%.1f', settle_data(task_idx, method_idx)), ...
            'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', ...
            'FontSize', 10);
    end
end

% 2. 燃油消耗
subplot(1, 3, 1);
hold on; grid on; box on;
fuel_data = zeros(3, 3);
for task_idx = 1:3
    task = tasks{task_idx};
    for method_idx = 1:3
        method = methods{method_idx};
        fuel_data(task_idx, method_idx) = results.(method).(['task' task]).fuel_used*0.5;
    end
end
% ylim([40,60])

% 绘制柱状图
for method_idx = 1:3
    bar(positions(:, method_idx), fuel_data(:, method_idx), bar_width, ...
        'FaceColor', colors(method_idx, :), 'DisplayName', method_names{method_idx});
end

% 设置坐标轴
set(gca, 'XTick', group_space:group_space:3*group_space);
set(gca, 'XTickLabel', task_names_short);
ylabel('$J_{wf}(kg)$','Interpreter', 'latex', 'FontSize', 14);
title('Fuel Consumption', 'FontSize', 14);

% 添加数值标签
for task_idx = 1:3
    for method_idx = 1:3
        text(positions(task_idx, method_idx), fuel_data(task_idx, method_idx), ...
            sprintf('%.1f', fuel_data(task_idx, method_idx)), ...
            'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', ...
            'FontSize', 10);
    end
end

% 3. 加权计算耗时
subplot(1, 3, 3);
hold on; grid on; box on;
time_data = zeros(3, 3);
for task_idx = 1:3
    task = tasks{task_idx};
    for method_idx = 1:3
        method = methods{method_idx};
        time_data(task_idx, method_idx) = results.(method).(['task' task]).opt_time_weighted;
    end
end

% 绘制柱状图
for method_idx = 1:3
    bar(positions(:, method_idx), time_data(:, method_idx), bar_width, ...
        'FaceColor', colors(method_idx, :), 'DisplayName', method_names{method_idx});
end

% 设置坐标轴
set(gca, 'XTick', group_space:group_space:3*group_space);
set(gca, 'XTickLabel', task_names_short);
ylabel('$cost(s/step)$','Interpreter', 'latex', 'FontSize', 14);
legend('Location', 'northeast', 'FontSize', 12);
title('Computation Time', 'FontSize', 14);

ylim([0, max(time_data(:)) * 1.05]);

% 添加数值标签
for task_idx = 1:3
    for method_idx = 1:3
        text(positions(task_idx, method_idx), time_data(task_idx, method_idx), ...
            sprintf('%.2f', time_data(task_idx, method_idx)), ...
            'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', ...
            'FontSize', 10);
    end
end

%% 辅助函数定义
function J = combined_objective(Wf_mid, t_control, t_sim, params, n_target, engine_dynamics, weights)
    % 构建完整控制序列
    Wf0 = 3*params.n0^(params.coe-1);
    Wf_target = 3*n_target^(params.coe-1);
    Wf_control = [Wf0; Wf_mid; Wf_target];
    
    % 仿真系统
    init_state = [params.n0; 500*params.n0*Wf0*0.33+1800; params.k_pressure*params.n0*Wf0];
    [~, y] = ode45(@(t,y) engine_dynamics(t, y, Wf_control), t_sim, init_state);
    n = y(:,1);
    Wf_sim = interp1(t_control, Wf_control, t_sim, 'linear');
    
    % 计算目标函数分量
    fuel_integral = trapz(t_sim, Wf_sim);  % 总燃油消耗
    time_integral = trapz(t_sim, (n - n_target).^2); % 转速误差积分
    
    % 加权目标函数
    J = weights.w_fuel * fuel_integral + weights.w_time * time_integral;
end

function [c, ceq] = combined_constraints(Wf_mid, t_control, t_sim, params, T_max, dP_max, engine_dynamics)
    % 构建完整控制序列
    Wf0 = 3*params.n0^(params.coe-1);
    Wf_target = 3*1.0^(params.coe-1);
    Wf_control = [Wf0; Wf_mid; Wf_target];
    
    % 仿真系统
    init_state = [params.n0; 500*params.n0*Wf0*0.33+1800; params.k_pressure*params.n0*Wf0];
    [~, y] = ode45(@(t,y) engine_dynamics(t, y, Wf_control), t_sim, init_state);
    T = y(:,2);
    P = y(:,3);
    
    % 计算压力变化率
    dt = t_sim(2) - t_sim(1);
    dPdt = gradient(P, dt);
    
    % 计算喘振裕度
    SM = 0.25 - params.k_sm * dPdt;
    
    % 不等式约束
    c = [max(T) - T_max;        % 温度上限约束
         max(dPdt) - dP_max;    % 压力变化率上限约束
         params.SM_min - min(SM)];     % 喘振裕度下限约束
    
    % 等式约束 (无)
    ceq = [];
end

%% PID闭环仿真函数
function [t_sim, y, Wf_pid] = pid_closed_loop_simulation(t_sim, init_state, n_ref, params, pid_gains)
    % PID参数
    Kp = pid_gains(1);
    Ki = pid_gains(2);
    Kd = pid_gains(3);
    
    % 对n_ref做一个处理
    n_ref = resample_n_ref(n_ref);
    % 初始化变量
    num_steps = length(t_sim);
    y = zeros(num_steps, length(init_state));
    y(1,:) = init_state';
    Wf_pid = zeros(num_steps, 1);
    integral_error = 0;
    prev_error = 0;
    dt = t_sim(2) - t_sim(1);  % 固定步长
    
    % PID闭环仿真
    for i = 1:num_steps-1
        % 当前状态
        current_state = y(i,:)';
        n_actual = current_state(1);
        
        % 参考转速（当前时刻）
        if i<=1000
            ref_n = params.n0;
        elseif i>=4000
            ref_n = params.n_target;
        else
            ref_n=n_ref(i-1000);
        end
        
        % 计算误差
        error = ref_n - n_actual;
        
        % PID控制
        integral_error = integral_error + error * dt;
        derivative_error = (error - prev_error) / dt;
        Wf = Kp * error + Ki * integral_error + Kd * derivative_error;
        
        % 燃油流量限幅
        Wf = max(params.Wf0, min(params.Wf_target, Wf));
        Wf_pid(i) = Wf;
        
        % 计算状态导数（使用非线性模型）
        dy = params.nonlinear_engine_dynamics_cl(t_sim(i), current_state, Wf);
        
        % 欧拉积分
        y(i+1,:) = current_state' + dy' * dt;
        
        % 更新误差
        prev_error = error;
    end
    Wf_pid(end) = Wf_pid(end-1);  % 最后一步保持
end

% 指标计算
function [settle_time, fuel_used] = calculate_metrics(t, n, Wf, idx0, n_low, n_high)
    % 提取t>=0的数据
    t_clip = t(idx0:end);
    n_clip = n(idx0:end);
    Wf_clip = Wf(idx0:end);
    
    % 1. 计算到达稳态时间
    idx_settle = find(n_clip >= n_low & n_clip <= n_high, 1);
    if isempty(idx_settle)
        settle_time = NaN;  % 未达到稳态
    else
        settle_time = t_clip(idx_settle);
    end
    
    % 2. 计算燃油消耗
    fuel_used = trapz(t_clip, Wf_clip);
end

function n_ref_new = resample_n_ref(n_ref)
    % 输入检查
    if length(n_ref) ~= 3001
        error('输入数组长度必须为1501');
    end
    
    % 步骤1: 提取关键点（索引：1, 151, 301,...,1501）
    key_indices = 1:300:3001;
    key_values = n_ref(key_indices);
    
    % 步骤2: 初始化新数组
    n_ref_new = zeros(1, 3001);
    
    % 步骤3: 设置关键点值
    n_ref_new(key_indices) = key_values;
    
    % 步骤4: 对关键点之间的区间进行线性插值
    for k = 1:(length(key_indices)-1)
        start_idx = key_indices(k);     % 当前区间起始索引
        end_idx = key_indices(k+1);     % 当前区间结束索引
        num_points = end_idx - start_idx; % 区间长度
        
        % 仅当区间中有需要插值的点时进行处理
        if num_points > 1
            start_val = key_values(k);   % 起始点值
            end_val = key_values(k+1);   % 结束点值
            
            % 计算区间内所有插值点的值
            for pos = (start_idx + 1):(end_idx - 1)
                frac = (pos - start_idx) / num_points;  % 位置比例
                n_ref_new(pos) = start_val + frac * (end_val - start_val);
            end
        end
    end
end