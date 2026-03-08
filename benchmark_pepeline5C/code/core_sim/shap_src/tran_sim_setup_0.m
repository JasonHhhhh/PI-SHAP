function [par] = tran_sim_setup_0(par,cc0)
%% 仿真准备1
% 压缩机动作
[~,c]=size(cc0); % r为小时间隔下的时间节点个数
par.tr.cc0=cc0; % 一段时间内的5个压缩机的压比（包括最后一个时间节点）
% 时间长度
par.tr.m.N=c-2;   % time discretization points 
% % 进口压力
% par.tr.m.N=N;   
% % 出口流量

% 定义相关的值
GN=par.tr.m.GN;    % # of gNodes
M=par.tr.m.M;      % # of state variables - edges and nodes
C=par.tr.m.C;      % # of compressors
[par.tr.m.x,par.tr.m.D]=foDc(par.tr.m.N);      % compute first order collocation nodes x and differentiation matrix D
[par.tr.m.x,par.tr.m.w]=fonodes(par.tr.m.N);   % compute first order collocation nodes x and differentiation matrix D
par.tr.m.t=(-par.tr.m.x+1)*par.tr.m.Ts/2;       % rescale collocation points on [-1,1] to time interval [0,T]
par.tr.m.N1=par.tr.m.N+1; % 不包括最后一个节点的时间个数
par.tr.m.tk=par.tr.m.t(1:par.tr.m.N1); % 不包括最后一个时间点的归一化时间结点
par.tr.m.xk=par.tr.m.x(1:par.tr.m.N1); % 不包括最后一个时间点的【-1,1】化的时间结点
par.tr.tt0=[0:par.tr.m.N1]'*par.tr.c.T/par.tr.m.N1; % 真实的时间轴
par.tr.fd0=zeros(GN,c); %所有分输用户 s d 都是0；出口都为baseline

% par.tr.dout=@(t) interp1qr(par.tr.m.xd',par.tr.m.Yq',t)';  
% par.tr.m.d=sparse(par.tr.dout(par.tr.m.tk*par.tr.c.Tsc));
% par.tr.m.d=[par.tr.m.d par.tr.m.d(:,1)];
% par.tr.pslout=@(t) interp1qr(par.tr.m.xd',par.tr.m.Pslack',t)'; % 获得仿真时间内的出口压力，扩展到所有
% par.tr.m.pslack=par.tr.pslout(par.tr.m.tk*par.tr.c.Tsc);
% par.tr.m.pslack=[par.tr.m.pslack par.tr.m.pslack(:,1)];
%% 仿真准备2
sim=par.sim; % 仿真采用稳态ss的数值化参数，分割区间更多
% 生成供还是求的布尔变量
gall=par.tr.n0.phys_node; gunique=unique(gall);
gallind=zeros(size(gall)); guniqueind=zeros(size(gunique));
for j=1:length(gallind)
    gallind(j)=find(par.tr.m.fn==gall(j));
end
for j=1:length(guniqueind)
    guniqueind(j)=find(par.tr.m.fn==gunique(j));
end
gtod=sparse(length(guniqueind),length(gall));
for j=1:length(guniqueind)
    gtod(j,:)=(gallind==guniqueind(j));
end

par.tr.m.gtod = gtod;
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
sim.startupgrid=[0:sim.tstep/sim.c.Tsc:sim.m.Ts*sim.startup]; % 启动
sim.periodgrid=[0:sim.tstep/sim.c.Tsc:sim.m.Ts]; % 周期
sim.cyclesgrid=[0:sim.tstep/sim.c.Tsc:(sim.nperiods-1)*sim.m.Ts]; % 周期循环 时间网格
par.sim=sim;
end


function [x,D]=foDc(N)
%x=-([0:N]'-N/2)/(N/2);
x=-([0:N+1]'-(N+1)/2)/((N+1)/2);
D=eye(N+1)-diag(ones(N,1),-1);
D(1,N+1)=-1;
D=-D*(N/2);
end

function [x,w]=fonodes(N)
%x=-([0:N]'-N/2)/(N/2);
x=-([0:N+1]'-(N+1)/2)/((N+1)/2);
w=ones(N+1,1)/(N/2);
end
