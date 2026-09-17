classdef virtual_hil_tx < matlab.apps.AppBase
    properties (Access = public)
        UIFigure          matlab.ui.Figure
        StatusLabel       matlab.ui.control.Label
        NormalBtn         matlab.ui.control.Button
        LGBtn             matlab.ui.control.Button
        LLBtn             matlab.ui.control.Button
        LLGBtn            matlab.ui.control.Button
        LLLBtn            matlab.ui.control.Button
        StartStopBtn      matlab.ui.control.Button
    end
    properties (Access = private)
        TxTimer
        IsTransmitting = false
        CurrentFaultMode = 1 % 1: Normal, 2: LG, 3: LL, 4: LLG, 5: LLL
        SampleIndex = 0
        DatasetLog = zeros(0, 7)
    end
    methods (Access = private)
        function createComponents(app)
            % Main Window
            app.UIFigure = uifigure('Visible', 'on');
            app.UIFigure.Position = [150 150 400 350];
            app.UIFigure.Name = 'Virtual HIL Fault Transmitter';
            
            % Status Indicator
            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.Position = [50 280 300 30];
            app.StatusLabel.FontSize = 14;
            app.StatusLabel.HorizontalAlignment = 'center';
            app.StatusLabel.Text = 'State: NORMAL (Idle)';
            
            % Scenario Control Buttons
            app.NormalBtn = uibutton(app.UIFigure, 'push');
            app.NormalBtn.Position = [50 220 140 40];
            app.NormalBtn.Text = 'Normal System';
            app.NormalBtn.ButtonPushedFcn = @(~,~) app.setFaultMode(1, 'NORMAL');
            
            app.LGBtn = uibutton(app.UIFigure, 'push');
            app.LGBtn.Position = [210 220 140 40];
            app.LGBtn.Text = 'Inject LG Fault';
            app.LGBtn.ButtonPushedFcn = @(~,~) app.setFaultMode(2, 'LG FAULT (Phase A)');
            
            app.LLBtn = uibutton(app.UIFigure, 'push');
            app.LLBtn.Position = [50 160 140 40];
            app.LLBtn.Text = 'Inject LL Fault';
            app.LLBtn.ButtonPushedFcn = @(~,~) app.setFaultMode(3, 'LL FAULT (AB)');
            
            app.LLGBtn = uibutton(app.UIFigure, 'push');
            app.LLGBtn.Position = [210 160 140 40];
            app.LLGBtn.Text = 'Inject LLG Fault';
            app.LLGBtn.ButtonPushedFcn = @(~,~) app.setFaultMode(4, 'LLG FAULT (AB-G)');
            
            app.LLLBtn = uibutton(app.UIFigure, 'push');
            app.LLLBtn.Position = [50 100 300 40];
            app.LLLBtn.Text = 'Inject 3-Phase LLL Fault';
            app.LLLBtn.ButtonPushedFcn = @(~,~) app.setFaultMode(5, '3-PHASE LLL FAULT');
            
            % Master Start/Stop Control Button
            app.StartStopBtn = uibutton(app.UIFigure, 'push');
            app.StartStopBtn.Position = [50 30 300 50];
            app.StartStopBtn.FontSize = 16;
            app.StartStopBtn.FontWeight = 'bold';
            app.StartStopBtn.Text = 'START TRANSMISSION';
            app.StartStopBtn.BackgroundColor = [0.2 0.7 0.2];
            app.StartStopBtn.FontColor = [1 1 1];
            app.StartStopBtn.ButtonPushedFcn = @(~,~) app.toggleTransmission();
        end
        
        function startupFcn(app, varargin)
            % Initialize Background Timer (50 ms transmission interval)
            app.TxTimer = timer('ExecutionMode', 'fixedRate', ...
                                'Period', 0.05, ...
                                'TimerFcn', @(~,~) app.transmitCallback);
        end
        
        function setFaultMode(app, mode, name)
            app.CurrentFaultMode = mode;
            if app.IsTransmitting
                app.StatusLabel.Text = sprintf('State: %s (Streaming)', name);
            else
                app.StatusLabel.Text = sprintf('State: %s (Idle)', name);
            end
        end
        
        function toggleTransmission(app)
            if app.IsTransmitting
                stop(app.TxTimer);
                app.IsTransmitting = false;
                app.StartStopBtn.Text = 'START TRANSMISSION';
                app.StartStopBtn.BackgroundColor = [0.2 0.7 0.2];
                % Clear shared variable on stop
                evalin('base', 'clear hil_telemetry_stream');
                
                % Save logged dataset and reset buffer cleanly
                loggedData = app.DatasetLog;
                save('hil_logged_dataset.mat', 'loggedData');
                app.DatasetLog = zeros(0, 7);
            else
                start(app.TxTimer);
                app.IsTransmitting = true;
                app.StartStopBtn.Text = 'STOP TRANSMISSION';
                app.StartStopBtn.BackgroundColor = [0.8 0.2 0.2];
            end
        end
        
        function transmitCallback(app)
            % Generate a burst of 50 samples per 50 ms tick (1 kHz effective rate)
            numSamples = 50;
            k = sqrt(2);
            
            % Compute time steps for this frame batch
            t = (app.SampleIndex + (1:numSamples)) * 0.001;
            app.SampleIndex = app.SampleIndex + numSamples;
            
            % Base 3-phase waveforms
            va = k * sin(2*pi*50*t);
            vb = k * sin(2*pi*50*t - 2*pi/3);
            vc = k * sin(2*pi*50*t + 2*pi/3);
            ia = k * sin(2*pi*50*t);
            ib = k * sin(2*pi*50*t - 2*pi/3);
            ic = k * sin(2*pi*50*t + 2*pi/3);
            
            % Apply current fault injection scenario
            switch app.CurrentFaultMode
                case 2 % LG Fault (Phase A sags, Current surges)
                    va = va * 0.2;
                    ia = ia * 3.5;
                case 3 % LL Fault (Phase A & B drop, currents surge)
                    va = va * 0.5; vb = vb * 0.5;
                    ia = ia * 2.8; ib = ib * 2.8;
                case 4 % LLG Fault (Phase A & B severe sag)
                    va = va * 0.1; vb = vb * 0.1;
                    ia = ia * 4.0; ib = ib * 4.0;
                case 5 % LLL Fault (All phases sag, currents surge)
                    va = va * 0.05; vb = vb * 0.05; vc = vc * 0.05;
                    ia = ia * 5.0;  ib = ib * 5.0;  ic = ic * 5.0;
            end
            
            % Stream the latest single point for instantaneous ingestion
            latestSample = [va(end), vb(end), vc(end), ia(end), ib(end), ic(end)];
            assignin('base', 'hil_telemetry_stream', latestSample);
            
            % Log telemetry paired with ground-truth fault mode safely
            app.DatasetLog = [app.DatasetLog; latestSample, app.CurrentFaultMode];
        end
    end
    methods (Access = public)
        function app = virtual_hil_tx(varargin)
            createComponents(app);
            registerApp(app, app.UIFigure);
            runStartupFcn(app, @(app) startupFcn(app, varargin{:}));
            if nargout == 0
                clear app
            end
        end
        function delete(app)
            if ~isempty(app.TxTimer) && isvalid(app.TxTimer)
                stop(app.TxTimer);
                delete(app.TxTimer);
            end
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end
end