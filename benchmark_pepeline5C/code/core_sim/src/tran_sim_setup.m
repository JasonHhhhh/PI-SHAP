function [par]=tran_sim_setup(par)

sim=par.sim; % 仿真采用稳态ss的数值化参数，分割区间更多

sim.m.cc0=par.tr.cc0;% 压缩机压比
sim.m.Yd=sim.m.Yq; % 定义离散后的所有非气源节点的属性，是否为出口，不是：0 是：出口流量，baseline，来自xls文件 % 出口流量
sim.m.Yd(1:sim.m.fn,:)=par.tr.m.Yq(1:sim.m.fn,:); % 都是一样的！！！
sim.m.Ygd=interp1qr(par.tr.tt0,par.tr.fd0(1:length(par.tr.m.gd),:)',par.tr.m.xd')';
sim.m.Ygs=interp1qr(par.tr.tt0,par.tr.fd0(length(par.tr.m.gd)+1:length(par.tr.m.gall),:)',par.tr.m.xd')'; 
sim.m.Yf=interp1qr(par.tr.tt0,par.tr.fd0',par.tr.m.xd')';
sim.m.Yd(par.tr.m.guniqueind,:)=sim.m.Yd(par.tr.m.guniqueind,:)+... 
    par.tr.m.gtod*sim.m.Yf; 
sim.m.Yd1=mean(sim.m.Yd,2); %作为第一步稳态初值


sim.m.Ys=par.tr.m.Pslack; % 给定的气源压力，恒定的
sim.m.xd=par.tr.m.xd;% 真实时间索引 24h分成了101个点
sim.m.N=par.tr.m.N; % 因为第一个点确定了所以剩下24个点 23h区间来优化
sim.m.t=par.tr.m.t; % 归一化的时间索引 每小时
sim.m.x=par.tr.m.x; % -([0:N+1]'-(N+1)/2)/((N+1)/2); 什么意思？？？

sim.m.N1=par.tr.m.N1; 
% 时间点个数，最终用于处理结果，此处记住要给N+1，N为时间小时数-1，因为后边会+1，
% eg：sim.m.N1=24，par.tr.m.N=23，par.tr.cc0： 25*5

% sim.m.tk=par.tr.m.tk; % 归一化后的时间点
% sim.m.xk=par.tr.m.xk; % tr.m.xk=tr.m.x(1:tr.m.N1);

sim.tstep=sim.c.T/sim.solsteps; % 每一步实际时长
% sim.m.Ts：归一化以后的总时长
sim.startupgrid=[0:sim.tstep/sim.c.Tsc:sim.m.Ts*sim.startup]; % 启动 (归一化时间)
sim.periodgrid=[0:sim.tstep/sim.c.Tsc:sim.m.Ts]; % 周期
sim.cyclesgrid=[0:sim.tstep/sim.c.Tsc:(sim.nperiods-1)*sim.m.Ts]; % 周期循环 时间网格
par.sim=sim;


function [x,D]=foDc(N)

%x=-([0:N]'-N/2)/(N/2);
x=-([0:N+1]'-(N+1)/2)/((N+1)/2);
D=eye(N+1)-diag(ones(N,1),-1);
D(1,N+1)=-1;
D=-D*(N/2);

function [x,w]=fonodes(N)
%x=-([0:N]'-N/2)/(N/2);
x=-([0:N+1]'-(N+1)/2)/((N+1)/2);
w=ones(N+1,1)/(N/2);

