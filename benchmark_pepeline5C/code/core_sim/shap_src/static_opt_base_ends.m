function [ss]=static_opt_base_ends(ss,end_node)
% end_node means the time
ss.Nvec_old=ss.Nvec;ss.m.Ts_old=ss.m.Ts;
% if (end_type==1)
ss.m.d=ss.m.Yq(:,end_node); % 稀疏阵：气体流出或进入的每个节点的流量，归一化后
ss.m.prslack=ss.m.Prslack(:,end_node);% 气源价格
ss.m.pslack=ss.m.Pslack(:,end_node);% 气源压力
% elseif (end_type==-1)
    % tr.m.d=tr.m.Yq(:,end); % 稀疏阵：气体流出或进入的每个节点的流量，归一化后
    % tr.m.prslack=tr.m.Prslack(:,end);% 气源价格
    % tr.m.pslack=tr.m.Pslack(:,end);% 气源压力
% end
if(ss.m.doZ==1), ss.m.pslack=p_to_rho_nd(ss.m.pslack,ss.c.b1,ss.c.b2,ss.c.psc); end
ss.m.int_flow_const=0; % 不知道是干嘛的
%load sizes
FN=ss.m.FN;    % # of flow nodes
PN=ss.m.PN;    % # of pressure nodes 气源
GN=ss.m.GN;    % # of gNodes
NE=ss.m.NE;    % # of edges
M=ss.m.M;      % # of state variables - edges and nodes
C=ss.m.C;      % # of compressors

tic,
% 要求解的时间结点，此处稳态为0，动态为?
v=1;

% Low-order derivative scheme
ss.m.N=0;                 % time discretization points
N=ss.m.N;       % # of time intervals
N1=ss.m.N+1;    % # of time collocation points

ss.m.x=0;ss.m.D=0;ss.m.w=1;ss.m.t=0;ss.m.N1=1;ss.m.tk=0;ss.m.xk=0;

% Initialize Optimization

% initial guess
%variables e.g. x_{ij} have space in i (rows) and time in j (cols)
% 列为时间结点
% 行为空间结点
%stack columns x_i in a single vector
if(v==1)

    pp0=kron(ones(N1,1),ss.m.p_min_nd(ss.n.nonslack_nodes));   %initialize density 时间-空间矩阵
    qq0=kron(zeros(N1,1),ones(NE,1));                %initialize flux
    cc0=kron(ones(N1,1),ss.n.c_max);                %initialize compressions

    xu0=[pp0;qq0;cc0];                               %stack it all in a vector
    xr=xu0+rand(size(xu0))/1000;                     %perturb (used to get Jacobian structure)
end

%define constraints

%discharge pressure setpoints

%linear equality constraints
ss.m.Aeq=[];
ss.m.Beq=[];

%     tr.m.Beq=[pp_init;qq_init;cc_init;dd_init];
%     tr.m.Aeq=sparse(FN+NE+C+GN,(FN+NE+C+GN)*N1);
%     tr.m.Aeq(1:FN,1:FN)=sparse(eye(FN));
%     tr.m.Aeq(FN+1:FN+NE,N1*FN+1:N1*FN+NE)=sparse(eye(NE));
%     tr.m.Aeq(FN+NE+1:FN+NE+C,N1*(FN+NE)+1:N1*(FN+NE)+C)=sparse(eye(C));
%     tr.m.Aeq(FN+NE+C+1:FN+NE+C+GN,N1*(FN+NE+C)+1:N1*(FN+NE+C)+GN)=sparse(eye(GN));

%links from supplier slack nodes
slinks=ss.m.comp_pos(ss.m.spos,2);% 得到索引而已
clinks=ss.m.comp_pos(:,2);

%relax bounds on optimized flows at gnodes so that interval-averaged
% bounds dominate ？？？？ 用于后续动态时间的出口流量约束
bnd_rel=2;
%lower bounds on variables
lbp=kron(ones(N1,1),ss.m.p_min_nd(ss.n.nonslack_nodes));
if(ss.m.doZ==1),
    lbp=kron(ones(N1,1),p_to_rho_nd(ss.m.p_min_nd(ss.n.nonslack_nodes),ss.c.b1,ss.c.b2,ss.c.psc));      %on pressure
