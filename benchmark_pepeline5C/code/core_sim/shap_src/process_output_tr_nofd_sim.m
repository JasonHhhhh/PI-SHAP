function [par]=process_output_tr_nofd_sim(par)
% Anatoly Zlotnik, January 2019

mfolder=par.mfolder;
out=par.out;

if(par.out.dosim==1), sim=par.sim; end
tr=par.tr; 
psi_to_pascal=tr.c.psi_to_pascal;
mpa_to_psi=1000000/psi_to_pascal;
tr.c.mpa_to_psi=mpa_to_psi;
mmscfd_to_kgps=tr.c.mmscfd_to_kgps;
hp_to_watt=745.7;
if(par.out.doZ==1), b1=tr.c.b1; b2=tr.c.b2; end

%process simulation output
if(par.out.dosim==1)
    out.tt=sim.tt/3600;         %plotting time in hours
    out.qqinsim=sim.qqin;                  %flow boundary in
    out.qqoutsim=sim.qqout;                %flow boundary out
    if(par.out.plotnodal==1)
        out.ppsim=sim.pnodout(:,1:sim.n0.nv);  %pressure (nodal)
        out.qqsim=[out.qqinsim out.qqoutsim];  %all boundary flows
    else
        out.ppsim=sim.pnodout(:,1:sim.n.nv);   %pressure (all)
        out.qqsim=sim.qq;                      %flows (all)
    end
%     if(par.out.units==1), out.ppsim=out.ppsim/psi_to_pascal;
%         out.qqsim=out.qqsim/mmscfd_to_kgps;
%         out.qqinsim=out.qqinsim/mmscfd_to_kgps;  out.qqoutsim=out.qqoutsim/mmscfd_to_kgps;
%     end
end

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
par.tr.m_cost_every=out.cpowsim;% w
par.tr.m_var=abs(out.supp_flowsim-mean(out.supp_flowsim))/86400; % kgps/s
par.tr.m_supp=out.supp_flowsim; % kgps
par.tr.m_mass=mean(out.pipe_mass_0(:,1:5),2).*mmscfd_to_kgps; % kgps
% 取出24h内的
solsteps = par.sim.solsteps;
par.tr.m_cost=par.tr.m_cost(end-par.sim.solsteps:end,:);% w
par.tr.m_cost_every=par.tr.m_cost_every(end-par.sim.solsteps:end,:);% w
par.tr.m_var=par.tr.m_var(end-par.sim.solsteps:end,:); % kgps/s
par.tr.m_mass=par.tr.m_mass(end-par.sim.solsteps:end,:); % kgps
par.tr.m_supp=par.tr.m_supp(end-par.sim.solsteps:end,:); % kgps
par.tr.m_cc=sim.cc(end-par.sim.solsteps:end,:); % kgps

drr = diff(sim.cc)./diff(sim.tt);
rr = sim.cc(end-par.sim.solsteps:end,:);
tt = sim.tt(end-par.sim.solsteps:end,:);
drr = drr(end-par.sim.solsteps:end,:);

% 289到25份
index_get=1:12:289;
par.tr.shap.cc=rr(index_get,:);
par.tr.shap.m_cost=par.tr.m_cost(index_get,:);
par.tr.shap.m_cost_every=par.tr.m_cost_every(index_get,:);
par.tr.shap.m_dcc_every=drr(index_get,:);
par.tr.shap.m_mass=par.tr.m_mass(index_get,:);
par.tr.shap.m_supp=par.tr.m_supp(index_get,:);
par.tr.shap.m_var=par.tr.m_var(index_get,:);

