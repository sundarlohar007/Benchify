// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/models/keystore_config.dart';

void main() {
  group('KeystoreConfig', () {
    test('creates from constructor', () {
      final config = KeystoreConfig(
        keystorePath: '/path/to/keystore.jks',
        keystorePassword: 'secret',
        keyAlias: 'mykey',
        keyPassword: 'keypass',
      );

      expect(config.keystorePath, '/path/to/keystore.jks');
      expect(config.keystorePassword, 'secret');
      expect(config.keyAlias, 'mykey');
      expect(config.keyPassword, 'keypass');
    });

    test('toJson produces correct map', () {
      final config = KeystoreConfig(
        keystorePath: '/path/to/keystore.jks',
        keystorePassword: 'secret',
        keyAlias: 'mykey',
        keyPassword: 'keypass',
      );

      final json = config.toJson();
      expect(json['keystore_path'], '/path/to/keystore.jks');
      expect(json['keystore_password'], 'secret');
      expect(json['key_alias'], 'mykey');
      expect(json['key_password'], 'keypass');
    });

    test('fromJson parses correctly', () {
      final json = {
        'keystore_path': '/path/to/keystore.jks',
        'keystore_password': 'secret',
        'key_alias': 'mykey',
        'key_password': 'keypass',
      };

      final config = KeystoreConfig.fromJson(json);
      expect(config.keystorePath, '/path/to/keystore.jks');
      expect(config.keystorePassword, 'secret');
      expect(config.keyAlias, 'mykey');
      expect(config.keyPassword, 'keypass');
    });

    test('fromJson handles missing fields gracefully', () {
      final config = KeystoreConfig.fromJson({});
      expect(config.keystorePath, '');
      expect(config.keystorePassword, '');
      expect(config.keyAlias, '');
      expect(config.keyPassword, '');
    });
  });
}
