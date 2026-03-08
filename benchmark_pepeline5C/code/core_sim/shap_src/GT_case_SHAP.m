%% 参数定义
params = struct();
params.coe = 3;
params.tau = 0.2;      % 转速动态时间常数 [s]
params.tau_T = 2.5;    % 温度动态时间常数 [s]
params.tau_P = 1.0;    % 压力动态时间常数 [s] (新增)
params.n0 = 0.75;      % 初始转速
params.k_thrust = 0.8*1000; % 推力计算系数
params.k_pressure = 100;    % 压力计算系数 (新增)
params.k_sm = 0.01;    % SM变化幅值系数 (新增)

% 初始计算
Wf0 = 3*params.n0^(params.coe-1);      % 初始燃油流量
% Wf_target = 3.0;    % 目标燃油流量
Wf_target = Wf0 + 1.25;    % 目标燃油流量

tspan = [0 30];     % 仿真时间范围
dt = 0.01;           % 时间步长

% 初始温度和压力计算
T_des0 = 500*params.n0*Wf0*0.33 + 1800;
P_des0 = params.k_pressure * params.n0 * Wf0;  % 初始压力 (新增)
init_state = [params.n0; T_des0; P_des0];  % 状态向量: [转速; 温度; 压力] (修改)

%% 燃油流量函数 (t=5s时阶跃变化)
Wf_func = @(t) Wf0 + (Wf_target - Wf0)*(t >= 5);

%% 1. 原始动态模型仿真 (包含温度和压力动态)
options = odeset('MaxStep', dt); 
odefun_original = @(t, y) [
    % 转速动态: dn/dt = (1/tau)(n*Wf - 3*n^coe)
    (1/params.tau) * (y(1)*Wf_func(t) - 3.0*y(1)^params.coe);
    
    % 温度动态: dT/dt = (T_des - T)/tau_T
    (1/params.tau_T) * ((500*y(1)*Wf_func(t)*0.33 + 1800) - y(2));
    
    % 压力动态: dP/dt = (P_des - P)/tau_P (新增)
    (1/params.tau_P) * ((params.k_pressure * y(1) * Wf_func(t)) - y(3))
];

[t_orig, y_orig] = ode45(odefun_original, tspan, init_state, options);
n_orig = y_orig(:,1);  % 提取转速
T_orig = y_orig(:,2);  % 提取温度
P_orig = y_orig(:,3);  % 提取压力 (新增)

% 计算目标温度（无惯性）
T_des_orig = 500 * n_orig .* arrayfun(Wf_func, t_orig) * 0.33 + 1800;

% 计算目标压力（无惯性）(新增)
P_des_orig = params.k_pressure * n_orig .* arrayfun(Wf_func, t_orig);

%% 2. 稳态假设模型仿真
t_steady = tspan(1):dt:tspan(2);
Wf_steady = arrayfun(Wf_func, t_steady);
n_steady = (Wf_steady / 3.0).^(1/(params.coe-1));  % 从稳态方程求解
T_steady = 500 * n_steady .* Wf_steady * 0.33 + 1800;  % 稳态温度
P_steady = params.k_pressure * n_steady .* Wf_steady;   % 稳态压力 (新增)

P_des_linear = params.k_pressure * n_linear .* arrayfun(Wf_func, t_lin);
P_des_steady = params.k_pressure * n_steady .* Wf_steady;   % 注意：这里n_steady和Wf_steady都是向量

%% 3. 平衡点附近线性化模型 (包含温度和压力动态)
n_lin_point = params.n0;  % 线性化点（初始转速）
% 计算初始平衡点温度和压力
T0 = 500 * n_lin_point * Wf0 * 0.33 + 1800;
P0 = params.k_pressure * n_lin_point * Wf0;  % (新增)

% 计算雅可比矩阵元素 (扩展为3x3)
% 转速动态的偏导
df1_dn = (1/params.tau) * (Wf0 - 3.0*params.coe*n_lin_point^(params.coe-1));
df1_dT = 0;  
df1_dP = 0;  % 新增
df1_dWf = (1/params.tau) * n_lin_point;

% 温度动态的偏导
df2_dn = (1/params.tau_T) * (500*0.33*Wf0);
df2_dT = -1/params.tau_T;  
df2_dP = 0;  % 新增
df2_dWf = (1/params.tau_T) * (500*0.33*n_lin_point);

% 压力动态的偏导 (新增)
df3_dn = (1/params.tau_P) * (params.k_pressure * Wf0);
df3_dT = 0;
df3_dP = -1/params.tau_P;
df3_dWf = (1/params.tau_P) * (params.k_pressure * n_lin_point);

