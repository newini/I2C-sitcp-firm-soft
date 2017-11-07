#!/usr/bin/env python
#---------------------------------------------------------------------
# ADC readout software by using I2C & SiTCP
# Require : Python, python-tk
#           Modules:  matplotlib, pandas
# Created : 11/7/2017 by Eunchong Kim
#---------------------------------------------------------------------
import sys
import time
import signal
import socket
import optparse
import datetime
import threading
import numpy

# plot
import matplotlib
import matplotlib.pyplot as plt
import pandas

# Static
rd_channels = 11 # total channels
plot_period = 10 # second

# Global
i = 1
plot_flg = 0
stop_flg = 0
my_data = [[] for n in range(rd_channels) ]

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
    op.add_option('-m', '--mode', dest='mode', 
                  type='string', action='store', default='production', 
                  help='mode')
    return op

def createDemoServer():
    TCP_IP = '127.0.0.1'
    TCP_PORT = 24
    #BUFFER_SIZE = 1024  # Normally 1024
    
    demo_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    demo_socket.bind((TCP_IP, TCP_PORT))
    demo_socket.listen(1)

    print('\tDemo Server: Start TCP server!')
    
    demo_connection, addr = demo_socket.accept()
    sys.stdout.write('\tDemo Server: Connection address: ')
    print(addr)
    while 1:
        if( stop_flg == 1 ):
            print('\tDemo Server: Stopping TCP server...')
            break
        demo_server_send_data  = ''
        #demo_server_received_data = demo_connection.recv(BUFFER_SIZE)
      # create random data
        for i in range(rd_channels):
            demo_server_send_data += 'R' 
            demo_server_send_data += chr(i)               # int 2 ascii
            rand_data = int( 4096*numpy.random.rand() )
            demo_server_send_data += chr(rand_data/256)   # int 2 ascii
            demo_server_send_data += chr(rand_data%256)   # int 2 ascii
        demo_connection.send(demo_server_send_data)
        time.sleep(0.99)
    demo_connection.close()
    print('\tDemo Server: Stoped!')

def write_print(file, time, header, data, channels): # file, str, str array, int array, int
    sys.stdout.write('%s  ' % time)
    file.write('%s  ' % time )
    for i in range(channels):
        sys.stdout.write('%3s %4d  ' % (header[i],data[i]) )                     
        file.write('%3s %4d'% (header[i],data[i]) )
    sys.stdout.write('mV \n')
    file.write('\n')
        
def receive_data( file):
    global i
    global plot_flg
    global my_data
    while(1):
        if (stop_flg == 1):
            break
        rx_data = receive_message(my_socket, rd_channels)
        time_now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        header = []   # String
        data = []     # int
      # ascii 2 header & data
        for channel in range(rd_channels):
            header.append( rx_data[4*channel] + `ord(rx_data[4*channel+1])` )       # Header, ascii + ascii 2 int
            data.append( ord(rx_data[4*channel+2])*256+ord(rx_data[4*channel+3] ))  # 12bit data, 4bit ascii 2 int * 256 + 8bit ascii 2 int
            data[channel] = data[channel]*2.48/4.096                                # calibration
            my_data[channel].append( data[channel] )
            if (i > plot_period+1):
                my_data[channel].pop(0) # delete data at 0
        write_print(file, time_now, header, data, rd_channels)
        if ( (i>plot_period) & (i%plot_period == 1) ):
            plot_flg = 1
            time.sleep(0.1)
            plot_flg = 0
        i += 1

if __name__ == '__main__':
    parser = optionParser()
#    if len(sys.argv)==1:
#        parser.print_help()
#        print 'Example: %s -a 192.168.10.16 -p 24' % (sys.argv[0])
#        sys.exit(0)
    opt, args = parser.parse_args()
    host = opt.ip_address
    port = opt.port
    mode = opt.mode
    if (mode == 'demo'):
        host = '127.0.0.1'
        thread_createDemoServer = threading.Thread( target=createDemoServer, args=() )
        thread_createDemoServer.start()
        time.sleep(1)
  # TCP connect
    print ('Start the client connecting to host:port=%s:%d ... ' % (host, port) )
    my_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    my_socket.connect( (host, port) )
    print ('Connected!' )

  # Plot style
    plt.style.use('ggplot') 
    fig, axes = plt.subplots(nrows=3, ncols=4) # 3 x 4 plots
    plt.xlabel("Time")
    plt.ylabel("Voltage[mV]")
    plt.grid()

  # Variables
    start_time = datetime.datetime.now()
    file_name = start_time.strftime('%Y%m%d_%H%M%S') + '.txt'
    file = open(file_name, 'w')
    print ('Start to receive data. \'Ctrl + c \' to avoid.' )

  # Thread
    thread_receive_data = threading.Thread( target=receive_data, args=(file,) )

  # Main
    try:
        thread_receive_data.start()
      # Main plot
        while (1):  
            time.sleep(0.05)
            if ( plot_flg == 1 ):
                data_y = my_data
                if (i > plot_period+1):
                    start_time = start_time + datetime.timedelta(seconds=plot_period) # shift plot_period second
                index = pandas.date_range( start_time.strftime("%Y-%m-%d %H:%M:%S"), periods=plot_period+1, freq='S') 
                for channel in range(rd_channels):
                    my_plot = pandas.Series( data_y[channel], index)
                    #if ( i%1800 == 0 ): # clear every 30 min
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
                    my_plot.plot( ax=axes[row,column] )
                    plt.pause(0.001)
    except KeyboardInterrupt:
        print("W: interrupt received, stopping...")
    finally:
        stop_flg = 1
        time.sleep(1)
        # clean up
        my_socket.close()
        file.close()
