#!/usr/bin/env python3

from mininet.net import Mininet
from mininet.topo import Topo
from mininet.log import setLogLevel, info
from mininet.cli import CLI
from mininet.node import OVSKernelSwitch

from p4_mininet import P4Switch, P4Host
from p4runtime_switch import P4RuntimeSwitch

import subprocess
import argparse
from time import sleep


class SimpleRouter(Topo):
    def __init__(self, sw_path, thrift_port, grpc_port, **opts):
        # Initialize topology and default options
        Topo.__init__(self, **opts)
        # adding a P4Switch
        
        r1 = self.addSwitch('r1',
                        cls = P4RuntimeSwitch,
                        sw_path = sw_path,
                        #json_path = json_path,
                        thrift_port = thrift_port,
                        grpc_port = grpc_port,
                        device_id = 1,
                        cpu_port = 510)
        r2 = self.addSwitch('r2',
                        cls = P4RuntimeSwitch,
                        sw_path = sw_path,
                        #json_path = json_path,
                        thrift_port = thrift_port+1,
                        grpc_port = grpc_port+1,
                        device_id = 2,
                        cpu_port = 510)


         # switchs
        s1 = self.addSwitch('s1', cls = OVSKernelSwitch)
        s2 = self.addSwitch('s2', cls = OVSKernelSwitch)

        h11 = self.addHost('h11', ip = "10.0.1.10/24", mac="00:aa:00:00:01:01")
        h12 = self.addHost('h12', ip = "10.0.1.20/24", mac="00:aa:00:00:01:02")

        h21 = self.addHost('h21', ip = "10.0.2.10/24", mac="00:aa:00:00:02:01")
        h22 = self.addHost('h22', ip = "10.0.2.20/24", mac="00:aa:00:00:02:02")

        self.addLink(h11, s1)
        self.addLink(h12, s1)
        self.addLink(s1, r1, port2=1, addr2="00:bb:bb:00:01:01")

        self.addLink(h21, s2)
        self.addLink(h22, s2)
        self.addLink(s2, r2, port2=1, addr2="00:bb:bb:00:02:01")

        self.addLink(r1, r2, port1=2, port2=2, addr1="00:bb:bb:00:01:02", addr2="00:bb:bb:00:02:02")

def main():
    parser = argparse.ArgumentParser(description='Mininet demo')
    parser.add_argument('--behavioral-exe', help='Path to behavioral executable',
                        type=str, action="store", default='simple_switch_grpc')
    parser.add_argument('--thrift-port', help='Thrift server port for table updates',
                        type=int, action="store", default=9091)
    parser.add_argument('--grpc-port', help='gRPC server port for controller comm',
                        type=int, action="store", default=50051)
    #parser.add_argument('--json', help='Path to JSON config file',
    #                    type=str, action="store", required=True)

    args = parser.parse_args()



    topo = SimpleRouter(args.behavioral_exe,
                        args.thrift_port,
                        args.grpc_port)
                        #args.json)

    # the host class is the P4Host
    # the switch class is the P4Switch
    net = Mininet(topo = topo,
                  host = P4Host,
                  #switch = P4Switch,
                  controller = None)

    # Here, the mininet will use the constructor (__init__()) of the P4Switch class, 
    # with the arguments passed to the SingleSwitchTopo class in order to create 
    # our software switch.
    net.start()


    h11 = net.get("h11")
    h11.setARP("10.0.1.254", "00:bb:bb:00:01:01")
    h11.setDefaultRoute("dev eth0 via 10.0.1.254")

    h12 = net.get("h12")
    h12.setARP("10.0.1.254", "00:bb:bb:00:01:01")
    h12.setDefaultRoute("dev eth0 via 10.0.1.254")


    h21 = net.get("h21")
    h21.setARP("10.0.2.254", "00:bb:bb:00:02:01")
    h21.setDefaultRoute("dev eth0 via 10.0.2.254")

    h22 = net.get("h22")
    h22.setARP("10.0.2.254", "00:bb:bb:00:02:01")
    h22.setDefaultRoute("dev eth0 via 10.0.2.254")


    sleep(1)  # time for the host and switch confs to take effect

    subprocess.call("sudo ovs-ofctl add-flow s1 actions=normal", shell=True)
    subprocess.call("sudo ovs-ofctl add-flow s2 actions=normal", shell=True)
    

    print("Ready !")

    CLI( net )
    net.stop()

if __name__ == '__main__':
    setLogLevel( 'info' )
    main()
