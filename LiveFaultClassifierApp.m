classdef LiveFaultClassifierApp < matlab.apps.AppBase
    properties (Access = public)
        UIFigure          matlab.ui.Figure
        WaveformAxes      matlab.ui.control.UIAxes
        ProbabilityAxes   matlab.ui.control.UIAxes
        StatusLabel       matlab.ui.control.Label
        AlarmLabel        matlab.ui.control.Label
    end
    properties (Access = private)
        TrainedModel
        DataTimer
        
        BufferSize = 200;
        SampleIndex = 0;
        VaBuf, VbBuf, VcBuf
        IaBuf, IbBuf, IcBuf
        TimeBuf
    end
    methods (Access = private)
        function createComponents(app)
            % Main UI Figure Window
            app.UIFigure = uifigure('Visible', 'on');
            app.UIFigure.Position = [100 100 800 600];
            app.UIFigure.Name = 'Live Power System Fault Classifier';
            
            % Top Axes: Live Signal Waveforms
            app.WaveformAxes = uiaxes(app.UIFigure);
            app.WaveformAxes.Position = [50 310 700 240];
            title(app.WaveformAxes, 'Live Voltage & Current Waveforms (p.u.)');
            xlabel(app.WaveformAxes, 'Time (s)');
            ylabel(app.WaveformAxes, 'Amplitude');
            grid(app.WaveformAxes, 'on');
            
            % Bottom-Left Axes: Fault Probability Bar Chart
            app.ProbabilityAxes = uiaxes(app.UIFigure);
            app.ProbabilityAxes.Position = [50 40 420 220];
            title(app.ProbabilityAxes, 'Fault Class Probabilities');
            ylabel(app.ProbabilityAxes, 'Probability');
            ylim(app.ProbabilityAxes, [0 1]);
            grid(app.ProbabilityAxes, 'on');
            
            % System Model Status Label
            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.Position = [500 180 250 30];
            app.StatusLabel.FontSize = 14;
            app.StatusLabel.Text = 'Status: Initializing...';
            
            % Real-Time Fault Alarm Banner
            app.AlarmLabel = uilabel(app.UIFigure);
            app.AlarmLabel.Position = [500 80 250 70];
            app.AlarmLabel.FontSize = 15;
            app.AlarmLabel.FontWeight = 'bold';
            app.AlarmLabel.HorizontalAlignment = 'center';
            app.AlarmLabel.Text = 'INITIALIZING';
            app.AlarmLabel.BackgroundColor = [0.8 0.8 0.8];
            app.AlarmLabel.FontColor = [1 1 1];
        end
        
        function startupFcn(app, varargin)
            % Initialize circular signal buffers
            app.VaBuf   = zeros(1, app.BufferSize);
            app.VbBuf   = zeros(1, app.BufferSize);
            app.VcBuf   = zeros(1, app.BufferSize);
            app.IaBuf   = zeros(1, app.BufferSize);
            app.IbBuf   = zeros(1, app.BufferSize);
            app.IcBuf   = zeros(1, app.BufferSize);
            app.TimeBuf = zeros(1, app.BufferSize);
            
            % Load trained Random Forest model
            if exist('trained_fault_model.mat', 'file')
                data = load('trained_fault_model.mat');
                app.TrainedModel = data.mdl;
                app.StatusLabel.Text = 'Status: Model Active';
                app.StatusLabel.FontColor = [0 0.5 0];
            else
                app.StatusLabel.Text = 'Status: model missing!';
                app.StatusLabel.FontColor = [0.8 0 0];
            end
            
            % Setup background streaming timer (100 ms refresh)
            app.DataTimer = timer('ExecutionMode', 'fixedRate', ...
                                  'Period', 0.1, ...
                                  'TimerFcn', @(~,~) app.timerCallback);
            start(app.DataTimer);
        end
        
        function timerCallback(app)
            if isempty(app.TrainedModel)
                return;
            end
            
            app.SampleIndex = app.SampleIndex + 1;
            t = app.SampleIndex * 0.001;
            
            % Ingest live telemetry from MATLAB Base Workspace
            if evalin('base', 'exist(''hil_telemetry_stream'', ''var'')')
                streamData = evalin('base', 'hil_telemetry_stream');
                va = streamData(1);
                vb = streamData(2);
                vc = streamData(3);
                ia = streamData(4);
                ib = streamData(5);
                ic = streamData(6);
            else
                % Default to healthy 1.0 p.u. baseline when transmitter is inactive
                k = sqrt(2);
                va = k * sin(2*pi*50*t);
                vb = k * sin(2*pi*50*t - 2*pi/3);
                vc = k * sin(2*pi*50*t + 2*pi/3);
                ia = k * sin(2*pi*50*t);
                ib = k * sin(2*pi*50*t - 2*pi/3);
                ic = k * sin(2*pi*50*t + 2*pi/3);
            end
            
            % Sliding window update
            app.VaBuf = [app.VaBuf(2:end), va];
            app.VbBuf = [app.VbBuf(2:end), vb];
            app.VcBuf = [app.VcBuf(2:end), vc];
            app.IaBuf = [app.IaBuf(2:end), ia];
            app.IbBuf = [app.IbBuf(2:end), ib];
            app.IcBuf = [app.IcBuf(2:end), ic];
            app.TimeBuf = [app.TimeBuf(2:end), t];
            
            % Compute 6 p.u. RMS features
            v_rms = [rms(app.VaBuf), rms(app.VbBuf), rms(app.VcBuf)];
            i_rms = [rms(app.IaBuf), rms(app.IbBuf), rms(app.IcBuf)];
            features = [v_rms, i_rms];
            
            % Class prediction & posterior probabilities
            [pred_label, scores] = predict(app.TrainedModel, features);
            class_names = {'Normal', 'LG (A)', 'LL (AB)', 'LLG (AB-G)', 'LLL'};
            
            % Handle numerical vs categorical prediction returns safely
            if iscell(pred_label) || iscategorical(pred_label) || isstring(pred_label)
                pred_idx = find(strcmp(class_names, string(pred_label)));
            else
                pred_idx = pred_label;
            end
            
            if isempty(pred_idx)
                pred_idx = 1; % Default to Normal if unmapped
            end
            
            % Render live waveforms
            hold(app.WaveformAxes, 'off');
            plot(app.WaveformAxes, app.TimeBuf, app.VaBuf, 'r', ...
                 app.TimeBuf, app.VbBuf, 'g', app.TimeBuf, app.VcBuf, 'b');
            title(app.WaveformAxes, 'Live Waveforms (p.u.)');
            xlabel(app.WaveformAxes, 'Time (s)');
            ylabel(app.WaveformAxes, 'Amplitude');
            grid(app.WaveformAxes, 'on');
            
            % Render probability distribution
            bar(app.ProbabilityAxes, scores);
            set(app.ProbabilityAxes, 'XTickLabel', class_names);
            title(app.ProbabilityAxes, 'Fault Probability Distribution');
            ylabel(app.ProbabilityAxes, 'Probability');
            ylim(app.ProbabilityAxes, [0 1]);
            grid(app.ProbabilityAxes, 'on');
            
            % Alarm banner status update
            if pred_idx == 1
                app.AlarmLabel.Text = 'SYSTEM NORMAL';
                app.AlarmLabel.BackgroundColor = [0.2 0.8 0.2];
            else
                app.AlarmLabel.Text = sprintf('FAULT DETECTED: %s', class_names{pred_idx});
                app.AlarmLabel.BackgroundColor = [0.9 0.2 0.2];
            end
        end
    end
    methods (Access = public)
        function app = LiveFaultClassifierApp(varargin)
            createComponents(app);
            registerApp(app, app.UIFigure);
            runStartupFcn(app, @(app) startupFcn(app, varargin{:}));
            if nargout == 0
                clear app
            end
        end
        function delete(app)
            if ~isempty(app.DataTimer) && isvalid(app.DataTimer)
                stop(app.DataTimer);
                delete(app.DataTimer);
            end
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end
    end 