% 这里做：cost和mass两个指标
%cost
% 对于一个指标序列，都可以套用shap函数去评估起点、终点、tr阶段的所有cc cc' 以及cc的shap值
% 整理shap等效时：每一个时刻的V的权重
item_shap_cost=par.tr.shap.m_cost_every(2:end,:)./par.tr.shap.m_dcc_every(2:end,:);
% par.tr.shap.item_shap_cost=item_shap_cost;
par.tr.shap.ori_Jcost= sum(par.tr.shap.m_cost_every(2:end,:).*(sim.tt(2)-sim.tt(1)));
par.tr.shap.shap_Jcost = sum(item_shap_cost.*((par.tr.shap.cc(2:end,:)-par.tr.shap.cc(1:end-1,:))));
par.tr.shap.item_shap_cost = item_shap_cost.*((par.tr.shap.cc(2:end,:)-par.tr.shap.cc(1:end-1,:)));
% 
wmid_shap_cost=item_shap_cost(1:end-1,:)-item_shap_cost(2:end,:);
wend_shap_cost=item_shap_cost(end,:);w0_shap_cost=-item_shap_cost(1,:);
wall_shap_cost=[w0_shap_cost;wmid_shap_cost;wend_shap_cost];
par.tr.shap.wall_shap_cost=wall_shap_cost./max(wall_shap_cost);
% shapW_Jcost = sum(wall_shap_cost.*par.tr.shap.cc);
% sum(wmid_shap_cost.*par.tr.shap.cc(2:end-1,:))
% wmid_shap_cost_sc=wmid_shap_cost./ori_Jcost;
% 对cost：正为正贡献；负为负贡献。因为压比始终为正
% mass
item_shap_supp=par.tr.shap.m_supp(2:end,:)./par.tr.shap.m_dcc_every(2:end,:)./5;
% par.tr.shap.item_shap_supp=item_shap_supp;
par.tr.shap.ori_Jsupp= sum(par.tr.shap.m_supp(2:end,:).*(sim.tt(2)-sim.tt(1)));
% 二者不一定相同，因为存在离散误差;而且我们假设了动作cc和M的关系，是一个模糊的隐函数，这里不纠结相等的积分关系
par.tr.shap.item_shap_supp = item_shap_supp.*((par.tr.shap.cc(2:end,:)-par.tr.shap.cc(1:end-1,:)));
% 
wmid_shap_supp=item_shap_supp(1:end-1,:)-item_shap_supp(2:end,:);
wend_shap_supp=item_shap_supp(end,:);w0_shap_supp=-item_shap_supp(1,:);
wall_shap_supp=[w0_shap_supp;wmid_shap_supp;wend_shap_supp];
par.tr.shap.wall_shap_supp=wall_shap_supp./max(wall_shap_supp);
% shapW_Jsupp = mean(sum(wall_shap_supp.*par.tr.shap.cc));
% shap有一个性质：
% 起点的shap value是一定的

% var 减少压力波动
item_shap_var=par.tr.shap.m_var(2:end,:)./par.tr.shap.m_dcc_every(2:end,:)./5;
% par.tr.shap.item_shap_var=item_shap_var;
par.tr.shap.ori_Jvar= sum(par.tr.shap.m_var(2:end,:).*(sim.tt(2)-sim.tt(1)));
% 二者不一定相同，因为存在离散误差;而且我们假设了动作cc和M的关系，是一个模糊的隐函数，这里不纠结相等的积分关系
par.tr.shap.item_shap_var = item_shap_var.*((par.tr.shap.cc(2:end,:)-par.tr.shap.cc(1:end-1,:)));
% 
wmid_shap_var=item_shap_var(1:end-1,:)-item_shap_var(2:end,:);
wend_shap_var=item_shap_var(end,:);w0_shap_var=-item_shap_var(1,:);
wall_shap_var=[w0_shap_var;wmid_shap_var;wend_shap_var];
par.tr.shap.wall_shap_var=wall_shap_var./max(wall_shap_var);


a = 4444;


%out.mult0_pmax=tr.mult0_pmax/2*tr.m.N/(tr.c.psc/1000000)/mpa_to_psi;    %output pressure marginal prices ($/
%out.mult0_cmax=tr.mult0_cmax/2*tr.m.N*3.6/0.75; %compression marginal prices ($/hp)

function [xints]=pts_to_int(tpts,xpts,ibnds)
    xbnds=interp1qr(tpts,xpts,ibnds); In=length(ibnds)-1;
    xints=(xbnds(1:In,:)+xbnds(2:In+1,:))/2;
return;