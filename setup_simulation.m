% Script to configure transmission_system.slx parameters programmatically
modelName = 'transmission_system';
open_system(modelName);

% Enable Real-Time Pacing (1x real-time speed)
set_param(modelName, 'EnablePacing', 'on');
set_param(modelName, 'PacingRate', '1');

% Set solver to fixed-step for real-time execution
set_param(modelName, 'SolverType', 'Fixed-step');
set_param(modelName, 'Solver', 'ode3'); % Bogacki-Shampine
set_param(modelName, 'FixedStep', '0.0001'); % 10 kHz sampling

% Note: In Simulink, configure the UDP Receive block properties:
% - Local IP port: 5001
% - Output data type: uint8
% - Vector size: 4

% Note: Configure the UDP Send block properties:
% - Remote IP address: 127.0.0.1
% - Remote IP port: 5002
% - Data size: 6 (Double-precision RMS V/I vector: [Va, Vb, Vc, Ia, Ib, Ic])