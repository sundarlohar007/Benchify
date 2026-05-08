/// TDD tests for per-process network stats — RED phase.
///
/// Test 1: Parses /proc/pid/net/dev format correctly.
/// Test 2: Computes per-interface TX/RX byte deltas.
/// Test 3: Classifies interfaces: wlan* -> wifi, rmnet* -> cellular, other.
/// Test 4: Returns NetPerProcessResult with correct fields.

use performancebench_sdk;

#[test]
fn test_parse_net_dev_per_process_basic() {
    let content = "Inter-|   Receive                                                |  Transmit\n face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed\nwlan0: 12345678 1000    0    0    0     0          0         0 87654321 800     0    0    0     0       0          0\nrmnet_data0: 55555 50       0    0    0     0          0         0 66666 30      0    0    0     0       0          0\nlo: 10000 20       0    0    0     0          0         0 10000 20      0    0    0     0       0          0";

    let ifaces = performancebench_sdk::metrics::net_per_process::parse_net_dev(content);
    // lo is filtered
    assert_eq!(ifaces.len(), 2, "Expected 2 interfaces (wlan0 + rmnet), got {}", ifaces.len());

    let wlan0 = ifaces.iter().find(|i| i.name == "wlan0").expect("wlan0 not found");
    assert_eq!(wlan0.rx_bytes, 12345678);
    assert_eq!(wlan0.tx_bytes, 87654321);
    assert_eq!(wlan0.rx_packets, 1000);
    assert_eq!(wlan0.tx_packets, 800);
}

#[test]
fn test_parse_net_dev_skips_loopback_and_header() {
    let content = "Inter-|   Receive ...\n face |bytes ...\nlo: 99999 10 0 0 0 0 0 0 88888 5 0 0 0 0 0 0";
    let ifaces = performancebench_sdk::metrics::net_per_process::parse_net_dev(content);
    assert_eq!(ifaces.len(), 0, "Loopback should be filtered");
}

#[test]
fn test_classify_interface_wifi_cellular_other() {
    // We test via the collect interface
    let wifi_iface = performancebench_sdk::metrics::net_per_process::NetInterface {
        name: "wlan0".into(),
        rx_bytes: 1000, rx_packets: 10, tx_bytes: 500, tx_packets: 5,
    };
    let cellular_iface = performancebench_sdk::metrics::net_per_process::NetInterface {
        name: "rmnet_data0".into(),
        rx_bytes: 200, rx_packets: 2, tx_bytes: 100, tx_packets: 1,
    };
    let other_iface = performancebench_sdk::metrics::net_per_process::NetInterface {
        name: "eth0".into(),
        rx_bytes: 300, rx_packets: 3, tx_bytes: 150, tx_packets: 2,
    };

    assert_eq!(performancebench_sdk::metrics::net_per_process::classify_interface(&wifi_iface.name), "wifi");
    assert_eq!(performancebench_sdk::metrics::net_per_process::classify_interface(&cellular_iface.name), "cellular");
    assert_eq!(performancebench_sdk::metrics::net_per_process::classify_interface(&other_iface.name), "other");
}

#[test]
fn test_compute_net_per_process_deltas() {
    let prev = vec![
        performancebench_sdk::metrics::net_per_process::NetInterface {
            name: "wlan0".into(), rx_bytes: 10000, rx_packets: 100, tx_bytes: 5000, tx_packets: 50,
        },
    ];
    let curr = vec![
        performancebench_sdk::metrics::net_per_process::NetInterface {
            name: "wlan0".into(), rx_bytes: 15000, rx_packets: 150, tx_bytes: 8000, tx_packets: 80,
        },
    ];

    let deltas = performancebench_sdk::metrics::net_per_process::compute_deltas(&prev, &curr);
    assert_eq!(deltas.len(), 1);
    assert_eq!(deltas[0].name, "wlan0");
    assert_eq!(deltas[0].rx_delta, 5000);
    assert_eq!(deltas[0].tx_delta, 3000);
}

#[test]
fn test_net_per_process_result_fields() {
    let result = performancebench_sdk::metrics::net_per_process::NetPerProcessResult {
        total_tx: 1000,
        total_rx: 2000,
        wifi_tx: 800,
        wifi_rx: 1500,
        cellular_tx: 200,
        cellular_rx: 500,
        other_tx: 0,
        other_rx: 0,
    };

    assert_eq!(result.total_tx, 1000);
    assert_eq!(result.total_rx, 2000);
    assert_eq!(result.wifi_tx, 800);
    assert_eq!(result.wifi_rx, 1500);
    assert_eq!(result.cellular_tx, 200);
    assert_eq!(result.cellular_rx, 500);
}
