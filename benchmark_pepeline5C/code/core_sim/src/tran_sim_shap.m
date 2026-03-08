function [m_cost,m_var] = tran_sim_shap(cc,par)
% TRAN_SIM_SHAP Summary of this function goes here
% Detailed explanation goes here
[m,~]=size(cc);
cc=reshape(cc,m,25,5);
m_cost=zeros(m,1);
m_var=zeros(m,1);
for i=1:m
    cc0=reshape(cc(i,:,:),25,5);
    [par]=tran_sim_setup_0(par,cc0');
    % execute simulation
    [par.sim]=tran_sim_base_flat_noextd(par.sim);
    [par]=process_output_tr_nofd(par);
    m_cost(i,1) = par.tr.m_cost;
    m_var(i,1) =par.tr.m_var;
    % m_ts=par.tr.m_ts;
end
end

