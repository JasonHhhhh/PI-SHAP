function varargout = main_sim_case(stage)
if nargin < 1
    stage = 'settings';
end

switch lower(stage)
    case 'settings'
        out = run_case_settings();
        varargout = {out};
    case 'ss'
        par = run_case_ss_opt();
        varargout = {par};
    case 'ss_check'
        out = run_ss_opt_stage_min();
        varargout = {out};
    case 'ss_plan'
        out = run_ss_opt_plan_min();
        varargout = {out};
    case 'tr'
        par = run_case_tr_opt();
        varargout = {par};
    case 'tr_opt_1'
        out = run_tr_opt_1_compare_singleobj();
        varargout = {out};
    case 'tr_granularity'
        out = run_tr_opt_granularity_min();
        varargout = {out};
    case 'tr_granularity_singleobj'
        out = run_tr_opt_granularity_singleobj_min();
        varargout = {out};
    case 'tr_cost'
        out = run_tr_obj_min('cost');
        varargout = {out};
    case 'tr_supp'
        out = run_tr_obj_min('supp');
        varargout = {out};
    case 'tr_cost_supply'
        out = run_tr_cost_supply_min();
        varargout = {out};
    case 'sim'
        [results, summary_tbl] = run_case_sim();
        varargout = {results, summary_tbl};
    case 'all'
        run_case_settings();
        run_case_ss_opt();
        run_ss_opt_stage_min();
        run_ss_opt_plan_min();
        run_tr_opt_granularity_min();
        run_case_tr_opt();
        [results, summary_tbl] = run_case_sim();
        varargout = {results, summary_tbl};
    otherwise
        error('Unsupported stage: %s. Use settings|ss|ss_check|ss_plan|tr|tr_opt_1|tr_granularity|tr_granularity_singleobj|tr_cost|tr_supp|tr_cost_supply|sim|all.', stage);
end
end
