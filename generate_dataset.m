clc; clear; close all;

model_name = 'transmission_system';
if ~exist([model_name, '.slx'], 'file')
    error('Error: %s.slx not found in working directory.', model_name);
end

% Force-close any open/dirty instances to prevent save-callback triggers
if bdIsLoaded(model_name)
    close_system(model_name, 0);
end

% Load cleanly into memory without opening the GUI diagram
load_system(model_name);

fault_block = [model_name, '/Three-Phase Fault'];
load_block  = [model_name, '/Three-Phase Series RLC Load'];

scenarios = {
    'Normal (No Fault)',   {'off','off','off','off'}, 1;
    'LG Fault (Phase A)',  {'on', 'off','off','on' }, 2;
    'LL Fault (Phase AB)', {'on', 'on', 'off','off'}, 3;
    'LLG Fault (AB-G)',    {'on', 'on', 'off','on' }, 4;
    'LLL Fault (ABC)',     {'on', 'on', 'on', 'off'}, 5;
};

samples_per_class = 40;
total_samples = samples_per_class * size(scenarios, 1);

dataset_features = zeros(total_samples, 6);
dataset_labels   = zeros(total_samples, 1);

sim_inputs = repmat(Simulink.SimulationInput(model_name), total_samples, 1);
idx = 1;

fprintf('====================================================\n');
fprintf('  Building Batch Simulation Tasks                   \n');
fprintf('====================================================\n');

for s = 1:size(scenarios, 1)
    cfg   = scenarios{s, 2};
    label = scenarios{s, 3};
    
    for run_i = 1:samples_per_class
        rand_power = 100e6 * (0.9 + 0.2 * rand());
        
        in = Simulink.SimulationInput(model_name);
        in = in.setBlockParameter(fault_block, 'FaultA', cfg{1});
        in = in.setBlockParameter(fault_block, 'FaultB', cfg{2});
        in = in.setBlockParameter(fault_block, 'FaultC', cfg{3});
        in = in.setBlockParameter(fault_block, 'GroundFault', cfg{4});
        in = in.setBlockParameter(load_block,  'ActivePower', num2str(rand_power));
        
        sim_inputs(idx) = in;
        dataset_labels(idx) = label;
        idx = idx + 1;
    end
end

fprintf('Running %d batch simulations using parsim...\n', total_samples);
sim_outputs = parsim(sim_inputs, 'ShowProgress', 'on');

for i = 1:total_samples
    telemetry = sim_outputs(i).hil_telemetry_stream;
    mid_idx = round(0.75 * size(telemetry, 1));
    dataset_features(i, :) = telemetry(mid_idx, :);
end

save('fault_dataset.mat', 'dataset_features', 'dataset_labels');
bdclose(model_name);

fprintf('====================================================\n');
fprintf(' SUCCESS: Dataset saved -> fault_dataset.mat [%d x %d]\n', size(dataset_features, 1), size(dataset_features, 2));
fprintf('====================================================\n');