import 'dart:io';

class RootService {
  Future<bool> requestRoot() async {
    try {
      final result = await Process.run('su', ['-c', 'id']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<String> execute(String command) async {
    try {
      // Escape single quotes in command for su -c '...'
      final escapedCommand = command.replaceAll("'", "'\\''");
      final result = await Process.run('su', ['-c', command]);
      if (result.exitCode != 0) {
        throw Exception('Command failed: $command\nStderr: ${result.stderr}');
      }
      return result.stdout.toString().trim();
    } catch (e) {
      throw Exception('Execution failed: $e');
    }
  }

  Future<bool> isRedirected(String packageName) async {
    try {
      final path = '/data/data/$packageName';
      final output = await execute('ls -ld $path');
      // Symlinks start with 'l' in ls -l output: lrwxrwxrwx ...
      return output.startsWith('l');
    } catch (e) {
      return false;
    }
  }

  Future<String?> getRedirectTarget(String packageName) async {
    try {
      final path = '/data/data/$packageName';
      final output = await execute('ls -ld $path');
      if (output.startsWith('l')) {
        // lrwxrwxrwx ... /data/data/com.example -> /target/path
        final parts = output.split('->');
        if (parts.length > 1) {
          return parts[1].trim();
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> redirectAppData(String packageName, String targetPath) async {
    final originalPath = '/data/data/$packageName';
    final newPath = '$targetPath/$packageName';

    // 1. Check if already redirected
    if (await isRedirected(packageName)) {
      throw Exception('App is already redirected.');
    }

    // 2. Stop the app
    await execute('am force-stop $packageName');

    // 3. Create target parent directory if not exists
    await execute('mkdir -p "$targetPath"');

    // 4. Move data
    // Use cp -a to preserve attributes, then rm.
    // Note: If target is on FAT32/exFAT (like some SD cards), permissions/ownership will be lost.
    // This is a known limitation.
    await execute('cp -a "$originalPath" "$newPath"');
    
    // Verify copy
    final checkNew = await execute('ls -d "$newPath"');
    if (checkNew.isEmpty) throw Exception('Failed to copy data to $newPath');

    // 5. Remove original
    await execute('rm -rf "$originalPath"');

    // 6. Create symlink
    await execute('ln -s "$newPath" "$originalPath"');

    // 7. Fix permissions (Attempt to restore context/owner)
    // We should capture owner/context before moving, but since we copied, 
    // we hope cp -a did its job. If not (different fs), we might need manual chown.
    // For now, rely on cp -a.
  }

  Future<void> restoreAppData(String packageName) async {
    final originalPath = '/data/data/$packageName';
    
    if (!await isRedirected(packageName)) {
      throw Exception('App is not redirected.');
    }

    final targetPath = await getRedirectTarget(packageName);
    if (targetPath == null) throw Exception('Could not determine target path.');

    // 1. Stop app
    await execute('am force-stop $packageName');

    // 2. Remove symlink
    await execute('rm "$originalPath"');

    // 3. Move data back
    // We use cp -a again to try to preserve whatever permissions exist
    await execute('cp -a "$targetPath" "$originalPath"');
    
    // 4. Remove target data
    await execute('rm -rf "$targetPath"');

    // 5. Ensure ownership is correct for restored data
    // Since we copied back, owner might be root if running as su.
    // We need to find the app's UID.
    // Usually `dumpsys package packageName` gives userId.
    final dumpsys = await execute('dumpsys package $packageName | grep userId');
    // output: userId=10123
    final userIdMatch = RegExp(r'userId=(\d+)').firstMatch(dumpsys);
    if (userIdMatch != null) {
      final uid = userIdMatch.group(1);
      await execute('chown -R $uid:$uid "$originalPath"');
    }
    
    // Restore context
    // chcon -R u:object_r:app_data_file:s0 "$originalPath"
    // This is a standard context for app data.
    await execute('chcon -R u:object_r:app_data_file:s0 "$originalPath"');
  }
}
