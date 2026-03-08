function sim_result = simulate_policy_min(par_base, cc_policy, cfg, policy_name)
if nargin < 4
    policy_name = 'custom';
end

expected_steps = size(par_base.tr.cc0, 2);
expected_comps = size(par_base.tr.cc0, 1);
if ~isequal(size(cc_policy), [expected_steps expected_comps])
    error('cc_policy must be %dx%d, got %s', expected_steps, expected_comps, mat2str(size(cc_policy)));
end

par = par_base;
par.sim = par.ss;
par.sim.rtol0 = cfg.rtol0;
par.sim.atol0 = cfg.atol0;
par.sim.rtol1 = cfg.rtol1;
par.sim.atol1 = cfg.atol1;
par.sim.rtol = cfg.rtol;
par.sim.atol = cfg.atol;
par.sim.startup = cfg.startup;
par.sim.nperiods = cfg.nperiods;
par.sim.solsteps = cfg.solsteps;
par.sim.fromss = 1;

par = tran_sim_setup_0_min(par, cc_policy');
par.sim = tran_sim_base_flat_noextd(par.sim);
par = process_output_tr_nofd_sim(par);

sim_result = struct();
sim_result.policy_name = policy_name;
sim_result.cc_policy = cc_policy;
sim_result.par = par;
sim_result.metrics = struct();
sim_result.metrics.Jcost = sum(par.tr.shap.ori_Jcost);
sim_result.metrics.Jsupp = par.tr.shap.ori_Jsupp;
sim_result.metrics.Jvar = par.tr.shap.ori_Jvar;

sim_result.features = struct();
sim_result.features.x = par.tr.shap.cc(2:end,:);
sim_result.features.dx = par.tr.shap.m_dcc_every(2:end,:);
end
