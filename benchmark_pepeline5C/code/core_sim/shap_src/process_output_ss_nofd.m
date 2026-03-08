function [par]=process_output_ss_nofd(par,ss_name)
% Anatoly Zlotnik, February 2019

% mfolder=par.mfolder;
out=par.out;
% 
% ss_terminal=par.ss_terminal; 

ss_this=par.(ss_name);

psi_to_pascal=ss_this.c.psi_to_pascal;
mpa_to_psi=1000000/psi_to_pascal;
ss_this.c.mpa_to_psi=mpa_to_psi;
mmscfd_to_kgps=ss_this.c.mmscfd_to_kgps;
hp_to_watt=745.7;
if(par.out.doZ==1), b1=ss_this.c.b1; b2=ss_this.c.b2; end

%process_terminal optimization output
%process_terminal dimensional solution (metric)
pp=zeros(length(ss_this.tt0),ss_this.n0.nv);
%s_nodal=[ss_terminal.m.pslack ss_terminal.m.pslack(:,1)];
s_nodal=ss_this.m.pslack;
if(ss_this.m.extension>0), s_nodal=ss_this.m.pslack; end
scf=find(ismember(ss_this.m.snodes,ss_this.m.comp_pos(ss_this.m.spos,1)));
s(scf,:)=ss_this.cc0(ss_this.m.spos,:).*s_nodal(scf,:);
pp(:,ss_this.m.snodes)=s';
pp(:,ss_this.m.dnodes)=ss_this.pp0';
qq=ss_this.qq0'*ss_this.m.Xs*ss_this.c.qsc; 
ff=ss_this.qq0'*ss_this.c.qsc; 
for j=1:length(ss_this.m.dpos)
    cpj=ss_this.n.comp_pos(ss_this.m.dpos(j),1);
    pp(:,cpj)=pp(:,cpj).*ss_this.cc0(ss_this.m.dpos(j),:)';
end
%nodal press_terminalure (before compress_terminalors)
pp_nodal=zeros(length(ss_this.tt0),ss_this.n.nv);
pp_nodal(:,ss_this.m.snodes)=s_nodal';
pp_nodal(:,ss_this.m.dnodes)=ss_this.pp0';

if(ss_this.m.doZ==1), pp=rho_to_p_nd(pp,ss_this.c.b1,ss_this.c.b2,ss_this.c.psc);
    pp_nodal=rho_to_p_nd(pp_nodal,ss_this.c.b1,ss_this.c.b2,ss_this.c.psc); end