end
%lbq=kron(ones(N1,1),-10*max(abs(tr.n.q_max))*ones(NE,1)/tr.c.qsc); %on flow
lbq_val=-10*max(abs(ss.n.q_max))/ss.c.qsc*ones(NE,1);
lbq_val(clinks)=ss.m.flow_min_nd./ss.m.xs(clinks);
lbq_val(slinks)=zeros(length(slinks),1);
lbq=kron(ones(N1,1),lbq_val);                                       %on flow
lbc=kron(ones(N1,1),ss.n.c_min);                                    %on compressor ratio

ipopt_options.lb = [lbp;lbq;lbc];                               %lower bound on all variables
% 变量有节点压力、流量、压缩机压比、负荷

%upper bounds on variables
ubp=kron(ones(N1,1),ss.m.p_max_nd(ss.n.nonslack_nodes));
if(ss.m.doZ==1)
    ubp=kron(ones(N1,1),p_to_rho_nd(ss.m.p_max_nd(ss.n.nonslack_nodes),ss.c.b1,ss.c.b2,ss.c.psc));        %on pressure
end
ubq_val=10*max(abs(ss.n.q_max))/ss.c.qsc*ones(NE,1);
ubq_val(clinks)=ss.m.flow_max_nd./ss.m.xs(clinks);
ubq=kron(ones(N1,1),ubq_val);                                         %on flow
ubc=kron(ones(N1,1),ss.n.c_max);                                      %on compressor ratio
ipopt_options.ub = [ubp;ubq;ubc];                                 %upper bound on all variables


%lower bounds on constraints
ss.m.hplsc=1;
dischpliml=-kron(ones(N1,1),ss.m.p_max_nd(ss.n.comp_pos(:,1)));
if(ss.m.doZ==1),
    dischpliml=-kron(ones(N1,1),p_to_rho_nd(ss.m.p_max_nd(ss.n.comp_pos(:,1)),ss.c.b1,ss.c.b2,ss.c.psc));  %on discharge
end
hpliml=-kron(ones(N1,1),ss.m.boost_pow_max_nd)*ss.m.hplsc;       %on power
ipopt_options.cl = [ss.m.Beq;zeros(M*N1,1);dischpliml-1000000;hpliml-100000000];   %lower bounds on the constraint functions.
if(ss.intervals>1 && v==length(ss.Nvec) && ss.m.N>0)
    ipopt_options.cl=[ipopt_options.cl;ss.m.bineqlb]; end

%upper bounds on constraints
dischplimu=zeros(C*N1,1);                                        %on discharge
hplimu=zeros(C*N1,1);                                              %on power
ipopt_options.cu = [ss.m.Beq;zeros(M*N1,1);dischplimu+1000000;hplimu+1000000];   %upper bounds on the constraint functions.
if(ss.intervals>1 && v==length(ss.Nvec) && ss.m.N>0)
    ipopt_options.cu=[ipopt_options.cu;ss.m.binequb]; end

if(v==1)
    % 随机取变量作为初值
    xu0=full(min(max(rand(size(xu0)).*(ipopt_options.ub-ipopt_options.lb)+ipopt_options.lb,ipopt_options.lb),ipopt_options.ub));
    %xu0=full(min(max(xu0,ipopt_options.lb),ipopt_options.ub));
end



% IPOPT parameters

%scaling parameters
ss.m.smsc=ss.m.C*ss.m.Ts/2*max(ss.Nvec)/ss.m.cdw;  %weight cost on derivative of compressions in final step
ss.m.smsd=ss.m.GN*ss.m.Ts/2*max(ss.Nvec)/ss.m.ddw;  %weight cost on derivative of flexible demands in final step
ss.m.objsc=ss.m.Ts/2/ss.m.odw;                 %this scales the objective for ipopt

%Jacobian sparsity pattern
JS=sparse(abs(sign(pipe_jacobian_base_static(xr,ss.m))));
%sum(sum(abs(JS)>0))/prod(size(JS))

%Set the IPOPT options.
ipopt_options.ipopt.mu_strategy = 'adaptive';
ipopt_options.ipopt.hessian_approximation = 'limited-memory';
%options.ipopt.limited_memory_update_type = 'BFGS';
ipopt_options.ipopt.limited_memory_update_type = 'sr1';
ipopt_options.ipopt.max_iter = ss.m.maxiter;
ipopt_options.ipopt.print_level=5;
ipopt_tol=ss.m.opt_tol; %if(v==length(Nvec)) ipopt_tol=1e-4; end
ipopt_options.ipopt.tol = ipopt_tol;
ipopt_options.ipopt.constr_viol_tol = ipopt_tol/10;
ipopt_options.ipopt.acceptable_tol= ipopt_tol;
ipopt_options.ipopt.output_file=ss.output_file;

