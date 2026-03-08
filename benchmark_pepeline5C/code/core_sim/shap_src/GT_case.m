clc,close all;clear
%% 参数定义
params = struct();
params.coe = 3;
params.tau = 1;      % 转速动态时间常数 [s]
params.tau_T = 2;    % 温度动态时间常数 [s]
params.tau_P = 1.5;    % 压力动态时间常数 [s] (新增)
params.n0 = 0.75;      % 初始转速
params.k_thrust = 0.8*1000; % 推力计算系数
params.k_pressure = 100;    % 压力计算系数 (新增)
params.k_sm = 0.005;    % SM变化幅值系数 (新增)

% 初始计算
Wf0 = 3*params.n0^(params.coe-1);      % 初始燃油流量
% Wf_target = 3.0;    % 目标燃油流量
Wf_target = Wf0 + 0.3;    % 目标燃油流量
n_target = (Wf_target / 3.0).^(1/(params.coe-1));  % 从稳态方程求解

tspan = [0 30];     % 仿真时间范围
dt = 0.1;           % 时间步长

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
P_des_linear = params.k_pressure * n_linear .* arrayfun(Wf_func, t_lin);
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

%% Visualization with Horizontal Layout
set(groot, 'defaultAxesFontName', 'Times New Roman');  
set(groot, 'defaultTextFontName', 'Times New Roman'); 
set(groot, 'defaultLegendFontName', 'Times New Roman');
set(groot, 'defaultColorbarFontName', 'Times New Roman');
set(groot, 'defaultAxesFontSize', 12);  % Increase axis font size
set(groot, 'defaultTextFontSize', 14);  % Increase title font size

figure('Position', [100, 100, 1800, 500], 'Color', 'w')  % Slightly wider for larger fonts

% Define zoom regions for each subplot [t_start, t_end, y_min, y_max]
zoom_regions = {
    [5*4, 10*4, 0.8, 0.82];   % Rotational Speed
    [6*4, 20*4, 2050/2.1, 2070/2.1];     % Temperature
    [6*4, 15*4, 150*10, 165*10];     % Pressure
    [4*4, 15*4, 0.16, 0.32]    % Surge Margin
};
inset_positions = [
    0.35 0.35 0.6 0.5;   % 子图1：右上角
    0.45 0.15 0.5 0.6;    % 子图2：右上角
    0.45 0.15 0.5 0.6;    % 子图3：右上角
    0.45 0.15 0.5 0.6   % 子图4：右下角（避免遮挡曲线）
];
% 1. Rotational Speed Comparison
subplot(1,4,1)
ax1 = gca; % Get axis handle
plot(t_orig*4, n_orig, 'LineWidth', 2, 'DisplayName', 'Original Dynamic')
hold on
plot(t_lin*4, n_linear, 'LineWidth', 2, 'DisplayName', 'Linearized Dynamic')
plot(t_steady*4, n_steady, 'LineWidth', 2, 'DisplayName', 'Steady-state','Color','k','LineStyle','--')
hl = legend('Location', 'southeast', 'FontSize', 12);
xlabel('$t$ (s)','Interpreter', 'latex', 'FontSize', 14)
ylabel('Scaled $n$','Interpreter', 'latex', 'FontSize', 14)
title('Rotational Speed Response', 'FontSize', 14)
grid on;xlim([0,100])
set(ax1, 'GridLineStyle', '--') % Set dashed grid
box on

% Add zoomed inset
zoombox = zoom_regions{1};
axes('Position', [ax1.Position(1)+ax1.Position(3)*inset_positions(1,1), ...
                  ax1.Position(2)+ax1.Position(4)*inset_positions(1,2), ...
                  ax1.Position(3)*inset_positions(1,3), ...
                  ax1.Position(4)*inset_positions(1,4)]);
plot(t_orig*4, n_orig, 'LineWidth', 1.5)
hold on
plot(t_lin*4, n_linear, 'LineWidth', 1.5)
plot(t_steady*4, n_steady, 'LineWidth', 1.5,'Color','k','LineStyle','--')
xlim([zoombox(1), zoombox(2)])
ylim([zoombox(3), zoombox(4)])
grid on
set(gca, 'GridLineStyle', '--', 'FontSize', 9)
title('Zoom', 'FontSize', 10)
box on

% 2. Temperature Response
subplot(1,4,2)
ax2 = gca;
plot(t_orig*4, T_orig/2.1, 'LineWidth', 2, 'DisplayName', 'Original (Inertia)')
hold on
plot(t_lin*4, T_linear/2.1, 'LineWidth', 2, 'DisplayName', 'Linearized')
plot(t_steady*4, T_steady/2.1, 'LineWidth', 2, 'DisplayName', 'Steady-state','Color','k','LineStyle','--')
xlabel('$t$ (s)','Interpreter', 'latex', 'FontSize', 14)
ylabel('$T$ (K)','Interpreter', 'latex', 'FontSize', 14)
title('Temperature Response', 'FontSize', 14)
grid on;xlim([0,100])
set(ax2, 'GridLineStyle', '--') % Set dashed grid
box on

