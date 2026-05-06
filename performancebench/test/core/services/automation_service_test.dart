// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/services/automation_service.dart';

/// A fake ADB service that records calls and returns canned responses.
/// This allows us to test AutomationService command construction
/// and response parsing without real ADB.
class _FakeAdbServiceForAutomation {
  final List<_AdbAutomationCall> calls = [];
  final List<String> responseLines = [];
  bool shouldSucceed = true;

  Future<String?> adbShell(String serial, String command,
      {Duration timeout = const Duration(seconds: 3)}) async {
    calls.add(_AdbAutomationCall('shell', serial, command));
    if (!shouldSucceed) return null;

    // Return the first response line if available
    if (responseLines.isNotEmpty) {
      return responseLines.removeAt(0);
    }
    return 'Broadcast completed: result=0';
  }
}

class _AdbAutomationCall {
  final String type;
  final String serial;
  final String command;
  const _AdbAutomationCall(this.type, this.serial, this.command);
}

void main() {
  group('AutomationService', () {
    late _FakeAdbServiceForAutomation fakeAdb;
    late AutomationService service;

    setUp(() {
      fakeAdb = _FakeAdbServiceForAutomation();
      service = AutomationService(
        runShell: fakeAdb.adbShell,
      );
    });

    // ── Test 1: supportedActions contains all 7 commands ──
    test('supportedActions lists all 7 broadcast actions', () {
      expect(AutomationService.supportedActions, hasLength(7));
      expect(AutomationService.supportedActions, contains('START_SESSION'));
      expect(AutomationService.supportedActions, contains('STOP_SESSION'));
      expect(AutomationService.supportedActions, contains('PAUSE'));
      expect(AutomationService.supportedActions, contains('RESUME'));
      expect(AutomationService.supportedActions, contains('MARKER'));
      expect(AutomationService.supportedActions, contains('SCREENSHOT'));
      expect(AutomationService.supportedActions, contains('EXPORT'));
    });

    // ── Test 2: sendCommand constructs correct ADB broadcast intent ──
    test('sendCommand constructs am broadcast with correct action', () async {
      await service.sendCommand(
        deviceSerial: 'emulator-5554',
        action: 'START_SESSION',
        payload: {'session_id': 'abc-123'},
      );

      expect(fakeAdb.calls, isNotEmpty);
      final call = fakeAdb.calls.first;

      expect(call.command, contains('am broadcast'));
      expect(call.command, contains('-a com.benchify.COMMAND'));
      expect(call.command, contains('--es action START_SESSION'));
      expect(call.command, contains('--es payload'));
      expect(call.command, contains('"session_id":"abc-123"'));
    });

    // ── Test 3: sendCommand rejects invalid action ──
    test('sendCommand rejects unsupported action', () async {
      final result = await service.sendCommand(
        deviceSerial: 'emulator-5554',
        action: 'INVALID_ACTION',
        payload: {},
      );

      expect(result, isNull);
    });

    // ── Test 4: sendCommand returns null on ADB failure ──
    test('sendCommand returns null when ADB command fails', () async {
      fakeAdb.shouldSucceed = false;

      final result = await service.sendCommand(
        deviceSerial: 'emulator-5554',
        action: 'PAUSE',
        payload: {},
      );

      expect(result, isNull);
    });

    // ── Test 5: sendCommand parses ADB broadcast result correctly ──
    test('sendCommand parses response from ADB output', () async {
      fakeAdb.responseLines.add(
        'Broadcasting: Intent { act=com.benchify.COMMAND }\n'
        'Broadcast completed: result=0, data="{\\"action\\":\\"PAUSE\\",\\"status\\":\\"ok\\"}"',
      );

      final result = await service.sendCommand(
        deviceSerial: 'emulator-5554',
        action: 'PAUSE',
        payload: {},
      );

      // Since ADB response parsing extracts from the output,
      // the response is parsed from ADB stdout
      expect(result, isNotNull);
    });

    // ── Test 6: addMarker convenience method ──
    test('addMarker sends MARKER command with correct payload', () async {
      await service.addMarker(
        deviceSerial: 'emulator-5554',
        sessionId: 'test-session',
        note: 'boss fight',
      );

      expect(fakeAdb.calls, isNotEmpty);
      final call = fakeAdb.calls.first;
      expect(call.command, contains('--es action MARKER'));
      expect(call.command, contains('"session_id"'));
      expect(call.command, contains('"boss fight"'));
    });

    // ── Test 7: startSession sends START_SESSION command ──
    test('startSession sends START_SESSION command', () async {
      await service.startSession(
        deviceSerial: 'emulator-5554',
        sessionId: 'my-session',
      );

      expect(fakeAdb.calls, isNotEmpty);
      final call = fakeAdb.calls.first;
      expect(call.command, contains('--es action START_SESSION'));
      expect(call.command, contains('"session_id":"my-session"'));
    });

    // ── Test 8: stopSession sends STOP_SESSION command ──
    test('stopSession sends STOP_SESSION command', () async {
      await service.stopSession(
        deviceSerial: 'emulator-5554',
      );

      expect(fakeAdb.calls, isNotEmpty);
      final call = fakeAdb.calls.first;
      expect(call.command, contains('--es action STOP_SESSION'));
    });

    // ── Test 9: screenshot sends SCREENSHOT command with label ──
    test('screenshot sends SCREENSHOT command with label', () async {
      await service.screenshot(
        deviceSerial: 'emulator-5554',
        label: 'death',
      );

      expect(fakeAdb.calls, isNotEmpty);
      final call = fakeAdb.calls.first;
      expect(call.command, contains('--es action SCREENSHOT'));
      expect(call.command, contains('"label"'));
    });

    // ── Test 10: export sends EXPORT command ──
    test('export sends EXPORT command', () async {
      await service.exportSession(
        deviceSerial: 'emulator-5554',
      );

      expect(fakeAdb.calls, isNotEmpty);
      final call = fakeAdb.calls.first;
      expect(call.command, contains('--es action EXPORT'));
    });

    // ── Test 11: deviceSerial is validated ──
    test('sendCommand validates device serial', () async {
      final result = await service.sendCommand(
        deviceSerial: '', // empty serial
        action: 'PAUSE',
        payload: {},
      );

      expect(result, isNull);
    });
  });
}
