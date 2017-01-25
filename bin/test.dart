// Copyright (c) 2017, filiph. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart';

main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print("Please provide the name of the file with the repositories.");
    exit(2);
    return;
  }

  final inFile = new File(arguments.single);

  final dir = await Directory.systemTemp.createTemp("github-repos-test");
  final dirPath = absolute(dir.path);
  log.info("Created temp dir: $dir");

  for (var line in await inFile.readAsLines()) {
    final repoWithOrg = line.trim();
    if (repoWithOrg.isEmpty) {
      continue;
    }
    final repoName = repoWithOrg.split('/').last;
    final cloneUrl = "https://github.com/$repoWithOrg.git";
    log.info("Going to fetch: $cloneUrl");

    {
      final gitCloneResult = await Process.run(
          'git', ['clone', '--depth', '1', cloneUrl],
          workingDirectory: dirPath);
      if (gitCloneResult.exitCode != 0) {
        print("$repoWithOrg,CLONE_ERROR,,");
        log.severe(gitCloneResult.stdout);
        log.severe(gitCloneResult.stderr);
        continue;
      }
    }

    final cloneDirPath = join(dirPath, repoName);

    if (!await new File(join(cloneDirPath, "pubspec.yaml")).exists()) {
      print("$repoWithOrg,NO_PUBSPEC,$cloneDirPath,");
      continue;
    }

    {
      final pubGetResult =
          await Process.run('pub', ['get'], workingDirectory: cloneDirPath);
      await _outputToFile(
          cloneDirPath, "pub_get", pubGetResult.stdout, pubGetResult.stderr);
      if (pubGetResult.exitCode != 0) {
        print("$repoWithOrg,PUB_GET_ERROR,$cloneDirPath,");
        continue;
      }
    }

    if (!await new Directory(join(cloneDirPath, "test")).exists()) {
      print("$repoWithOrg,NO_TESTS,$cloneDirPath,");
      continue;
    }

    {
      final testResult = await Process.run('pub', ['run', 'test'],
          workingDirectory: cloneDirPath);
      await _outputToFile(
          cloneDirPath, "pub_run_test", testResult.stdout, testResult.stderr);
      if (testResult.exitCode != 0) {
        print("$repoWithOrg,TEST_ERROR,$cloneDirPath,");
        continue;
      }
      if (testResult.stdout
          .toString()
          .contains('Could not find package "test".')) {
        print("$repoWithOrg,STILL_ON_UNITTEST,$cloneDirPath,");
        continue;
      }
      if (testResult.stdout.toString().trim() == "No tests ran.") {
        final browserTestResult = await Process.run(
            'pub', ['run', 'test', '-p', 'dartium'],
            workingDirectory: cloneDirPath);
        await _outputToFile(cloneDirPath, "pub_run_test",
            browserTestResult.stdout, browserTestResult.stderr);
        if (testResult.exitCode != 0) {
          print("$repoWithOrg,TEST_ERROR_DARTIUM,$cloneDirPath,");
          continue;
        }
        if (browserTestResult.stdout.toString().trim() == "No tests ran.") {
          print("$repoWithOrg,NO_TESTS_RAN,$cloneDirPath,");
          continue;
        }
      }
    }

    print("$repoWithOrg,FINE,$cloneDirPath,");
  }
}

/// Logger for the testing script.
final log = new Logger("github-repos test");

Future<Null> _outputToFile(
    String dirPath, String filename, String stdout, String stderr) async {
  final stdoutFile = new File(join(dirPath, "$filename.stdout.txt"));
  await stdoutFile.writeAsString(stdout);
  final stderrFile = new File(join(dirPath, "$filename.stderr.txt"));
  await stderrFile.writeAsString(stderr);
  return;
}