% 状态空间矩阵
A = [df1_dn, df1_dT, df1_dP;
     df2_dn, df2_dT, df2_dP;
     df3_dn, df3_dT, df3_dP];  % 3x3矩阵
B = [df1_dWf;
     df2_dWf;
     df3_dWf];  % 3x1矩阵

% 线性化状态方程: dx/dt = A*x + B*u
odefun_linear = @(t, x) A * x + B * (Wf_func(t) - Wf0);
[t_lin, x_lin] = ode45(odefun_linear, tspan, [0; 0; 0]);  % 初始偏移为0 (3维)

% 还原实际状态
n_linear = n_lin_point + x_lin(:,1);  
T_linear = T0 + x_lin(:,2);           
P_linear = P0 + x_lin(:,3);           % 新增压力

%% 推力计算函数
calc_thrust = @(n, Wf) params.k_thrust * Wf .* n.^2 .* (2*n - n.^2);

% 计算各模型的推力
thrust_orig = calc_thrust(n_orig, arrayfun(Wf_func, t_orig));
thrust_steady = calc_thrust(n_steady, Wf_steady);
thrust_linear = calc_thrust(n_linear, arrayfun(Wf_func, t_lin));

%% 喘振裕度(SM)静态关系计算
% SM = 0.3 - k_sm * (P_des - P)
SM_orig = 0.3 - params.k_sm * (P_des_orig - P_orig);
SM_linear = 0.3 - params.k_sm * (P_des_linear - P_linear);
SM_steady = 0.3 - params.k_sm * (P_des_steady - P_steady); % 恒等于0.3

%% 可视化结果
figure('Position', [0, 0, 900, 1200])

% 转速比较
subplot(4,1,1)
plot(t_orig, n_orig, 'LineWidth', 2, 'DisplayName', '原始动态模型')
hold on
plot(t_steady, n_steady, '--', 'LineWidth', 2, 'DisplayName', '稳态假设模型')
plot(t_lin, n_linear, 'LineWidth', 2, 'DisplayName', '线性化模型')
yline(1.0, 'k:', '目标转速', 'LabelHorizontalAlignment', 'left')
xline(5, 'r-', '燃油阶跃变化点')
xlabel('时间 [s]')
ylabel('转速 n')
title('三种模型转速响应比较')
legend('Location', 'southeast')
grid on

% 温度响应比较
subplot(4,1,2)
plot(t_orig, T_orig, 'LineWidth', 2, 'DisplayName', '原始模型(有惯性)')
hold on
plot(t_orig, T_des_orig, '--', 'LineWidth', 2, 'DisplayName', '目标温度(无惯性)')
plot(t_steady, T_steady, 'LineWidth', 2, 'DisplayName', '稳态模型')
plot(t_lin, T_linear, 'LineWidth', 2, 'DisplayName', '线性模型')
yline(2000, 'r:', '温度约束 2000K', 'LabelHorizontalAlignment', 'left')
xline(5, 'r-', '燃油阶跃变化点')
xlabel('时间 [s]')
ylabel('温度 T [K]')
title('温度响应比较')
legend('Location', 'southeast')
grid on

% 压力响应比较 (新增)
subplot(4,1,3)
plot(t_orig, P_orig, 'LineWidth', 2, 'DisplayName', '原始模型(有惯性)')
hold on
plot(t_orig, P_des_orig, '--', 'LineWidth', 2, 'DisplayName', '目标压力(无惯性)')
plot(t_steady, P_steady, 'LineWidth', 2, 'DisplayName', '稳态模型')
plot(t_lin, P_linear, 'LineWidth', 2, 'DisplayName', '线性模型')
xline(5, 'r-', '燃油阶跃变化点')
xlabel('时间 [s]')
ylabel('压力 P')
title('压力响应比较 (新增一阶惯性)')
legend('Location', 'southeast')
grid on

%% 可视化中的SM子图
subplot(4,1,4)
plot(t_orig, SM_orig, 'LineWidth', 2, 'DisplayName', '原始模型')
hold on
plot(t_steady, SM_steady, 'LineWidth', 2, 'DisplayName', '稳态模型')
plot(t_lin, SM_linear, 'LineWidth', 2, 'DisplayName', '线性模型')
yline(0.3, 'k:', '目标SM=0.3', 'LabelHorizontalAlignment', 'left')
xlabel('时间 [s]')
ylabel('喘振裕度(SM)')
title('SM静态关系: SM = 0.3 - k_{sm}(P_{des}-P)')
legend('Location', 'southeast')
grid on