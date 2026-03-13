import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient? _client;

  static SupabaseClient get client {
    _client ??= Supabase.instance.client;
    return _client!;
  }

  // Auth Methods
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await client.auth.signUp(email: email, password: password);
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static User? getCurrentUser() {
    return client.auth.currentUser;
  }

  static Stream<AuthState> authStateChanges() {
    return client.auth.onAuthStateChange;
  }

  // Database Methods
  static Future<List<Map<String, dynamic>>> fetchData({
    required String table,
    String? select,
  }) async {
    try {
      var query = client.from(table).select(select ?? '*');
      return await query;
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }

  static Future<void> insertData({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    try {
      await client.from(table).insert(data);
    } catch (e) {
      throw Exception('Error inserting data: $e');
    }
  }

  static Future<void> updateData({
    required String table,
    required Map<String, dynamic> data,
    required String whereColumn,
    required dynamic whereValue,
  }) async {
    try {
      await client
          .from(table)
          .update(data)
          .eq(whereColumn, whereValue);
    } catch (e) {
      throw Exception('Error updating data: $e');
    }
  }

  static Future<void> deleteData({
    required String table,
    required String whereColumn,
    required dynamic whereValue,
  }) async {
    try {
      await client.from(table).delete().eq(whereColumn, whereValue);
    } catch (e) {
      throw Exception('Error deleting data: $e');
    }
  }

  // Storage Methods
  static Future<String> uploadFile({
    required String bucket,
    required String path,
    required dynamic file,
  }) async {
    try {
      final response = await client.storage.from(bucket).upload(path, file);
      return response;
    } catch (e) {
      throw Exception('Error uploading file: $e');
    }
  }

  static Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    try {
      await client.storage.from(bucket).remove([path]);
    } catch (e) {
      throw Exception('Error deleting file: $e');
    }
  }

  static String getPublicUrl({
    required String bucket,
    required String path,
  }) {
    return client.storage.from(bucket).getPublicUrl(path);
  }
}

