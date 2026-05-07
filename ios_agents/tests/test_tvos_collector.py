# SPDX-License-Identifier: MIT
# Copyright (c) 2024 PerformanceBench Contributors
#!/usr/bin/env python3
"""Tests for tvos_collector.py — tvOS pyidevice metric collector.

Per 05-02-PLAN Task 2: Test tvOS device discovery, metric collection,
NULL fields for unavailable metrics (battery, cellular).
"""
import json
import os
import sys
import pytest
from unittest.mock import patch, MagicMock

# Add ios_agents to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from tvos_collector import (
    TvosDevice,
    TvosMetricSample,
    discover_devices,
    format_metric_sample,
    NULLABLE_TVOS_FIELDS,
    TVOS_AVAILABLE_CHANNELS,
)


class TestTvosDevice:
    """Tests for tvOS device data model."""

    def test_platform_is_tvos(self):
        """Device platform should be 'tvos'."""
        device = TvosDevice(
            udid="abc123",
            name="Apple TV",
            product_type="AppleTV6,2",
            os_version="18.0",
        )
        assert device.platform == "tvos"

    def test_from_pyidevice_json(self):
        """Should parse pyidevice device JSON correctly."""
        data = {
            "UniqueDeviceID": "abc123def456",
            "DeviceName": "Living Room Apple TV",
            "ProductType": "AppleTV6,2",
            "ProductVersion": "18.0",
            "DeviceClass": "AppleTV",
        }
        device = TvosDevice.from_pyidevice(data)
        assert device.udid == "abc123def456"
        assert device.name == "Living Room Apple TV"
        assert device.product_type == "AppleTV6,2"
        assert device.os_version == "18.0"

    def test_from_pyidevice_minimal(self):
        """Should handle minimal pyidevice output."""
        data = {
            "UniqueDeviceID": "xyz",
            "DeviceClass": "AppleTV",
        }
        device = TvosDevice.from_pyidevice(data)
        assert device.udid == "xyz"
        assert device.name == "Unknown"


