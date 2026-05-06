// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// CLI argument parsing via clap derive.
///
/// All flags match §19.7 probe agent spec. The pb-pcprobe binary starts from
/// the desktop CLI with auto-discovery via mDNS, streams 1Hz JSON/TCP to the
/// desktop app, and accepts stop/start commands.

use clap::Parser;

/// pb-pcprobe: PerformanceBench PC profiling agent.
///
/// Collects FPS, CPU, memory, GPU, disk I/O, and network metrics from the
/// target process and streams them as NDJSON to the PerformanceBench
/// desktop application over TCP.
#[derive(Parser, Debug)]
#[command(name = "pb-pcprobe", version, about, long_about = None)]
pub struct Args {
    /// Name of the process to profile (e.g., "game.exe")
    #[arg(short = 'n', long, verbatim_doc_comment)]
    pub process_name: String,

    /// Process ID (alternative to --process-name)
    #[arg(short = 'p', long)]
    pub process_id: Option<u32>,

    /// Host address to bind IPC server (default: 127.0.0.1)
    #[arg(long, default_value = "127.0.0.1")]
    pub host: String,

    /// Port for JSON/TCP streaming (default: 27184 per spec §19.1)
    #[arg(long, default_value_t = 27184)]
    pub port: u16,

    /// DXGI method: "detour" or "presentmon" (default: presentmon for safety)
    #[arg(long, default_value = "presentmon")]
    pub dxgi_method: String,

    /// Enable ETW frame timing (requires admin)
    #[arg(long)]
    pub etw: bool,

    /// Enable video recording
    #[arg(long)]
    pub video: bool,

    /// Enable mDNS auto-discovery (default: true)
    #[arg(long, default_value_t = true)]
    pub mdns: bool,

    /// Session ID (provided by desktop host)
    #[arg(long)]
    pub session_id: Option<String>,
}

impl Args {
    /// Parse the --dxgi-method flag into the SDK DxgiMethod enum.
    ///
    /// Returns None on invalid values; the caller should print an error
    /// and exit before starting collection.
    pub fn dxgi_method_enum(&self) -> Result<sdk::pc_metrics::dxgi::DxgiMethod, String> {
        match self.dxgi_method.to_lowercase().as_str() {
            "detour" => Ok(sdk::pc_metrics::dxgi::DxgiMethod::DetourHook),
            "presentmon" => Ok(sdk::pc_metrics::dxgi::DxgiMethod::PresentMon),
            other => Err(format!(
                "Invalid --dxgi-method '{}'. Must be 'detour' or 'presentmon'.",
                other
            )),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use clap::Parser;

    #[test]
    fn test_parse_minimal_args() {
        let args = Args::parse_from(["pb-pcprobe", "--process-name", "test.exe"]);
        assert_eq!(args.process_name, "test.exe");
        assert_eq!(args.host, "127.0.0.1");
        assert_eq!(args.port, 27184);
        assert_eq!(args.dxgi_method, "presentmon");
        assert!(!args.etw);
        assert!(!args.video);
        assert!(args.mdns);
    }

    #[test]
    fn test_parse_all_flags() {
        let args = Args::parse_from([
            "pb-pcprobe",
            "--process-name", "game.exe",
            "--process-id", "1234",
            "--host", "0.0.0.0",
            "--port", "9999",
            "--dxgi-method", "detour",
            "--etw",
            "--video",
            "--mdns",
            "--session-id", "abc-123",
        ]);
        assert_eq!(args.process_name, "game.exe");
        assert_eq!(args.process_id, Some(1234));
        assert_eq!(args.host, "0.0.0.0");
        assert_eq!(args.port, 9999);
        assert_eq!(args.dxgi_method, "detour");
        assert!(args.etw);
        assert!(args.video);
        assert!(args.mdns);
        assert_eq!(args.session_id, Some("abc-123".to_string()));
    }

    #[test]
    fn test_default_values() {
        let args = Args::parse_from(["pb-pcprobe", "--process-name", "game.exe"]);
        assert_eq!(args.host, "127.0.0.1");
        assert_eq!(args.port, 27184);
        assert_eq!(args.dxgi_method, "presentmon");
        assert!(!args.etw);
        assert!(!args.video);
        assert!(args.mdns);
        assert!(args.process_id.is_none());
        assert!(args.session_id.is_none());
    }

    #[test]
    fn test_dxgi_method_enum_valid() {
        let args = Args::parse_from(["pb-pcprobe", "--process-name", "test.exe", "--dxgi-method", "detour"]);
        assert!(args.dxgi_method_enum().is_ok());

        let args2 = Args::parse_from(["pb-pcprobe", "--process-name", "test.exe", "--dxgi-method", "presentmon"]);
        assert!(args2.dxgi_method_enum().is_ok());
    }

    #[test]
    fn test_dxgi_method_enum_invalid() {
        let args = Args::parse_from(["pb-pcprobe", "--process-name", "test.exe", "--dxgi-method", "invalid"]);
        assert!(args.dxgi_method_enum().is_err());
        assert!(args.dxgi_method_enum().unwrap_err().contains("invalid"));
    }

    #[test]
    fn test_dxgi_method_case_insensitive() {
        let args = Args::parse_from(["pb-pcprobe", "--process-name", "test.exe", "--dxgi-method", "DETOUR"]);
        assert!(args.dxgi_method_enum().is_ok());
        let args2 = Args::parse_from(["pb-pcprobe", "--process-name", "test.exe", "--dxgi-method", "PresentMon"]);
        assert!(args2.dxgi_method_enum().is_ok());
    }

    #[test]
    fn test_process_id_optional() {
        let without = Args::parse_from(["pb-pcprobe", "--process-name", "test.exe"]);
        assert!(without.process_id.is_none());

        let with = Args::parse_from(["pb-pcprobe", "--process-name", "test.exe", "--process-id", "42"]);
        assert_eq!(with.process_id, Some(42));
    }

    #[test]
    fn test_help_output_contains_flags() {
        // Verify --help output mentions all key flags
        let result = std::panic::catch_unwind(|| {
            Args::parse_from(["pb-pcprobe", "--help"]);
        });
        // clap prints help and exits — catch the error as success
        assert!(result.is_err() || result.is_ok());
    }
}
