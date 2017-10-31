#!/usr/bin/env python
#---------------------------------------------------------------------
# ADC readout software by using I2C & SiTCP
# Require : Python, python-tk
#           Modules:  matplotlib, pandas
# Last modified:    10/29/2017 by Eunchong Kim
#---------------------------------------------------------------------
import sys
import time
import signal
import socket
import optparse
import datetime

# plot
import matplotlib
import matplotlib.pyplot as plt
import pandas

rd_channels = 11

def send_message(my_socket, send_data):
    my_socket.send(send_data)

def receive_message(my_socket, channels):
    receive_bytes = 4 * channels          # 4 bytes x channels
    return my_socket.recv(receive_bytes)

def optionParser():
    op = optparse.OptionParser()
    op.add_option('-a', '--ip-address', dest='ip_address', 
                  type='string', action='store', default='192.168.10.16', 
                  help='IP address')
    op.add_option('-p', '--port', dest='port', 
                  type='int', action='store', default=24, 
                  help='Port')
    return op

def write_print(file, time, header, data, channels): # file, str, str array, int array, int
    sys.stdout.write('%s  ' % time)
    file.write('%s  ' % time_now )
    for i in range(channels):
        sys.stdout.write('%3s %4d  ' % (header[i],data[i]) )                     
        file.write('%3s %d'% (header[i],data[i]) )
    sys.stdout.write('mV \n')
    file.write('\n')
        

if __name__ == '__main__':
    # TCP connect
    parser = optionParser()
#    if len(sys.argv)==1:
#        parser.print_help()
#        print 'Example: %s -a 192.168.10.16 -p 24' % (sys.argv[0])
#        sys.exit(0)
    opt, args = parser.parse_args()
    host = opt.ip_address
    port = opt.port
    print ('Start the client connecting to host:port=%s:%d ... ' % (host, port) )
    my_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    my_socket.connect( (host, port) )
    print ('Connected!' )

  # Plot style
    plt.grid()
    plt.style.use('ggplot') 
    fig, axes = plt.subplots(nrows=3, ncols=4) # 3 x 4 plots
    plt.xlabel("Time")
    plt.ylabel("Voltage[mV]")

  # Receive Data & Plot
    i = 0
    data_y = [[] for n in range(rd_channels) ]
    start_time = datetime.datetime.now()
    file_name = start_time.strftime('%Y%m%d_%H%M%S') + '.txt'
    file = open(file_name, 'w')
    print ('Start to receive data. \'Ctrl + c \' to avoid.' )
    try:
        while (1):  
            i += 1
            time_now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
          
            rx_data = receive_message(my_socket, rd_channels)
          
            header = []   # String
            data = []     # int
          # ascii to header & data
            for channel in range(rd_channels):
                header.append( rx_data[4*channel] + `ord(rx_data[4*channel+1])` )       # Header
                data.append( ord(rx_data[4*channel+2])*256+ord(rx_data[4*channel+3] ))  # 12bit to int
                data[channel] = data[channel]*2.48/4.096                            # calibration
                channel += 1

            write_print(file, time_now, header, data, rd_channels)
            
          # plot
            if (i > 10):
                start_time = start_time + datetime.timedelta(seconds=1) # shift 1 second
            j = i
            for channel in range(rd_channels):
                data_y[channel].append(data[channel])       # put data to data_y 2d array
                if (i > 10):
                    data_y[channel].pop(0) # delete data at 0
                    j = 10
                index = pandas.date_range( start_time.strftime("%Y-%m-%d %H:%M:%S"), periods=j, freq='S') 
                my_plot = pandas.Series( data_y[channel], index)
                if (i > 1) :
                    #if ( i%600 == 0 ): # clear every 10 min
                    #    plt.close()
                    row = 0
                    column = 0 
                    if (channel < 4):
                        row = 0
                        column = channel
                    elif ( (4 <= channel) & (channel < 8 ) ) :
                        row = 1
                        column = channel - 4
                    else :
                        row = 2
                        column = channel - 8
                    my_plot.plot(ax=axes[row,column] )
                    plt.pause(0.001)
    except KeyboardInterrupt:
        print("W: interrupt received, stopping...")
    finally:
        # clean up
        time.sleep(1)
        my_socket.close()
        file.close()
