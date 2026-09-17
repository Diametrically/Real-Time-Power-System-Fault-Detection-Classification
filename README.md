# Real-Time Power System Fault Detection & Classification (HIL Simulator & ML Dashboard)

[![MATLAB](https://img.shields.io/badge/MATLAB-R2023a%2B-orange.svg)](https://www.mathworks.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Status](https://img.shields.io/badge/Status-Active-success.svg)]()

A comprehensive MATLAB-based **Hardware-in-the-Loop (HIL)** simulation and real-time machine learning classification framework designed for electrical power systems. This project demonstrates automated telemetry transmission, sliding-window RMS feature extraction, and live fault classification across multiple symmetrical and asymmetrical fault scenarios.

---

## 🚀 Key Features

* **Virtual HIL Transmitter (`virtual_hil_tx`)**: Simulates 3-phase voltage and current waveforms ($50\text{ Hz}$) at a $1\text{ kHz}$ effective rate. Allows live fault injection via an interactive GUI:
  * Normal Operation
  * Single Line-to-Ground (LG) Fault — Phase A
  * Line-to-Line (LL) Fault — Phases AB
  * Line-to-Line-to-Ground (LLG) Fault — Phases AB-G
  * Three-Phase Balanced (LLL) Fault
* **Live Fault Classifier Dashboard (`LiveFaultClassifierApp`)**: Real-time MATLAB App Designer UI that streams telemetry from the workspace, maintains a sliding-window buffer, calculates real-time RMS feature vectors, executes an ensemble machine learning model (`predict`), and updates waveform plots, probability distribution bar charts, and fault alarm banners.
* **Offline Dataset Logging & Retraining Pipeline**: Captures ground-truth telemetry logs during active simulations and provides an offline automated pipeline to retrain and update the Random Forest classification model (`trained_fault_model.mat`).

---

## 🛠️ System Architecture
```text 

[ Virtual HIL Transmitter ] ──(Shared Workspace)──> [ Live Fault Classifier App ]
         │                                                      │
         ├─► Generates 3-Phase Waveforms                        ├─► Sliding Window ($0.2\text{ s}$)
         ├─► Injects Fault Scenarios                            ├─► Extracts 6 RMS Features
         └─► Logs Dataset (`hil_logged_dataset.mat`)            └─► Real-time `predict()` & Alarm UI
                                                                        ▲
                                                                        │
[ Offline Training Script ] <─── Retrains Model ────────────────────────┘

```

## 📂 Repository Structure

├── virtual_hil_tx.m             # HIL Transmitter GUI & Data Logging App
├── LiveFaultClassifierApp.m     # Real-Time Monitoring & ML Inference Dashboard
├── train_model.m                # Offline Feature Extraction & Random Forest Training Script
├── trained_fault_model.mat      # Pre-trained Ensemble Classifier Model
└── README.md                    # Project Documentation



⚙️ Installation & Prerequisites
Requirements: MATLAB (R2021a or newer recommended) with the following toolboxes:

Statistics and Machine Learning Toolbox (for fitcensemble, predict, and bagged decision trees)

MATLAB App Designer (for UI execution)

Clone the Repository:

git clone [https://github.com/diametrically/Real-Time-Power-System-Fault-Detection-Classification.git](https://github.com/your-username/Real-Time-Power-System-Fault-Detection-Classification.git)
cd Real-Time-Power-System-Fault-Detection-Classification

🎮 How to Run
Step 1: Launch the Real-Time Classifier Dashboard
Open MATLAB, navigate to the repository folder, and launch the monitoring application:

              LiveFaultClassifierApp.m

Step 2: Launch the Virtual HIL Transmitter
Open a second window or command line instance and run the transmitter:

              virtual_hil_tx.m

Step 3: Simulate Faults
In the Virtual HIL Transmitter window, click START TRANSMISSION.

Click through the various fault buttons (Inject LG Fault, Inject LL Fault, etc.) to observe real-time classification, probability shifts, and alarm banner activations on the Classifier Dashboard.

Click STOP TRANSMISSION to automatically export your session data into hil_logged_dataset.mat.

🔄 Retraining the Model Offline
To retrain the machine learning model using your custom recorded simulation data:

Record a dataset using the transmitter app and stop transmission to save hil_logged_Dataset.mat.

Run the training script in the MATLAB command window:

               train_model.m

Restart LiveFaultClassifierApp to automatically load your newly optimized trained_fault_model.mat.






📜 License
Distributed under the MIT License. See LICENSE for more information.

👤 Author
    Roy-  https://github.com/Diametrically/



