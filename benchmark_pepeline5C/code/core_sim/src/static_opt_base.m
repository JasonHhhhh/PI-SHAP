function [tr]=static_opt_base(tr)

tr.Nvec_old=tr.Nvec;tr.m.Ts_old=tr.m.Ts;

%load sizes
FN=tr.m.FN;    % # of flow nodes
PN=tr.m.PN;    % # of pressure nodes 气源
GN=tr.m.GN;    % # of gNodes
NE=tr.m.NE;    % # of edges
M=tr.m.M;      % # of state variables - edges and nodes
C=tr.m.C;      % # of compressors
tr.m.int_flow_const=0; % 不知道是干嘛的
tic,
% 要求解的时间结点，此处稳态为0，动态为?
for v=1:length(tr.Nvec)        %iterate optimizations for increasing discretization

    % Low-order derivative scheme
    tr.m.N=0;                 % time discretization points
    N=tr.m.N;       % # of time intervals
    N1=tr.m.N+1;    % # of time collocation points

    tr.m.x=0;tr.m.D=0;tr.m.w=1;tr.m.t=0;tr.m.N1=1;tr.m.tk=0;tr.m.xk=0;

    % Initialize Optimization

    % demands and prices on collocation nodes

    tr.m.d=tr.m.Yq1; % 稀疏阵：气体流出或进入的每个节点的流量，归一化后
    tr.m.prslack=tr.m.Prslack1;% 气源价格
    tr.m.pslack=tr.m.Pslack1;% 气源压力
    if(tr.m.doZ==1), tr.m.pslack=p_to_rho_nd(tr.m.Pslack1,tr.c.b1,tr.c.b2,tr.c.psc); end



    % initial guess
    %variables e.g. x_{ij} have space in i (rows) and time in j (cols)
    % 列为时间结点
    % 行为空间结点
    %stack columns x_i in a single vector
    if(v==1)
        if(tr.m.use_init_state==0)
            pp0=kron(ones(N1,1),tr.m.p_min_nd(tr.n.nonslack_nodes));   %initialize density 时间-空间矩阵
            qq0=kron(zeros(N1,1),ones(NE,1));                %initialize flux
            cc0=kron(ones(N1,1),tr.n.c_max);                %initialize compressions
        elseif(tr.m.use_init_state==1)
            pp0=kron(ones(N,1),tr.m.p_min_nd(tr.n.nonslack_nodes));   %initialize density
            qq0=kron(zeros(N,1),ones(NE,1));                %initialize flux
            cc0=kron(ones(N,1),tr.n.c_max);                %initialize compressions
        end
        xu0=[pp0;qq0;cc0];                               %stack it all in a vector
        xr=xu0+rand(size(xu0))/1000;                     %perturb (used to get Jacobian structure)
    end

    %define constraints

    %discharge pressure setpoints

    %linear equality constraints
    tr.m.Aeq=[];
    tr.m.Beq=[];

    %     tr.m.Beq=[pp_init;qq_init;cc_init;dd_init];
    %     tr.m.Aeq=sparse(FN+NE+C+GN,(FN+NE+C+GN)*N1);
    %     tr.m.Aeq(1:FN,1:FN)=sparse(eye(FN));
    %     tr.m.Aeq(FN+1:FN+NE,N1*FN+1:N1*FN+NE)=sparse(eye(NE));
    %     tr.m.Aeq(FN+NE+1:FN+NE+C,N1*(FN+NE)+1:N1*(FN+NE)+C)=sparse(eye(C));
    %     tr.m.Aeq(FN+NE+C+1:FN+NE+C+GN,N1*(FN+NE+C)+1:N1*(FN+NE+C)+GN)=sparse(eye(GN));

    %links from supplier slack nodes
    slinks=tr.m.comp_pos(tr.m.spos,2);% 得到索引而已
    clinks=tr.m.comp_pos(:,2);

    %relax bounds on optimized flows at gnodes so that interval-averaged
    % bounds dominate ？？？？ 用于后续动态时间的出口流量约束
    bnd_rel=2;
    %lower bounds on variables
    lbp=kron(ones(N1,1),tr.m.p_min_nd(tr.n.nonslack_nodes));
    if(tr.m.doZ==1),
        lbp=kron(ones(N1,1),p_to_rho_nd(tr.m.p_min_nd(tr.n.nonslack_nodes),tr.c.b1,tr.c.b2,tr.c.psc));      %on pressure
    end
    %lbq=kron(ones(N1,1),-10*max(abs(tr.n.q_max))*ones(NE,1)/tr.c.qsc); %on flow
    lbq_val=-10*max(abs(tr.n.q_max))/tr.c.qsc*ones(NE,1);
    lbq_val(clinks)=tr.m.flow_min_nd./tr.m.xs(clinks);
    lbq_val(slinks)=zeros(length(slinks),1);
    lbq=kron(ones(N1,1),lbq_val);                                       %on flow
    lbc=kron(ones(N1,1),tr.n.c_min);                                    %on compressor ratio
                                
    ipopt_options.lb = [lbp;lbq;lbc];                               %lower bound on all variables
    % 变量有节点压力、流量、压缩机压比、负荷

    %upper bounds on variables
    ubp=kron(ones(N1,1),tr.m.p_max_nd(tr.n.nonslack_nodes));
    if(tr.m.doZ==1),
        ubp=kron(ones(N1,1),p_to_rho_nd(tr.m.p_max_nd(tr.n.nonslack_nodes),tr.c.b1,tr.c.b2,tr.c.psc));        %on pressure
    end
    ubq_val=10*max(abs(tr.n.q_max))/tr.c.qsc*ones(NE,1);
    ubq_val(clinks)=tr.m.flow_max_nd./tr.m.xs(clinks);
    ubq=kron(ones(N1,1),ubq_val);                                         %on flow
    ubc=kron(ones(N1,1),tr.n.c_max);                                      %on compressor ratio
    ipopt_options.ub = [ubp;ubq;ubc];                                 %upper bound on all variables


    %lower bounds on constraints
    tr.m.hplsc=1;
    dischpliml=-kron(ones(N1,1),tr.m.p_max_nd(tr.n.comp_pos(:,1)));
    if(tr.m.doZ==1),
        dischpliml=-kron(ones(N1,1),p_to_rho_nd(tr.m.p_max_nd(tr.n.comp_pos(:,1)),tr.c.b1,tr.c.b2,tr.c.psc));  %on discharge
    end
    hpliml=-kron(ones(N1,1),tr.m.boost_pow_max_nd)*tr.m.hplsc;       %on power
    ipopt_options.cl = [tr.m.Beq;zeros(M*N1,1);dischpliml;hpliml];   %lower bounds on the constraint functions.
    if(tr.intervals>1 && v==length(tr.Nvec) && tr.m.N>0)
        ipopt_options.cl=[ipopt_options.cl;tr.m.bineqlb]; end

    %upper bounds on constraints
    dischplimu=zeros(C*N1,1);                                        %on discharge
    hplimu=zeros(C*N1,1);                                              %on power
    ipopt_options.cu = [tr.m.Beq;zeros(M*N1,1);dischplimu;hplimu];   %upper bounds on the constraint functions.
    if(tr.intervals>1 && v==length(tr.Nvec) && tr.m.N>0)
        ipopt_options.cu=[ipopt_options.cu;tr.m.binequb]; end

    if(v==1)
        % 随机取变量作为初值
        xu0=full(min(max(rand(size(xu0)).*(ipopt_options.ub-ipopt_options.lb)+ipopt_options.lb,ipopt_options.lb),ipopt_options.ub));
        %xu0=full(min(max(xu0,ipopt_options.lb),ipopt_options.ub));
    end