%compute mass_terminal in pipes
if(ss_this.m.doZ==1), p_density=p_to_rho(pp',ss_this.c.b1,ss_this.c.b2,ss_this);
else p_density=ss_this.c.psc*pp'/(ss_this.c.gasR*ss_this.c.gasT); end
p_comp=ss_this.cc0;
out.(ss_name).p_mass=pipe_mass(p_density,p_comp,ss_this.m);    %all pipes
out.(ss_name).pipe_mass_0=(ss_this.n.disc_to_edge*out.(ss_name).p_mass)';       %original pipes

ss_this.pnodin=pp_nodal*ss_this.c.psc;   %nodal press_terminalures (before compress_terminalion)
ss_this.pnodout=pp*ss_this.c.psc;     %nodal press_terminalures (after compress_terminalion)
ss_this.qqin=qq(:,ss_this.n.from_flows);
ss_this.qqout=qq(:,ss_this.n.to_flows);
%pipe inlet and outlet press_terminalure (compress_terminalors only at inlets)
for j=1:ss_this.n0.ne
    if(ss_this.n0.comp_bool(j)==1)
        %ss_terminal.ppin(:,j)=ss_terminal.pnodout(:,ss_terminal.n0.from_id(j));
        ss_this.ppin(:,j)=ss_this.pnodin(:,ss_this.n0.from_id(j));
        ss_this.ppout(:,j)=ss_this.pnodin(:,ss_this.n0.to_id(j));
    elseif(ss_this.n0.comp_bool(j)==0)
        ss_this.ppin(:,j)=ss_this.pnodin(:,ss_this.n0.from_id(j));
        ss_this.ppout(:,j)=ss_this.pnodin(:,ss_this.n0.to_id(j));
    end
end
%pipe inlet and outlet flux
ss_this.ffin=ff(:,ss_this.n.from_flows);
ss_this.ffout=ff(:,ss_this.n.to_flows);

out.(ss_name).tt0=ss_this.tt0/3600;         %plotting time in hours
out.(ss_name).qqinopt=ss_this.qqin;                  %flow boundary in
out.(ss_name).qqoutopt=ss_this.qqout;                %flow boundary out
%if(par.out.plotnodal==1)
    out.(ss_name).ppoptnodal=ss_this.pnodin(:,1:ss_this.n0.nv);
    out.(ss_name).ppopt=ss_this.pnodout(:,1:ss_this.n0.nv);  %press_terminalure (nodal)
    out.(ss_name).qqopt=[out.(ss_name).qqinopt out.(ss_name).qqoutopt];  %all boundary flows
%else
    %out.ppoptall=ss_terminal.pnodout(:,1:ss_terminal.n.nv);   %press_terminalure (all)
    %out.qqoptall=ss_terminal.qq0;                      %flows (all)
%end
out.(ss_name).ppinopt=ss_this.ppin; out.(ss_name).ppoutopt=ss_this.ppout;
if(par.out.units==1), out.(ss_name).ppopt=out.(ss_name).ppopt/psi_to_pascal; out.(ss_name).ppoptnodal=out.(ss_name).ppoptnodal/psi_to_pascal; 
out.(ss_name).ppinopt=ss_this.ppin/psi_to_pascal; out.(ss_name).ppoutopt=ss_this.ppout/psi_to_pascal; 
out.(ss_name).qqopt=out.(ss_name).qqopt/mmscfd_to_kgps; out.(ss_name).qqinopt=out.(ss_name).qqinopt/mmscfd_to_kgps;  
out.(ss_name).qqoutopt=out.(ss_name).qqoutopt/mmscfd_to_kgps; out.(ss_name).pipe_mass_0=out.(ss_name).pipe_mass_0/mmscfd_to_kgps/86400; end

%market flow solution
ss_this.m.Yd=[ss_this.m.Yq1(1:ss_this.m.FN) ss_this.m.Yq1(1:ss_this.m.FN)];
% ss_terminal.m.Yd(ss_terminal.m.guniqueind,:)=ss_terminal.m.Yd(ss_terminal.m.guniqueind,:)+ss_terminal.m.gtod*ss_terminal.fd0;
%ss_terminal.m.Yd=interp1qr(ss_terminal.m.xd',ss_terminal.m.Yq(1:ss_terminal.m.FN,:)',ss_terminal.tt0)';
%ss_terminal.m.Yd(ss_terminal.m.guniqueind,:)=ss_terminal.m.Yd(ss_terminal.m.guniqueind,:)+ss_terminal.m.gtod*ss_terminal.fd0;
% ss_terminal.m.Ygd=ss_terminal.fd0(1:length(ss_terminal.m.gd),:);
% ss_terminal.m.Ygs=-ss_terminal.fd0(length(ss_terminal.m.gd)+1:length(ss_terminal.m.gall),:);

%compress_terminalor discharge press_terminalures
%if(par.out.dosim==1), out.csetsim=psim1(:,ss_terminal.m.comp_pos(:,1)); end
out.(ss_name).csetopt=out.(ss_name).ppopt(:,ss_this.m.comp_pos(:,1));

%process_terminal parameters (compress_terminalion ratios and demands)
out.(ss_name).cc=ss_this.cc0'; out.(ss_name).td=ss_this.m.xd/3600; 
out.(ss_name).dbase=ss_this.m.Yq(1:length(ss_this.m.fn),:)'*ss_this.c.qsc;     %base flow "q"
% out.(ss_name).gsub=ss_terminal.m.Yubs'*ss_terminal.c.qsc;   %upper bounds on sales
% out.(ss_name).gslb=ss_terminal.m.Ylbs'*ss_terminal.c.qsc;   %lower bounds on sales
% out.(ss_name).gdub=ss_terminal.m.Yubd'*ss_terminal.c.qsc;   %upper bounds on buys
% out.(ss_name).gdlb=ss_terminal.m.Ylbd'*ss_terminal.c.qsc;   %lower bounds on buys
% out.(ss_name).gdsol=ss_terminal.m.Ygd'*ss_terminal.c.qsc;   %gnode buyer solutions
% out.(ss_name).gss_terminalol=-ss_terminal.m.Ygs'*ss_terminal.c.qsc;   %gnode seller solutions
% %gnode buyer and seller solutions for all original gnodes 
% GN0=length(ss_terminal.n0.phys_node);    %number of original gnodes
% out.(ss_name).gdsol_all=zeros(2,GN0); out.(ss_name).gdsol_all(:,ss_terminal.dmax_pos)=out.(ss_name).gdsol;
% out.(ss_name).gss_terminalol_all=zeros(2,GN0); out.(ss_name).gss_terminalol_all(:,ss_terminal.smax_pos)=out.(ss_name).gss_terminalol;
out.(ss_name).dgflows=full(ss_this.m.Yd(ss_this.m.guniqueind,:))'*ss_this.c.qsc; %flow at nodes with gnodes
slinks=ss_this.m.comp_pos(ss_this.m.spos,2); 
out.(ss_name).supp_flow=qq(:,slinks);    %supply flow 
out.(ss_name).nonslack_flow=full(ss_this.m.Yd(1:length(ss_this.n0.nonslack_nodes),:))*ss_this.c.qsc;
out.(ss_name).flows_all=zeros(ss_this.n0.nv,ss_this.m.N1+1);
out.(ss_name).flows_all(ss_this.n0.slack_nodes,:)=-out.(ss_name).supp_flow;
out.(ss_name).flows_all(ss_this.n0.nonslack_nodes,:)=out.(ss_name).nonslack_flow;
out.(ss_name).dgflows_all=out.(ss_name).flows_all(ss_this.n0.phys_node,:); %flow at all original gnodes
% out.(ss_name).supp_flow_sim=sim.qq(:,slinks);    %supply flow 
% out.(ss_name).flows_all_sim=zeros(sim.n0.nv,length(sim.tt));
% out.(ss_name).flows_all_sim(sim.n0.slack_nodes,:)=-out.(ss_name).supp_flow_sim;
% out.(ss_name).flows_all_sim(sim.n0.nonslack_nodes,:)=full(sim.m.Yd(1:length(sim.n0.nonslack_nodes),:))*sim.c.qsc;
if(par.out.units==1), 
    out.(ss_name).dbase=out.(ss_name).dbase/mmscfd_to_kgps; 
%     out.(ss_name).gsub=out.(ss_name).gsub/mmscfd_to_kgps; 
%     out.(ss_name).gslb=out.(ss_name).gslb/mmscfd_to_kgps; out.(ss_name).gdub=out.(ss_name).gdub/mmscfd_to_kgps; out.(ss_name).gdlb=out.(ss_name).gdlb/mmscfd_to_kgps;
%     out.(ss_name).gdsol=out.(ss_name).gdsol/mmscfd_to_kgps; out.(ss_name).gss_terminalol=out.(ss_name).gss_terminalol/mmscfd_to_kgps;
%     out.(ss_name).gdsol_all=out.(ss_name).gdsol_all/mmscfd_to_kgps; out.(ss_name).gss_terminalol_all=out.(ss_name).gss_terminalol_all/mmscfd_to_kgps;
    out.(ss_name).dgflows=out.(ss_name).dgflows/mmscfd_to_kgps; out.(ss_name).dgflows_all=out.(ss_name).dgflows_all/mmscfd_to_kgps; 
    out.(ss_name).dgflows_all=out.(ss_name).dgflows_all/mmscfd_to_kgps;  out.(ss_name).supp_flow=out.(ss_name).supp_flow/mmscfd_to_kgps; 
    out.(ss_name).flows_all=out.(ss_name).flows_all/mmscfd_to_kgps;  
    %out.(ss_name).supp_flow_sim/mmscfd_to_kgps; %out.(ss_name).flows_all_sim/mmscfd_to_kgps;  
end

%check nodal flow balance
out.(ss_name).flowbal=ss_this.n0.Amp*out.(ss_name).qqoutopt'+ss_this.n0.Amm*out.(ss_name).qqinopt'-out.(ss_name).flows_all;
out.(ss_name).flowbalrel=3*out.(ss_name).flowbal./(abs(ss_this.n0.Amp*out.(ss_name).qqoutopt')+abs(ss_this.n0.Amm*out.(ss_name).qqinopt')+abs(out.(ss_name).flows_all));
out.(ss_name).flowbalrel(mean(out.(ss_name).flowbal')./mean(out.(ss_name).flowbalrel')<ss_this.m.opt_tol,:)=0; out.(ss_name).flowbalrel=out.(ss_name).flowbalrel';

%out.(ss_name).flowbals=ss_terminal.n0.Amp*out.(ss_name).qqoutsim'+ss_terminal.n0.Amm*out.(ss_name).qqinsim'-out.(ss_name).flows_all;
%out.(ss_name).flowbalsrel=3*out.(ss_name).flowbal./(abs(ss_terminal.n0.Amp*out.(ss_name).qqoutsim')+abs(ss_terminal.n0.Amm*out.(ss_name).qqinsim')+abs(out.(ss_name).flows_all));
%out.(ss_name).flowbalsrel(mean(out.(ss_name).flowbal')./mean(out.(ss_name).flowbalrel')<ss_terminal.m.opt_tol,:)=0;


%compress_terminalor power
% if(par.out.dosim==1)
%     cposs_terminalim=par.ss_terminal.m.comp_pos; m=ss_terminal.m.mpow;
%     out.(ss_name).cccom=interp1qr(out.(ss_name).tt0,ss_terminal.cc0',out.(ss_name).ttcom);
%     qcompsim=interp1qr(out.(ss_name).tt,sim.qq(:,cposs_terminalim(:,2)),ttcomsim); 
%     cpow_nd=(abs(qcompsim)).*((out.(ss_name).cccom).^(2*m)-1);
%     out.(ss_name).cpowsim=cpow_nd.*kron(ss_terminal.m.eff',ones(size(cpow_nd,1),1))*ss_terminal.c.mmscfd_to_hp/mmscfd_to_kgps;
% end
out.(ss_name).ccopt=ss_this.cc0';
cposopt=ss_this.m.comp_pos; m=ss_this.m.mpow;
qcompopt=qq(:,cposopt(:,2)); %cpow_nd=(abs(qcompopt)).*((ss_terminal.cc0').^(m)-1);
%out.(ss_name).cpowopt=cpow_nd.*kron(ss_terminal.m.eff',ones(size(cpow_nd,1),1))*ss_terminal.c.mmscfd_to_hp/mmscfd_to_kgps;
out.(ss_name).cpowopt=(abs(qcompopt)).*((ss_this.cc0').^(m)-1)*ss_this.m.Wc;   %comp power in Watts

%process_terminal locational marginal price
% out.(ss_name).lmptr=par.ss_terminal.lmp0(par.ss_terminal.m.flexnodes,:)'/2*par.ss_terminal.m.N/par.ss_terminal.m.odw*par.ss_terminal.c.Tsc*par.ss_terminal.c.Tsc/2;
% lmpss_terminal=par.ss_terminal.lmp0(par.ss_terminal.m.flexnodes,:)'/par.ss_terminal.m.odw*par.ss_terminal.c.Tsc*par.ss_terminal.c.Tsc/2;
% out.(ss_name).lmptr=par.ss_terminal.lmp0'/2*par.ss_terminal.m.N/par.ss_terminal.m.odw*par.ss_terminal.c.Tsc*par.ss_terminal.c.Tsc/2;
% lmpss_terminal=par.ss_terminal.lmp0'/ss_terminal.m.odw*ss_terminal.c.Tsc*ss_terminal.c.Tsc/2;
if(ss_this.m.N==0), trmN=2; end
if(ss_this.m.N>1), trmN=ss_this.m.N; end
% out.(ss_name).trlmp=ss_terminal.lmp0'/2*trmN;    %all lmps
% out.(ss_name).trlmpnodal=out.(ss_name).trlmp(:,1:length(ss_terminal.m.fn));
% out.(ss_name).trlmpnodal_all=zeros(par.ss_terminal.m.N1+1,ss_terminal.n0.nv);
% out.(ss_name).trlmpnodal_all(:,ss_terminal.n0.slack_nodes)=-ss_terminal.m.prslack';
% out.(ss_name).trlmpnodal_all(:,ss_terminal.n0.nonslack_nodes)=out.(ss_name).trlmpnodal;
% out.(ss_name).gnodelmp=out.(ss_name).trlmpnodal_all(:,ss_terminal.n0.phys_node);
%out.(ss_name).gnodelmp=ss_terminal.lmp0(ss_terminal.n0.phys_node,:)'/2*trmN;     %lmps at all gnodes
% out.(ss_name).dglmp=ss_terminal.lmp0(ss_terminal.m.guniqueind,:)'/2*trmN;     %lmps at market nodes
% out.(ss_name).gdlmp=ss_terminal.lmp0(ss_terminal.m.gallind(1:length(ss_terminal.m.gd)),:)'/2*trmN;     %lmps at demand gnodes
% out.(ss_name).gslmp=ss_terminal.lmp0(ss_terminal.m.gallind(length(ss_terminal.m.gd):length(ss_terminal.m.gall)),:)'/2*trmN;     %lmps at supply gnodes
% if(par.out.(ss_name).dosim==1), out.(ss_name).lmpss_terminal=par.ss_terminal.lmp0'; end
out.(ss_name).Prd=ss_this.m.Prd; out.(ss_name).Prs=ss_this.m.Prs; 
out.(ss_name).Prslack=interp1qr(ss_this.m.xd',ss_this.m.Prslack',out.(ss_name).tt0);  %bid and offer prices
out.(ss_name).mult0_pmax=ss_this.mult0_pmax'/2*trmN*ss_this.c.psi_to_pascal/ss_this.c.psc*3600;    %output press_terminalure marginal prices ($/Psi/hr)
out.(ss_name).mult0_cmax=ss_this.mult0_cmax'/2*trmN*3.6/0.75; %compress_terminalion marginal prices ($/hp)
if(par.out.units==1), 
%     out.(ss_name).trlmp=out.(ss_name).trlmp*mmscfd_to_kgps; 
%      out.(ss_name).trlmpnodal=out.(ss_name).trlmpnodal*mmscfd_to_kgps; 
%      out.(ss_name).dglmp=out.(ss_name).dglmp*mmscfd_to_kgps; out.(ss_name).gnodelmp=out.(ss_name).gnodelmp*mmscfd_to_kgps;
%      out.(ss_name).gdlmp=out.(ss_name).gdlmp*mmscfd_to_kgps; out.(ss_name).gslmp=out.(ss_name).gslmp*mmscfd_to_kgps; 
     out.(ss_name).Prd=out.(ss_name).Prd*mmscfd_to_kgps; out.(ss_name).Prs=out.(ss_name).Prs*mmscfd_to_kgps;
     out.(ss_name).Prslack=out.(ss_name).Prslack*mmscfd_to_kgps;
     out.(ss_name).cpowopt=out.(ss_name).cpowopt/hp_to_watt;
     %if(par.out.(ss_name).dosim==1), out.(ss_name).lmpss_terminal=out.(ss_name).lmpss_terminal*mmscfd_to_kgps; end
end
% out.(ss_name).lmpin=zeros(size(out.(ss_name).ppinopt)); out.(ss_name).lmpout=zeros(size(out.(ss_name).ppoutopt));
% for j=1:ss_terminal.n0.ne
%     if(ismember(ss_terminal.n0.from_id(j),ss_terminal.m.pn))
%         out.(ss_name).lmpin(:,j)=out.(ss_name).Prslack(:,find(ss_terminal.m.pn==ss_terminal.n0.from_id(j))); else
%         out.(ss_name).lmpin(:,j)=out.(ss_name).trlmpnodal(:,find(ss_terminal.m.fn==ss_terminal.n0.from_id(j))); end
%     if(ismember(ss_terminal.n0.to_id(j),ss_terminal.m.pn))
%         out.(ss_name).lmpout(:,j)=out.(ss_name).Prslack(:,find(ss_terminal.m.pn==ss_terminal.n0.to_id(j))); else
%         out.(ss_name).lmpout(:,j)=out.(ss_name).trlmpnodal(:,find(ss_terminal.m.fn==ss_terminal.n0.to_id(j))); end
% end
%cmap=colormap;
%set(0,'DefaultAxesColorOrder',cmap(floor(rand(length(ss_terminal.m.gs),1)*64)+1,:))

out.(ss_name).guniqueind=ss_this.m.guniqueind; out.(ss_name).gunique=ss_this.m.gunique; out.(ss_name).fn=ss_this.m.fn; out.(ss_name).pn=ss_this.m.pn;
out.(ss_name).n0=ss_this.n0; out.(ss_name).n=ss_this.n; out.(ss_name).gd=ss_this.m.gd; out.(ss_name).gs=ss_this.m.gs; out.(ss_name).FN=ss_this.m.FN; out.(ss_name).PN=ss_this.m.PN;
out.(ss_name).cn=ss_this.m.C; 
out.(ss_name).mfolder=par.mfolder;

% if(par.out.savecsvoutput==1)
%         mfolder=par.mfolder;
% %     if(par.out.intervals_out==0)
%         pipe_cols=[1:out.(ss_name).n0.ne-out.(ss_name).n0.nc]; comp_cols=[out.(ss_name).n0.ne-out.(ss_name).n0.nc+1:out.(ss_name).n0.ne];
%         %dlmwrite([mfolder '\ss_' ss_name '\output_ss_tpts.csv'],double(out.(ss_name).tt0),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\ss_' ss_name '\output_ss_pipe-press_terminalure-in.csv'],double([pipe_cols;out.(ss_name).ppinopt(1,pipe_cols)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\ss_' ss_name '\output_ss_pipe-press_terminalure-out.csv'],double([pipe_cols;out.(ss_name).ppoutopt(1,pipe_cols)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\ss_' ss_name '\output_ss_comp-press_terminalure-in.csv'],double([1:out.(ss_name).n0.nc;out.(ss_name).ppinopt(1,comp_cols)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\ss_' ss_name '\output_ss_comp-press_terminalure-out.csv'],double([1:out.(ss_name).n0.nc;out.(ss_name).ppoutopt(1,comp_cols)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\ss_' ss_name '\output_ss_pipe-flow-in.csv'],double([pipe_cols;out.(ss_name).qqinopt(1,pipe_cols)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\ss_' ss_name '\output_ss_pipe-flow-out.csv'],double([pipe_cols;out.(ss_name).qqoutopt(1,pipe_cols)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\ss_' ss_name '\output_ss_comp-flow-in.csv'],double([1:out.(ss_name).n0.nc;out.(ss_name).qqinopt(1,comp_cols)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\ss_' ss_name '\output_ss_comp-flow-out.csv'],double([1:out.(ss_name).n0.nc;out.(ss_name).qqoutopt(1,comp_cols)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\ss_' ss_name '\output_ss_nodal-press_terminalure.csv'],double([[1:out.(ss_name).n0.nv];out.(ss_name).ppoptnodal(1,:)]),'precision',16,'delimiter',',');
%         %dlmwrite([mfolder '\ss_' ss_name '\output_ss_gnode-physical-withdrawals.csv'],double([out.(ss_name).gunique';out.(ss_name).dgflows]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\ss_' ss_name '\output_ss_nonslack-flows.csv'],double([out.(ss_name).fn';out.(ss_name).flows_all(ss_this.n0.nonslack_nodes,1)']),'precision',16,'delimiter',',');
% %         dlmwrite([mfolder '\ss_' ss_name '\output_ss_gnode-supply-flows.csv'],double([1:GN0;out.(ss_name).gss_terminalol_all(1,:)]),'precision',16,'delimiter',',');
% %         dlmwrite([mfolder '\ss_' ss_name '\output_ss_gnode-demand-flows.csv'],double([1:GN0;out.(ss_name).gdsol_all(1,:)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\ss_' ss_name '\output_ss_slack-flows.csv'],double([out.(ss_name).pn';out.(ss_name).supp_flow(1,:)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\ss_' ss_name '\output_ss_comp-ratios.csv'],double([[1:out.(ss_name).cn];out.(ss_name).ccopt(1,:)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\ss_' ss_name '\output_ss_comp-discharge-press_terminalure.csv'],double([[1:out.(ss_name).cn];out.(ss_name).csetopt(1,:)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\ss_' ss_name '\output_ss_comp-power.csv'],double([[1:out.(ss_name).cn];out.(ss_name).cpowopt(1,:)]),'precision',16,'delimiter',',');
% %         dlmwrite([mfolder '\ss_' ss_name '\output_ss_lmp-nodal-all.csv'],double([out.(ss_name).fn';out.(ss_name).trlmpnodal(1,:)]),'precision',16,'delimiter',',');
% %         dlmwrite([mfolder '\ss_' ss_name '\output_ss_lmp-gnodes.csv'],double([[1:GN0];out.(ss_name).gnodelmp(1,:)]),'precision',16,'delimiter',',');
%         %dlmwrite([mfolder '\ss_' ss_name '\output_ss_lmp-bidders.csv'],double([out.(ss_name).gunique';out.(ss_name).dglmp]),'precision',16,'delimiter',',');
% %         dlmwrite([mfolder '\ss_' ss_name '\output_ss_pipe-lmp-in.csv'],double([pipe_cols;out.(ss_name).lmpin(1,pipe_cols)]),'precision',16,'delimiter',',');
% %         dlmwrite([mfolder '\ss_' ss_name '\output_ss_pipe-lmp-out.csv'],double([pipe_cols;out.(ss_name).lmpout(1,pipe_cols)]),'precision',16,'delimiter',',');
% %         dlmwrite([mfolder '\ss_' ss_name '\output_ss_comp-lmp-in.csv'],double([1:out.(ss_name).n0.nc;out.(ss_name).lmpin(1,comp_cols)]),'precision',16,'delimiter',',');
% %         dlmwrite([mfolder '\ss_' ss_name '\output_ss_comp-lmp-out.csv'],double([1:out.(ss_name).n0.nc;out.(ss_name).lmpout(1,comp_cols)]),'precision',16,'delimiter',',');
% %         dlmwrite([mfolder '\ss_' ss_name '\output_ss_comp-pmax-mp.csv'],double([[1:out.(ss_name).n0.nc];out.(ss_name).mult0_pmax(1,:)]),'precision',16,'delimiter',',');
% %         dlmwrite([mfolder '\ss_' ss_name '\output_ss_comp-hpmax-mp.csv'],double([[1:out.(ss_name).n0.nc];out.(ss_name).mult0_cmax(1,:)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\ss_' ss_name '\output_ss_flowbalrel.csv'],double([[1:out.(ss_name).n0.nv];out.(ss_name).flowbalrel(1,:)]),'precision',16,'delimiter',',');
%         dlmwrite([mfolder '\ss_' ss_name '\output_ss_pipe-mass.csv'],double([pipe_cols;out.(ss_name).pipe_mass_0(1,pipe_cols)]),'precision',16,'delimiter',',');
% end
%     if(par.out.intervals_out>0)
%         %inputs on intervals
%         out.(ss_name).int_qbar=ss_this.int_qbar; out.(ss_name).int_dmax=ss_this.int_dmax; out.(ss_name).int_dmin=ss_this.int_dmin;
%         out.(ss_name).int_smax=ss_this.int_smax; out.(ss_name).int_smin=ss_this.int_smin; out.(ss_name).int_cd=ss_this.int_cd;
%         out.(ss_name).int_cs=ss_this.int_cs; out.(ss_name).int_cslack=ss_this.int_cslack; out.(ss_name).int_pslack=ss_this.int_pslack;
%         if(ss_this.intervals>0 && ss_this.units==1)
%             out.(ss_name).int_cd=out.(ss_name).int_cd*mmscfd_to_kgps;
%             out.(ss_name).int_cs=out.(ss_name).int_cs*mmscfd_to_kgps; 
%             out.(ss_name).int_cslack=out.(ss_name).int_cslack*mmscfd_to_kgps;
%         end
%         %------------------
%         %revert to full gnode index list
%         out.(ss_name).gdsol_all=zeros(2,ss_this.n0.ng);
%         out.(ss_name).gdsol_all(:,ss_this.dmax_pos)=out.(ss_name).gdsol;
%         out.(ss_name).gss_terminalol_all=zeros(2,ss_this.n0.ng);
%         out.(ss_name).gss_terminalol_all(:,ss_this.smax_pos)=out.(ss_name).gss_terminalol;
% 
%         In=par.out.intervals_out;  %24 intervals on optimization period (1 day)
%         T=ss_this.c.T/3600;             %time in hours
%         int_bounds=[0:T/In:T]; out.(ss_name).int_bounds=int_bounds;
%         [out.(ss_name).dbase_int]=pts_to_int(ss_this.m.xd'/3600,out.(ss_name).dbase,int_bounds');
%         [out.(ss_name).gsub_int]=pts_to_int(ss_this.m.xd'/3600,out.(ss_name).gsub,int_bounds');
%         [out.(ss_name).gslb_int]=pts_to_int(ss_this.m.xd'/3600,out.(ss_name).gslb,int_bounds');
%         [out.(ss_name).gdub_int]=pts_to_int(ss_this.m.xd'/3600,out.(ss_name).gdub,int_bounds');
%         [out.(ss_name).gdlb_int]=pts_to_int(ss_this.m.xd'/3600,out.(ss_name).gdlb,int_bounds');
%         [out.(ss_name).gdsol_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).gdsol_all,int_bounds');
%         [out.(ss_name).gss_terminalol_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).gss_terminalol_all,int_bounds');
%         [out.(ss_name).dgflows_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).dgflows_all,int_bounds');
%         [out.(ss_name).supp_flow_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).supp_flow,int_bounds');
%         [out.(ss_name).flows_all_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).flows_all',int_bounds');
%         [out.(ss_name).Prslack_int]=pts_to_int(ss_this.m.xd'/3600,ss_this.m.Prslack',int_bounds');
%         [out.(ss_name).Prs_int]=pts_to_int(ss_this.m.xd'/3600,ss_this.m.Prs',int_bounds');
%         [out.(ss_name).Prd_int]=pts_to_int(ss_this.m.xd'/3600,ss_this.m.Prd',int_bounds');
%         %------------------
%         [out.(ss_name).ppinopt_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).ppinopt,int_bounds');
%         [out.(ss_name).ppoutopt_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).ppoutopt,int_bounds');
%         [out.(ss_name).qqinopt_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).qqinopt,int_bounds');
%         [out.(ss_name).qqoutopt_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).qqoutopt,int_bounds');
%         [out.(ss_name).ppoptnodal_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).ppoptnodal,int_bounds');
%         [out.(ss_name).dgflows_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).dgflows,int_bounds');
%         [out.(ss_name).supp_flow_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).supp_flow,int_bounds');
%         [out.(ss_name).ccopt_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).ccopt,int_bounds');
%         [out.(ss_name).csetopt_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).csetopt,int_bounds');
%         [out.(ss_name).cpowopt_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).cpowopt,int_bounds');
%         [out.(ss_name).trlmpnodal_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).trlmpnodal,int_bounds');
%         [out.(ss_name).dglmp_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).dglmp,int_bounds');
%         [out.(ss_name).lmpin_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).lmpin,int_bounds');
%         [out.(ss_name).lmpout_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).lmpout,int_bounds');
%         [out.(ss_name).mult0_pmax_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).mult0_pmax,int_bounds');
%         [out.(ss_name).mult0_cmax_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).mult0_cmax,int_bounds');
%         [out.(ss_name).flowbalrel_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).flowbalrel,int_bounds');
%         [out.(ss_name).pipe_mass_int]=pts_to_int(out.(ss_name).tt0,out.(ss_name).pipe_mass_0,int_bounds');
%         pipe_cols=[1:out.(ss_name).n0.ne-out.(ss_name).n0.nc]; comp_cols=[out.(ss_name).n0.ne-out.(ss_name).n0.nc+1:out.(ss_name).n0.ne];
% 
% 
%         if(par.out.steadystateonly==0)
%             %write filescsv
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_pipe-press_terminalure-in.csv'],double([pipe_cols;out.(ss_name).ppinopt_int(:,pipe_cols)]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_pipe-press_terminalure-out.csv'],double([pipe_cols;out.(ss_name).ppoutopt_int(:,pipe_cols)]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_comp-press_terminalure-in.csv'],double([1:out.(ss_name).n0.nc;out.(ss_name).ppinopt_int(:,comp_cols)]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_comp-press_terminalure-out.csv'],double([1:out.(ss_name).n0.nc;out.(ss_name).ppoutopt_int(:,comp_cols)]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_pipe-flow-in.csv'],double([pipe_cols;out.(ss_name).qqinopt_int(:,pipe_cols)]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_pipe-flow-out.csv'],double([pipe_cols;out.(ss_name).qqoutopt_int(:,pipe_cols)]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_comp-flow-in.csv'],double([1:out.(ss_name).n0.out.(ss_name).nc;out.(ss_name).qqinopt_int(:,comp_cols)]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_comp-flow-out.csv'],double([1:out.(ss_name).n0.nc;out.(ss_name).qqoutopt_int(:,comp_cols)]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_nodal-press_terminalure.csv'],double([[1:out.(ss_name).n0.nv];out.(ss_name).ppoptnodal_int]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_gnode-physical-withdrawals.csv'],double([ss_this.m.guniqueind';out.(ss_name).dgflows_int]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_gnode-supply-flows.csv'],double([ss_this.n0.phys_node';out.(ss_name).gss_terminalol_int]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_gnode-demand-flows.csv'],double([ss_this.n0.phys_node';out.(ss_name).gdsol_int]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_slack-flows.csv'],double([out.(ss_name).pn';out.(ss_name).supp_flow_int]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_comp-ratios.csv'],double([[1:out.(ss_name).cn];out.(ss_name).ccopt_int]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_comp-discharge-press_terminalure.csv'],double([[1:out.(ss_name).cn];out.(ss_name).csetopt_int]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_comp-power.csv'],double([[1:out.(ss_name).cn];out.(ss_name).cpowopt_int]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_lmp-nodal-all.csv'],double([out.(ss_name).fn';out.(ss_name).trlmpnodal_int]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_lmp-bidders.csv'],douint_flow_constble([out.(ss_name).gunique';out.(ss_name).dglmp_int]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_pipe-lmp-in.csv'],double([pipe_cols;out.(ss_name).lmpin_int(:,pipe_cols)]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_pipe-lmp-out.csv'],double([pipe_cols;out.(ss_name).lmpout_int(:,pipe_cols)]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_comp-lmp-in.csv'],double([1:out.(ss_name).n0.nc;out.(ss_name).lmpin_int(:,comp_cols)]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_comp-lmp-out.csv'],double([1:out.(ss_name).n0.nc;out.(ss_name).lmpout_int(:,comp_cols)]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_comp-pmax-mp.csv'],double([[1:out.(ss_name).n0.nc];out.(ss_name).mult0_pmax_int]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_comp-hpmax-mp.csv'],double([[1:out.(ss_name).n0.nc];out.(ss_name).mult0_cmax_int]),'precision',16,'delimiter',',');
%             dlmwrite([mfolder '\ss_' ss_name '\output_int_flowbalrel.csv'],double([[1:out.(ss_name).n0.nv];out.(ss_name).flowbalrel_int]),'precision',16,'delimiter',',');
%         end
%     end

% if(ss_this.m.save_state==1)
% dlmwrite([mfolder '\ss_' ss_name '\output_ss_state_save.csv'],double(full(ss_this.state_save)),'precision',16,'delimiter',',');
% end

par.out.(ss_name)=out.(ss_name);
%par.ss_terminal=ss_terminal;

%out.(ss_name).mult0_pmax=ss_terminal.mult0_pmax/2*ss_terminal.m.N/(ss_terminal.c.psc/1000000)/mpa_to_psi;    %output press_terminalure marginal prices ($/
%out.(ss_name).mult0_cmax=ss_terminal.mult0_cmax/2*ss_terminal.m.N*3.6/0.75; %compress_terminalion marginal prices ($/hp)

function [xints]=pts_to_int(tpts,xpts,ibnds)
    xbnds=interp1qr(tpts,xpts,ibnds); In=length(ibnds)-1;
    xints=(xbnds(1:In,:)+xbnds(2:In+1,:))/2;
return;