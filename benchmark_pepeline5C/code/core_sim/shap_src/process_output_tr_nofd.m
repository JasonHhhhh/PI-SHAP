function [par]=process_output_tr_nofd(par)
% Anatoly Zlotnik, January 2019

% mfolder=par.mfolder;
out=par.out;

tr=par.tr; 

psi_to_pascal=tr.c.psi_to_pascal;
mpa_to_psi=1000000/psi_to_pascal;
tr.c.mpa_to_psi=mpa_to_psi;
mmscfd_to_kgps=tr.c.mmscfd_to_kgps;
hp_to_watt=745.7;
if(par.out.doZ==1), b1=tr.c.b1; b2=tr.c.b2; end

%compute mass in pipes
% sim.pp是归一化结果 simppin\out等,以及sim.qq都是正常值 
if(tr.m.doZ==1), p_density=p_to_rho(sim.pp',tr.c.b1,tr.c.b2,sim);
else p_density=tr.c.psc*sim.pp'/(tr.c.gasR*tr.c.gasT); end
p_comp=sim.cc';
out.p_mass=pipe_mass_sim_noextd(p_density,p_comp,sim.m);    %all pipes
out.pipe_mass_0=(par.tr.n.disc_to_edge*out.p_mass)';       %original pipes
if(par.out.units==1),out.pipe_mass_0=out.pipe_mass_0/mmscfd_to_kgps/86400;end

slinks=sim.m.comp_pos(sim.m.spos,2); 
out.supp_flowsim=sim.qq(:,slinks);    %supply flow 

%pipe inlet and outlet flux
% sim.ffin=sim.ff(:,sim.n.from_flows);
% sim.ffout=sim.ff(:,sim.n.to_flows);

%     out.ppinopt=tr.ppin; out.ppoutopt=tr.ppout;
%     if(par.out.units==1), out.ppopt=out.ppopt/psi_to_pascal; out.ppoptnodal=out.ppoptnodal/psi_to_pascal;
%         out.ppinopt=tr.ppin/psi_to_pascal; out.ppoutopt=tr.ppout/psi_to_pascal;
%         out.qqopt=out.qqopt/mmscfd_to_kgps; out.qqinopt=out.qqinopt/mmscfd_to_kgps;
%         out.qqoutopt=out.qqoutopt/mmscfd_to_kgps; out.pipe_mass_0=out.pipe_mass_0/mmscfd_to_kgps/86400; 
%     end

%compressor discharge pressures ok!!

psim1=interp1qr(out.tt,out.ppsim,out.tt);
if(par.out.dosim==1), out.csetsim=psim1(:,sim.m.comp_pos(:,1)); end


%check nodal flow balance 
% out.flowbal=tr.n0.Amp*out.qqoutopt'+tr.n0.Amm*out.qqinopt'-out.flows_all;
% out.flowbalrel=3*out.flowbal./(abs(tr.n0.Amp*out.qqoutopt')+abs(tr.n0.Amm*out.qqinopt')+abs(out.flows_all));
% out.flowbalrel(mean(out.flowbal')./mean(out.flowbalrel')<tr.m.opt_tol,:)=0; out.flowbalrel=out.flowbalrel';

%out.flowbals=tr.n0.Amp*out.qqoutsim'+tr.n0.Amm*out.qqinsim'-out.flows_all;
%out.flowbalsrel=3*out.flowbal./(abs(tr.n0.Amp*out.qqoutsim')+abs(tr.n0.Amm*out.qqinsim')+abs(out.flows_all));
%out.flowbalsrel(mean(out.flowbal')./mean(out.flowbalrel')<tr.m.opt_tol,:)=0;

%compressor power ok!!
if(par.out.dosim==1)
    cpossim=sim.m.comp_pos; m=sim.m.mpow;
    qcompsim=out.qqsim(:,cpossim(:,2)); %cpow_nd=(abs(qcompopt)).*((tr.cc0').^(m)-1);
    out.cpowsim=(abs(qcompsim)).*((sim.cc'').^(m)-1)*sim.m.Wc;   %comp power in Watts
end
% out.ccopt=tr.cc0';
% cposopt=par.tr.m.comp_pos; m=tr.m.mpow;
% qcompopt=qq(:,cposopt(:,2)); %cpow_nd=(abs(qcompopt)).*((tr.cc0').^(m)-1);
% out.cpowopt=(abs(qcompopt)).*((tr.cc0').^(m)-1)*tr.m.Wc;   %comp power in Watts
out.td=sim.m.xd/3600; 

out.guniqueind=sim.m.guniqueind; out.gunique=sim.m.gunique; out.fn=sim.m.fn; out.pn=sim.m.pn;
out.n0=sim.n0; out.n=sim.n; out.gd=sim.m.gd; out.gs=sim.m.gs; out.FN=sim.m.FN; out.PN=sim.m.PN;
out.cn=sim.m.C; 
out.mfolder=par.mfolder;

if(par.out.savecsvoutput==1)
    if(par.out.intervals_out==0)
        pipe_cols=[1:out.n0.ne-out.n0.nc]; comp_cols=[out.n0.ne-out.n0.nc+1:out.n0.ne];
%         dlmwrite([mfolder '\output_ts_tpts.csv'],double(out.tt),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\output_ts_pipe-pressure-in.csv'],double([pipe_cols;sim.ppin(:,pipe_cols)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\output_ts_pipe-pressure-out.csv'],double([pipe_cols;sim.ppout(:,pipe_cols)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\output_ts_comp-pressure-in.csv'],double([1:out.n0.nc;sim.ppin(:,comp_cols)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\output_ts_comp-pressure-out.csv'],double([1:out.n0.nc;sim.ppout(:,comp_cols)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\output_ts_pipe-flow-in.csv'],double([pipe_cols;out.qqinsim(:,pipe_cols)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\output_ts_pipe-flow-out.csv'],double([pipe_cols;out.qqoutsim(:,pipe_cols)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\output_ts_comp-flow-in.csv'],double([1:out.n0.nc;out.qqinsim(:,comp_cols)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\output_ts_comp-flow-out.csv'],double([1:out.n0.nc;out.qqoutsim(:,comp_cols)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\output_ts_slack-flows.csv'],double([out.pn';out.supp_flowsim]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\output_ts_comp-ratios.csv'],double([[1:out.cn];sim.cc]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\output_ts_comp-discharge-pressure.csv'],double([[1:out.cn];out.csetsim]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\output_ts_comp-power.csv'],double([[1:out.cn];out.cpowsim]),'precision',16,'delimiter',',');
%          dlmwrite([mfolder '\output_ts_pipe-mass.csv'],double([pipe_cols;out.pipe_mass_0(:,pipe_cols)]),'precision',16,'delimiter',',');
%          dlmwrite([mfolder '\output_ts_flowbalrel.csv'],double([[1:out.n0.nv];out.flowbalrel]),'precision',16,'delimiter',',');
    end
    
end

out.dbase=tr.m.Yq(1:length(tr.m.fn),:)'*tr.c.qsc; 
par.out=out;
par.tr=tr;
par.tr.m_cost=mean(out.cpowsim,2);% w
par.tr.m_var=abs(out.supp_flowsim-mean(out.supp_flowsim))/86400; % kgps/s
par.tr.m_supp=out.supp_flowsim; % kgps
par.tr.m_mass=mean(out.pipe_mass_0(:,1:5),2).*mmscfd_to_kgps; % kgps

solsteps = par.sim.solsteps;
m_cost=par.tr.m_cost(end-par.sim.solsteps:end,:);% w
m_var=par.tr.m_var(end-par.sim.solsteps:end,:); % kgps/s
m_mass=par.tr.m_mass(end-par.sim.solsteps:end,:); % kgps
m_supp=par.tr.m_supp(end-par.sim.solsteps:end,:); % kgps

m_cost=m_cost/mean(m_cost);% w
m_var=m_var/mean(m_var); % kgps/s
m_supp=m_supp/mean(m_supp); % kgps
m_mass=m_mass/mean(m_mass); % kgps

drr = diff(sim.cc)./diff(sim.tt);
rr = sim.cc(end-par.sim.solsteps:end,:);
tt = sim.tt(end-par.sim.solsteps:end,:);
drr = drr(end-par.sim.solsteps:end,:);
interval = (length(tt)-1)/24;
ind = 1:interval:length(tt);
par.shap_cost = zeros(25,5);
par.shap_mass = zeros(25,5);
par.shap_var = zeros(25,5);
par.shap_supp = zeros(25,5);
par.shap_error = zeros(4,5);
% 测试一下 DH-SHAP
for ii=1:length(par.id_v)
    id_c = par.id_v(ii);
    r=rr(:,id_c); % 仅仅压比是被研究的动作
    dr=drr(:,id_c);

    shap_cost = zeros(solsteps+1,1);
    shap_cost(1) = -m_cost(2)./dr(2).*r(1);
    shap_cost(end) = m_cost(end)./dr(end).*r(end);
    for i=2:solsteps
        shap_cost(i)=((m_cost(i)./dr(i))-(m_cost(i+1)./dr(i+1))).*r(i);
    end
    cost_shap = sum(shap_cost);
%     shap_cost_fun=@(t) interp1qr(tt,shap_cost,t);
%     shap_cost_h= shap_cost_fun(tt_h);
    shap_cost_h= shap_cost(ind);
    costfun=@(t) interp1qr(tt,m_cost,t);
    cost_ori=quadl(@(t) costfun(t'),tt(1),tt(end))';
    shap_cost_error = (cost_shap-cost_ori)./cost_ori;

    shap_var = zeros(solsteps+1,1);
    shap_var(1) = -m_var(2)./dr(2).*r(1);
    shap_var(end) = m_var(end)./dr(end).*r(end);
    for i=2:solsteps
        shap_var(i)=((m_var(i)./dr(i))-(m_var(i+1)./dr(i+1))).*r(i);
    end
    var_shap = sum(shap_var);
%     shap_var_fun=@(t) interp1qr(tt,shap_var,t);
%     shap_var_h= shap_var_fun(tt_h);
    shap_var_h= shap_var(ind);
    varfun=@(t) interp1qr(tt,m_var,t);
    var_ori=quadl(@(t) varfun(t'),tt(1),tt(end))';
    shap_var_error = (var_shap-var_ori)./var_ori;

    shap_mass = zeros(solsteps+1,1);
    shap_mass(1) = -m_mass(2)./dr(2).*r(1);
    shap_mass(end) = m_mass(end)./dr(end).*r(end);
    for i=2:solsteps
        shap_mass(i)=((m_mass(i)./dr(i))-(m_mass(i+1)./dr(i+1))).*r(i);
    end
    % 采样得到25个时间点的shap
%     shap_mass_fun=@(t) interp1qr(tt,shap_mass,t);
%     shap_mass_h= shap_mass_fun(tt_h);
    shap_mass_h= shap_mass(ind);
    mass_shap = sum(shap_mass);
    massfun=@(t) interp1qr(tt,m_mass,t);
    mass_ori=quadl(@(t) massfun(t'),tt(1),tt(end))';
    shap_mass_error = (mass_shap-mass_ori)./mass_ori;

    shap_supp = zeros(solsteps+1,1);
    shap_supp(1) = -m_supp(2)./dr(2).*r(1);
    shap_supp(end) = m_supp(end)./dr(end).*r(end);
    for i=2:solsteps
        shap_supp(i)=((m_supp(i)./dr(i))-(m_supp(i+1)./dr(i+1))).*r(i);
    end
    % 采样得到25个时间点的shap
    %     shap_supp_fun=@(t) interp1qr(tt,shap_supp,t);
    %     shap_supp_h= shap_supp_fun(tt_h);
    shap_supp_h= shap_supp(ind);
    supp_shap = sum(shap_supp);
    suppfun=@(t) interp1qr(tt,m_supp,t);
    supp_ori=quadl(@(t) suppfun(t'),tt(1),tt(end))';
    shap_supp_error = (supp_shap-supp_ori)./supp_ori;

    par.shap_cost(:,id_c)=shap_cost_h;
    par.shap_var(:,id_c)=shap_var_h;
    par.shap_mass(:,id_c)=shap_mass_h;
    par.shap_supp(:,id_c)=shap_supp_h; % 与以上不同
    par.shap_error(:,id_c)=[shap_cost_error,shap_var_error,shap_mass_error,shap_supp_error];
end
a = 4444;


%out.mult0_pmax=tr.mult0_pmax/2*tr.m.N/(tr.c.psc/1000000)/mpa_to_psi;    %output pressure marginal prices ($/
%out.mult0_cmax=tr.mult0_cmax/2*tr.m.N*3.6/0.75; %compression marginal prices ($/hp)

function [xints]=pts_to_int(tpts,xpts,ibnds)
    xbnds=interp1qr(tpts,xpts,ibnds); In=length(ibnds)-1;
    xints=(xbnds(1:In,:)+xbnds(2:In+1,:))/2;
return;