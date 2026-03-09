function dirs = hvac_setup_io(root_dir)
output_dir = fullfile(root_dir, 'outputs');
figure_dir = fullfile(output_dir, 'figures');
table_dir = fullfile(output_dir, 'tables');

ensure_dir_hvac(output_dir);
ensure_dir_hvac(figure_dir);
ensure_dir_hvac(table_dir);

dirs = struct();
dirs.root_dir = root_dir;
dirs.output_dir = output_dir;
dirs.figure_dir = figure_dir;
dirs.table_dir = table_dir;
end

function ensure_dir_hvac(path_dir)
if exist(path_dir, 'dir') ~= 7
    mkdir(path_dir);
end
end
