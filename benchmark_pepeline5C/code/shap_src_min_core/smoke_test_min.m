function smoke_test_min()
[~, summary_tbl] = run_min_pipeline_min();

numeric_vals = [ ...
    summary_tbl.Jcost, summary_tbl.Jsupp, summary_tbl.Jvar, ...
    summary_tbl.ScoreCost, summary_tbl.ScoreSupp, summary_tbl.ScoreVar, ...
    summary_tbl.ScoreCostW, summary_tbl.ScoreSuppW, summary_tbl.ScoreVarW];

if any(~isfinite(numeric_vals), 'all')
    error('Smoke test failed: non-finite values found in summary table.');
end

row_tr = summary_tbl(summary_tbl.Policy == "tr_opt", :);
row_ss = summary_tbl(summary_tbl.Policy == "ss_opt", :);
if isempty(row_tr) || isempty(row_ss)
    error('Smoke test failed: missing tr_opt or ss_opt row.');
end

if row_tr.Jcost > 1.05 * row_ss.Jcost
    error('Smoke test failed: tr_opt Jcost is unexpectedly high.');
end

if row_tr.Jsupp > 1.05 * row_ss.Jsupp
    error('Smoke test failed: tr_opt Jsupp is unexpectedly high.');
end

fprintf('smoke_test_min passed.\n');
end
