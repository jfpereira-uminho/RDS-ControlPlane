
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800;
const bit<8> TYPE_TCP  = 0x06;
const bit<8> TYPE_UDP  = 0x11;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/


typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;


header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset; 
    bit<3>  res;
    bit<3>  ecn;       
    bit<6>  ctrl;       
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}



struct metadata {
    ip4Addr_t   next_hop_ipv4;
}

struct headers {
    ethernet_t   ethernet;
    ipv4_t       ipv4;
    tcp_t        tcp;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
 
    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }
    
    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }

}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {   
    apply { /* do nothing */  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    counter(8192, CounterType.packets) c;

                  
    action drop() {
        mark_to_drop(standard_metadata);
    }

   
    action ipv4_fwd(ip4Addr_t nxt_hop, egressSpec_t port) {
        meta.next_hop_ipv4 = nxt_hop;
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
        c.count((bit<32>) 1);
    }

    table ipv4_lpm {
        key = { hdr.ipv4.dstAddr : lpm; }
        actions = {
            ipv4_fwd;
            drop;
            NoAction;
        }
        default_action = drop;
    }

    action rewrite_src_mac(macAddr_t src_mac) {
        hdr.ethernet.srcAddr = src_mac;
    }

    table src_mac {
        key = { standard_metadata.egress_spec : exact; }
        actions = {
            rewrite_src_mac;
            drop;
        }
        default_action = drop;
    }

    action rewrite_dst_mac(macAddr_t dst_mac) {
        hdr.ethernet.dstAddr = dst_mac;
    }

    table dst_mac {
        key = { meta.next_hop_ipv4 : exact; }
        actions = {
            rewrite_dst_mac;
            drop;
        }
        default_action = drop;
    }
    
    
    apply {
        if (hdr.ipv4.isValid()) {
            ipv4_lpm.apply();
            src_mac.apply();
            dst_mac.apply();
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { /* do nothing */ }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
    /* this recalculates the checksum */
    apply {
	update_checksum(
	    hdr.ipv4.isValid(),
            { hdr.ipv4.version,
	          hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);   
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