end


% IPOPT parameters

%scaling parameters
tr.m.smsc=tr.m.C*tr.m.Ts/2*max(tr.Nvec)/tr.m.cdw;  %weight cost on derivative of compressions in final step
tr.m.smsd=tr.m.GN*tr.m.Ts/2*max(tr.Nvec)/tr.m.ddw;  %weight cost on derivative of flexible demands in final step
tr.m.objsc=tr.m.Ts/2/tr.m.odw;                 %this scales the objective for ipopt

%Jacobian sparsity pattern
JS=sparse(abs(sign(pipe_jacobian_base_static(xr,tr.m))));
%sum(sum(abs(JS)>0))/prod(size(JS))

%Set the IPOPT options.
ipopt_options.ipopt.mu_strategy = 'adaptive';
ipopt_options.ipopt.hessian_approximation = 'limited-memory';
%options.ipopt.limited_memory_update_type = 'BFGS';
ipopt_options.ipopt.limited_memory_update_type = 'sr1';
ipopt_options.ipopt.max_iter = tr.m.maxiter;
ipopt_options.ipopt.print_level=5;
ipopt_tol=tr.m.opt_tol; %if(v==length(Nvec)) ipopt_tol=1e-4; end
ipopt_options.ipopt.tol = ipopt_tol;
ipopt_options.ipopt.constr_viol_tol = ipopt_tol/10;
ipopt_options.ipopt.acceptable_tol= ipopt_tol;
ipopt_options.ipopt.output_file=tr.output_file;

