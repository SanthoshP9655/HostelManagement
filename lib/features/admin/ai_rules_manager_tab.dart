import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AIRulesManagerTab extends StatefulWidget {
  const AIRulesManagerTab({super.key});

  @override
  State<AIRulesManagerTab> createState() => _AIRulesManagerTabState();
}

class _AIRulesManagerTabState extends State<AIRulesManagerTab> {
  bool _isUploading = false;
  String? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    final doc = await FirebaseFirestore.instance.collection('hostel_rules').doc('latest').get();
    if (doc.exists) {
      if (mounted) {
        setState(() => _lastUpdated = (doc.data()?['updatedAt'] as Timestamp?)?.toDate().toString());
      }
    }
  }

  Future<void> _uploadPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);

    if (result != null && result.files.single.path != null) {
      setState(() => _isUploading = true);
      
      try {
        final File file = File(result.files.single.path!);
        final String fileName = 'hostel_rules_${DateTime.now().millisecondsSinceEpoch}.pdf';
        
        // 1. Upload to Supabase Bucket 'rules'
        await Supabase.instance.client.storage.from('rules').upload(fileName, file);
        final String publicUrl = Supabase.instance.client.storage.from('rules').getPublicUrl(fileName);
            
        // 2. Update Firestore tracking
        await FirebaseFirestore.instance.collection('hostel_rules').doc('latest').set({
          'fileUrl': publicUrl,
          'fileName': fileName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI Rules Context Updated!')));
        }
        _fetchStatus();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Manage AI Context Elements', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Upload the official hostel PDF. The student AI calculates its answers directly from this assigned document context.'),
          const SizedBox(height: 32),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Colors.blue.withOpacity(0.05),
            leading: const Icon(Icons.description, color: Colors.blue),
            title: const Text('Current Context Rules Document'),
            subtitle: Text('Last Sync: ${_lastUpdated ?? "Never Uploaded"}'),
          ),
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _uploadPDF,
              icon: _isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload),
              label: Text(_isUploading ? 'Validating & Uploading...' : 'Upload New Rules PDF'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
