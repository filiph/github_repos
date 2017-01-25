// Copyright (c) 2017, filiph. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print("Please provide the name of at least one organization.");
    exit(2);
    return;
  }

  final out = new File("out.csv");

  final orgs = arguments.toList();
  final org = arguments.first;
  String url = _getApiUrl(org);

  bool headerShown = false;
  final flattened = new List<List<Object>>();

  do {
    final response = await http.get(url);

    print(response.body);

    final List<Map<String, Object>> data = JSON.decode(response.body);

    for (var record in data) {
      if (!headerShown) {
        flattened.add(record.keys.toList(growable: false));
        headerShown = true;
      }
      flattened.add(record.values.toList(growable: false));
    }

    url = null;
    for (String link in response.headers['link'].split(',')) {
      if (link.endsWith('rel="next"')) {
        url = _urlInLinkMatcher.firstMatch(link).group(1);
        break;
      }
    }

    if (url == null) {
      orgs.removeAt(0);
      if (orgs.isNotEmpty) {
        url = _getApiUrl(orgs.first);
      }
    }
    print("url = $url");
  } while (url != null);

  await out.writeAsString(_csvEncoder.convert(flattened));
}

const _csvEncoder = const ListToCsvConverter();

/// Matches the URL in github API Link header item.
///
/// Example of such a string:
///
///     <https://api.github.com/organizations/1609975/repos?page=1>; rel="first"
final _urlInLinkMatcher = new RegExp(r"<(.+?)>;");

String _getApiUrl(String org) {
  final url = 'https://api.github.com/orgs/$org/repos';
  return url;
}