class TestDiscoverDevices:
    """Tests for tvOS device discovery."""

    @patch("tvos_collector.subprocess.run")
    def test_discovers_apple_tv(self, mock_run):
        """Should discover Apple TV devices via pyidevice."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps([
                {
                    "UniqueDeviceID": "tv123",
                    "DeviceName": "Living Room Apple TV",
                    "ProductType": "AppleTV6,2",
                    "ProductVersion": "18.0",
                    "DeviceClass": "AppleTV",
                }
            ]),
            stderr="",
        )

        devices = discover_devices()
        assert len(devices) == 1
        assert devices[0].platform == "tvos"
        assert devices[0].name == "Living Room Apple TV"

    @patch("tvos_collector.subprocess.run")
    def test_filters_out_non_apple_tv(self, mock_run):
        """Should filter out devices that are not Apple TV."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps([
                {
                    "UniqueDeviceID": "iphone123",
                    "DeviceName": "iPhone",
                    "ProductType": "iPhone15,2",
                    "ProductVersion": "18.0",
                    "DeviceClass": "iPhone",
                },
                {
                    "UniqueDeviceID": "tv456",
                    "DeviceName": "Apple TV",
                    "ProductType": "AppleTV6,2",
                    "ProductVersion": "18.0",
                    "DeviceClass": "AppleTV",
                },
            ]),
            stderr="",
        )

        devices = discover_devices()
        assert len(devices) == 1
        assert devices[0].platform == "tvos"

    @patch("tvos_collector.subprocess.run")
    def test_empty_on_pyidevice_failure(self, mock_run):
        """Should return empty list when pyidevice fails."""
        mock_run.return_value = MagicMock(
            returncode=1, stdout="", stderr="pyidevice not found"
        )

        devices = discover_devices()
        assert len(devices) == 0

    @patch("tvos_collector.subprocess.run")
    def test_detects_gen_1_2_no_usb_c(self, mock_run):
        """Should flag gen 1/2 Apple TV without USB-C."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps([
                {
                    "UniqueDeviceID": "tv_old",
                    "DeviceName": "Apple TV",
                    "ProductType": "AppleTV5,3",  # Apple TV 4K gen 1 (no USB-C)
                    "ProductVersion": "16.0",
                    "DeviceClass": "AppleTV",
                }
            ]),
            stderr="",
        )

        devices = discover_devices()
        if devices:
            # Gen 1/2 should have a warning about USB-C requirement
            assert any("USB-C" in w for w in devices[0].warnings)


class TestNullableFields:
    """Tests for tvOS metric fields that should always be NULL/None."""

    def test_battery_fields_nullable(self):
        """Battery fields should be in the NULLABLE list."""
        battery_fields = {"battery_pct", "battery_ma", "battery_mv",
                          "battery_temp_c", "charging"}
        assert battery_fields.issubset(NULLABLE_TVOS_FIELDS)

    def test_cellular_fields_nullable(self):
        """Cellular network fields should be in the NULLABLE list."""
        cellular_fields = {"net_cellular_tx_bytes", "net_cellular_rx_bytes"}
        assert cellular_fields.issubset(NULLABLE_TVOS_FIELDS)

    def test_non_nullable_not_in_list(self):
        """FPS, CPU, Memory should NOT be in NULLABLE list."""
        assert "fps" not in NULLABLE_TVOS_FIELDS
        assert "cpu_pct" not in NULLABLE_TVOS_FIELDS
        assert "memory_pss_kb" not in NULLABLE_TVOS_FIELDS


class TestAvailableChannels:
    """Tests for tvOS available metric channels."""

    def test_fps_in_available_channels(self):
        """FPS channel should be in available channels."""
        assert "fps" in TVOS_AVAILABLE_CHANNELS

    def test_cpu_in_available_channels(self):
        """CPU channel should be in available channels."""
        assert "cpu" in TVOS_AVAILABLE_CHANNELS

    def test_battery_not_in_available_channels(self):
        """Battery channel should NOT be in available channels."""
        assert "battery" not in TVOS_AVAILABLE_CHANNELS

    def test_cellular_not_in_available_channels(self):
        """Cellular channel should NOT be in available channels."""
        assert "cellular" not in TVOS_AVAILABLE_CHANNELS
        assert "net_cellular" not in TVOS_AVAILABLE_CHANNELS


class TestFormatMetricSample:
    """Tests for metric sample JSON formatting."""

    def test_nullable_fields_are_none(self):
        """Nullable fields should be explicitly None in output."""
        sample = TvosMetricSample(
            timestamp=1700000000000,
            fps=60.0,
            cpu_pct=25.5,
            memory_pss_kb=250000,
            net_tx_bytes=1000,
            net_rx_bytes=500,
            thermal_status=0,
            gpu_pct=45.0,
        )
        formatted = format_metric_sample(sample)
        assert formatted["battery_pct"] is None
        assert formatted["battery_ma"] is None
        assert formatted["net_cellular_tx_bytes"] is None

    def test_available_fields_populated(self):
        """Available fields should have proper values."""
        sample = TvosMetricSample(
            timestamp=1700000000000,
            fps=60.0,
            cpu_pct=30.0,
            memory_pss_kb=200000,
            net_tx_bytes=1500,
            net_rx_bytes=800,
            thermal_status=1,
            gpu_pct=50.0,
        )
        formatted = format_metric_sample(sample)
        assert formatted["fps"] == 60.0
        assert formatted["cpu"] == 30.0
        assert formatted["mem_bytes"] == 200000 * 1024
        assert formatted["thermal"] == 1

    def test_output_is_valid_json(self):
        """Formatted output should be valid JSON."""
        sample = TvosMetricSample(
            timestamp=1700000000000,
            fps=60.0,
            cpu_pct=30.0,
            memory_pss_kb=200000,
            net_tx_bytes=1000,
            net_rx_bytes=500,
            thermal_status=0,
            gpu_pct=40.0,
        )
        formatted = format_metric_sample(sample)
        json_str = json.dumps(formatted)
        parsed = json.loads(json_str)
        assert parsed["fps"] == 60.0
