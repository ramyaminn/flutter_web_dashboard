import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ConfigDashboardApp());
}

class ConfigDashboardApp extends StatelessWidget {
  const ConfigDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboard Config',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: DashboardPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DashboardPage extends StatefulWidget {
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String imageBase64 = '';
  String imageName = '';
  String logoUrl = '';
  String textValue = '';
  bool isLoading = false;
  String message = '';

  Future<void> pickImageFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final bytes = file.bytes!;
      imageBase64 = base64Encode(bytes);
      imageName = file.name;
      setState(() {
        logoUrl = '';
      });
    }
  }

  Future<void> uploadImageAndConfigToGitHub() async {
    setState(() {
      isLoading = true;
      message = '';
    });

    const token = String.fromEnvironment('GITHUB_TOKEN');
    const repo = 'ramyaminn/config-cluewear-com';
    const branch = 'main';


    final imagePath = 'assets/$imageName';
    final configPath = 'config_en.json';
    final imageApiUrl = 'https://api.github.com/repos/$repo/contents/$imagePath';
    final configApiUrl = 'https://api.github.com/repos/$repo/contents/$configPath';
    final rawConfigUrl = 'https://raw.githubusercontent.com/$repo/$branch/$configPath';

    try {
      /// 1. رفع الصورة
      final imageUpload = await http.put(
        Uri.parse(imageApiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "message": "Upload logo image",
          "content": imageBase64,
          "branch": branch,
        }),
      );

      if (imageUpload.statusCode != 201 && imageUpload.statusCode != 200) {
        setState(() {
          message = "❌ فشل رفع الصورة: ${imageUpload.body}";
          isLoading = false;
        });
        return;
      }

      final imageUrl = 'https://raw.githubusercontent.com/$repo/$branch/$imagePath';

      /// 2. تحميل config_en.json من GitHub (raw)
      final configRes = await http.get(Uri.parse(rawConfigUrl));
      if (configRes.statusCode != 200) {
        setState(() {
          message = "❌ فشل تحميل config_en.json: ${configRes.statusCode}";
          isLoading = false;
        });
        return;
      }

      final jsonConfig = jsonDecode(configRes.body);

      /// 3. تعديل عنصر layout: logo فقط
      bool logoFound = false;
      for (var item in jsonConfig['HorizonLayout']) {
        if (item['layout'] == 'logo') {
          item['image'] = imageUrl;
          item['text'] = textValue;
          logoFound = true;
        }
      }

      if (!logoFound) {
        setState(() {
          message = "⚠️ لم يتم العثور على عنصر layout: logo داخل HorizonLayout";
          isLoading = false;
        });
        return;
      }

      /// 4. الحصول على sha من GitHub API
      final getSha = await http.get(
        Uri.parse(configApiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final sha = jsonDecode(getSha.body)['sha'];

      /// 5. رفع الملف المعدل
      final updatedContent = base64Encode(utf8.encode(jsonEncode(jsonConfig)));
      final configUpload = await http.put(
        Uri.parse(configApiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "message": "Update layout: logo image and text",
          "content": updatedContent,
          "sha": sha,
          "branch": branch,
        }),
      );

      if (configUpload.statusCode == 200 || configUpload.statusCode == 201) {
        setState(() => message = "✅ تم تحديث config بنجاح!");
      } else {
        setState(() => message = "❌ فشل رفع config: ${configUpload.body}");
      }
    } catch (e) {
      setState(() => message = "❌ حصل خطأ: $e");
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cluewear Dashboard")),
      body: Center(
        child: SizedBox(
          width: 600,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: pickImageFromDevice,
                  icon: const Icon(Icons.image),
                  label: const Text("اختر صورة من جهازك"),
                ),
                const SizedBox(height: 10),
                if (imageName.isNotEmpty) Text("📎 الصورة المختارة: $imageName"),

                const SizedBox(height: 20),
                TextField(
                  decoration: const InputDecoration(
                    labelText: "نص اللوجو (اختياري)",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => textValue = val,
                ),
                const SizedBox(height: 30),
                isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: uploadImageAndConfigToGitHub,
                        icon: const Icon(Icons.upload),
                        label: const Text("رفع إلى GitHub"),
                      ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: TextStyle(
                    color: message.contains("✅") ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
