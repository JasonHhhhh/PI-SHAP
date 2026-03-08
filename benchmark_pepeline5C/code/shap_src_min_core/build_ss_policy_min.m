function ccc_ssopt = build_ss_policy_min(par)
ccc_tropt = par.tr.cc0';

all_nodes = 2:4:101;
mid_nodes = all_nodes(2:end-1);
allcc = [];

for mid_node = mid_nodes
    field_name = sprintf('ss_%d', mid_node);
    if ~isfield(par, field_name)
        error('Missing field in baseline par: %s', field_name);
    end
    allcc = [allcc par.(field_name).cc0(:,2)]; %#ok<AGROW>
end

ccc_ssopt = [par.ss_start.cc0(:,2) allcc par.ss_terminal.cc0(:,2)]';
ccc_ssopt(end,:) = ccc_tropt(end,:);

if ~isequal(size(ccc_ssopt), size(ccc_tropt))
    error('Policy shape mismatch. ss_opt=%s, tr_opt=%s', mat2str(size(ccc_ssopt)), mat2str(size(ccc_tropt)));
end
end
