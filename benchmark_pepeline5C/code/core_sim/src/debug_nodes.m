
load('E:\working\Matlab_prjs\Gas_Line_case\Pinn\ss_par.mat');
% 监测以下 节点设置是否正确
from_flows=par.sim.n.from_flows;
to_flows=par.sim.n.to_flows;

% 先得到给出的粗糙稳态初解
ss_sim=par.ss;
from_flows_ss=ss_sim.n.from_flows;
to_flows_ss=ss_sim.n.to_flows;
ppp0=ss_sim.m.ppp0;
qqq0=ss_sim.m.qqq0;
pp_nodal=zeros(1,ss_sim.n.nv);
pp_nodal(:,ss_sim.m.snodes)=ss_sim.m.Pslack1;
pp_nodal(:,ss_sim.m.dnodes)=ppp0;

ss_edges_cell = par.ss.n.edges_cell;
[n_edges,~] = size(ss_edges_cell);
tr_edges_cell = par.tr.n.edges_cell;
% 精网格 初始解保存
ppp0_jing=zeros(1,par.sim.n.nv)';
qqq0_jing=zeros(1,par.sim.n.nv-1)';

for j=1:n_edges-par.ss.n.nc

    %% 首先粗糙初解上采样，形成精细解的初解
    i=j+par.ss.n.nc;
    ss_edge_nodes = ss_edges_cell{i};
    tr_edge_nodes = tr_edges_cell{i};
    [num_ss,~] = size(ss_edge_nodes);
    [num_tr,~] = size(tr_edge_nodes);
    x_raw = linspace(1,100,num_ss);
    x_new = linspace(1,100,num_tr);
    yp_raw=pp_nodal(ss_edge_nodes);
    yp_new=interp1(x_raw,yp_raw,x_new);
    ppp0_jing(tr_edge_nodes)=yp_new;

    yq_raw=qqq0(from_flows_ss(j):to_flows_ss(j));
    num_edge_raw=length(from_flows_ss(j):to_flows_ss(j));
    num_edge_now=length(from_flows(j):to_flows(j));
    x_raw = linspace(1,100,num_edge_raw);
    x_new = linspace(1,100,num_edge_now);
    yq_new=interp1(x_raw,yq_raw,x_new);
    qqq0_jing(from_flows(j):to_flows(j))=yq_new;

end
ppp0_jing=ppp0_jing(2:end);
qqq0_jing(1:5)=qqq0(1:5);
a=1;