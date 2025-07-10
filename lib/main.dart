import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const DashboardApp());

class DashboardApp extends StatelessWidget {
  const DashboardApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Config Dashboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ConfigDashboard(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ConfigDashboard extends StatefulWidget {
  const ConfigDashboard({super.key});
  @override
  State<ConfigDashboard> createState() => _ConfigDashboardState();
}

class _ConfigDashboardState extends State<ConfigDashboard> {
  String? logoUrl;
  List<String> sliderImages = [];
  Color mainColor = Colors.blue;

  final String githubRepo = "ramyaminn/config-cluewear-com";
  final String githubToken = "YOUR_GITHUB_TOKEN_HERE";

  Future<String?> uploadFileToGitHub(html.File file, String fileName) async {
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    await reader.onLoad.first;
    final base64Content = reader.result.toString().split(",").last;

    final url = Uri.parse("https://api.github.com/repos/$githubRepo/contents/main/$fileName");
    final response = await http.put(url,
      headers: {
        'Authorization': 'token $githubToken',
        'Accept': 'application/vnd.github+json',
      },
      body: jsonEncode({
        "message": "Upload $fileName",
        "content": base64Content,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return "https://raw.githubusercontent.com/$githubRepo/main/$fileName";
    } else {
      print("Upload error: ${response.body}");
      return null;
    }
  }

  void pickFile(Function(html.File file) onPicked) {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();
    uploadInput.onChange.listen((_) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        onPicked(files.first);
      }
    });
  }

  void generateAndUploadJson() async {
    final config = {
      "appConfig": {
        "logo": logoUrl ?? "",
        "slider": sliderImages,
        "colors": {"main": "#${mainColor.value.toRadixString(16).substring(2)}"}
      }
    };
    final base64Content = base64Encode(utf8.encode(jsonEncode(config)));
    final url = Uri.parse("https://api.github.com/repos/$githubRepo/contents/main/config_en.json");
    final response = await http.put(url,
      headers: {
        'Authorization': 'token $githubToken',
        'Accept': 'application/vnd.github+json',
      },
      body: jsonEncode({
        "message": "Update config_en.json",
        "content": base64Content,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("config_en.json uploaded!")));
    } else {
      print("Error: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Config Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ElevatedButton(
            onPressed: () {
              pickFile((file) async {
                final url = await uploadFileToGitHub(file, "logo.png");
                if (url != null) setState(() => logoUrl = url);
              });
            },
            child: const Text("Upload Logo"),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              pickFile((file) async {
                final name = "slide${sliderImages.length+1}.png";
                final url = await uploadFileToGitHub(file, name);
                if (url != null) setState(() => sliderImages.add(url));
              });
            },
            child: const Text("Add Slider Image"),
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Text("Main Color: "),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                setState(() {
                  mainColor = mainColor == Colors.blue ? Colors.red : Colors.blue;
                });
              },
              child: Container(width: 30, height: 30, color: mainColor),
            )
          ]),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: generateAndUploadJson,
            child: const Text("Upload config_en.json"),
          ),
        ]),
      ),
    );
  }
}
