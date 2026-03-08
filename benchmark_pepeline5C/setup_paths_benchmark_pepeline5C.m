function setup_paths_benchmark_pepeline5C()
this_dir = fileparts(mfilename('fullpath'));

addpath(genpath(fullfile(this_dir, 'code')));
addpath(genpath(fullfile(this_dir, 'modules')));

fprintf('Paths added for benchmark_pepeline5C:\n');
fprintf('- %s\n', fullfile(this_dir, 'code'));
fprintf('- %s\n', fullfile(this_dir, 'modules'));
end