% The callback functions.
ipopt_funcs.objective         = @(xu) pipe_obj_base_static(xu,tr.m);
ipopt_funcs.gradient          = @(xu) pipe_grad_base_static(xu,tr.m);
ipopt_funcs.constraints       = @(xu) pipe_constraints_base_static(xu,tr.m);
ipopt_funcs.jacobian          = @(xu) pipe_jacobian_base_static(xu,tr.m);
ipopt_funcs.jacobianstructure = @() JS;
ipopt_funcs.hessian           = @() 1;
ipopt_funcs.hessianstructure  = @() 1;


% run optimization

disp(['Solving with ' num2str(tr.Nvec(v)) ' points...'])
% Run IPOPT several times (can't exit from mex file, so limit iterations)
[xf,ip_info] = ipopt(xu0,ipopt_funcs,ipopt_options);
if(ip_info.iter>ipopt_options.ipopt.max_iter-2)
    disp(['Solving again with ' num2str(tr.Nvec(v)) ' points...'])
    [xf,ip_info] = ipopt(xf,ipopt_funcs,ipopt_options);
end

%% Save old stuff
tr.m.xks=tr.m.xk;       %old LGL time grid for resampling
tr.m.N1s=tr.m.N1;    	%old time points
tr.m.Ns=tr.m.N;         %old time points
tr.xf=xf;


ipopt_net_time=toc, tr.m.ipopt_net_time=ipopt_net_time;

% save output

xf=tr.xf;
[tr.objval,tr.objecon,tr.objeff]=pipe_obj_base_static(xf,tr.m);
tr.resid=pipe_constraints_base_static(xf,tr.m);
tr.ip_info=ip_info;

if(tr.m.use_init_state==0)
    %restriction to original horizon if extension used
    tr.pp0=[reshape(xf(1:N1*FN),FN,N1) xf(1:FN)];
    tr.qq0=[reshape(xf(N1*FN+1:N1*M),NE,N1) xf(N1*FN+1:N1*FN+NE)];
    tr.cc0=[reshape(xf(N1*M+1:N1*M+N1*C),C,N1) xf(N1*M+1:N1*M+C)];
    tr.lmp0=-[reshape(ip_info.lambda(1:FN*N1),FN,N1) ip_info.lambda(1:FN)]/tr.m.odw;
    tr.mult0_pmax=[reshape(ip_info.lambda(N1*M+1:N1*(M+C)),C,N1) ip_info.lambda(N1*M+1:N1*M+C)]/tr.m.odw;
    tr.mult0_cmax=[reshape(ip_info.lambda(N1*(M+C)+1:N1*(M+2*C)),C,N1) ip_info.lambda(N1*(M+C)+1:N1*(M+C)+C)]/tr.m.odw;
end


tr.m.d=[tr.m.d tr.m.d(:,1)];
tr.m.prslack=tr.m.Prslack1;
tr.m.pslack=tr.m.Pslack1;
tr.tt0=[0:tr.m.N1]'*tr.c.T/tr.m.N1;

if(tr.m.save_state==1)
    tr.state_save=[...
        tr.pp0(:,tr.m.state_save_pts);...
        tr.qq0(:,tr.m.state_save_pts);...
        tr.cc0(:,tr.m.state_save_pts);...
        tr.fd0(:,tr.m.state_save_pts);...
        tr.m.d(:,tr.m.state_save_pts);...
        tr.m.prslack(:,tr.m.state_save_pts);...
        tr.m.pslack(:,tr.m.state_save_pts);...
        tr.mult0_pmax(:,tr.m.state_save_pts);...
        tr.mult0_cmax(:,tr.m.state_save_pts)];
end


% if(tr.Nvec(end)>1),
%     tr=rmfield(tr,{'dout','dlbout','dubout','prdout','prslout'}); end



%saved state uses density
ppp0=tr.pp0(:,1); qqq0=tr.qq0(:,1); ccc0=tr.cc0(:,1);
tr.m.ppp0=ppp0; tr.m.qqq0=qqq0; tr.m.ccc0=ccc0;
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


