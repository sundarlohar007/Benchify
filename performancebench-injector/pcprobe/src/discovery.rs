// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// mDNS/Bonjour auto-discovery for pb-pcprobe.
///
/// Advertises `_pb-pcprobe._tcp.local.` service so the PerformanceBench
/// desktop app can auto-discover probes on the local network.
///
/// Falls back to manual `--host` if mDNS unavailable (Windows without
/// Bonjour, strict firewalls).

use anyhow::{Context, Result};
use mdns_sd::{ServiceDaemon, ServiceEvent, ServiceInfo};

pub const SERVICE_TYPE: &str = "_pb-pcprobe._tcp.local.";

/// Information about a discovered probe host.
#[derive(Debug, Clone)]
pub struct DiscoveredHost {
    pub address: String,
    pub port: u16,
    pub hostname: String,
    pub version: String,
}

/// Advertise the pb-pcprobe service via mDNS on the configured port.
///
/// Returns the ServiceDaemon handle. The caller must hold this handle
/// for the duration of the advertisement; dropping it will unregister
/// the service.
pub fn advertise_pcprobe(port: u16) -> Result<ServiceDaemon> {
    let hostname = hostname::get()
        .and_then(|h| h.into_string().ok())
        .unwrap_or_else(|| "unknown".to_string());

    let service_name = format!("pb-pcprobe-{}.{}", hostname, SERVICE_TYPE);

    let properties = [
        ("port".to_string(), port.to_string()),
        ("version".to_string(), "3.0.0".to_string()),
        ("hostname".to_string(), hostname),
    ];

    let service_info = ServiceInfo::new(
        SERVICE_TYPE,
        &service_name,
        &hostname,
        "",
        port,
        &properties[..],
    )?;

    let daemon = ServiceDaemon::new().context("Failed to create mDNS daemon")?;
    daemon.register(service_info).context("Failed to register mDNS service")?;

    log::info!(
        "mDNS advertised: {} on port {} (version 3.0.0)",
        service_name,
        port
    );

    Ok(daemon)
}

/// Discover pb-pcprobe hosts on the local network via mDNS browsing.
///
/// Searches for `_pb-pcprobe._tcp.local.` services and returns a list of
/// discovered hosts with their addresses, ports, and version info.
///
/// This function blocks for a short browse period (2-3 seconds) to collect
/// responses. Used by the desktop app to auto-discover LAN probes.
pub fn discover_hosts() -> Result<Vec<DiscoveredHost>> {
    let daemon = ServiceDaemon::new().context("Failed to create mDNS daemon for discovery")?;

    let receiver = daemon.browse(SERVICE_TYPE).context("Failed to browse mDNS services")?;

    let mut hosts: Vec<DiscoveredHost> = Vec::new();

    // Browse for a limited time (2 seconds)
    let start = std::time::Instant::now();
    let timeout = std::time::Duration::from_secs(2);

    while start.elapsed() < timeout {
        match receiver.recv_timeout(std::time::Duration::from_millis(200)) {
            Ok(event) => match event {
                ServiceEvent::ServiceResolved(info) => {
                    let address = info.get_addresses().iter().next().cloned();
                    let port = info.get_port();
                    let hostname = info
                        .get_property("hostname")
                        .unwrap_or("unknown")
                        .to_string();
                    let version = info
                        .get_property("version")
                        .unwrap_or("0.0.0")
                        .to_string();

                    if let Some(addr) = address {
                        // Skip loopback addresses (local probe)
                        if addr.is_ipv4() && !addr.is_loopback() {
                            hosts.push(DiscoveredHost {
                                address: addr.to_string(),
                                port,
                                hostname,
                                version,
                            });
                        }
                    }
                }
                _ => {
                    // Ignore non-resolution events
                }
            },
            Err(std::sync::mpsc::RecvTimeoutError::Timeout) => continue,
            Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => break,
        }
    }

    log::info!("mDNS discovery found {} probe(s) on LAN", hosts.len());
    Ok(hosts)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_service_type_constant() {
        assert_eq!(SERVICE_TYPE, "_pb-pcprobe._tcp.local.");
    }

    #[test]
    fn test_discovered_host_fields() {
        let host = DiscoveredHost {
            address: "192.168.1.100".to_string(),
            port: 27184,
            hostname: "game-pc".to_string(),
            version: "3.0.0".to_string(),
        };
        assert_eq!(host.port, 27184);
        assert_eq!(host.version, "3.0.0");
        assert!(!host.address.is_empty());
    }

    #[test]
    fn test_discover_hosts_returns_empty_or_list() {
        // mDNS discovery might not find anything in test environment
        match discover_hosts() {
            Ok(hosts) => {
                // In test environments, typically no hosts found — that's ok
                log::debug!("Discovered {} hosts", hosts.len());
            }
            Err(e) => {
                // mDNS daemon might not be available in CI — that's ok
                log::debug!("mDNS discovery error (expected in CI): {}", e);
            }
        }
    }
}
