# ADC readout 

ADC readout firmware & software for KC705 by using I2C and SiTCP. 

## About ADC readout firmware

Readout ADC data via I2C. max to 4 bytes per channels, max to 15channels.

Use Vivado and import these:

* **constrs_1**   - constraints sources
* **sim_1**       - Simulation TestBanch sources
* **sources_1**   - Verilog-HDL sources


## About ADC readout software

in the directory of software:

* **install.py**     - install python and modules (for ubuntu)
* **ADC_readout.py**  - software to receive data via SiTCP, and to monitor

python and python module matplotlib, pandas are required.

to use ADC_readout.py, type

```
python ADC_readout.py
```

### demo

use demo mode to check software's behavior

```
sudo python ADC_readout.py -m demo
```

In demo mode, a TCP server created and produce random data between 0 to 4095 then send to client.
