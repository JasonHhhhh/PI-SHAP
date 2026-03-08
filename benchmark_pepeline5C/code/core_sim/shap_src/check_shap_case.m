clc,clear;

syms t
U=t^2;V=2*t;
M=U+V;
T=10;
res = int(M,t,0,T);
res=vpa(res)

U_f=matlabFunction(U);V_f=matlabFunction(V);M_f=matlabFunction(M);

t_numeric=linspace(0,T,100);

U_numeric=U_f(t_numeric);
V_numeric=V_f(t_numeric); % 给定的某种V的规律
M_numeric=M_f(t_numeric);

M_numeric_=M_numeric(1:end-1);
delta_t=t_numeric(2)-t_numeric(1);
% 数值积分1
upper=T;
lower=0;
res_numeric=sum(M_numeric_.*delta_t)

% 数值积分2
upper=2*(T^3);
lower=0;
delta_V=V_numeric(2:end)-V_numeric(1:end-1);
dVdt=delta_V/delta_t;
res_shap0=sum(M_numeric_./dVdt.*delta_V)

% 整理shap等效时：每一个时刻的V的权重
weight_shap=M_numeric_./dVdt;
w0=-weight_shap(1);
wmid=weight_shap(1:end-1)-weight_shap(2:end);
wend=weight_shap(end);
weights_all=[w0,wmid,wend]';
res_shap1=sum(weights_all.*V_numeric')

%% 这里一定要找到这样做的意义，物理意义是什么？后边的才能清晰


%% 采用一个剥离工况影响的手段/或将工况影响纳入在内
% 1 导数为0，连续上是没有意义的（分割点）；2
%% 若单调，在平稳过程中则按照另外一套思路考虑：
% 且v'>0：M公式系统给定的; V的规律是给定的被评估的目标（Vt） 积分上下限是完全由时间决定的
% 那么任何一个动态过程将能够被shap快速解析，分解成规划指令对指标的正负贡献度
% 在多个动态过程上快速采样（速度上甚至允许实现在线细粒度采样和规则学习），通过tree提取出这样的规则直接直接供调度使用

%% 若考虑更广义的过程，对于v'<eps的过程我们考虑为ss的影响性，这里shap将不再给出对ss过程的近似，
% 即我们不会计算相应的shap权重

% 场景是：已知起点和终点（已经用ss优化算法所确定），所以对中间的动态过程，我们可以进行shap的各种评估，
% 对规定时刻的v' v U_all 都有一个唯一确定的contibution；我们通过有限次采样得到无限次可泛化应用的规则
% 我们与动态规划的优化方法作对比，证明这样做几乎在性能上是接近的；与其他规则对比（随机、纯稳态的台阶调度）；补充两个前沿

% 我们的算法性能更好



% 对比优化方法和其他模糊指定的调度策略方法

%% 你这里的方法改进的是？系统的调度措施，根据已经提取出来的规则集（off-line fast nested knowledge），
% 替代对无限动态时序决策空间的难以描述，用DN-shap描述并给出指标，引导快速决策！
% 这个offline的规则集将告诉我，起点和终点固定：中间t时刻下，输入v v'的取值，告诉我仅在这一时刻点下对M的contribution是？
% 
% 生成合理的调度措施，
% 这样的调度措施的效果甚至可以和动态优化媲美，基本上优于台阶式的ss优化得到的结果





%% 认为weights_all是针对于每一个变量的贡献度评价（V->M），这为实施规划提供了重要依据
% 条件：单调；对每一个过程都