% The callback functions.
ipopt_funcs.objective         = @(xu) pipe_obj_base_static(xu,ss.m);
ipopt_funcs.gradient          = @(xu) pipe_grad_base_static(xu,ss.m);
ipopt_funcs.constraints       = @(xu) pipe_constraints_base_static(xu,ss.m);
ipopt_funcs.jacobian          = @(xu) pipe_jacobian_base_static(xu,ss.m);
ipopt_funcs.jacobianstructure = @() JS;
ipopt_funcs.hessian           = @() 1;
ipopt_funcs.hessianstructure  = @() 1;


% run optimization

disp(['Solving with ' num2str(ss.Nvec(v)) ' points...'])
% Run IPOPT several times (can't exit from mex file, so limit iterations)
[xf,ip_info] = ipopt(xu0,ipopt_funcs,ipopt_options);
if(ip_info.iter>ipopt_options.ipopt.max_iter-2)
    disp(['Solving again with ' num2str(ss.Nvec(v)) ' points...'])
    [xf,ip_info] = ipopt(xf,ipopt_funcs,ipopt_options);
end

%% Save old stuff
ss.m.xks=ss.m.xk;       %old LGL time grid for resampling
ss.m.N1s=ss.m.N1;    	%old time points
ss.m.Ns=ss.m.N;         %old time points
ss.xf=xf;


ipopt_net_time=toc, ss.m.ipopt_net_time=ipopt_net_time;

% save output

xf=ss.xf;
[ss.objval,ss.objecon,ss.objeff]=pipe_obj_base_static(xf,ss.m);
ss.resid=pipe_constraints_base_static(xf,ss.m);
ss.ip_info=ip_info;

if(ss.m.use_init_state==0)
    %restriction to original horizon if extension used
    ss.pp0=[reshape(xf(1:N1*FN),FN,N1) xf(1:FN)];
    ss.qq0=[reshape(xf(N1*FN+1:N1*M),NE,N1) xf(N1*FN+1:N1*FN+NE)];
    ss.cc0=[reshape(xf(N1*M+1:N1*M+N1*C),C,N1) xf(N1*M+1:N1*M+C)];
    ss.lmp0=-[reshape(ip_info.lambda(1:FN*N1),FN,N1) ip_info.lambda(1:FN)]/ss.m.odw;
    ss.mult0_pmax=[reshape(ip_info.lambda(N1*M+1:N1*(M+C)),C,N1) ip_info.lambda(N1*M+1:N1*M+C)]/ss.m.odw;
    ss.mult0_cmax=[reshape(ip_info.lambda(N1*(M+C)+1:N1*(M+2*C)),C,N1) ip_info.lambda(N1*(M+C)+1:N1*(M+C)+C)]/ss.m.odw;
end


ss.m.d=[ss.m.d ss.m.d(:,1)];
ss.tt0=[0:ss.m.N1]'*ss.c.T/ss.m.N1;

if(ss.m.save_state==1)
    ss.state_save=[...
        ss.pp0(:,ss.m.state_save_pts);...
        ss.qq0(:,ss.m.state_save_pts);...
        ss.cc0(:,ss.m.state_save_pts);...
        ss.fd0(:,ss.m.state_save_pts);...
        ss.m.d(:,ss.m.state_save_pts);...
        ss.m.prslack(:,ss.m.state_save_pts);...
        ss.m.pslack(:,ss.m.state_save_pts);...
        ss.mult0_pmax(:,ss.m.state_save_pts);...
        ss.mult0_cmax(:,ss.m.state_save_pts)];
end


% if(tr.Nvec(end)>1),
%     tr=rmfield(tr,{'dout','dlbout','dubout','prdout','prslout'}); end



%saved state uses density
ppp0=ss.pp0(:,1); qqq0=ss.qq0(:,1); ccc0=ss.cc0(:,1);
ss.m.ppp0=ppp0; ss.m.qqq0=qqq0; ss.m.ccc0=ccc0;
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
function [p]=rho_to_p_nd(rho,b1,b2,psc)
p=(-b1+sqrt(b1^2+4*b2*psc*rho))/(2*b2*psc);
end
function [rho]=p_to_rho_nd(p,b1,b2,psc)
rho=p.*(b1+b2*psc*p);
end