% Add zoomed inset
zoombox = zoom_regions{2};
axes('Position', [ax2.Position(1)+ax2.Position(3)*inset_positions(2,1), ...
                  ax2.Position(2)+ax2.Position(4)*inset_positions(2,2), ...
                  ax2.Position(3)*inset_positions(2,3), ...
                  ax2.Position(4)*inset_positions(2,4)]);
plot(t_orig*4, T_orig/2.1, 'LineWidth', 1.5)
hold on
plot(t_lin*4, T_linear/2.1, 'LineWidth', 1.5)
plot(t_steady*4, T_steady/2.1, 'LineWidth', 1.5,'Color','k','LineStyle','--')
xlim([zoombox(1), zoombox(2)])
ylim([zoombox(3), zoombox(4)])
grid on
set(gca, 'GridLineStyle', '--', 'FontSize', 9)
title('Zoom', 'FontSize', 10)
box on

% 3. Pressure Response
subplot(1,4,3)
ax3 = gca;
plot(t_orig*4, P_orig*10, 'LineWidth', 2, 'DisplayName', 'Original (Inertia)')
hold on
plot(t_lin*4, P_linear*10, 'LineWidth', 2, 'DisplayName', 'Linearized')
plot(t_steady*4, P_steady*10, 'LineWidth', 2, 'DisplayName', 'Steady-state','Color','k','LineStyle','--')
xlabel('$t$ (s)','Interpreter', 'latex', 'FontSize', 14)
ylabel('$P$ (kPa)','Interpreter', 'latex', 'FontSize', 14)
title('Pressure Response', 'FontSize', 14)
grid on;xlim([0,100])
set(ax3, 'GridLineStyle', '--') % Set dashed grid
box on

% Add zoomed inset
zoombox = zoom_regions{3};
axes('Position', [ax3.Position(1)+ax3.Position(3)*inset_positions(3,1), ...
                  ax3.Position(2)+ax3.Position(4)*inset_positions(3,2), ...
                  ax3.Position(3)*inset_positions(3,3), ...
                  ax3.Position(4)*inset_positions(3,4)]);
plot(t_orig*4, P_orig*10, 'LineWidth', 1.5)
hold on
plot(t_lin*4, P_linear*10, 'LineWidth', 1.5)
plot(t_steady*4, P_steady*10, 'LineWidth', 1.5,'Color','k','LineStyle','--')
xlim([zoombox(1), zoombox(2)])
ylim([zoombox(3), zoombox(4)])
grid on
set(gca, 'GridLineStyle', '--', 'FontSize', 9)
title('Zoom', 'FontSize', 10)
box on

% 4. Surge Margin (SM)
subplot(1,4,4)
ax4 = gca;
plot(t_orig*4, SM_orig, 'LineWidth', 2, 'DisplayName', 'Original')
hold on
plot(t_lin*4, SM_linear, 'LineWidth', 2, 'DisplayName', 'Linearized')
plot(t_steady*4, SM_steady, 'LineWidth', 2, 'DisplayName', 'Steady-state','Color','k','LineStyle','--')
xlabel('$t$ (s)','Interpreter', 'latex', 'FontSize', 14)
ylabel('$SM$','Interpreter', 'latex', 'FontSize', 14)
ylim([0.16,0.32])
title('Surge Margin', ...
      'Interpreter', 'latex', 'FontSize', 14)
grid on;xlim([0,100])
set(ax4, 'GridLineStyle', '--') % Set dashed grid
box on

% Add zoomed inset
zoombox = zoom_regions{4};
axes('Position', [ax4.Position(1)+ax4.Position(3)*inset_positions(3,1), ...
                  ax4.Position(2)+ax4.Position(4)*inset_positions(3,2), ...
                  ax4.Position(3)*inset_positions(3,3), ...
                  ax4.Position(4)*inset_positions(3,4)]);
plot(t_orig*4, SM_orig, 'LineWidth', 1.5)
hold on
plot(t_lin*4, SM_linear, 'LineWidth', 1.5)
plot(t_steady*4, SM_steady, 'LineWidth', 1.5,'Color','k','LineStyle','--')
xlim([zoombox(1), zoombox(2)])
ylim([zoombox(3), zoombox(4)])
grid on
set(gca, 'GridLineStyle', '--', 'FontSize', 9)
title('Zoom', 'FontSize', 10)
box on


